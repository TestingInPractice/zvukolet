extends Node
## Локальное сохранение прогресса и настроек в user://.
##
## В MVP нет аккаунта и облака: все данные остаются на устройстве. Файлы
## versioned для будущих миграций, пишутся атомарно через временный файл, а
## повреждённый файл не ломает запуск (берём значения по умолчанию).
## Autoload SaveManager. Пути можно переопределить в тестах.

signal progress_changed()
signal settings_changed()

const SCHEMA_VERSION := 1
const DEFAULT_PROGRESS_PATH := "user://progress.json"
const DEFAULT_SETTINGS_PATH := "user://settings.json"

var progress_path := DEFAULT_PROGRESS_PATH
var settings_path := DEFAULT_SETTINGS_PATH

var _progress: Dictionary = {}
var _settings: Dictionary = {}


func _ready() -> void:
	reload()


## Читает оба файла с диска, подставляя значения по умолчанию.
func reload() -> void:
	_progress = _load_file(progress_path, _default_progress())
	_settings = _load_file(settings_path, _default_settings())


func get_progress() -> Dictionary:
	return _progress.duplicate(true)


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return _settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	save_settings()
	settings_changed.emit()


## Учитывает попытку по паре и сохраняет прогресс.
func record_attempt(pair_id: String, correct: bool) -> void:
	var pairs: Dictionary = _progress.get("pairs", {})
	var raw: Variant = pairs.get(pair_id)
	var entry: Dictionary = {}
	if raw is Dictionary:
		entry = raw
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	if correct:
		entry["correct"] = int(entry.get("correct", 0)) + 1
	pairs[pair_id] = entry
	_progress["pairs"] = pairs
	save_progress()
	progress_changed.emit()


## Учитывает результат по режиму и сохраняет прогресс.
func record_mode(mode_id: String, correct: bool) -> void:
	if mode_id.is_empty():
		return
	var modes: Dictionary = _progress.get("modes", {})
	var raw: Variant = modes.get(mode_id)
	var entry: Dictionary = {}
	if raw is Dictionary:
		entry = raw
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	if correct:
		entry["correct"] = int(entry.get("correct", 0)) + 1
	modes[mode_id] = entry
	_progress["modes"] = modes
	save_progress()
	progress_changed.emit()


## Отмечает завершённое занятие и сохраняет прогресс.
func complete_session() -> void:
	_progress["sessions_completed"] = int(_progress.get("sessions_completed", 0)) + 1
	_progress["last_session_at"] = Time.get_datetime_string_from_system(true)
	save_progress()
	progress_changed.emit()


func reset_progress() -> void:
	_progress = _default_progress()
	save_progress()
	progress_changed.emit()


func save_progress() -> bool:
	return _write_file(progress_path, _progress)


func save_settings() -> bool:
	return _write_file(settings_path, _settings)


func _default_progress() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"sessions_completed": 0,
		"last_session_at": "",
		"pairs": {},
		"modes": {},
	}


func _default_settings() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"master_volume": 1.0,
		"voice_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 1.0,
		"last_set_id": "",
		"last_mode": "",
	}


func _load_file(path: String, defaults: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return defaults
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		AppLogger.warning("SaveManager", "cannot open: " + path)
		return defaults
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		AppLogger.warning("SaveManager", "corrupted file, using defaults: " + path)
		return defaults
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		AppLogger.warning("SaveManager", "not an object, using defaults: " + path)
		return defaults
	var data: Dictionary = parsed
	return _merge_defaults(defaults, data)


func _merge_defaults(defaults: Dictionary, data: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	for key: Variant in data.keys():
		result[key] = data[key]
	if int(result.get("version", 0)) < 1:
		result["version"] = SCHEMA_VERSION
	return result


func _write_file(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		AppLogger.warning("SaveManager", "cannot write: " + tmp)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(path)
	)
	if err != OK:
		AppLogger.warning("SaveManager", "rename failed: " + path)
		return false
	return true
