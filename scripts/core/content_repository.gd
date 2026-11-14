extends Node
## Чтение встроенного контента из res://content. Только чтение.
##
## Загружает контрасты, пары каждого контраста и встроенные наборы. Пары
## индексируются по id, чтобы набор мог ссылаться на них списком pair_ids.
## Autoload-синглтон ContentRepository.

const CONTRASTS_PATH := "res://content/contrasts.json"
const SETS_DIR := "res://content/sets"

signal content_loaded()

var _contrasts: Array[Dictionary] = []
var _pairs_by_contrast: Dictionary = {}
var _pair_index: Dictionary = {}
var _builtin_sets: Array[Dictionary] = []
var _builtin_set_index: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	load_content()


## Перечитывает весь встроенный контент. Возвращает true, если контрасты есть.
func load_content() -> bool:
	_contrasts.clear()
	_pairs_by_contrast.clear()
	_pair_index.clear()
	_builtin_sets.clear()
	_builtin_set_index.clear()
	_loaded = false

	var raw: Variant = _read_json(CONTRASTS_PATH)
	if raw is Dictionary:
		for item: Variant in (raw as Dictionary).get("contrasts", []):
			if item is Dictionary:
				_contrasts.append((item as Dictionary).duplicate(true))

	for contrast in _contrasts:
		var contrast_id := str(contrast.get("id", ""))
		var pairs_file := str(contrast.get("pairs_file", ""))
		if contrast_id.is_empty() or pairs_file.is_empty():
			continue
		var pairs := _load_pairs(pairs_file)
		_pairs_by_contrast[contrast_id] = pairs
		for pair in pairs:
			_pair_index[str(pair.get("id", ""))] = pair

	_load_builtin_sets()

	_loaded = not _contrasts.is_empty()
	AppLogger.info("ContentRepository", "loaded", {
		"contrasts": _contrasts.size(),
		"pairs": _pair_index.size(),
		"sets": _builtin_sets.size(),
	})
	content_loaded.emit()
	return _loaded


func is_loaded() -> bool:
	return _loaded


func get_contrasts() -> Array[Dictionary]:
	return _contrasts.duplicate(true)


func get_contrast(contrast_id: String) -> Dictionary:
	for contrast in _contrasts:
		if str(contrast.get("id", "")) == contrast_id:
			return contrast.duplicate(true)
	return {}


func get_pairs(contrast_id: String) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = _pairs_by_contrast.get(contrast_id, [])
	return pairs.duplicate(true)


func get_pair(pair_id: String) -> Dictionary:
	if _pair_index.has(pair_id):
		return (_pair_index[pair_id] as Dictionary).duplicate(true)
	return {}


func get_builtin_sets() -> Array[Dictionary]:
	return _builtin_sets.duplicate(true)


func get_builtin_set(set_id: String) -> Dictionary:
	if _builtin_set_index.has(set_id):
		return (_builtin_set_index[set_id] as Dictionary).duplicate(true)
	return {}


func _load_pairs(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = _read_json(path)
	if not (raw is Dictionary):
		return result
	for item: Variant in (raw as Dictionary).get("pairs", []):
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _load_builtin_sets() -> void:
	var dir := DirAccess.open(SETS_DIR)
	if dir == null:
		AppLogger.warning("ContentRepository", "sets_dir_missing", {"path": SETS_DIR})
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var raw: Variant = _read_json(SETS_DIR + "/" + file_name)
		if not (raw is Dictionary):
			continue
		var record := (raw as Dictionary).duplicate(true)
		var set_id := str(record.get("id", ""))
		if set_id.is_empty():
			continue
		_builtin_sets.append(record)
		_builtin_set_index[set_id] = record


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		AppLogger.warning("ContentRepository", "missing_file", {"path": path})
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)
