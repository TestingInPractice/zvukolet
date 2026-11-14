extends Node
## Единая точка чтения набора: встроенный или пользовательский.
##
## Возвращает список пар, готовых к показу, с подставленными путями медиа.
## Для пользовательского набора, где путь к медиа пустой, подставляется медиа
## встроенной пары с тем же id: взрослый мог менять только текст. Autoload
## SetRepository.

signal sets_changed()


func _ready() -> void:
	CustomSetsStore.sets_changed.connect(_on_store_changed)


func _on_store_changed() -> void:
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
	pair["id"] = pair_id
	return pair
