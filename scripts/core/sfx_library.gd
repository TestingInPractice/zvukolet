class_name SfxLibrary
extends RefCounted
## Пути коротких интерфейсных звуков и удобные помощники воспроизведения.
##
## Файлы заглушечные и короткие. Все вызовы идут через AudioManager, поэтому
## отсутствующий файл не ломает игру, а лишь пишет предупреждение.

const CLICK := "res://assets/audio/sfx/click.wav"
const CORRECT := "res://assets/audio/sfx/correct.wav"
const ERROR := "res://assets/audio/sfx/error.wav"
const COMPLETE := "res://assets/audio/sfx/complete.wav"

const ALL := [CLICK, CORRECT, ERROR, COMPLETE]


static func play(path: String) -> bool:
	return AudioManager.play_sfx(path)


static func click() -> bool:
	return play(CLICK)


static func correct() -> bool:
	return play(CORRECT)


static func error() -> bool:
	return play(ERROR)


static func complete() -> bool:
	return play(COMPLETE)
