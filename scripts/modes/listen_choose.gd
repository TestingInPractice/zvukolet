extends ModeBase
## Режим «послушай и выбери»: ребёнок слышит слово и выбирает картинку.
##
## Проверяет слуховое различение, а не произношение.

func _mode_title() -> String:
	return "Послушай и выбери"


func _instruction(_pair: Dictionary, _side: String) -> String:
	return "Послушай слово и выбери картинку."


func _play_sample(pair: Dictionary, side: String) -> void:
	AudioManager.play_pair_side(pair, side)


func _render(pair: Dictionary, side: String) -> void:
	_play_sample(pair, side)
	_add_image_button(str(pair.get("image_a", "")), "a")
	_add_image_button(str(pair.get("image_b", "")), "b")
