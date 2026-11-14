# Звуколёт: handoff для новой сессии

Дата: 2026-11-14
Проект: `Звуколёт`
Репозиторий: `TestingInPractice/zvukolet`
Локальная папка: `zvukolet`
Ветка: `main`

## Что читать первым

1. `docs/plans/session-handoff.md` - этот файл.
2. `docs/product/mvp-brief.md` - продукт, сценарий, границы MVP.
3. `docs/plans/mvp-task-breakdown.md` - дерево задач и подробные описания.
4. `docs/plans/mvp-task-breakdown.json` - машиночитаемая декомпозиция.
5. `docs/research/govorun-competitor-analysis.md` - конкурентный анализ.

## Продукт

`Звуколёт` - офлайн-тренажёр минимальных пар для домашней практики с детьми 3-6 лет.

Первый контраст: `ш-с`.

MVP:
- 5-10 пар;
- три режима: `послушай и выбери`, `повтори за взрослым`, `назови картинку`;
- занятие 3-5 минут;
- роль взрослого: запуск, помощь, отметка результата;
- Android первый;
- офлайн;
- без ASR, камеры, аккаунтов и подписки;
- без клинических обещаний;
- SLP-ревью до релиза.

Не входит в MVP:
- автоматическая оценка речи;
- постановка звука;
- диагностика;
- облачная синхронизация;
- iOS;
- социальные функции.

## Где ведётся работа

Vikunja:
- URL: `http://192.168.0.206:3456`
- проект: `#18` `Звуколёт`
- родительская задача: `#225`
- задачи MVP: `#226`-`#263`

Корневые задачи:
- `#226` Зафиксировать MVP и критерии релиза
- `#230` Подготовить контент контраста ш-с
- `#235` Собрать технический скелет Godot-проекта
- `#241` Подготовить иллюстрации, аудио и UI-тему
- `#245` Реализовать игровое ядро минимальных пар
- `#250` Сделать локальный прогресс и родительский экран
- `#254` Провести QA MVP на Android
- `#259` Подготовить релизный пакет MVP

Связи:
- 38 parent-subtask;
- 46 blocked;
- всего 84;
- проверено: 84 существуют, 0 ошибок, 0 циклов.

## Текущий статус

