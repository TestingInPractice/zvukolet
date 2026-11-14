class_name SetList
extends Control
## Список пользовательских наборов: создать, открыть, удалить, импортировать.
##
## Встроенные наборы здесь не показываются: родитель создаёт только свои.
## Экран сам хостит редактор набора, чтобы возврат из редактора не терял список.

signal open_editor(set_id: String)

const EDITOR_SCENE := preload("res://scenes/constructor/set_editor.tscn")

var _rows_box: VBoxContainer
var _empty_label: Label
var _editor: SetEditor
var _layout: VBoxContainer
var _message: AcceptDialog
var _import_dialog: FileDialog
var _back_button: Button
var _editor_open: bool = false


func _ready() -> void:
	_build_ui()
	CustomSetsStore.sets_changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in _rows_box.get_children():
		child.queue_free()
	var records := CustomSetsStore.get_sets()
	for record in records:
		_rows_box.add_child(_build_row(record))
	_empty_label.visible = records.is_empty()
	AppLogger.info("SetList", "refreshed", {"rows": records.size()})


func get_row_count() -> int:
	return _rows_box.get_child_count()


func _build_row(record: Dictionary) -> Control:
	var set_id := str(record.get("id", ""))
	var row := PanelContainer.new()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var label := Label.new()
	label.text = "%s (%d)" % [str(record.get("name", "")), CustomSetsStore.pair_count(set_id)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)

	var open_button := Button.new()
	open_button.text = "Открыть"
	open_button.pressed.connect(_on_row_open.bind(set_id))
	line.add_child(open_button)

	var delete_button := Button.new()
	delete_button.text = "Удалить"
	delete_button.pressed.connect(_on_row_delete.bind(set_id))
	line.add_child(delete_button)

	return row


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 12)
	margin.add_child(_layout)

	var title := Label.new()
	title.text = "Мои наборы"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layout.add_child(title)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_layout.add_child(buttons)

	var new_button := Button.new()
	new_button.text = "Новый набор"
	new_button.pressed.connect(_on_new_pressed)
	buttons.add_child(new_button)

	var import_button := Button.new()
	import_button.text = "Импорт .zvset"
	import_button.pressed.connect(_on_import_pressed)
	buttons.add_child(import_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)

	_empty_label = Label.new()
	_empty_label.text = "Пока нет своих наборов. Создайте первый."
	_layout.add_child(_empty_label)

	_back_button = Button.new()
	_back_button.text = "Назад"
	ScreenStyle.back_icon(_back_button)
	_back_button.pressed.connect(_on_back_pressed)
	_layout.add_child(_back_button)

	_message = AcceptDialog.new()
	add_child(_message)

	_import_dialog = FileDialog.new()
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.use_native_dialog = true
	_import_dialog.filters = PackedStringArray(["*." + SetPackageFormat.EXTENSION])
	_import_dialog.file_selected.connect(_on_import_path_selected)
	add_child(_import_dialog)

	_editor = EDITOR_SCENE.instantiate() as SetEditor
	_editor.visible = false
	_editor.set_saved.connect(_on_editor_saved)
	_editor.close_requested.connect(_on_editor_close_requested)
	add_child(_editor)


func _on_new_pressed() -> void:
	var record := CustomSetsStore.create_set("Новый набор", _default_contrast_id())
	var set_id := str(record.get("id", ""))
	if set_id.is_empty():
		return
	_show_editor(set_id)


func _on_import_pressed() -> void:
	_import_dialog.popup_centered_ratio(0.8)


func _on_import_path_selected(path: String) -> void:
	var bytes := _read_bytes(path)
	if bytes.is_empty():
		_show_message("Не удалось прочитать файл набора.")
		return
	var result := SetPackageImporter.import_bytes(bytes)
	if not bool(result.get("ok", false)):
		_show_message(SetPackageFormat.user_message(str(result.get("error", ""))))
		return
	refresh()
	_show_message("Набор «%s» импортирован: пар %d." % [
		str(result.get("name", "")), int(result.get("pairs", 0))])


func _on_row_open(set_id: String) -> void:
	open_editor.emit(set_id)
	_show_editor(set_id)


func _on_row_delete(set_id: String) -> void:
	CustomSetsStore.delete_set(set_id)


func _show_editor(set_id: String) -> void:
	_editor_open = true
	_layout.visible = false
	_editor.visible = true
	_editor.open_set(set_id)


func _show_list() -> void:
	_editor_open = false
	_editor.visible = false
	_layout.visible = true


func _on_editor_saved(_set_id: String) -> void:
	_show_list()
	refresh()


func _on_editor_close_requested() -> void:
	_show_list()


func _on_back_pressed() -> void:
	if _editor_open:
		_show_list()
		return
	Navigation.back()


func _default_contrast_id() -> String:
	var contrasts := ContentRepository.get_contrasts()
	if contrasts.is_empty():
		return ""
	return str(contrasts[0].get("id", ""))


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _show_message(text: String) -> void:
	_message.dialog_text = text
	_message.popup_centered()
