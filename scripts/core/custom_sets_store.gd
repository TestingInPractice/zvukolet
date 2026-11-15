extends Node
## Хранилище пользовательских наборов.
##
## Метаданные всех наборов лежат в одном файле user://custom_sets.json, медиа
## наборов в каталоге user://custom_sets/<set_id>/. Autoload-синглтон
## CustomSetsStore. Пути save_path и sets_dir переопределяемы, чтобы тесты
## работали в изолированном каталоге и не трогали данные пользователя.

const SCHEMA_VERSION := 1
const STORE_FILE := "user://custom_sets.json"
const SETS_DIR := "user://custom_sets"

signal sets_changed()

## Переопределяемо в тестах.
var save_path: String = STORE_FILE
var sets_dir: String = SETS_DIR

var _sets: Array[Dictionary] = []
var _loaded: bool = false


func _ready() -> void:
	reload()


## Перечитывает хранилище с диска.
func reload() -> void:
	_sets.clear()
	_loaded = false
	var raw: Variant = _read_store()
	if raw is Dictionary:
		for item: Variant in (raw as Dictionary).get("sets", []):
			if item is Dictionary:
				_sets.append(_normalize_record(item as Dictionary))
	_loaded = true
	AppLogger.info("CustomSetsStore", "loaded", {"sets": _sets.size()})


## Удаляет все наборы (в памяти и на диске). Для тестов.
func clear_all() -> void:
	_sets.clear()
	_persist()
	sets_changed.emit()


func get_sets() -> Array[Dictionary]:
	return _sets.duplicate(true)


func get_set(set_id: String) -> Dictionary:
	var index := _find_index(set_id)
	if index < 0:
		return {}
	return _sets[index].duplicate(true)


func has_set(set_id: String) -> bool:
	return _find_index(set_id) >= 0


func create_set(name: String, contrast_id: String, mode_id := "") -> Dictionary:
	var record := {
		"id": _generate_id(),
		"name": _clean_name(name),
		"contrast_id": contrast_id,
		"mode_id": mode_id,
		"pairs": {},
	}
	_sets.append(record)
	_ensure_dir(set_dir(str(record["id"])))
	if not _persist():
		return {}
	sets_changed.emit()
	return record.duplicate(true)


func delete_set(set_id: String) -> bool:
	var index := _find_index(set_id)
	if index < 0:
		return false
	_sets.remove_at(index)
	_remove_dir(set_dir(set_id))
	if not _persist():
		return false
	sets_changed.emit()
	return true


func rename_set(set_id: String, name: String) -> bool:
	var index := _find_index(set_id)
	if index < 0:
		return false
	_sets[index]["name"] = _clean_name(name)
	if not _persist():
		return false
	sets_changed.emit()
	return true


func get_pair_ids(set_id: String) -> Array[String]:
	var result: Array[String] = []
	var record := get_set(set_id)
	var pairs: Dictionary = record.get("pairs", {})
	for raw_key in pairs.keys():
		result.append(str(raw_key))
	return result


func get_pair(set_id: String, pair_id: String) -> Dictionary:
	var record := get_set(set_id)
	var pairs: Dictionary = record.get("pairs", {})
	if pairs.has(pair_id):
		return (pairs[pair_id] as Dictionary).duplicate(true)
	return {}


func add_pair(set_id: String, pair_id: String, pair_data: Dictionary) -> bool:
	var index := _find_index(set_id)
	if index < 0 or pair_id.is_empty():
		return false
	var pairs: Dictionary = _sets[index].get("pairs", {})
	if pairs.has(pair_id):
		return false
	pairs[pair_id] = _normalize_pair(pair_data)
	_sets[index]["pairs"] = pairs
	if not _persist():
		return false
	sets_changed.emit()
	return true


func remove_pair(set_id: String, pair_id: String) -> bool:
	var index := _find_index(set_id)
	if index < 0:
		return false
	var pairs: Dictionary = _sets[index].get("pairs", {})
	if not pairs.has(pair_id):
		return false
	pairs.erase(pair_id)
	_sets[index]["pairs"] = pairs
	if not _persist():
		return false
	sets_changed.emit()
	return true


func update_pair_word(set_id: String, pair_id: String, side: String, word: String) -> bool:
	if side != "a" and side != "b":
		return false
	var index := _find_index(set_id)
	if index < 0:
		return false
	var pairs: Dictionary = _sets[index].get("pairs", {})
	if not pairs.has(pair_id):
		return false
	var pair: Dictionary = pairs[pair_id]
	pair["word_" + side] = word.strip_edges()
	pairs[pair_id] = pair
	_sets[index]["pairs"] = pairs
	if not _persist():
		return false
	sets_changed.emit()
	return true


