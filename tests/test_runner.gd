extends Node
## Headless-раннер проверок контента, хранилища, формата набора и сцен.
##
## Запуск:
##   godot --headless --path . tests/test_runner.tscn
## Выход 0, если все проверки прошли, и 1 при любой ошибке.
##
## Проверки работают в изолированном каталоге user://zvukolet_test, поэтому не
## трогают пользовательские наборы.

const TEST_DIR := "user://zvukolet_test"
const TEST_STORE := "user://zvukolet_test/custom_sets.json"
const TEST_SETS_DIR := "user://zvukolet_test/sets"
const TEST_EXPORT := "user://zvukolet_test/export.zvset"
const TEST_PROGRESS := "user://zvukolet_test/progress.json"
const TEST_SETTINGS := "user://zvukolet_test/settings.json"

const NETWORK_TOKENS := [
	"HTTPClient", "HTTPRequest", "WebSocketPeer", "StreamPeerTCP",
	"PacketPeerUDP", "TCPServer", "UDPServer", "StreamPeerTLS",
	"WebSocketClient", "WebSocketServer", "connect_to_host",
	"http://", "https://",
]

var _checks: int = 0
var _failures: int = 0
var _set_id: String = ""


func _ready() -> void:
	_prepare_isolation()
	_run_content_tests()
	_run_custom_store_tests()
	_run_package_tests()
	_run_format_tests()
	_run_scene_tests()
	_run_navigation_tests()
	_run_audio_tests()
	_run_sfx_tests()
	_run_save_tests()
	_run_session_tests()
	_run_mode_tests()
	_run_progress_tests()
	_run_parent_screen_tests()
	_run_settings_tests()
	_run_about_screen_tests()
	_run_offline_tests()
	_cleanup()
	_report()
	get_tree().quit(1 if _failures > 0 else 0)


func _prepare_isolation() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SETS_DIR))
	CustomSetsStore.save_path = TEST_STORE
	CustomSetsStore.sets_dir = TEST_SETS_DIR
	CustomSetsStore.reload()
	CustomSetsStore.clear_all()
	SaveManager.progress_path = TEST_PROGRESS
	SaveManager.settings_path = TEST_SETTINGS
	SaveManager.reload()


func _run_content_tests() -> void:
	_check(ContentRepository.is_loaded(), "контрасты загружены")
	_check(ContentRepository.get_contrasts().size() >= 1, "есть хотя бы один контраст")
	var pairs := ContentRepository.get_pairs("sh_s")
	_check(pairs.size() >= 5, "пар в контрасте ш-с не меньше пяти")
	var playable := SetRepository.get_playable_pairs("builtin_sh_s")
	_check(playable.size() == 10, "встроенный набор даёт 10 пар")
	var all_words := true
	for pair in playable:
		if str(pair.get("word_a", "")).is_empty() or str(pair.get("word_b", "")).is_empty():
			all_words = false
	_check(all_words, "у каждой пары набора есть оба слова")


func _run_custom_store_tests() -> void:
	var record := CustomSetsStore.create_set("Тест", "sh_s")
	_set_id = str(record.get("id", ""))
	_check(not _set_id.is_empty(), "набор создан")
	_check(CustomSetsStore.has_set(_set_id), "набор есть в хранилище")
	var pair := ContentRepository.get_pair("sh_s_01")
	_check(CustomSetsStore.add_pair(_set_id, "sh_s_01", pair), "пара добавлена в набор")
	_check(CustomSetsStore.pair_count(_set_id) == 1, "в наборе одна пара")
	CustomSetsStore.rename_set(_set_id, "Тест 2")
	_check(str(CustomSetsStore.get_set(_set_id).get("name", "")) == "Тест 2", "набор переименован")


