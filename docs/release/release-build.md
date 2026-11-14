# Сборка релизного APK: Звуколёт

Дата: 2026-11-14
Задача: Vikunja #260
Область: воспроизводимая релизная сборка Android.

## 1. Что уже готово

- `export_presets.cfg` содержит пресет `Android` (package `com.zvukolet.app`,
  arm64-v8a, портрет, launcher-иконки).
- `project.godot` включает портретную ориентацию, `import_etc2_astc=true` и
  `config/icon`.
- Debug APK собирается и проверен (задача #240).
- Релизная сборка проверена как proof-of-concept: `--export-release` собирает
  подписанный APK (см. `docs/qa/2026-11-14-release-apk.md`).

## 2. Что нужно от владельца

Релизный APK подписывается постоянным ключом. Это идентичность приложения в
магазине: её нельзя менять после публикации. Поэтому keystore создаёт и хранит
владелец, а не репозиторий.

Что сделать один раз:

1. Создать keystore:

```bash
keytool -genkeypair -v \
  -keystore zvukolet-release.keystore \
  -alias zvukolet \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Zvukolet, O=<организация>, C=RU"
```

2. Хранить keystore и пароли ВНЕ репозитория (менеджер секретов). В репозиторий
   keystore не попадает: он в `.gitignore`.

3. В Godot: Project -> Export -> Android -> вкладка Keystore -> указать Release
   Keystore, Release User и пароли. Поля запишутся в `export_presets.cfg`, но
   коммитить их с путём и паролем нельзя. Для CI использовать секреты.

## 3. Сборка релиза

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Android" builds/android/zvukolet-release.apk
```

Результат: `builds/android/zvukolet-release.apk` (каталог `builds/` в
`.gitignore`).

## 4. Проверка APK

```bash
AAPT2=/path/to/android-sdk/build-tools/<ver>/aapt2
APKSIGNER=/path/to/android-sdk/build-tools/<ver>/apksigner

"$AAPT2" dump badging builds/android/zvukolet-release.apk
"$APKSIGNER" verify --verbose builds/android/zvukolet-release.apk
```

Ожидание: package `com.zvukolet.app`, versionCode `1`, versionName `0.1.0`,
minSdk 24, targetSdk 36, label `Звуколёт`, native-code `arm64-v8a`, подпись v2 и
v3 true.

## 5. Установка на чистое устройство

```bash
adb install -r builds/android/zvukolet-release.apk
```

Проверка установки и запуска на чистом устройстве: задача #256.

## 6. Релизная чистота

- `config/dev_mode` в релизе не должен влиять на поведение: проверить перед
  публикацией.
- Debug-логи и отладочные оверлеи не должны быть видны ребёнку.
- В APK не должно быть тестовых наборов и секретов.
- Иконка и label заданы (задача #240).

## 7. Ограничения

- Keystore и пароли не коммитятся.
- Релизная подпись создаётся владельцем: без неё публикация невозможна.
- Сборка `--export-release` требует наличия релизных шаблонов экспорта Godot.
