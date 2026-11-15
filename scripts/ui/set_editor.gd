class_name SetEditor
extends Control
## Редактор пользовательского набора: имя, режим и пары слов, введённые вручную.
##
## Пары не берутся из готовой библиотеки: взрослый сам вводит два слова. Для
## каждого слова можно приложить свою картинку и свою озвучку: выбрать файл,
## записать голос с микрофона, послушать и убрать. Если своего медиа нет, слово
## берёт картинку и звук из встроенной библиотеки по тексту слова; если и там
## нет, слово показывается текстом. Набор самодостаточен и переносится .zvset.

signal set_saved(set_id: String)
signal close_requested()

## Предел одной записи с микрофона. Дольше десяти секунд слово не произносят,
## а забытая запись не должна расти бесконечно.
const RECORD_DURATION := 10.0

var _set_id: String = ""
var _mode_id: String = ""
var _row_edits: Array[Dictionary] = []
var _row_seq := 0

var _name_edit: LineEdit
var _mode_label: Label
var _rows_box: VBoxContainer
var _message: AcceptDialog
var _save_dialog: FileDialog
var _pending_bytes: PackedByteArray = PackedByteArray()

## Идёт ли запись и для какого слова. Запись одна на весь экран: AudioEffectCapture
## на шине один, второй одновременный захват невозможен.
var _recording_row_id: String = ""
var _recording_side: String = ""
## Токен сторожа записи: новый отсчёт отменяет предыдущий, чтобы авто-стоп
## сработал ровно один раз для текущей записи.
var _record_guard_token := 0


func _ready() -> void:
	_build_ui()


## Открывает набор для правки.
func open_set(set_id: String) -> void:
	_set_id = set_id
	var record := CustomSetsStore.get_set(set_id)
	if record.is_empty():
		AppLogger.warning("SetEditor", "set_missing", {"set_id": set_id})
		return
	_mode_id = str(record.get("mode_id", ""))
	_name_edit.text = str(record.get("name", ""))
	_mode_label.text = "Режим: " + _mode_title(_mode_id)
	_rebuild_rows(CustomSetsStore.get_pair_ids(set_id))
	AppLogger.info("SetEditor", "opened", {"set_id": set_id, "pairs": _row_edits.size()})


## Заполненные пары редактора (оба слова непустые). Для тестов и сохранения.
func get_pairs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _row_edits:
		var word_a := (entry["a"] as LineEdit).text.strip_edges()
		var word_b := (entry["b"] as LineEdit).text.strip_edges()
		if word_a.is_empty() or word_b.is_empty():
			continue
		result.append({"word_a": word_a, "word_b": word_b})
	return result


## Режим открытого набора. Для тестов.
func get_mode_id() -> String:
	return _mode_id


## Идентификаторы строк редактора. Для тестов и привязки обработчиков.
func row_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in _row_edits:
		ids.append(str(entry.get("row_id", "")))
	return ids


## Прикладывает картинку к слову пары: ужимает и пишет в user:// набора.
## Возвращает результат ImageSaver. Для тестов и обработчика выбора файла.
func apply_image(row_id: String, side: String, bytes: PackedByteArray) -> Dictionary:
	var entry := _find_entry(row_id)
	if entry.is_empty():
		return {"ok": false, "error": "no_row"}
	var base := _ensure_media_base(entry)
	var target := CustomSetsStore.set_dir(_set_id) + CustomSetsStore.image_file_name(base, side)
	var saved := ImageSaver.save_image(bytes, target)
	if not bool(saved.get("ok", false)):
		_set_status(entry, side, "Не удалось: " + str(saved.get("error", "")))
		return saved
	entry["image_" + side] = target
	SetRepository.clear_cache()
	_refresh_side(entry, side)
	_set_status(entry, side, "Картинка добавлена")
	return saved