func _run_package_tests() -> void:
	var exported := SetPackageExporter.export_to_path(_set_id, TEST_EXPORT)
	_check(bool(exported.get("ok", false)), "набор экспортирован в .zvset")
	var imported := SetPackageImporter.import_path(TEST_EXPORT)
	_check(bool(imported.get("ok", false)), "набор импортирован из .zvset")
	var new_id := str(imported.get("set_id", ""))
	_check(not new_id.is_empty(), "у импортированного набора есть id")
	_check(CustomSetsStore.pair_count(new_id) == 1, "в импортированном наборе одна пара")
	var new_pair := CustomSetsStore.get_pair(new_id, "sh_s_01")
	_check(str(new_pair.get("image_a", "")).begins_with("user://"), "медиа импортированного набора лежит в user://")


func _run_format_tests() -> void:
	var bad := SetPackageFormat.validate_manifest({"format": "nope"}, {})
	_check(not bool(bad.get("ok", false)), "чужой формат отклонён")
	var manifest := SetPackageFormat.build_manifest("Имя", "sh_s", [{"id": "p1", "word_a": "а", "word_b": "б"}])
	var good := SetPackageFormat.validate_manifest(manifest, {})
	_check(bool(good.get("ok", false)), "минимальный манифест без медиа валиден")


func _run_scene_tests() -> void:
	var list_scene := load("res://scenes/constructor/set_list.tscn") as PackedScene
	var list := list_scene.instantiate() as SetList
	add_child(list)
	_check(list.get_row_count() >= 1, "список наборов показывает созданные наборы")
	list.queue_free()

	var editor_scene := load("res://scenes/constructor/set_editor.tscn") as PackedScene
	var editor := editor_scene.instantiate() as SetEditor
	add_child(editor)
	editor.open_set(_set_id)
	_check(editor.get_included_pair_ids().size() == 1, "редактор видит включённую пару")
	editor.queue_free()


func _run_audio_tests() -> void:
	_check(AudioManager.has_method("play_voice"), "аудио-менеджер доступен")
	_check(AudioManager.play_voice("") == false, "пустой путь голоса отклонён")
	_check(AudioManager.play_voice("res://assets/audio/pairs/sh_s/nope.wav") == false, "отсутствующий файл голоса не ломает игру")
	_check(AudioManager.play_sfx("res://assets/audio/pairs/sh_s/nope.wav") == false, "отсутствующий SFX не ломает игру")
	var pair := ContentRepository.get_pair("sh_s_01")
	_check(not pair.is_empty(), "пара sh_s_01 доступна")
	_check(AudioManager.play_pair_side(pair, "a") == true, "голос пары проигрывается")
	_check(AudioManager.voice_queue_size() == 0, "очередь голоса пуста после запуска")
	AudioManager.clear_voice_queue()
	AudioManager.set_master_volume(0.5)
	_check(is_equal_approx(AudioManager.get_master_volume(), 0.5), "громкость 0.5 сохраняется")
	AudioManager.set_master_volume(2.0)
	_check(is_equal_approx(AudioManager.get_master_volume(), 1.0), "громкость выше 1 ограничена")
	AudioManager.set_master_volume(-1.0)
	_check(is_equal_approx(AudioManager.get_master_volume(), 0.0), "громкость ниже 0 ограничена")
	AudioManager.set_master_volume(1.0)
	AudioManager.stop_voice()


func _run_sfx_tests() -> void:
	_check(SfxLibrary.ALL.size() == 4, "объявлены четыре интерфейсных звука")
	var all_exist := true
	for path: String in SfxLibrary.ALL:
		if not ResourceLoader.exists(path):
			all_exist = false
	_check(all_exist, "все файлы SFX существуют")
	_check(SfxLibrary.click(), "звук клика играет")
	_check(SfxLibrary.correct(), "звук верного ответа играет")
	_check(SfxLibrary.error(), "звук ошибки играет")
	_check(SfxLibrary.complete(), "звук завершения играет")
	_check(AudioManager.get_sfx_volume() < 1.0, "SFX тише мастер-канала по умолчанию")
	AudioManager.stop_sfx()


