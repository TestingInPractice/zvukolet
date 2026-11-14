# Звуколёт

Офлайн-тренажёр минимальных пар для домашней практики с детьми 3-6 лет.

Первый контраст: `ш-с`.

Продукт помогает родителю провести короткое занятие (3-5 минут), в котором
ребёнок учится различать похожие слова на слух и в речи. Приложение не ставит
диагноз, не заменяет логопеда и не обещает постановку звука.

## Требования

- Godot 4.x (разрабатывается и проверяется на 4.6).

## Запуск

Из редактора:

1. Открыть Godot 4.x.
2. Import -> выбрать `project.godot` в корне репозитория.
3. Нажать Play (F5). Запускается главная сцена `scenes/main.tscn`.

Из командной строки (проверка импорта и запуска без окна):

```bash
godot --headless --path . --import
godot --headless --path . --quit
```

## Структура

```
project.godot        настройки проекта (имя, версия, ориентация, масштаб)
scenes/              сцены Godot, главная сцена scenes/main.tscn
scenes/constructor/  экраны конструктора наборов
scripts/core/        ядро: контент, наборы, формат .zvset, логирование
scripts/modes/       логика игровых режимов
scripts/ui/          элементы интерфейса
content/             встроенный контент (контрасты, пары, наборы)
assets/              иллюстрации, аудио, UI-тема
tools/               вспомогательные скрипты (заглушки медиа)
tests/               тесты проекта (headless-раннер)
docs/                продуктовая и техническая документация
```

## Конструктор наборов

Конструктор позволяет собрать собственный набор минимальных пар:

- выбрать контраст;
- включить нужные пары;
- создать, переименовать и удалить свой набор;
- экспортировать набор в файл `.zvset` и импортировать его.

Встроенный контент доступен только для чтения. Пользовательские наборы
хранятся в `user://custom_sets.json` и `user://custom_sets/<id>/`.

Формат файла набора и модель данных: `docs/design/content-model.md`.

## Тесты

```bash
godot --headless --path . tests/test_runner.tscn
```

Раннер проверяет загрузку контента, хранилище наборов, экспорт и импорт
`.zvset`, валидацию манифеста и создание экранов. Выход 0, если всё прошло.

## Сборка для Android

Android первый таргет MVP. Проект уже настроен: `export_presets.cfg` содержит
пресет `Android`, а `project.godot` включает портретную ориентацию и импорт
текстур ETC2/ASTC (без него Android-экспорт падает).

Что нужно один раз:

1. Установить шаблоны экспорта Godot 4.6 (Editor -> Manage Export Templates).
2. Установить Android SDK с build-tools, platform-tools и платформой.
3. Указать в Editor Settings пути к Android SDK и Java SDK (Android -> SDK Path,
   Java SDK Path). Для debug-сборки Godot использует собственный debug-keystore.
4. Приложение использует debug-подпись; релизный keystore в репозиторий не
   попадает (см. `.gitignore`).

Сборка debug APK из командной строки:

```bash
godot --headless --path . --import
godot --headless --path . --export-debug "Android" builds/android/zvukolet.apk
```

Результат: `builds/android/zvukolet.apk`. Каталог `builds/` в `.gitignore` и в
репозиторий не попадает.

Параметры сборки: package `com.zvukolet.app`, version code `1`, version name
`0.1.0`, minSdk 24, arm64-v8a.

Установка на устройство (нужен подключённый телефон с включённой отладкой):

```bash
adb install -r builds/android/zvukolet.apk
```

Секретов в репозитории нет: keystore и пароли не коммитятся.

## Сборка для Web (PWA)

Звуколёт собирается в web и публикуется как устанавливаемое офлайн-PWA. Пресет
`Web` в `export_presets.cfg` включает встроенный PWA-режим Godot (манифест и
service worker для офлайна). Threads выключены: GitHub Pages не отдаёт заголовки
COOP/COEP, а с threads без них SharedArrayBuffer не работает.

Сборка:

```bash
godot --headless --path . --import
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
```

Результат в `build/web/`. Каталог `build/` в `.gitignore`.

Локальная проверка:

```bash
cd build/web && python3 -m http.server 8123
```

Открыть `http://localhost:8123/index.html`.

Публикация и проверка на GitHub Pages: `docs/release/pwa-deploy.md`. QA сборки:
`docs/qa/2026-11-14-web-pwa.md`.

## Документация

- `docs/product/mvp-brief.md`: продукт, сценарий, границы MVP.
- `docs/design/content-model.md`: модель контента и формат `.zvset`.
- `docs/plans/mvp-task-breakdown.md`: дерево задач и подробные описания.
- `docs/research/govorun-competitor-analysis.md`: конкурентный анализ.
- `docs/plans/session-handoff.md`: состояние проекта для новой сессии.

## Границы MVP

- один контраст `ш-с`, 5-10 пар;
- три режима: `послушай и выбери`, `повтори за взрослым`, `назови картинку`;
- конструктор наборов с экспортом и импортом `.zvset`;
- Android first, офлайн;
- без ASR, камеры, аккаунтов, подписки и клинических процентов;
- SLP-ревью контента до релиза.

## Ограничения

- Не коммитить и не деплоить без явного запроса.
- Не использовать em dash, en dash и emoji в документах и коде.
- Не трогать пользовательские файлы в `user://`.