Сделано:
- MVP brief: `docs/product/mvp-brief.md` (обновлён: конструктор наборов в MVP).
- Детальная декомпозиция: `docs/plans/mvp-task-breakdown.json` и `.md`.
- 38 задач созданы в Vikunja.
- Все 38 описаний обновлены подробными планами.
- `#227` Описать MVP, сценарий и границы - done.
- Конкурентный анализ Govorun: `docs/research/govorun-competitor-analysis.md`.
- Имя репозитория подтверждено: `zvukolet`. `zvukarik` отдаёт 404. Не переименовывать.
- `#236` Godot-проект инициализирован: `project.godot`, `scenes/main.tscn`, `.gitignore`, `README.md`.
- Модель контента и формат `.zvset`: `docs/design/content-model.md`.
- Встроенный контент `ш-с`: `content/contrasts.json`, `content/pairs/sh_s.json` (10 пар-кандидатов), `content/sets/builtin_sh_s.json`.
- Заглушки медиа: `tools/generate_stub_media.py`, 20 PNG и 20 WAV в `assets/`.
- Ядро: `scripts/core/` (`content_repository`, `custom_sets_store`, `set_repository`, `set_package_format`, `set_package_archive`, `set_package_exporter`, `set_package_importer`, `app_logger`).
- Конструктор: `scripts/ui/set_editor.gd`, `scripts/ui/set_list.gd`, `scenes/constructor/*.tscn`, авто-загрузки в `project.godot`.
- Навигация и экраны MVP: `scripts/core/navigation.gd` (авто-загрузка), `scripts/ui/screen_style.gd`, `scripts/ui/start_screen.gd`, `scripts/ui/mode_select.gd`, `scripts/ui/game_screen.gd`, `scripts/ui/session_summary.gd`, сцены `scenes/main.tscn`, `scenes/mode_select.tscn`, `scenes/game.tscn`, `scenes/session_summary.tscn`.
- Аудио-менеджер: `scripts/core/audio_manager.gd` (авто-загрузка), один голос за раз, очередь или отмена, отдельные плееры для SFX и музыки, громкость по каналам, тихий отказ на отсутствующем файле.
- Сохранение: `scripts/core/save_manager.gd` (авто-загрузка), `user://progress.json` и `user://settings.json`, версия схемы, атомарная запись, отказ на повреждённом файле.
- Игровое ядро: `scripts/core/session_controller.gd` (сессия: порядок пар, счёт попыток и верных ответов, завершение), `scripts/modes/mode_base.gd` (базовый режим: прогресс, инструкция, картинки, ответы, повтор, закончить), `scripts/modes/listen_choose.gd`, `scripts/modes/repeat_after_adult.gd`, `scripts/modes/name_picture.gd`, сцены `scenes/modes/*.tscn`. Игровой экран подгружает выбранный режим, экран итога показывает попытки и верные ответы.
- Прогресс и родительский экран: `scripts/core/progress_store.gd` (срез по парам и режимам, последнее занятие, сброс), запись режима в `SaveManager.record_mode`, `scripts/ui/parent_screen.gd` и `scenes/parent_screen.tscn` (пары, ошибки, режимы, последнее занятие, пояснение `это не диагностика`), `scripts/ui/settings.gd` и `scenes/settings.tscn` (громкость, включение звука, сброс прогресса с подтверждением), кнопка `Родителям` на стартовом экране.
- UI-тема: `assets/ui/theme.tres` (палитра, состояния кнопок, скругления) подключена в `project.godot` как `gui/theme/custom`, иконки режимов и возврата в `assets/ui/icons/*.svg`, сборка темы `tools/build_ui_theme.gd`, спека `docs/design/ui-spec.md`, помощники в `scripts/ui/screen_style.gd`.
- Звуки интерфейса: `scripts/core/sfx_library.gd` (`SfxLibrary`), четыре SFX в `assets/audio/sfx/`, генератор `tools/generate_stub_sfx.py`, спека `docs/design/sfx-spec.md`, подключение через `ScreenStyle.wire_click` и `ModeBase`.
- Android-экспорт: `export_presets.cfg` (пресет `Android`, package `com.zvukolet.app`, arm64-v8a, launcher-иконки), `project.godot` (портрет, `import_etc2_astc=true`, `config/icon`), заглушка иконки `tools/generate_app_icon.py`, debug APK собирается в `builds/android/zvukolet.apk`, команда сборки в `README.md`.
- Пакет для SLP-ревью: `docs/content/slp-review.md` (пары, спорные пары, сценарии, тексты, вопросы, блок заключения). Ждёт подписи логопеда.
- Экран `О проекте`, privacy и дисклеймер: `scripts/ui/about_screen.gd`, `scenes/about_screen.tscn`, кнопка `О проекте` на родительском экране, `docs/legal/privacy.md`, `docs/legal/disclaimer.md`.
- QA-план MVP: `docs/qa/mvp-qa-plan.md`. Офлайн: `docs/qa/offline-check.md` + автотест на отсутствие сетевых вызовов. Сценарии режимов: `docs/design/mode-scenarios.md`. Метрики: `docs/product/mvp-metrics.md`. Риски: `docs/product/mvp-risks.md`.
- Релиз: `docs/release/release-build.md` (процесс сборки), `docs/release/rustore-card.md` (черновик карточки), QA `docs/qa/2026-11-14-release-apk.md` (релизный APK собран временным ключом, proof-of-concept).
- Индекс QA evidence: `docs/qa/README.md`.
- Headless-тесты: `tests/test_runner.gd` и `.tscn`, 103 проверки, выход 0.
- QA evidence: `docs/qa/2026-11-14-content-and-constructor.md`, `docs/qa/2026-11-14-navigation-and-screens.md`, `docs/qa/2026-11-14-audio-manager.md`, `docs/qa/2026-11-14-save-manager.md`, `docs/qa/2026-11-14-game-core.md`, `docs/qa/2026-11-14-parent-screen.md`, `docs/qa/2026-11-14-ui-theme.md`, `docs/qa/2026-11-14-sfx.md`, `docs/qa/2026-11-14-android-export.md`, `docs/qa/2026-11-14-about-screen.md`, `docs/qa/2026-11-14-release-apk.md`, `docs/qa/offline-check.md`.