func _run_navigation_tests() -> void:
	_check(Navigation.MODE_IDS.size() == 3, "объявлены три режима")
	var titles_ok := true
	for mode_id: String in Navigation.MODE_IDS:
		if Navigation.mode_title(mode_id).is_empty():
			titles_ok = false
	_check(titles_ok, "у каждого режима есть название")
	for path in [Navigation.START, Navigation.MODE_SELECT, Navigation.GAME, Navigation.SESSION_SUMMARY]:
		_check(ResourceLoader.exists(path), "сцена существует: " + path)
	_check(Navigation.history_size() == 0, "история навигации стартует пустой")

	var start_scene := load(Navigation.START) as PackedScene
	var start_screen := start_scene.instantiate()
	add_child(start_screen)
	_check(_count_buttons(start_screen) == 3, "стартовый экран: начать, конструктор и родителям")
	start_screen.queue_free()

	var mode_scene := load(Navigation.MODE_SELECT) as PackedScene
	var mode_screen := mode_scene.instantiate()
	add_child(mode_screen)
	_check(_count_buttons(mode_screen) == 4, "экран выбора режима: три режима и назад")
	mode_screen.queue_free()

	Navigation.selected_mode = "listen_choose"
	var game_scene := load(Navigation.GAME) as PackedScene
	var game_screen := game_scene.instantiate()
	add_child(game_screen)
	_check(game_screen.get_child_count() >= 1, "игровой экран загружает режим")
	game_screen.queue_free()
	Navigation.selected_mode = ""

	var summary_scene := load(Navigation.SESSION_SUMMARY) as PackedScene
	var summary := summary_scene.instantiate()
	add_child(summary)
	_check(_count_buttons(summary) == 1, "экран итога: кнопка готово")
	summary.queue_free()


func _run_save_tests() -> void:
	var progress := SaveManager.get_progress()
	_check(int(progress.get("version", 0)) == 1, "прогресс имеет версию схемы")
	_check(int(progress.get("sessions_completed", -1)) == 0, "прогресс стартует с нуля")

	SaveManager.set_setting("master_volume", 0.5)
	_check(is_equal_approx(float(SaveManager.get_setting("master_volume", 0.0)), 0.5), "настройка сохранена в память")
	_check(FileAccess.file_exists(TEST_SETTINGS), "файл настроек записан")
	_check(not FileAccess.file_exists(TEST_SETTINGS + ".tmp"), "временный файл настроек убран")

	SaveManager.record_attempt("sh_s_01", true)
	SaveManager.record_attempt("sh_s_01", false)
	var pairs: Dictionary = SaveManager.get_progress().get("pairs", {})
	var entry: Dictionary = pairs.get("sh_s_01", {})
	_check(int(entry.get("attempts", 0)) == 2, "попытки пары посчитаны")
	_check(int(entry.get("correct", 0)) == 1, "верные попытки пары посчитаны")

	SaveManager.complete_session()
	_check(int(SaveManager.get_progress().get("sessions_completed", 0)) == 1, "занятие засчитано")
	_check(FileAccess.file_exists(TEST_PROGRESS), "файл прогресса записан")

	SaveManager.reload()
	_check(is_equal_approx(float(SaveManager.get_setting("master_volume", 0.0)), 0.5), "настройка восстановлена после перезапуска")
	_check(int(SaveManager.get_progress().get("sessions_completed", 0)) == 1, "прогресс восстановлен после перезапуска")

	var bad := FileAccess.open(TEST_PROGRESS, FileAccess.WRITE)
	bad.store_string("{ это не json")
	bad.close()
	SaveManager.reload()
	var recovered := SaveManager.get_progress()
	_check(int(recovered.get("version", 0)) == 1, "повреждённый файл даёт версию по умолчанию")
	_check(int(recovered.get("sessions_completed", -1)) == 0, "повреждённый файл не ломает запуск")


