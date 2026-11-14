# QA: релизная сборка APK (proof-of-concept)

Дата: 2026-11-14
Задача: Vikunja #260
Сборка: Godot 4.6.3.stable, Java 23, build-tools 34.0.0

## Что проверяли

Что релизный экспорт Android (`--export-release`) собирает подписанный APK,
который устанавливается на устройство, и что релизный путь сборки воспроизводим
документально.

## Метод

1. Создан временный keystore вне репозитория (`keytool`, RSA 2048).
2. Поля keystore добавлены в `export_presets.cfg` только на время сборки.
3. Выполнен `godot --headless --path . --export-release "Android"
   builds/android/zvukolet-release.apk`.
4. APK проверен через `aapt2 dump badging` и `apksigner verify`.
5. Поля keystore убраны из `export_presets.cfg`: секрет и его путь в репозиторий
   не попадают.

## Наблюдения

- Сборка: `RELEASE_EXPORT_EXIT=0`, `[ DONE ] export`, `Signed`.
- Файл: `builds/android/zvukolet-release.apk`, 26.2 МБ (debug: 27.9 МБ).
- Манифест: package `com.zvukolet.app`, versionCode `1`, versionName `0.1.0`,
  minSdk 24, targetSdk 36, label `Звуколёт`, native-code `arm64-v8a`.
- Подпись: `Verified using v2 scheme: true`, `v3 scheme: true`, signer
  `CN=Zvukolet Test, OU=QA, O=TestingInPractice, L=Moscow, C=RU`.
- `export_presets.cfg` после проверки не содержит полей keystore.

## Почему этого достаточно

Proof-of-concept доказывает, что релизный путь сборки работает для этого
проекта: релизный шаблон есть, экспорт проходит, APK подписан и корректен по
манифесту. Полный процесс воспроизводимой релизной сборки описан в
`docs/release/release-build.md`.

## Что не покрыто

- Релизный APK подписан временным ключом, а не постоянным ключом владельца.
  Постоянный keystore создаёт владелец: это идентичность приложения в магазине.
  Без него публикация невозможна.
- Установка на чистое устройство и запуск: задача #256.
- Публикация в RuStore: задача #262.

## Артефакты

- Лог keytool: `/tmp/zvukolet_keytool.log`
- Лог экспорта: `/tmp/zvukolet_release_export.log`
- APK (временный, gitignored): `builds/android/zvukolet-release.apk`