## Заменяет все пары набора. Порядок ключей словаря сохраняется.
func set_pairs(set_id: String, pairs: Dictionary) -> bool:
	var index := _find_index(set_id)
	if index < 0:
		return false
	var normalized := {}
	for raw_key in pairs.keys():
		var pair_id := str(raw_key)
		if pair_id.is_empty():
			continue
		normalized[pair_id] = _normalize_pair(pairs[raw_key] as Dictionary)
	_sets[index]["pairs"] = normalized
	if not _persist():
		return false
	sets_changed.emit()
	return true


func pair_count(set_id: String) -> int:
	return get_pair_ids(set_id).size()


## Режим, выбранный при создании набора. Пусто, если набор старый.
func get_mode_id(set_id: String) -> String:
	return str(get_set(set_id).get("mode_id", ""))


func set_dir(set_id: String) -> String:
	return sets_dir + "/" + set_id + "/"


func pair_file_name(pair_id: String, side: String, extension: String) -> String:
	var ext := extension.to_lower()
	if ext.is_empty():
		ext = "dat"
	return "%s_%s.%s" % [pair_id, side, ext]


## Имя файла картинки пары: <pair>_<side>.webp. Один формат на все картинки.
func image_file_name(pair_id: String, side: String) -> String:
	return pair_file_name(pair_id, side, "webp")


## Имя файла озвучки пары: <pair>_<side>.<ext>.
func audio_file_name(pair_id: String, side: String, extension: String) -> String:
	return pair_file_name(pair_id, side, extension)


## Расширение файла по MIME-типу. Пусто, если тип не поддержан.
## Список обязан совпадать с WebFilePicker: каждый принятый там тип получает
## здесь непустое расширение, иначе файл сохранится без имени формата.
func extension_for_mime(mime: String) -> String:
	var clean := mime.strip_edges().to_lower()
	var semicolon := clean.find(";")
	if semicolon >= 0:
		clean = clean.substr(0, semicolon)
	match clean:
		"image/png":
			return "png"
		"image/jpeg":
			return "jpg"
		"image/webp":
			return "webp"
		"audio/wav", "audio/x-wav", "audio/wave":
			return "wav"
		"audio/ogg", "audio/vorbis", "audio/oga":
			return "ogg"
		"audio/mpeg", "audio/mp3":
			return "mp3"
		"audio/mp4", "audio/m4a", "audio/x-m4a", "audio/aac":
			return "m4a"
		_:
			return ""


## Удаляет файл медиа набора, если он лежит в каталоге набора. Чужой путь
## (res:// или вне каталога наборов) не трогаем.
func remove_media_file(path: String) -> void:
	if path.is_empty() or not path.begins_with(sets_dir + "/"):
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _normalize_record(source: Dictionary) -> Dictionary:
	var record := {
		"id": str(source.get("id", "")),
		"name": _clean_name(str(source.get("name", ""))),
		"contrast_id": str(source.get("contrast_id", "")),
		"mode_id": str(source.get("mode_id", "")),
		"pairs": {},
	}
	var raw_pairs: Variant = source.get("pairs", {})
	if raw_pairs is Dictionary:
		var pairs := {}
		for raw_key in (raw_pairs as Dictionary).keys():
			var pair_id := str(raw_key)
			if pair_id.is_empty():
				continue
			pairs[pair_id] = _normalize_pair((raw_pairs as Dictionary)[raw_key] as Dictionary)
		record["pairs"] = pairs
	return record


func _normalize_pair(source: Dictionary) -> Dictionary:
	var pair := {}
	for key: String in ["word_a", "word_b", "image_a", "image_b", "audio_a", "audio_b"]:
		pair[key] = str(source.get(key, ""))
	return pair


func _clean_name(name: String) -> String:
	var clean := name.strip_edges()
	if clean.is_empty():
		clean = "Новый набор"
	return clean


func _find_index(set_id: String) -> int:
	for i in _sets.size():
		if str(_sets[i].get("id", "")) == set_id:
			return i
	return -1


func _generate_id() -> String:
	var raw := "%d%d%d" % [Time.get_ticks_usec(), randi(), _sets.size()]
	return "c_" + raw.md5_text().substr(0, 8)


func _persist() -> bool:
	_ensure_dir(save_path.get_base_dir())
	var payload := {"version": SCHEMA_VERSION, "sets": _sets}
	var text := JSON.stringify(payload, "  ")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		AppLogger.error("CustomSetsStore", "persist_failed", {"path": save_path})
		return false
	file.store_string(text)
	file.close()
	return true


func _read_store() -> Variant:
	if not FileAccess.file_exists(save_path):
		return null
	var text := FileAccess.get_file_as_string(save_path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func _ensure_dir(path: String) -> void:
	if path.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _remove_dir(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