func _run_session_tests() -> void:
	var controller := SessionController.new()
	_check(controller.start("builtin_sh_s", 15, 12345), "сессия стартует")
	_check(controller.total() == 15, "в сессии 15 попыток")
	_check(not controller.current_pair().is_empty(), "текущая пара есть")
	var guard := 0
	while not controller.is_finished() and guard < 100:
		controller.advance(true)
		guard += 1
	_check(controller.is_finished(), "сессия завершается по числу попыток")
	_check(int(controller.summary().get("attempts", 0)) == 15, "итог считает попытки")
	_check(int(controller.summary().get("correct", 0)) == 15, "итог считает верные ответы")

	var manual := SessionController.new()
	manual.start("builtin_sh_s", 15, 7)
	manual.finish()
	_check(manual.is_finished(), "сессия завершается по кнопке Закончить")

	var missing := SessionController.new()
	_check(missing.start("no_such_set", 15, 1) == false, "сессия без набора не стартует")


func _run_mode_tests() -> void:
	for mode_id: String in ["listen_choose", "repeat_after_adult", "name_picture"]:
		var path := "res://scenes/modes/%s.tscn" % mode_id
		_check(ResourceLoader.exists(path), "сцена режима существует: " + mode_id)
		var scene := load(path) as PackedScene
		var mode := scene.instantiate() as ModeBase
		add_child(mode)
		var controller := SessionController.new()
		controller.start("builtin_sh_s", 15, 1)
		mode.setup(controller)
		_check(_count_buttons(mode) == 4, "режим " + mode_id + ": два варианта, повтор и закончить")
		mode.queue_free()


func _run_progress_tests() -> void:
	SaveManager.reset_progress()
	ProgressStore.record_attempt("sh_s_01", true, "listen_choose")
	ProgressStore.record_attempt("sh_s_01", false, "listen_choose")
	ProgressStore.record_attempt("sh_s_02", true, "name_picture")
	var pairs := ProgressStore.pairs_summary()
	_check(pairs.size() == 2, "прогресс по двум парам")
	var first: Dictionary = pairs[0]
	_check(str(first.get("pair_id", "")) == "sh_s_01", "пары отсортированы по id")
	_check(int(first.get("attempts", 0)) == 2, "попытки пары посчитаны")
	_check(int(first.get("errors", 0)) == 1, "ошибки пары посчитаны")
	var modes := ProgressStore.modes_summary()
	_check(modes.size() == 3, "в срезе режимов всегда три")
	var listen: Dictionary = modes[0]
	_check(str(listen.get("mode_id", "")) == "listen_choose", "первый режим это послушай и выбери")
	_check(int(listen.get("attempts", 0)) == 2, "попытки режима посчитаны")
	_check(int(listen.get("correct", 0)) == 1, "верные режима посчитаны")
	SaveManager.reload()
	_check(ProgressStore.pairs_summary().size() == 2, "прогресс переживает перезапуск")
	ProgressStore.reset()
	_check(ProgressStore.pairs_summary().is_empty(), "сброс очищает прогресс")


func _run_parent_screen_tests() -> void:
	_check(ResourceLoader.exists(Navigation.PARENT_SCREEN), "сцена родительского экрана существует")
	_check(ResourceLoader.exists(Navigation.SETTINGS), "сцена настроек существует")
	SaveManager.reset_progress()
	ProgressStore.record_attempt("sh_s_01", false, "listen_choose")
	var scene := load(Navigation.PARENT_SCREEN) as PackedScene
	var screen := scene.instantiate()
	add_child(screen)
	_check(_count_buttons(screen) == 3, "родительский экран: настройки, о проекте и назад")
	_check(_find_text(screen, "не диагностика"), "есть пояснение не диагностика")
	_check(_find_text(screen, "О проекте"), "есть кнопка о проекте")
	_check(_find_text(screen, "Попыток: 1"), "видно попытки по паре")
	screen.queue_free()
	SaveManager.reset_progress()


