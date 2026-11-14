class_name SetEditor
extends Control
## Редактор пользовательского набора.
##
## Имя, отметка пар контраста, сохранение и экспорт в файл .zvset. Пары
## берутся из встроенной библиотеки контраста: включённая пара копируется в
## набор целиком, поэтому набор самодостаточен и переносится файлом.

signal set_saved(set_id: String)
signal close_requested()

var _set_id: String = ""
var _contrast_id: String = ""
var _toggles: Dictionary = {}

var _name_edit: LineEdit
var _contrast_label: Label
var _rows_box: VBoxContainer
var _message: AcceptDialog
var _save_dialog: FileDialog
var _pending_bytes: PackedByteArray = PackedByteArray()


func _ready() -> void:
	_build_ui()


## Открывает набор для правки.
func open_set(set_id: String) -> void:
	_set_id = set_id
	_toggles.clear()
	var record := CustomSetsStore.get_set(set_id)
	if record.is_empty():
		AppLogger.warning("SetEditor", "set_missing", {"set_id": set_id})
		return
	_contrast_id = str(record.get("contrast_id", ""))
	_name_edit.text = str(record.get("name", ""))
	_contrast_label.text = _contrast_title(_contrast_id)
	var included := {}
	for pair_id in CustomSetsStore.get_pair_ids(set_id):
		included[pair_id] = true
	_rebuild_rows(included)
	AppLogger.info("SetEditor", "opened", {"set_id": set_id, "pairs": _toggles.size()})


## id пар, отмеченных в редакторе. Для тестов и сохранения.
func get_included_pair_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id in _toggles.keys():
		var toggle: CheckBox = _toggles[raw_id]
		if toggle.button_pressed:
			result.append(str(raw_id))
	return result


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

	_contrast_label = Label.new()
	layout.add_child(_contrast_label)

	var hint := Label.new()
	hint.text = "Отметьте пары для занятия"
	layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

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


func _rebuild_rows(included: Dictionary) -> void:
	for child in _rows_box.get_children():
		child.queue_free()
	_toggles.clear()
	var pairs := ContentRepository.get_pairs(_contrast_id)
	for pair in pairs:
		var pair_id := str(pair.get("id", ""))
		if pair_id.is_empty():
			continue
		var row := HBoxContainer.new()
		var toggle := CheckBox.new()
		toggle.button_pressed = included.has(pair_id)
		row.add_child(toggle)
		var label := Label.new()
		label.text = "%s / %s" % [str(pair.get("word_a", "")), str(pair.get("word_b", ""))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_rows_box.add_child(row)
		_toggles[pair_id] = toggle


func _on_save() -> void:
	if _set_id.is_empty():
		return
	var name := _name_edit.text.strip_edges()
	CustomSetsStore.rename_set(_set_id, name)
	var pairs := {}
	for pair_id in get_included_pair_ids():
		var source := ContentRepository.get_pair(pair_id)
		if source.is_empty():
			continue
		pairs[pair_id] = {
			"word_a": str(source.get("word_a", "")),
			"word_b": str(source.get("word_b", "")),
			"image_a": str(source.get("image_a", "")),
			"image_b": str(source.get("image_b", "")),
			"audio_a": str(source.get("audio_a", "")),
			"audio_b": str(source.get("audio_b", "")),
		}
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


func _contrast_title(contrast_id: String) -> String:
	var contrast := ContentRepository.get_contrast(contrast_id)
	if contrast.is_empty():
		return "Контраст: " + contrast_id
	return "Контраст: " + str(contrast.get("title", contrast_id))


func _show_message(text: String) -> void:
	_message.dialog_text = text
	_message.popup_centered()
