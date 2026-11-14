extends SceneTree
## Собирает UI-тему MVP и сохраняет её в assets/ui/theme.tres.
##
## Запуск: godot --headless --path . --script tools/build_ui_theme.gd
## Тема задаёт крупные спокойные кнопки, читаемые подписи и скругления.

const OUTPUT := "res://assets/ui/theme.tres"

const COLOR_TEXT := Color("#3A3A3A")
const COLOR_PRIMARY := Color("#3D8B7D")
const COLOR_PRIMARY_HOVER := Color("#4AA091")
const COLOR_PRIMARY_PRESSED := Color("#2F6E63")
const COLOR_DISABLED := Color("#B8C4C0")
const COLOR_SURFACE := Color("#FFFFFF")
const COLOR_FOCUS := Color("#E0A458")


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font_size = 30

	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_color", "Button", COLOR_SURFACE)
	theme.set_color("font_hover_color", "Button", COLOR_SURFACE)
	theme.set_color("font_pressed_color", "Button", COLOR_SURFACE)
	theme.set_color("font_focus_color", "Button", COLOR_SURFACE)
	theme.set_color("font_disabled_color", "Button", Color("#E8EEEC"))
	theme.set_font_size("font_size", "Button", 40)

	theme.set_stylebox("normal", "Button", _button_box(COLOR_PRIMARY))
	theme.set_stylebox("hover", "Button", _button_box(COLOR_PRIMARY_HOVER))
	theme.set_stylebox("pressed", "Button", _button_box(COLOR_PRIMARY_PRESSED))
	theme.set_stylebox("disabled", "Button", _button_box(COLOR_DISABLED))
	theme.set_stylebox("focus", "Button", _focus_box())

	var panel := StyleBoxFlat.new()
	panel.bg_color = COLOR_SURFACE
	panel.set_corner_radius_all(24)
	panel.set_content_margin_all(24)
	theme.set_stylebox("panel", "PanelContainer", panel)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	var err := ResourceSaver.save(theme, OUTPUT)
	if err != OK:
		push_error("cannot save theme: %d" % err)
		quit(1)
		return
	print("theme saved: ", OUTPUT)
	quit(0)


func _button_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(20)
	box.set_content_margin_all(20)
	box.content_margin_left = 28
	box.content_margin_right = 28
	return box


func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_corner_radius_all(20)
	box.set_border_width_all(4)
	box.border_color = COLOR_FOCUS
	return box
