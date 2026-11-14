class_name ProgressStore
extends RefCounted
## Чтение и запись прогресса поверх SaveManager.
##
## SaveManager хранит сырые данные в user://progress.json. ProgressStore даёт
## экранам удобные срезы: попытки и ошибки по парам, результат по режимам,
## последнее занятие. Данные всегда идут через SaveManager, отдельного файла нет.

## Записывает попытку по паре и результат по режиму.
static func record_attempt(pair_id: String, correct: bool, mode_id := "") -> void:
	if not pair_id.is_empty():
		SaveManager.record_attempt(pair_id, correct)
	if not mode_id.is_empty():
		SaveManager.record_mode(mode_id, correct)


## Срез по парам: попытки, верные ответы и ошибки. Отсортирован по id пары.
static func pairs_summary() -> Array[Dictionary]:
	var progress := SaveManager.get_progress()
	var pairs: Dictionary = progress.get("pairs", {})
	var result: Array[Dictionary] = []
	for pair_id: Variant in pairs.keys():
		var entry: Dictionary = pairs[pair_id]
		var attempts := int(entry.get("attempts", 0))
		var correct := int(entry.get("correct", 0))
		var pair := ContentRepository.get_pair(str(pair_id))
		result.append({
			"pair_id": str(pair_id),
			"label": _pair_label(str(pair_id), pair),
			"attempts": attempts,
			"correct": correct,
			"errors": maxi(0, attempts - correct),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("pair_id", "")) < str(b.get("pair_id", "")))
	return result


## Срез по режимам в порядке Navigation.MODE_IDS.
static func modes_summary() -> Array[Dictionary]:
	var progress := SaveManager.get_progress()
	var modes: Dictionary = progress.get("modes", {})
	var result: Array[Dictionary] = []
	for mode_id: String in Navigation.MODE_IDS:
		var raw: Variant = modes.get(mode_id)
		var entry: Dictionary = {}
		if raw is Dictionary:
			entry = raw
		result.append({
			"mode_id": mode_id,
			"title": Navigation.mode_title(mode_id),
			"attempts": int(entry.get("attempts", 0)),
			"correct": int(entry.get("correct", 0)),
		})
	return result


## Краткий итог последнего занятия.
static func last_session() -> Dictionary:
	var progress := SaveManager.get_progress()
	return {
		"sessions_completed": int(progress.get("sessions_completed", 0)),
		"last_session_at": str(progress.get("last_session_at", "")),
	}


## Сбрасывает прогресс через SaveManager.
static func reset() -> void:
	SaveManager.reset_progress()


static func _pair_label(pair_id: String, pair: Dictionary) -> String:
	if pair.is_empty():
		return pair_id
	var word_a := str(pair.get("word_a", ""))
	var word_b := str(pair.get("word_b", ""))
	if word_a.is_empty() or word_b.is_empty():
		return pair_id
	return "%s - %s" % [word_a, word_b]
