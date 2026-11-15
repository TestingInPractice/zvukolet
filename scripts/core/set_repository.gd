extends Node
## Единая точка чтения набора: встроенный или пользовательский.
##
## Возвращает список пар, готовых к показу, с подставленными путями медиа.
## Для пользовательского набора, где путь к медиа пустой, подставляется медиа
## встроенной пары с тем же id: взрослый мог менять только текст. Autoload
## SetRepository.

signal sets_changed()

## Кэш текстур и звуков по пути: медиа проигрывается много раз за игру, а load()
## на каждом кадре — лишняя работа. Сбрасывается по сигналу sets_changed, чтобы
## правка набора была видна сразу.
var _texture_cache: Dictionary = {}
var _audio_cache: Dictionary = {}


func _ready() -> void:
	CustomSetsStore.sets_changed.connect(_on_store_changed)


func _on_store_changed() -> void:
	clear_cache()
	sets_changed.emit()


## Сводки всех наборов: встроенные, затем пользовательские.
func get_set_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for builtin in ContentRepository.get_builtin_sets():
		result.append({
			"id": str(builtin.get("id", "")),
			"name": str(builtin.get("name", "")),
			"contrast_id": str(builtin.get("contrast_id", "")),
			"builtin": true,
			"pair_count": (builtin.get("pair_ids", []) as Array).size(),
		})
	for custom in CustomSetsStore.get_sets():
		var set_id := str(custom.get("id", ""))
		result.append({
			"id": set_id,
			"name": str(custom.get("name", "")),
			"contrast_id": str(custom.get("contrast_id", "")),
			"builtin": false,
			"pair_count": CustomSetsStore.pair_count(set_id),
		})
	return result


func set_exists(set_id: String) -> bool:
	return not resolve_set(set_id).is_empty()


## Возвращает {id, name, contrast_id, builtin, pairs} или пустой словарь.
func resolve_set(set_id: String) -> Dictionary:
	var builtin := ContentRepository.get_builtin_set(set_id)
	if not builtin.is_empty():
		var pairs: Array[Dictionary] = []
		for pair_id: Variant in builtin.get("pair_ids", []):
			var pair := ContentRepository.get_pair(str(pair_id))
			if not pair.is_empty():
				pairs.append(pair)
		return {
			"id": set_id,
			"name": str(builtin.get("name", "")),
			"contrast_id": str(builtin.get("contrast_id", "")),
			"mode_id": "",
			"builtin": true,
			"pairs": pairs,
		}
	var custom := CustomSetsStore.get_set(set_id)
	if custom.is_empty():
		return {}
	var custom_pairs: Array[Dictionary] = []
	for pair_id in CustomSetsStore.get_pair_ids(set_id):
		custom_pairs.append(_resolve_custom_pair(pair_id, custom))
	return {
		"id": set_id,
		"name": str(custom.get("name", "")),
		"contrast_id": str(custom.get("contrast_id", "")),
		"mode_id": str(custom.get("mode_id", "")),
		"builtin": false,
		"pairs": custom_pairs,
	}


func get_playable_pairs(set_id: String) -> Array[Dictionary]:
	var resolved := resolve_set(set_id)
	var result: Array[Dictionary] = []
	for pair: Dictionary in resolved.get("pairs", []):
		result.append(pair.duplicate(true))
	return result


## id набора по умолчанию: первый встроенный, иначе пустая строка.
func get_default_set_id() -> String:
	var builtin := ContentRepository.get_builtin_sets()
	if builtin.is_empty():
		return ""
	return str(builtin[0].get("id", ""))


func _resolve_custom_pair(pair_id: String, record: Dictionary) -> Dictionary:
	var pairs: Dictionary = record.get("pairs", {})
	var pair: Dictionary = (pairs.get(pair_id, {}) as Dictionary).duplicate(true)
	var fallback := ContentRepository.get_pair(pair_id)
	if not fallback.is_empty():
		for key: String in ["word_a", "word_b", "image_a", "image_b", "audio_a", "audio_b"]:
			if str(pair.get(key, "")).is_empty() and not str(fallback.get(key, "")).is_empty():
				pair[key] = fallback.get(key)
	_fill_media_by_word(pair)
	pair["id"] = pair_id
	return pair


## Подставляет картинку и озвучку из библиотеки по тексту слова, если своих нет.
func _fill_media_by_word(pair: Dictionary) -> void:
	for side: String in ["a", "b"]:
		var word := str(pair.get("word_" + side, ""))
		if word.strip_edges().is_empty():
			continue
		var media := ContentRepository.find_media_by_word(word)
		if media.is_empty():
			continue
		for field: String in ["image", "audio"]:
			var key := field + "_" + side
			if str(pair.get(key, "")).is_empty() and not str(media.get(field, "")).is_empty():
				pair[key] = media.get(field)


## Текстура по пути (res:// или user://) с кэшем. null, если файла нет.
##
## load() не открывает user:// в веб-сборке: у файла нет .import, поэтому
## картинки из user:// читаются через Image.load().
func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	var texture: Texture2D = null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
	else:
		var image := Image.new()
		var err := image.load(path)
		if err == OK:
			texture = ImageTexture.create_from_image(image)
		else:
			AppLogger.warning("SetRepository", "image_load_failed", {"path": path, "err": err})
	if texture == null:
		return null
	_texture_cache[path] = texture
	return texture


## Звук по пути (res:// или user://) с кэшем. null, если файла нет.
func load_audio(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _audio_cache.has(path):
		return _audio_cache[path] as AudioStream
	var stream := _load_audio(path)
	if stream == null:
		return null
	_audio_cache[path] = stream
	return stream


## Звук из произвольного файла набора, без кэша. Для предпросмотра в редакторе:
## файл перезаписывается при повторной записи, и кэш отдал бы старую версию.
func load_audio_file(path: String) -> AudioStream:
	if path.is_empty():
		return null
	return _load_audio(path)


## Сбрасывает кэш текстур и звуков. Вызывается по сигналу sets_changed и после
## правки медиа в редакторе.
func clear_cache() -> void:
	_texture_cache.clear()
	_audio_cache.clear()


## Загрузка звука. res:// открывается через load(), user:// — только через
## форматозависимый load_from_file(): в веб-сборке у файлов в user:// нет
## импорта, и общий загрузчик их не видит.
func _load_audio(path: String) -> AudioStream:
	var stream: AudioStream = null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
	else:
		match path.get_extension().to_lower():
			"wav":
				stream = AudioStreamWAV.load_from_file(path)
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
			"mp3":
				stream = AudioStreamMP3.load_from_file(path)
			_:
				AppLogger.warning("SetRepository", "audio_format_unsupported", {"path": path})
				return null
	if stream == null:
		AppLogger.warning("SetRepository", "audio_missing", {"path": path})
	return stream
