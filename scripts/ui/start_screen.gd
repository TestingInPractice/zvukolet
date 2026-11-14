extends Control
## Стартовый экран: короткое объяснение, вход в занятие и в конструктор наборов.

@onready var _start_button: Button = %StartButton
@onready var _constructor_button: Button = %ConstructorButton
@onready var _parent_button: Button = %ParentButton


func _ready() -> void:
	for button: Button in [_start_button, _constructor_button, _parent_button]:
		ScreenStyle.wire_click(button)
	_start_button.pressed.connect(_on_start_pressed)
	_constructor_button.pressed.connect(_on_constructor_pressed)
	_parent_button.pressed.connect(_on_parent_pressed)


func _on_start_pressed() -> void:
	Navigation.goto(Navigation.MODE_SELECT)


func _on_constructor_pressed() -> void:
	Navigation.goto(Navigation.SET_LIST)


func _on_parent_pressed() -> void:
	Navigation.goto(Navigation.PARENT_SCREEN)
