extends Control
## Экран выбора режима: три крупные кнопки и возврат назад.
##
## Список режимов берётся из Navigation.MODE_IDS, чтобы экраны не расходились.

const MODE_LABELS := {
	"listen_choose": "Послушай и выбери",
	"repeat_after_adult": "Повтори за взрослым",
	"name_picture": "Назови картинку",
}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Выбери режим"
	ScreenStyle.title(title)
	layout.add_child(title)

	for mode_id: String in Navigation.MODE_IDS:
		var button := Button.new()
		button.text = str(MODE_LABELS.get(mode_id, mode_id))
		ScreenStyle.big_button(button)
		ScreenStyle.mode_icon(button, mode_id)
		ScreenStyle.wire_click(button)
		button.pressed.connect(_on_mode_pressed.bind(mode_id))
		layout.add_child(button)

	var back_button := Button.new()
	back_button.text = "Назад"
	ScreenStyle.big_button(back_button)
	ScreenStyle.back_icon(back_button)
	ScreenStyle.wire_click(back_button)
	back_button.pressed.connect(_on_back_pressed)
	layout.add_child(back_button)


func _on_mode_pressed(mode_id: String) -> void:
	Navigation.goto_mode(mode_id)


func _on_back_pressed() -> void:
	Navigation.back()