func _run_about_screen_tests() -> void:
	_check(ResourceLoader.exists(Navigation.ABOUT_SCREEN), "сцена о проекте существует")
	var scene := load(Navigation.ABOUT_SCREEN) as PackedScene
	var screen := scene.instantiate()
	add_child(screen)
	_check(screen.has_disclaimer(), "есть дисклеймер о логопеде")
	_check(screen.has_privacy(), "есть текст о приватности")
	_check(_count_buttons(screen) == 1, "экран о проекте: кнопка назад")
	_check(not screen.version_text().is_empty(), "версия приложения видна")
	screen.queue_free()


func _run_settings_tests() -> void:
	var scene := load(Navigation.SETTINGS) as PackedScene
	var settings := scene.instantiate()
	add_child(settings)
	_check(settings.has_reset_confirmation(), "сброс требует подтверждения")
	settings.set_volume(0.3)
	_check(is_equal_approx(AudioManager.get_master_volume(), 0.3), "громкость применяется к звуку")
	_check(is_equal_approx(float(SaveManager.get_setting("master_volume", -1.0)), 0.3), "громкость сохраняется")
	settings.set_sound_enabled(false)
	_check(is_equal_approx(AudioManager.get_master_volume(), 0.0), "звук можно выключить")
	_check(is_equal_approx(float(SaveManager.get_setting("master_volume", -1.0)), 0.0), "выключенный звук сохраняется")
	settings.set_sound_enabled(true)
	_check(AudioManager.get_master_volume() > 0.0, "звук включается обратно")
	SaveManager.record_attempt("sh_s_01", true)
	settings.confirm_reset()
	_check(ProgressStore.pairs_summary().is_empty(), "подтверждённый сброс очищает прогресс")
	settings.queue_free()
	SaveManager.reset_progress()


func _run_offline_tests() -> void:
	var hits := _scan_for_network("res://scripts", ".gd")
	hits.append_array(_scan_for_network("res://scenes", ".tscn"))
	_check(hits.is_empty(), "в исходниках нет сетевых вызовов")
	for hit: String in hits:
		printerr("NETWORK: " + hit)


func _scan_for_network(dir_path: String, suffix: String) -> Array[String]:
	var hits: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return hits
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := dir_path.path_join(name)
			if dir.current_is_dir():
				hits.append_array(_scan_for_network(full, suffix))
			elif name.ends_with(suffix):
				hits.append_array(_scan_file(full, suffix))
		name = dir.get_next()
	dir.list_dir_end()
	return hits


func _scan_file(full: String, suffix: String) -> Array[String]:
	var hits: Array[String] = []
	var file := FileAccess.open(full, FileAccess.READ)
	if file == null:
		return hits
	var text := file.get_as_text()
	file.close()
	for token: String in NETWORK_TOKENS:
		if text.contains(token):
			hits.append(full + " [" + suffix + "]: " + token)
	return hits


func _find_text(node: Node, needle: String) -> bool:
	if node is Label and str((node as Label).text).contains(needle):
		return true
	if node is Button and str((node as Button).text).contains(needle):
		return true
	for child in node.get_children():
		if _find_text(child, needle):
			return true
	return false


func _count_buttons(node: Node) -> int:
	var total := 0
	if node is Button:
		total += 1
	for child in node.get_children():
		total += _count_buttons(child)
	return total


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + message)
	else:
		_failures += 1
		printerr("FAIL: " + message)


func _cleanup() -> void:
	AudioManager.stop_voice()
	AudioManager.stop_sfx()
	AudioManager.stop_music()
	if FileAccess.file_exists(TEST_EXPORT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_EXPORT))
	for path in [TEST_PROGRESS, TEST_SETTINGS, TEST_PROGRESS + ".tmp", TEST_SETTINGS + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "/sets"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))


func _report() -> void:
	print("=== проверок: %d, ошибок: %d ===" % [_checks, _failures])
	if _failures == 0:
		print("ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ")
	else:
		printerr("ЕСТЬ ОШИБКИ: %d" % _failures)
