class_name SessionController
extends RefCounted
## Сессия занятия: порядок пар, лимит попыток, прогресс и итог.
##
## Сессия короткая и без давления: нет ежедневной серии. Порядок пар
## перемешивается, число попыток ограничено. Каждая попытка пишется в прогресс
## через SaveManager, а завершение занятия отмечается один раз.

const DEFAULT_MAX_ATTEMPTS := 15

var _pairs: Array[Dictionary] = []
var _order: Array[int] = []
var _index := 0
var _results: Array[Dictionary] = []
var _finished := false
var _recorded_completion := false
var _mode_id: String = ""
var _rng := RandomNumberGenerator.new()


## Готовит сессию по набору. seed_value = 0 значит случайный порядок.
func start(set_id: String, max_attempts := DEFAULT_MAX_ATTEMPTS, seed_value := 0, mode_id := "") -> bool:
	_pairs = SetRepository.get_playable_pairs(set_id)
	if _pairs.is_empty():
		return false
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_mode_id = mode_id
	_order = _build_order(max_attempts)
	_index = 0
	_results.clear()
	_finished = false
	_recorded_completion = false
	return true


func current_pair() -> Dictionary:
	if _finished or _index >= _order.size():
		return {}
	return _pairs[_order[_index]]


func current_index() -> int:
	return _index


func total() -> int:
	return _order.size()


func is_finished() -> bool:
	return _finished


## Записывает попытку, двигает сессию и завершает её на последней попытке.
func advance(correct: bool) -> void:
	if _finished:
		return
	var pair := current_pair()
	if not pair.is_empty():
		var pair_id := str(pair.get("id", ""))
		_results.append({"pair_id": pair_id, "correct": correct})
		if not pair_id.is_empty():
			ProgressStore.record_attempt(pair_id, correct, _mode_id)
	_index += 1
	if _index >= _order.size():
		finish()


## Завершает сессию по кнопке. Повторный вызов не удваивает счёт.
func finish() -> void:
	_finished = true
	if _recorded_completion:
		return
	_recorded_completion = true
	SaveManager.complete_session()


func summary() -> Dictionary:
	var correct := 0
	for result: Dictionary in _results:
		if bool(result.get("correct", false)):
			correct += 1
	return {
		"attempts": _results.size(),
		"correct": correct,
		"pairs": _results.duplicate(true),
	}


func _build_order(max_attempts: int) -> Array[int]:
	var total := maxi(1, mini(max_attempts, _pairs.size() * 3))
	var order: Array[int] = []
	while order.size() < total:
		var cycle: Array[int] = []
		for i in _pairs.size():
			cycle.append(i)
		_shuffle(cycle)
		for idx: int in cycle:
			if order.size() >= total:
				break
			order.append(idx)
	return order


func _shuffle(values: Array[int]) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := values[i]
		values[i] = values[j]
		values[j] = tmp
