# QA: Android-экспорт и тестовая сборка (#240)

Дата: 2026-11-14
Задача: настроить Android-экспорт и собрать debug APK.

## Что тестировали

- `godot --headless --path . --import`.
- `godot --headless --path . --export-debug "Android" builds/android/zvukolet.apk`.
- Проверка APK: `aapt2 dump badging`, `apksigner verify --print-certs`.
- `godot --headless --path . tests/test_runner.tscn` (96 проверок).

## Что наблюдали

- Импорт: код 0.
- Экспорт: код 0, `[ DONE ] export`, создан `builds/android/zvukolet.apk`
  (примерно 27.9 МБ) и `.idsig`.
- Манифест: package `com.zvukolet.app`, versionCode 1, versionName 0.1.0,
  minSdk 24, targetSdk 36, label `Звуколёт`, arm64-v8a, launcher-иконки во всех
  плотностях.
- Подпись: Android Debug (`CN=Android Debug`), проверка `apksigner verify`
  прошла.
- Тесты: `проверок: 96, ошибок: 0`.

## Что нашли и исправили по пути

- Пустой ошибки конфигурации при экспорте: Android-экспорт требует включённого
  импорта текстур ETC2/ASTC. Добавили
  `rendering/textures/vram_compression/import_etc2_astc=true` в `project.godot`.
- Отсутствие иконки приложения: добавили заглушку `icon.png` и подключили её в
  `project.godot` и в пресете экспорта.
- Переопределение minSdk доступно только при сборке через Gradle. Оставили
  шаблонную сборку, minSdk берётся из шаблона (24).

## Почему этого достаточно

- APK собирается, подписан debug-ключом и содержит игру и arm64-библиотеку
  Godot, значит артефакт пригоден для установки на устройство.
- Манифест подтверждает package, версию, minSdk и label.
- Секретов в репозитории нет: keystore и `builds/` в `.gitignore`.

## Что опустили

- Установку и запуск на реальном устройстве (нет подключённого телефона).
  Проверка на устройстве в задачах #256 и #257.
- Релизную подпись и публикацию в RuStore.
- Скриншоты экранов на устройстве.
