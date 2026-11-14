# План: PWA через web-экспорт Godot

Дата: 2026-11-14
Цель: выпустить Звуколёт как устанавливаемое офлайн-PWA, хостинг GitHub Pages.

## Подход

Переиспользуем весь текущий проект Godot 4.6. Добавляем web-пресет экспорта и
встроенный PWA-режим Godot (манифест + service worker для офлайна). Threads
выключаем: GitHub Pages не отдаёт заголовки COOP/COEP, а с threads без них
SharedArrayBuffer не работает. Используем шаблон `web_nothreads_release.zip`.

## Шаги

1. Иконки PWA: `assets/icons/icon-144.png`, `icon-180.png`, `icon-512.png`
   (из `icon.png` 512x512), генератор `tools/generate_pwa_icons.py`.
2. Web-пресет в `export_presets.cfg` (`[preset.1]`, name="Web"):
   - `variant/thread_support=false`;
   - `html/head_include` со скриптом возобновления `AudioContext` по жесту и
     apple-mobile-web-app мета;
   - `progressive_web_app/enabled=true`, display=1 (standalone),
     orientation=2 (портрет), иконки 144/180/512, цвет фона из темы.
3. Экспорт: `godot --headless --path . --export-release "Web" build/web/index.html`.
4. `.gitignore`: добавить `build/`.
5. Локальная проверка: поднять `python3 -m http.server` в `build/web`, открыть
   через Playwright, проверить манифест, регистрацию service worker, загрузку
   приложения и отсутствие ошибок в консоли. QA: `docs/qa/2026-11-14-web-pwa.md`.
6. Документы: `docs/release/pwa-deploy.md` (сборка и деплой), раздел про Web/PWA
   в `README.md`.
7. Деплой на GitHub Pages: ветка `gh-pages` с файлами экспорта и `.nojekyll`,
   пуш в `TestingInPractice/zvukolet` (по явному запросу владельца).

## Проверка

- `godot --headless --path . --import` -> 0.
- `godot --headless --path . --export-release "Web" build/web/index.html` -> 0.
- В `build/web` есть: `index.html`, `index.js`, `index.wasm`, `index.pck`,
  `index.manifest.json`, `index.service.worker.js`, `index.audio.worklet.js`,
  иконки.
- Playwright: приложение грузится, canvas есть, service worker активен, консоль
  без ошибок.
- Автотесты проекта: 103 проверки, 0 ошибок.

## Ограничения и риски

- Вес первой загрузки: WASM около 30-40 МБ, нужен интернет для первой загрузки,
  дальше офлайн из кэша service worker.
- iOS Safari: установка PWA ограничена, но приложение работает во вкладке.
- Аудио в Web стартует только после жеста пользователя: стартовый экран с
  кнопкой это обеспечивает, плюс скрипт в `head_include` возобновляет контекст.
- GitHub Pages: без COOP/COEP, поэтому threads выключены.

## Ограничения проекта

- Не использовать em dash, en dash и emoji.
- Не коммитить и не деплоить без явного запроса.
- Не трогать пользовательские файлы в `user://`.
