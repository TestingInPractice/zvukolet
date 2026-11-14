extends ModeBase
## Режим «повтори за взрослым»: взрослый помогает ребёнку повторить слово.
##
## Приложение не оценивает артикуляцию: результат отмечает взрослый.

func _mode_title() -> String:
	return "Повтори за взрослым"


func _instruction(_pair: Dictionary, _side: String) -> String:
	return "Взрослый называет слово, ребёнок повторяет. Отметьте результат."


func _word_text(pair: Dictionary, side: String) -> String:
	return str(pair.get("word_" + side, ""))


func _play_sample(pair: Dictionary, side: String) -> void:
	AudioManager.play_pair_side(pair, side)


func _render(pair: Dictionary, side: String) -> void:
	_play_sample(pair, side)
	_add_image(str(pair.get("image_" + side, "")))
	_add_text_button("Получилось", true)
	_add_text_button("Повторим", false)