## Прикладывает озвучку к слову пары. bytes — данные в готовом формате, extension —
## расширение файла без точки. Для тестов и обработчиков записи/выбора файла.
func apply_audio(row_id: String, side: String, bytes: PackedByteArray, extension: String) -> Dictionary:
	var entry := _find_entry(row_id)
	if entry.is_empty():
		return {"ok": false, "error": "no_row"}
	var ext := extension.strip_edges().to_lower().trim_prefix(".")
	if ext.is_empty():
		return {"ok": false, "error": "bad_extension"}
	if bytes.is_empty():
		_set_status(entry, side, "Пустая запись")
		return {"ok": false, "error": "empty_bytes"}
	var base := _ensure_media_base(entry)
	var target := CustomSetsStore.set_dir(_set_id) + CustomSetsStore.audio_file_name(base, side, ext)
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		_set_status(entry, side, "Не удалось сохранить звук")
		return {"ok": false, "error": "write_failed"}
	file.store_buffer(bytes)
	file.close()
	entry["audio_" + side] = target
	SetRepository.clear_cache()
	_refresh_side(entry, side)
	_set_status(entry, side, "Озвучка добавлена")
	return {"ok": true, "error": ""}


## Убирает свою картинку и озвучку слова. Библиотечное медиа подставится снова.
func clear_media(row_id: String, side: String) -> void:
	var entry := _find_entry(row_id)
	if entry.is_empty():
		return
	for key: String in ["image_" + side, "audio_" + side]:
		var path := str(entry.get(key, ""))
		if not path.is_empty():
			CustomSetsStore.remove_media_file(path)
			entry[key] = ""
	SetRepository.clear_cache()
	_refresh_side(entry, side)
	_set_status(entry, side, "Своё медиа убрано")


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Редактор набора"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Название набора"
	layout.add_child(_name_edit)

	_mode_label = Label.new()
	layout.add_child(_mode_label)

	var hint := Label.new()
	hint.text = "Введите пары слов. Для каждого слова можно приложить свою картинку и озвучку; без них подставится картинка и звук из библиотеки."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

	var add_button := Button.new()
	add_button.text = "Добавить пару"
	add_button.pressed.connect(_on_add_pair)
	layout.add_child(add_button)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)

	var save_button := Button.new()
	save_button.text = "Сохранить"
	save_button.pressed.connect(_on_save)
	buttons.add_child(save_button)

	var export_button := Button.new()
	export_button.text = "Экспорт .zvset"
	export_button.pressed.connect(_on_export)
	buttons.add_child(export_button)

	_back_button_setup(layout)

	_message = AcceptDialog.new()
	add_child(_message)

	_save_dialog = FileDialog.new()
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.use_native_dialog = true
	_save_dialog.filters = PackedStringArray(["*." + SetPackageFormat.EXTENSION])
	_save_dialog.file_selected.connect(_on_save_path_selected)
	add_child(_save_dialog)


func _back_button_setup(layout: VBoxContainer) -> void:
	var back_button := Button.new()
	back_button.text = "Назад"
	ScreenStyle.back_icon(back_button)
	back_button.pressed.connect(func() -> void: close_requested.emit())
	layout.add_child(back_button)


func _rebuild_rows(pair_ids: Array[String]) -> void:
	for child in _rows_box.get_children():
		child.queue_free()
	_row_edits.clear()
	for pair_id in pair_ids:
		var pair := CustomSetsStore.get_pair(_set_id, pair_id)
		_add_row(str(pair.get("word_a", "")), str(pair.get("word_b", "")), pair)
	if _row_edits.is_empty():
		_add_row("", "", {})


