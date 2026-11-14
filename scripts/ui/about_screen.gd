extends Control
## Экран «О проекте»: версия, дисклеймер и приватность простыми словами.
##
## Экран доступен из родительского раздела. Тексты осторожные: приложение не
## ставит диагноз, не заменяет логопеда и не обещает постановку звука.

const DISCLAIMER_TEXT := "Звуколёт помогает провести короткое занятие дома. Приложение не ставит диагноз, не заменяет логопеда и не обещает постановку звука."
const PRIVACY_TEXT := "Приложение работает офлайн. Оно не собирает данные, не требует аккаунта и не отправляет ничего в сеть. Прогресс и настройки хранятся только на устройстве."


func _ready() -> void:
	_build_ui()


## Версия приложения для показа родителю.
func version_text() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.1.0"))


func has_disclaimer() -> bool:
	return _find_text(self, "не заменяет логопеда")


func has_privacy() -> bool:
	return _find_text(self, "не собирает данные")


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
	title.text = "О проекте"
	ScreenStyle.title(title)
	layout.add_child(title)

	var version := Label.new()
	version.text = "Звуколёт, версия %s" % version_text()
	ScreenStyle.subtitle(version)
	layout.add_child(version)

	_add_section(layout, "Дисклеймер")
	_add_paragraph(layout, DISCLAIMER_TEXT)

	_add_section(layout, "Приватность")
	_add_paragraph(layout, PRIVACY_TEXT)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	layout.add_child(spacer)

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


func _add_paragraph(layout: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(label)


func _on_back_pressed() -> void:
	Navigation.back()


func _find_text(node: Node, needle: String) -> bool:
	if node is Label and str((node as Label).text).contains(needle):
		return true
	for child in node.get_children():
		if _find_text(child, needle):
			return true
	return false
