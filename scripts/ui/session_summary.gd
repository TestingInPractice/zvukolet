extends Control
## Экран итога сессии: попытки и верные ответы. Итог приходит из Navigation.

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var summary := Navigation.last_summary
	var attempts := int(summary.get("attempts", 0))
	var correct := int(summary.get("correct", 0))

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
	title.text = "Итог занятия"
	ScreenStyle.title(title)
	layout.add_child(title)

	var stats := Label.new()
	stats.text = "Попыток: %d. Получилось: %d." % [attempts, correct]
	ScreenStyle.subtitle(stats)
	layout.add_child(stats)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var done_button := Button.new()
	done_button.text = "Готово"
	ScreenStyle.big_button(done_button)
	ScreenStyle.wire_click(done_button)
	done_button.pressed.connect(_on_done_pressed)
	layout.add_child(done_button)


func _on_done_pressed() -> void:
	Navigation.reset_to_start()