Не сделано (внешние или зависящие от человека шаги):
- SLP-ревью пар `ш-с` (пакет готов, нужна подпись логопеда; пары помечены `candidate`).
- Реальные записи аудио (#233) и финальные иллюстрации (#242) вместо заглушек.
- Установка и прогон APK на реальном устройстве (#256) и QA evidence по устройству (#258).
- Релизный APK с постоянным keystore владельца (#260) и публикация в RuStore (#262).
- Тест с 3-5 родителями (#263).

Git:
- Проект новый, много файлов untracked.
- Перед началом работы проверить `git status`.
- Не коммитить и не деплоить без явного запроса.

## Следующий шаг

Все задачи, выполнимые без человека и без устройства, закрыты. Осталось:

1. `#242` Финальные иллюстрации для 10 пар (нужен художник или генерация и ревью).
2. `#233` Реальные записи аудио для пар (нужна запись и обработка).
3. `#234` SLP-ревью: пакет `docs/content/slp-review.md` готов, нужна подпись логопеда.
4. `#256` и `#258` QA на реальном Android-устройстве и evidence по устройству.
5. `#260` Релизный APK с постоянным keystore владельца (процесс: `docs/release/release-build.md`).
6. `#262` Публикация карточки RuStore (черновик: `docs/release/rustore-card.md`).
7. `#263` Тест с 3-5 родителями.

Закрыты: `#226`, `#228`, `#229`, `#232`, `#235`, `#236`-`#240`, `#243`-`#250`,
`#251`-`#253`, `#255`, `#257`, `#261`, `#262`, `#264`. Открытые эпики закрываются,
когда закроются их внешние подзадачи.

## Ограничения

- Не использовать em dash, en dash и emoji в документах и коде.
- Не коммитить и не деплоить без явного запроса.
- Не трогать пользовательские файлы: `user://custom_sets.json`, `user://custom_sets/`, `user://progress.json`, `user://analytics/events.jsonl`.
- Не менять имя репозитория и продукта без подтверждения.
- Не добавлять ASR, камеру, аккаунты, подписку и клинические проценты в v1.
- Не использовать чужие логотипы, персонажи и лицензионные ассеты.
- Параллельно в `../azbuka/azbuka-src` есть незакоммиченный audio remap. Не трогать.

## Викунья: практические заметки

- API: `http://192.168.0.206:3456/api/v2`.
- Задачи проекта: `GET /api/v2/projects/18/tasks`.
- Обновление описания: `PATCH /api/v2/tasks/<ID>` с `{description: ...}`.
- Вложения: `POST /api/v2/tasks/<ID>/attachments`, multipart/form-data, поле `files`.
- Не печатать токены и пароли в чат и файлы.

## Skill и автоматизация

Скилл `vikunja-breakdown` находится в локальной конфигурации OpenCode. Если он не виден в новой сессии, использовать скрипт напрямую:

`~/.config/opencode/skills/vikunja-breakdown/scripts/vikunja_breakdown.py`

Скрипт уже умеет:
- создавать задачи;
- обновлять описания;
- создавать связи;
- обрабатывать `detail`, 409 cycle, 409 existing, 5xx retry и пустой 400.

## Стартовый prompt для новой сессии

Скопировать в новую сессию:

```text
Продолжаем проект Звуколёт.

Сначала прочитай:
1. docs/plans/session-handoff.md
2. docs/product/mvp-brief.md
3. docs/plans/mvp-task-breakdown.md

Затем проверь git status.

Следующий шаг: задачи #242 (финальные иллюстрации), #234 (SLP-ревью, пакет готов, нужна подпись), #255-#258 (QA MVP), #259-#262 (релизный пакет). UI-тема, звуки интерфейса и Android-экспорт с debug APK готовы, headless-тесты проходят, 96 проверок.

Не коммить и не деплой без явного запроса. Не используй em dash, en dash и emoji.
```

## Критерий готовности handoff

Новая сессия должна без дополнительных вопросов понять:
- что за продукт;
- где репозиторий;
- где Vikunja;
- что уже сделано;
- что делать дальше;
- какие ограничения нельзя нарушать.
