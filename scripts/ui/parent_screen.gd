extends Control
## Родительский экран: прогресс по парам и режимам без клинических выводов.
##
## Показывает, какие пары уже встречались, где чаще были ошибки и сколько было
## занятий. Проценты артикуляции не показываются: оценка остаётся за взрослым.

func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)

	var title := Label.new()
	title.text = "Прогресс"
	ScreenStyle.title(title)
	layout.add_child(title)

	var note := Label.new()
	note.text = "Это не диагностика. Здесь видно, какие пары уже встречались и где чаще были ошибки."
	ScreenStyle.subtitle(note)
	layout.add_child(note)

	_add_section(layout, "Пары")
	var pairs := ProgressStore.pairs_summary()
	if pairs.is_empty():
		_add_line(layout, "Пока нет данных. Проведите занятие.")
	else:
		for entry: Dictionary in pairs:
			_add_line(layout, "%s. Попыток: %d, ошибок: %d." % [
				str(entry.get("label", "")),
				int(entry.get("attempts", 0)),
				int(entry.get("errors", 0)),
			])

	_add_section(layout, "Режимы")
	for entry: Dictionary in ProgressStore.modes_summary():
		_add_line(layout, "%s. Попыток: %d, верных: %d." % [
			str(entry.get("title", "")),
			int(entry.get("attempts", 0)),
			int(entry.get("correct", 0)),
		])

	_add_section(layout, "Последнее занятие")
	var session := ProgressStore.last_session()
	if int(session.get("sessions_completed", 0)) == 0:
		_add_line(layout, "Занятий пока не было.")
	else:
		_add_line(layout, "Всего занятий: %d." % int(session.get("sessions_completed", 0)))
		_add_line(layout, "Последнее: %s." % str(session.get("last_session_at", "")))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	layout.add_child(spacer)

	var settings_button := Button.new()
	settings_button.text = "Настройки"
	ScreenStyle.big_button(settings_button)
	ScreenStyle.wire_click(settings_button)
	settings_button.pressed.connect(_on_settings_pressed)
	layout.add_child(settings_button)

	var about_button := Button.new()
	about_button.text = "О проекте"
	ScreenStyle.big_button(about_button)
	ScreenStyle.wire_click(about_button)
	about_button.pressed.connect(_on_about_pressed)
	layout.add_child(about_button)

	var back_button := Button.new()
	back_button.text = "Назад"
	ScreenStyle.big_button(back_button)
	ScreenStyle.back_icon(back_button)
	ScreenStyle.wire_click(back_button)
	back_button.pressed.connect(_on_back_pressed)
	layout.add_child(back_button)


func _add_section(layout: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	ScreenStyle.subtitle(label)
	layout.add_child(label)


func _add_line(layout: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(label)


func _on_settings_pressed() -> void:
	Navigation.goto(Navigation.SETTINGS)


func _on_about_pressed() -> void:
	Navigation.goto(Navigation.ABOUT_SCREEN)


func _on_back_pressed() -> void:
	Navigation.back()
