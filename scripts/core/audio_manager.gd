extends Node
## Единая точка воспроизведения звука: голос, SFX и музыка.
##
## Правило голоса: одновременно звучит один голосовой файл. Новый голос по
## умолчанию отменяет текущий; с queue=true встаёт в очередь и заиграет после
## текущего. SFX играют на отдельных плеерах и не перебивают голос. Музыка идёт
## на своём плеере. Отсутствующий файл не ломает игру: пишем предупреждение и
## возвращаем false. Autoload AudioManager.

signal voice_started(path: String)
signal voice_finished(path: String)
signal sfx_played(path: String)

const SFX_PLAYERS := 4
const BUS_VOICE := "Voice"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const SILENT_DB := -80.0

var _voice_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _voice_queue: Array[String] = []
var _current_voice_path: String = ""
var _sfx_index := 0
var _master_volume := 1.0
var _voice_volume := 1.0
var _sfx_volume := 0.6
var _music_volume := 1.0


func _ready() -> void:
	_voice_player = _make_player(BUS_VOICE)
	_voice_player.finished.connect(_on_voice_finished)
	_music_player = _make_player(BUS_MUSIC)
	for i in SFX_PLAYERS:
		_sfx_players.append(_make_player(BUS_SFX))
	_apply_all_volumes()


## Проигрывает голосовой файл. queue=true добавляет в очередь, если голос уже
## звучит. Возвращает true, если файл найден и воспроизведение начато.
func play_voice(path: String, queue := false) -> bool:
	if path.is_empty():
		return false
	if _voice_player.playing and queue:
		_voice_queue.append(path)
		return true
	var stream := _load_stream(path)
	if stream == null:
		return false
	_voice_queue.clear()
	_current_voice_path = path
	_voice_player.stream = stream
	_voice_player.play()
	voice_started.emit(path)
	return true


## Удобный помощник: проигрывает слово пары по стороне "a" или "b".
func play_pair_side(pair: Dictionary, side: String, queue := false) -> bool:
	return play_voice(str(pair.get("audio_" + side, "")), queue)


## Проигрывает короткий звук на отдельном плеере, не трогая голос.
func play_sfx(path: String) -> bool:
	if path.is_empty():
		return false
	var stream := _load_stream(path)
	if stream == null:
		return false
	var player := _next_sfx_player()
	player.stream = stream
	player.play()
	sfx_played.emit(path)
	return true


## Запускает музыку на отдельном плеере. Голос и SFX не затрагиваются.
func play_music(path: String) -> bool:
	if path.is_empty():
		return false
	var stream := _load_stream(path)
	if stream == null:
		return false
	_music_player.stream = stream
	_music_player.play()
	return true


func stop_music() -> void:
	_music_player.stop()
	_music_player.stream = null


## Останавливает голос и очищает очередь.
func stop_voice() -> void:
	_voice_queue.clear()
	_current_voice_path = ""
	_voice_player.stop()
	_voice_player.stream = null


## Останавливает все интерфейсные звуки.
func stop_sfx() -> void:
	for player in _sfx_players:
		player.stop()
		player.stream = null


func is_voice_playing() -> bool:
	return _voice_player.playing


func voice_queue_size() -> int:
	return _voice_queue.size()


func clear_voice_queue() -> void:
	_voice_queue.clear()


func set_master_volume(linear: float) -> void:
	_master_volume = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, _linear_to_db(_master_volume))


func get_master_volume() -> float:
	return _master_volume


func set_voice_volume(linear: float) -> void:
	_voice_volume = clampf(linear, 0.0, 1.0)
	_set_bus_volume(BUS_VOICE, _voice_volume)


func get_voice_volume() -> float:
	return _voice_volume


func set_sfx_volume(linear: float) -> void:
	_sfx_volume = clampf(linear, 0.0, 1.0)
	_set_bus_volume(BUS_SFX, _sfx_volume)


func get_sfx_volume() -> float:
	return _sfx_volume


func set_music_volume(linear: float) -> void:
	_music_volume = clampf(linear, 0.0, 1.0)
	_set_bus_volume(BUS_MUSIC, _music_volume)


func get_music_volume() -> float:
	return _music_volume


func _on_voice_finished() -> void:
	if not _current_voice_path.is_empty():
		voice_finished.emit(_current_voice_path)
		_current_voice_path = ""
	if _voice_queue.is_empty():
		return
	var next_path: String = _voice_queue.pop_front()
	play_voice(next_path)


func _make_player(bus_name: String) -> AudioStreamPlayer:
	_ensure_bus(bus_name)
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, _linear_to_db(linear))


func _apply_all_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _linear_to_db(_master_volume))
	_set_bus_volume(BUS_VOICE, _voice_volume)
	_set_bus_volume(BUS_SFX, _sfx_volume)
	_set_bus_volume(BUS_MUSIC, _music_volume)


func _next_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	var chosen := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	return chosen


func _load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		AppLogger.warning("AudioManager", "audio not found: " + path)
		return null
	var resource := load(path)
	if resource is AudioStream:
		return resource
	AppLogger.warning("AudioManager", "not an audio stream: " + path)
	return null


func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return SILENT_DB
	return linear_to_db(linear)
