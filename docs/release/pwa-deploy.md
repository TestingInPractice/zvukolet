# Деплой PWA на GitHub Pages

Дата: 2026-11-14
Область: web-сборка Звуколёт и публикация на GitHub Pages.

## 1. Сборка

```bash
godot --headless --path . --import
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

Результат в `build/web/`: `index.html`, `index.js`, `index.wasm`, `index.pck`,
`index.manifest.json`, `index.service.worker.js`, `index.audio.worklet.js`,
`index.audio.position.worklet.js`, `index.offline.html`, иконки. Каталог `build/`
в `.gitignore`.

Параметры пресета `Web` в `export_presets.cfg`:

- threads выключены (`variant/thread_support=false`): GitHub Pages не отдаёт
  заголовки COOP/COEP, а с threads без них SharedArrayBuffer не работает;
- PWA включён (`progressive_web_app/enabled=true`), режим `standalone`,
  ориентация портрет;
- в `html/head_include` добавлен скрипт возобновления `AudioContext` по жесту
  пользователя (иначе звук в Web молчит).

## 2. Локальная проверка

```bash
cd build/web && python3 -m http.server 8123
```

Открыть `http://localhost:8123/index.html`. Проверить: приложение стартует,
манифест доступен, service worker регистрируется, консоль без ошибок. Подробно:
`docs/qa/2026-11-14-web-pwa.md`.

## 3. Публикация на GitHub Pages

Сайт: `https://testinginpractice.github.io/zvukolet/`.

Ветка `gh-pages` содержит файлы из `build/web` плюс пустой файл `.nojekyll`
(чтобы GitHub Pages не обрабатывал файлы через Jekyll).

```bash
# Собрать и подготовить ветку
git worktree add /tmp/zvukolet-gh-pages gh-pages   # или создать ветку с нуля
cp -R build/web/. /tmp/zvukolet-gh-pages/
touch /tmp/zvukolet-gh-pages/.nojekyll
git -C /tmp/zvukolet-gh-pages add -A
git -C /tmp/zvukolet-gh-pages commit -m "deploy: web pwa build"
```

Пуш выполняется токеном из `~/.config/github-tokens.json` (см. скилл github-push),
токен в git config не хранится:

```bash
git -c credential.helper= push https://TestingInPractice:<TOKEN>@github.com/TestingInPractice/zvukolet.git gh-pages
```

После пуша включить GitHub Pages: Settings -> Pages -> Source: ветка `gh-pages`,
корень `/`. Через минуту открыть `https://testinginpractice.github.io/zvukolet/`.

## 4. Проверка после деплоя

- Страница открывается по HTTPS (нужен для service worker).
- В DevTools -> Application виден манифест и активный service worker.
- Доступна установка PWA на домашний экран.
- После первого визита приложение открывается офлайн (перезагрузка без сети).

## 5. Ограничения

- Первая загрузка требует интернет: WASM около 38 МБ. Дальше работает офлайн из
  кэша service worker.
- GitHub Pages не даёт настраивать заголовки, поэтому threads выключены.
- Обновление сборки: повторить шаги 1 и 3, закоммитить в `gh-pages` и запушить.