## Строит строку пары: два поля слов и два блока медиа (по одному на слово).
func _add_row(word_a: String, word_b: String, media: Dictionary) -> void:
	_row_seq += 1
	var row_id := "row_" + str(_row_seq)

	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)

	var edit_a := LineEdit.new()
	edit_a.placeholder_text = "Слово 1"
	edit_a.text = word_a
	edit_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(edit_a)

	var edit_b := LineEdit.new()
	edit_b.placeholder_text = "Слово 2"
	edit_b.text = word_b
	edit_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(edit_b)

	var remove_button := Button.new()
	remove_button.text = "Удалить"
	top.add_child(remove_button)

	var entry := {
		"row_id": row_id,
		"a": edit_a,
		"b": edit_b,
		"row": panel,
		"media_base": "",
		"image_a": _own_path(media, "image_a"),
		"image_b": _own_path(media, "image_b"),
		"audio_a": _own_path(media, "audio_a"),
		"audio_b": _own_path(media, "audio_b"),
		"thumb_a": null,
		"thumb_b": null,
		"status_a": null,
		"status_b": null,
		"record_button_a": null,
		"record_button_b": null,
	}
	remove_button.pressed.connect(_on_remove_row.bind(panel))

	column.add_child(_build_side_controls(entry, "a"))
	column.add_child(_build_side_controls(entry, "b"))

	edit_a.text_changed.connect(func(_t: String) -> void: _refresh_side(entry, "a"))
	edit_b.text_changed.connect(func(_t: String) -> void: _refresh_side(entry, "b"))

	_rows_box.add_child(panel)
	_row_edits.append(entry)
	_refresh_side(entry, "a")
	_refresh_side(entry, "b")


## Блок управления медиа одного слова: превью, кнопки и строка состояния.
func _build_side_controls(entry: Dictionary, side: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "Слово 1" if side == "a" else "Слово 2"
	box.add_child(title)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	box.add_child(controls)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(72, 72)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	controls.add_child(thumb)

	var image_button := _compact_button("Картинка")
	image_button.pressed.connect(_on_image_requested.bind(str(entry["row_id"]), side))
	controls.add_child(image_button)

	var record_button := _compact_button("Записать")
	record_button.pressed.connect(_on_record_pressed.bind(str(entry["row_id"]), side))
	controls.add_child(record_button)

	var file_button := _compact_button("Файл")
	file_button.pressed.connect(_on_audio_requested.bind(str(entry["row_id"]), side))
	controls.add_child(file_button)

	var play_button := _compact_button("Слушать")
	play_button.pressed.connect(_on_play_requested.bind(str(entry["row_id"]), side))
	controls.add_child(play_button)

	var clear_button := _compact_button("Очистить")
	clear_button.pressed.connect(_on_clear_requested.bind(str(entry["row_id"]), side))
	controls.add_child(clear_button)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)

	entry["thumb_" + side] = thumb
	entry["status_" + side] = status
	entry["record_button_" + side] = record_button
	return box


func _compact_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 26)
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _on_add_pair() -> void:
	_add_row("", "", {})


func _on_remove_row(panel: Control) -> void:
	for i in _row_edits.size():
		if _row_edits[i]["row"] == panel:
			_row_edits.remove_at(i)
			break
	panel.queue_free()


func _on_image_requested(row_id: String, side: String) -> void:
	var picked: Dictionary = await FilePicker.pick("image")
	if not bool(picked.get("ok", false)):
		_handle_pick_error(row_id, side, str(picked.get("error", "")))
		return
	apply_image(row_id, side, picked.get("bytes", PackedByteArray()))


func _on_audio_requested(row_id: String, side: String) -> void:
	var picked: Dictionary = await FilePicker.pick("audio")
	if not bool(picked.get("ok", false)):
		_handle_pick_error(row_id, side, str(picked.get("error", "")))
		return
	var extension := CustomSetsStore.extension_for_mime(str(picked.get("mime", "")))
	if extension.is_empty():
		_set_status(_find_entry(row_id), side, "Формат звука не поддержан")
		return
	apply_audio(row_id, side, picked.get("bytes", PackedByteArray()), extension)


func _on_record_pressed(row_id: String, side: String) -> void:
	var entry := _find_entry(row_id)
	if entry.is_empty():
		return
	if _is_recording(row_id, side):
		_stop_recording()
		return
	if not VoiceRecord.prepare_microphone():
		_set_status(entry, side, "Микрофона нет — выберите файл")
		return
	_start_recording(row_id, side)


