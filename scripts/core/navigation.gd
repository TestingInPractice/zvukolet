extends Node
## Навигация между экранами MVP: старт, выбор режима, игра, итог, конструктор.
##
## Держит историю экранов, чтобы кнопка `Назад` возвращала на предыдущий экран.
## Игровой экран читает выбранный режим из `selected_mode`.

signal navigated(scene_path: String)

const START := "res://scenes/main.tscn"
const MODE_SELECT := "res://scenes/mode_select.tscn"
const GAME := "res://scenes/game.tscn"
const SESSION_SUMMARY := "res://scenes/session_summary.tscn"
const SET_LIST := "res://scenes/constructor/set_list.tscn"
const PARENT_SCREEN := "res://scenes/parent_screen.tscn"
const SETTINGS := "res://scenes/settings.tscn"
const ABOUT_SCREEN := "res://scenes/about_screen.tscn"

const MODE_IDS := ["listen_choose", "repeat_after_adult", "name_picture"]

var selected_mode: String = ""
var last_summary: Dictionary = {}
var _history: Array[String] = []


## Переходит на экран и запоминает текущий экран для возврата.
func goto(path: String) -> void:
	_push_current(path)
	get_tree().change_scene_to_file(path)
	navigated.emit(path)


## Переходит на игровой экран с выбранным режимом.
func goto_mode(mode_id: String) -> void:
	selected_mode = mode_id
	goto(GAME)


## Возвращает на предыдущий экран. Если истории нет, открывает стартовый экран.
func back() -> void:
	if _history.is_empty():
		_replace_with(START)
		return
	var path: String = _history.pop_back()
	get_tree().change_scene_to_file(path)
	navigated.emit(path)


## Открывает стартовый экран и очищает историю.
func reset_to_start() -> void:
	_history.clear()
	selected_mode = ""
	get_tree().change_scene_to_file(START)
	navigated.emit(START)


func history_size() -> int:
	return _history.size()


## Человекочитаемое название режима для интерфейса.
func mode_title(mode_id: String) -> String:
	match mode_id:
		"listen_choose":
			return "Послушай и выбери"
		"repeat_after_adult":
			return "Повтори за взрослым"
		"name_picture":
			return "Назови картинку"
		_:
			return "Режим"


func _push_current(next_path: String) -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	var current_path := current.scene_file_path
	if current_path.is_empty() or current_path == next_path:
		return
	_history.append(current_path)


func _replace_with(path: String) -> void:
	_history.clear()
	get_tree().change_scene_to_file(path)
	navigated.emit(path)
