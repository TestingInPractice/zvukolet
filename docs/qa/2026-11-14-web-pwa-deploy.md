# QA: деплой PWA на GitHub Pages

Дата: 2026-11-14
Задача: публикация web-сборки как PWA (продолжение `docs/qa/2026-11-14-web-pwa.md`)
Хостинг: GitHub Pages, репозиторий `TestingInPractice/zvukolet`, источник `gh-pages` / `/`
Живой адрес: `https://testinginpractice.github.io/zvukolet/`

## Что проверяли

Что web-сборка опубликована как устанавливаемое офлайн-PWA: страница на живом HTTPS
отдаёт приложение, все ассеты доступны с верными типами, манифест и service worker
подхватываются, и что офлайн-перезагрузка работает после **одного** онлайн-визита.

## Как публиковали

```bash
# исходники (код + web/PWA) на main
git add -A && git commit -m "feat: MVP Звуколёт с web-экспортом и PWA"
git push origin main                       # f2359a0..976b462

# сборка в отдельную ветку gh-pages (как у azbuka), затем пуш
# (первый пуш упал на HTTP 400; повтор с HTTP/1.1 и большим postBuffer прошёл)
git -c http.postBuffer=524288000 -c http.version=HTTP/1.1 push origin gh-pages:gh-pages
```

Источник Pages переключён вручную: Settings -> Pages -> Source: `gh-pages` / `/`.

Офлайн-харденинг: Godot-SW не вызывает `clients.claim()` и кэширует `index.wasm` /
`index.pck` только через fetch, поэтому офлайн требовал двух онлайн-загрузок. Патч
`tools/patch_pwa_service_worker.py` дописывает в `index.service.worker.js` два
слушателя (`install`: `skipWaiting()`; `activate`: `clients.claim()` + backfill
`CACHEABLE_FILES`), после чего офлайна достаточно одного онлайн-визита. Патч
идемпотентен (маркер `zvukolet-pwa-patch`), backfill обычно берёт файлы из HTTP-кэша,
поэтому 37 МБ повторно по сети не тянутся.

## Команды проверки

```bash
curl -s https://testinginpractice.github.io/zvukolet/            # HTML загрузчика
for f in index.js index.wasm index.pck index.manifest.json index.service.worker.js; do
  curl -s -o /dev/null -w "$f %{http_code} %{content_type}\n" \
    "https://testinginpractice.github.io/zvukolet/$f"
done
```

Плюс Playwright (Chromium headless): один онлайн-визит, ожидание `serviceWorker.ready`,
backfill, затем `context.setOffline(true)` и `reload()`.

## Наблюдения

- Pages: `status=built`, `source.branch=gh-pages`, `source.path=/`,
  `html_url=https://testinginpractice.github.io/zvukolet/`.
- Живой `index.html`: заголовок `Звуколёт`, есть canvas, `index.js`, скрипт
  `__godotAudioCtx`.
- Типы ассетов: `index.js` 200 `application/javascript`; `index.wasm` 200
  `application/wasm`; `index.pck` 200 `application/octet-stream`; `index.manifest.json`
  200 `application/json`; `index.service.worker.js` 200 `application/javascript`;
  `index.144x144.png` 200 `image/png`.
- Манифест: `name` `Звуколёт`, `display` `standalone`, `orientation` `portrait`,
  `background_color` `#f5f0e8`, иконки 144/180/512.
- Живой `index.service.worker.js` содержит маркер патча `zvukolet-pwa-patch`.
- Playwright (живой HTTPS): визит 1 - canvas 540x1170, заголовок `Звуколёт`,
  ошибок страницы нет. После одного визита в кэше
  `Звуколёт-sw-cache-...` лежат все 9 файлов: `index.html`, `index.js`,
  `index.offline.html`, `index.icon.png`, `index.apple-touch-icon.png`,
  `index.audio.worklet.js`, `index.audio.position.worklet.js`, `index.pck`,
  `index.wasm`.
- Офлайн-перезагрузка после одного визита: canvas поднимается, заголовок
  `Звуколёт`, ошибок нет. До патча та же проверка отдавала страницу
  `You are offline`.

## Почему этого достаточно

Доказано, что PWA реально опубликовано и работает на живом HTTPS: приложение
стартует, все ассеты отдаются с корректными MIME-типами (включая
`application/wasm`, нужный для потоковой компиляции), манифест и service worker
активны, а офлайн-режим наступает после одного онлайн-визита - ключевое свойство
для детского офлайн-приложения. Проверка выполнена на том же хосте и по тому же
URL, что увидит пользователь.

## Что не покрыто

- Установка PWA на домашний экран iOS/Android и запуск как standalone: проверено
  частично (манифест + SW), ручная установка на реальном устройстве - вне этой
  проверки.
- iOS Safari и реальный мобильный браузер (аудио по жесту пользователя).
- Реальный тест с 3-5 родителями: #263.

## Изоляция и секреты

- QA на живом публичном URL, без доступа к `user://` и без записи в реальные
  данные. Локальные проверки шли через `http://localhost:8123`.
- Токен GitHub в командах пушa не печатался (маскировался); в артефактах и
  документе секретов нет.
- Сборка `build/web/` и ветка `gh-pages` не содержат keystore или ключей.

## Артефакты

- Скриншот офлайна (живой): `/tmp/zvukolet_live_offline.png`
- Скриншоты онлайн/офлайн (локально): `/tmp/zvukolet_live_qa_online.png`,
  `/tmp/zvukolet_live_qa_offline.png`
- Скрипты проверки: `/tmp/zvukolet_live_offline.js`, `/tmp/zvukolet_sw_local.js`
- Коммиты: `main` `976b462`; `gh-pages` `18b2742` (первый деплой),
  `992cefb` (патч SW).
- Патч: `tools/patch_pwa_service_worker.py`