func _on_play_requested(row_id: String, side: String) -> void:
	var entry := _find_entry(row_id)
	if entry.is_empty():
		return
	var path := _media_path(entry, side, "audio")
	if path.is_empty():
		_set_status(entry, side, "Звука нет")
		return
	if not AudioManager.play_voice(path):
		_set_status(entry, side, "Звук не проигрался")


func _on_clear_requested(row_id: String, side: String) -> void:
	clear_media(row_id, side)


func _start_recording(row_id: String, side: String) -> void:
	if not VoiceRecord.start_recording():
		_set_status(_find_entry(row_id), side, "Микрофон недоступен")
		return
	_recording_row_id = row_id
	_recording_side = side
	_set_status(_find_entry(row_id), side, "Идёт запись...")
	_refresh_side(_find_entry(row_id), side)
	_guard_recording(row_id, side)


## Авто-стоп записи через RECORD_DURATION. Токен отменяет прошлый отсчёт, чтобы
## ручной стоп не оставил работающий таймер.
func _guard_recording(row_id: String, side: String) -> void:
	_record_guard_token += 1
	var token := _record_guard_token
	await get_tree().create_timer(RECORD_DURATION).timeout
	if token != _record_guard_token:
		return
	if _is_recording(row_id, side):
		_stop_recording()


func _stop_recording() -> void:
	var row_id := _recording_row_id
	var side := _recording_side
	_recording_row_id = ""
	_recording_side = ""
	_record_guard_token += 1
	VoiceRecord.stop_recording()
	var entry := _find_entry(row_id)
	if entry.is_empty():
		return
	if VoiceRecord.has_data():
		apply_audio(row_id, side, VoiceRecord.get_wav_bytes(), "wav")
	else:
		_set_status(entry, side, "Ничего не записалось")
	_refresh_side(entry, side)


func _is_recording(row_id: String, side: String) -> bool:
	return VoiceRecord.is_recording() and _recording_row_id == row_id and _recording_side == side


func _handle_pick_error(row_id: String, side: String, code: String) -> void:
	if code == "cancelled":
		return
	_set_status(_find_entry(row_id), side, _pick_error_text(code))


func _pick_error_text(code: String) -> String:
	match code:
		"too_large":
			return "Файл слишком большой"
		"unsupported_type":
			return "Формат не поддержан"
		"convert_failed":
			return "Не удалось перекодировать звук"
		"already_open":
			return "Диалог уже открыт"
		"not_web", "no_bridge":
			return "Выбор файла недоступен"
		_:
			return "Не удалось выбрать файл"


func _on_save() -> void:
	if _set_id.is_empty():
		return
	CustomSetsStore.rename_set(_set_id, _name_edit.text)
	var pairs := {}
	for entry: Dictionary in _row_edits:
		var word_a := (entry["a"] as LineEdit).text.strip_edges()
		var word_b := (entry["b"] as LineEdit).text.strip_edges()
		if word_a.is_empty() or word_b.is_empty():
			continue
		pairs[_pair_id(word_a, word_b)] = _pair_with_media(entry, word_a, word_b)
	CustomSetsStore.set_pairs(_set_id, pairs)
	AppLogger.info("SetEditor", "saved", {"set_id": _set_id, "pairs": pairs.size()})
	set_saved.emit(_set_id)


func _on_export() -> void:
	if _set_id.is_empty():
		return
	var built := SetPackageExporter.build_package_bytes(_set_id)
	if not bool(built.get("ok", false)):
		_show_message(SetPackageFormat.user_message(str(built.get("error", ""))))
		return
	_pending_bytes = built.get("bytes", PackedByteArray())
	_save_dialog.current_file = str(built.get("file_name", ""))
	_save_dialog.popup_centered_ratio(0.8)


func _on_save_path_selected(path: String) -> void:
	if _pending_bytes.is_empty():
		return
	if not path.to_lower().ends_with("." + SetPackageFormat.EXTENSION):
		path += "." + SetPackageFormat.EXTENSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_show_message("Не удалось сохранить файл набора.")
		return
	file.store_buffer(_pending_bytes)
	file.close()
	_pending_bytes = PackedByteArray()
	_show_message("Файл набора сохранён.")
	AppLogger.info("SetEditor", "exported", {"path": path})


