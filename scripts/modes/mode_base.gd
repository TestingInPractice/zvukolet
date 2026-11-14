class_name ModeBase
extends Control
## Общая основа игровых режимов: прогресс, картинки, обратная связь, повтор.
##
## Наследники задают заголовок, инструкцию, отрисовку вариантов и звук образца.
## Базовый класс ведёт прогресс, показывает мягкую обратную связь и двигает
## сессию.

const FEEDBACK_DELAY := 0.9

var _session: SessionController
var _progress_label: Label
var _instruction_label: Label
var _word_label: Label
var _image_row: HBoxContainer
var _feedback_label: Label
var _answer_row: HBoxContainer
var _answered := false


func setup(session: SessionController) -> void:
	_session = session
	_build_ui()
	_show_current()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	_progress_label = Label.new()
	ScreenStyle.subtitle(_progress_label)
	layout.add_child(_progress_label)

	_instruction_label = Label.new()
	ScreenStyle.subtitle(_instruction_label)
	layout.add_child(_instruction_label)

	_word_label = Label.new()
	ScreenStyle.title(_word_label)
	layout.add_child(_word_label)

	_image_row = HBoxContainer.new()
	_image_row.add_theme_constant_override("separation", 24)
	_image_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_image_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_image_row)

	_feedback_label = Label.new()
	ScreenStyle.title(_feedback_label)
	layout.add_child(_feedback_label)

	_answer_row = HBoxContainer.new()
	_answer_row.add_theme_constant_override("separation", 24)
	_answer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(_answer_row)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	layout.add_child(bottom)

	var repeat_button := Button.new()
	repeat_button.text = "Повторить звук"
	ScreenStyle.big_button(repeat_button)
	repeat_button.pressed.connect(_on_repeat)
	bottom.add_child(repeat_button)

	var finish_button := Button.new()
	finish_button.text = "Закончить"
	ScreenStyle.big_button(finish_button)
	finish_button.pressed.connect(_on_finish)
	bottom.add_child(finish_button)


func _show_current() -> void:
	var pair := _session.current_pair()
	if pair.is_empty():
		_on_finish()
		return
	var side := _target_side()
	_progress_label.text = "Пара %d из %d" % [_session.current_index() + 1, _session.total()]
	_instruction_label.text = _instruction(pair, side)
	_word_label.text = _word_text(pair, side)
	_feedback_label.text = ""
	_clear(_image_row)
	_clear(_answer_row)
	_render(pair, side)


func _on_answer(correct: bool) -> void:
	if _answered:
		return
	_answered = true
	if correct:
		SfxLibrary.correct()
	else:
		SfxLibrary.error()
	_feedback_label.text = "Верно" if correct else "Почти, попробуем ещё"
	_session.advance(correct)
	await get_tree().create_timer(FEEDBACK_DELAY).timeout
	if not is_inside_tree():
		return
	_answered = false
	if _session.is_finished():
		_on_finish()
	else:
		_show_current()


func _on_repeat() -> void:
	var pair := _session.current_pair()
	if pair.is_empty():
		return
	_play_sample(pair, _target_side())


func _on_finish() -> void:
	SfxLibrary.complete()
	if _session != null and not _session.is_finished():
		_session.finish()
	Navigation.last_summary = _session.summary() if _session != null else {}
	Navigation.goto(Navigation.SESSION_SUMMARY)


func _target_side() -> String:
	return "a" if _session.current_index() % 2 == 0 else "b"


func _add_image(path: String) -> void:
	var texture := _load_texture(path)
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(240, 240)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if texture != null:
		rect.texture = texture
	_image_row.add_child(rect)


func _add_image_button(path: String, side: String) -> void:
	var texture := _load_texture(path)
	var button := Button.new()
	button.custom_minimum_size = Vector2(240, 240)
	button.expand_icon = true
	if texture != null:
		button.icon = texture
	button.pressed.connect(_on_answer.bind(side == _target_side()))
	_answer_row.add_child(button)


func _add_text_button(text: String, correct: bool) -> void:
	var button := Button.new()
	button.text = text
	ScreenStyle.big_button(button)
	button.pressed.connect(_on_answer.bind(correct))
	_answer_row.add_child(button)


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	if resource is Texture2D:
		return resource
	return null


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _mode_title() -> String:
	return "Режим"


func _instruction(_pair: Dictionary, _side: String) -> String:
	return ""


func _word_text(_pair: Dictionary, _side: String) -> String:
	return ""


func _play_sample(_pair: Dictionary, _side: String) -> void:
	pass


func _render(_pair: Dictionary, _side: String) -> void:
	pass
