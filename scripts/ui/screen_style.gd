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

const CARD_FILL := Color(1, 1, 1, 0.9)
const CARD_BORDER := Color(0.2901961, 0.627451, 0.5686275, 1)
const CARD_BORDER_WIDTH := 6
const CARD_RADIUS := 28
const CARD_PADDING := 18
const IMAGE_CARD_SIZE := 440


## Стиль карточки-контейнера: цветная рамка и приглушённая заливка,
## чтобы картинка предмета читалась, а контейнер не отвлекал.
static func image_card_box(fill: Color = CARD_FILL, border: Color = CARD_BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(CARD_BORDER_WIDTH)
	box.border_color = border
	box.set_corner_radius_all(CARD_RADIUS)
	box.set_content_margin_all(CARD_PADDING)
	return box


## Оформляет кнопку-картинку как контейнер с цветной рамкой.
static func image_card_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(IMAGE_CARD_SIZE, IMAGE_CARD_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.expand_icon = true
	button.add_theme_stylebox_override("normal", image_card_box())
	button.add_theme_stylebox_override("hover", image_card_box(Color(1, 1, 1, 1), CARD_BORDER.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", image_card_box(Color(0.9, 0.93, 0.92, 1), CARD_BORDER.darkened(0.1)))
	button.add_theme_stylebox_override("focus", image_card_box(Color(1, 1, 1, 0.95), CARD_BORDER))


## Контейнер для статичной картинки: та же рамка и заливка, что у кнопки-картинки.
static func image_card_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(IMAGE_CARD_SIZE, IMAGE_CARD_SIZE)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", image_card_box())
	return panel


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