## Ищет строку редактора по id.
func _find_entry(row_id: String) -> Dictionary:
	for entry: Dictionary in _row_edits:
		if str(entry.get("row_id", "")) == row_id:
			return entry
	return {}


## База имён файлов медиа строки. Стабильна в пределах строки: перезапись медиа
## того же слова ложится в тот же файл, а не плодит копии.
func _ensure_media_base(entry: Dictionary) -> String:
	var base := str(entry.get("media_base", ""))
	if not base.is_empty():
		return base
	var word_a := (entry["a"] as LineEdit).text.strip_edges()
	var word_b := (entry["b"] as LineEdit).text.strip_edges()
	if word_a.is_empty() and word_b.is_empty():
		base = "p_" + str(Time.get_ticks_usec())
	else:
		base = _pair_id(word_a, word_b)
	entry["media_base"] = base
	return base


## Путь медиа слова: своё (user://) или из библиотеки по тексту слова.
func _media_path(entry: Dictionary, side: String, field: String) -> String:
	var own := str(entry.get(field + "_" + side, ""))
	if not own.is_empty():
		return own
	var word := (entry[side] as LineEdit).text.strip_edges()
	if word.is_empty():
		return ""
	return str(ContentRepository.find_media_by_word(word).get(field, ""))


## Обновляет превью и подпись кнопки записи для слова.
func _refresh_side(entry: Dictionary, side: String) -> void:
	if entry.is_empty():
		return
	var thumb: TextureRect = entry.get("thumb_" + side)
	if thumb != null:
		var path := _media_path(entry, side, "image")
		thumb.texture = SetRepository.load_texture(path) if not path.is_empty() else null
	var record_button: Button = entry.get("record_button_" + side)
	if record_button != null:
		record_button.text = "Стоп" if _is_recording(str(entry.get("row_id", "")), side) else "Записать"


func _set_status(entry: Dictionary, side: String, text: String) -> void:
	if entry.is_empty():
		return
	var status: Label = entry.get("status_" + side)
	if status != null:
		status.text = text


## Путь к своему медиа из записи набора. Библиотечные (res://) пути не считаются
## своими: они восстановятся подстановкой по слову при следующем открытии.
func _own_path(media: Dictionary, key: String) -> String:
	var path := str(media.get(key, ""))
	if path.begins_with("user://"):
		return path
	return ""


## Стабильный id пары по словам: прогресс по паре не теряется при пересохранении.
func _pair_id(word_a: String, word_b: String) -> String:
	return "p_" + (word_a + "|" + word_b).to_lower().md5_text().substr(0, 8)


## Пара с медиа: своё (user://) в приоритете, иначе из библиотеки по тексту слова.
func _pair_with_media(entry: Dictionary, word_a: String, word_b: String) -> Dictionary:
	var media_a := _media_for(entry, "a", word_a)
	var media_b := _media_for(entry, "b", word_b)
	return {
		"word_a": word_a,
		"word_b": word_b,
		"image_a": str(media_a.get("image", "")),
		"image_b": str(media_b.get("image", "")),
		"audio_a": str(media_a.get("audio", "")),
		"audio_b": str(media_b.get("audio", "")),
	}


func _media_for(entry: Dictionary, side: String, word: String) -> Dictionary:
	var own_image := str(entry.get("image_" + side, ""))
	var own_audio := str(entry.get("audio_" + side, ""))
	var library := ContentRepository.find_media_by_word(word)
	return {
		"image": own_image if not own_image.is_empty() else str(library.get("image", "")),
		"audio": own_audio if not own_audio.is_empty() else str(library.get("audio", "")),
	}


func _mode_title(mode_id: String) -> String:
	if mode_id.is_empty():
		return "не выбран"
	return Navigation.mode_title(mode_id)


func _show_message(text: String) -> void:
	_message.dialog_text = text
	_message.popup_centered()
