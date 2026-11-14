extends ModeBase
## Режим «назови картинку»: ребёнок называет слово сам, взрослый отмечает.
##
## Приложение не распознаёт речь: результат ставит взрослый.

func _mode_title() -> String:
	return "Назови картинку"


func _instruction(_pair: Dictionary, _side: String) -> String:
	return "Ребёнок называет, что на картинке. Отметьте результат."


func _render(pair: Dictionary, side: String) -> void:
	_add_image(str(pair.get("image_" + side, "")))
	_add_text_button("Верно", true)
	_add_text_button("Повторим", false)
