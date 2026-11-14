class_name ScreenStyle
extends RefCounted
## Минимальный единый стиль экранов MVP: крупные кнопки и читаемые подписи.
##
## Полноценная UI-тема живёт в assets/ui/theme.tres и подключается как
## тема проекта. Здесь остаются размеры заголовков и иконки режимов и навигации.

const TITLE_FONT_SIZE := 56
const SUBTITLE_FONT_SIZE := 30
const BUTTON_FONT_SIZE := 40
const BUTTON_MIN_HEIGHT := 96

const ICON_MODE := {
	"listen_choose": "res://assets/ui/icons/mode_listen_choose.svg",
	"repeat_after_adult": "res://assets/ui/icons/mode_repeat_after_adult.svg",
	"name_picture": "res://assets/ui/icons/mode_name_picture.svg",
}
const ICON_BACK := "res://assets/ui/icons/back_arrow.svg"


static func title(label: Label) -> void:
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func subtitle(label: Label) -> void:
	label.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func big_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Ставит иконку режима на кнопку, если иконка есть.
static func mode_icon(button: Button, mode_id: String) -> void:
	_apply_icon(button, str(ICON_MODE.get(mode_id, "")))


## Ставит иконку возврата на кнопку, если иконка есть.
static func back_icon(button: Button) -> void:
	_apply_icon(button, ICON_BACK)


static func _apply_icon(button: Button, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	button.icon = load(path)
	button.expand_icon = true


## Подключает короткий звук клика к нажатию кнопки.
static func wire_click(button: Button) -> void:
	button.pressed.connect(SfxLibrary.click)
