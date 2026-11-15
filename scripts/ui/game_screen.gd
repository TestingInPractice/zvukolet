extends Control
## Игровой экран: запускает сессию и подгружает выбранный режим.
##
## Режим берётся из Navigation.selected_mode. Если набор недоступен, показываем
## понятную заглушку вместо падения.

const MODE_SCENES := {
	"listen_choose": "res://scenes/modes/listen_choose.tscn",
	"repeat_after_adult": "res://scenes/modes/repeat_after_adult.tscn",
	"name_picture": "res://scenes/modes/name_picture.tscn",
}
const DEFAULT_MODE := "listen_choose"
const DEFAULT_MAX_ATTEMPTS := 15

var _session: SessionController


func _ready() -> void:
	var set_id := Navigation.selected_set_id
	if set_id.is_empty() or not SetRepository.set_exists(set_id):
		set_id = SetRepository.get_default_set_id()
	var mode_id := Navigation.selected_mode
	if not MODE_SCENES.has(mode_id):
		mode_id = DEFAULT_MODE
	_session = SessionController.new()
	if not _session.start(set_id, DEFAULT_MAX_ATTEMPTS, 0, mode_id):
		_build_empty()
		return
	var scene := load(str(MODE_SCENES.get(mode_id, ""))) as PackedScene
	if scene == null:
		_build_empty()
		return
	var mode := scene.instantiate() as ModeBase
	add_child(mode)
	mode.setup(_session)


func _build_empty() -> void:
	var label := Label.new()
	label.text = "Нет доступного набора."
	ScreenStyle.title(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
