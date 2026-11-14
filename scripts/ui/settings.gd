extends Control
## Настройки: громкость, включение звука и сброс прогресса с подтверждением.
##
## Значения сохраняются в SaveManager и восстанавливаются при следующем запуске.

const VOLUME_KEY := "master_volume"

var _volume_slider: HSlider
var _sound_toggle: CheckButton
var _confirm_dialog: ConfirmationDialog


func _ready() -> void:
	_build_ui()
	_load_settings()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Настройки"
	ScreenStyle.title(title)
	layout.add_child(title)

	var volume_label := Label.new()
	volume_label.text = "Громкость"
	ScreenStyle.subtitle(volume_label)
	layout.add_child(volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.custom_minimum_size = Vector2(0, 60)
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.value_changed.connect(_on_volume_changed)
	layout.add_child(_volume_slider)

	_sound_toggle = CheckButton.new()
	_sound_toggle.text = "Звук включён"
	_sound_toggle.add_theme_font_size_override("font_size", ScreenStyle.SUBTITLE_FONT_SIZE)
	_sound_toggle.toggled.connect(_on_sound_toggled)
	layout.add_child(_sound_toggle)

	var reset_button := Button.new()
	reset_button.text = "Сбросить прогресс"
	ScreenStyle.big_button(reset_button)
	ScreenStyle.wire_click(reset_button)
	reset_button.pressed.connect(_on_reset_pressed)
	layout.add_child(reset_button)

	var back_button := Button.new()
	back_button.text = "Назад"
	ScreenStyle.big_button(back_button)
	ScreenStyle.back_icon(back_button)
	ScreenStyle.wire_click(back_button)
	back_button.pressed.connect(_on_back_pressed)
	layout.add_child(back_button)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "Подтверждение"
	_confirm_dialog.dialog_text = "Сбросить весь прогресс занятий? Это действие нельзя отменить."
	_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(_confirm_dialog)


func _load_settings() -> void:
	var volume := float(SaveManager.get_setting(VOLUME_KEY, 1.0))
	_volume_slider.set_value_no_signal(volume)
	_sound_toggle.set_pressed_no_signal(volume > 0.0)
	AudioManager.set_master_volume(volume)


func set_volume(value: float) -> void:
	_volume_slider.value = value


func set_sound_enabled(enabled: bool) -> void:
	_sound_toggle.set_pressed_no_signal(enabled)
	_on_sound_toggled(enabled)


func is_sound_enabled() -> bool:
	return _sound_toggle.button_pressed


func has_reset_confirmation() -> bool:
	return _confirm_dialog != null


func request_reset() -> void:
	_confirm_dialog.popup_centered()


func confirm_reset() -> void:
	_on_reset_confirmed()


func _on_volume_changed(value: float) -> void:
	AudioManager.set_master_volume(value)
	SaveManager.set_setting(VOLUME_KEY, value)
	if value > 0.0 and not _sound_toggle.button_pressed:
		_sound_toggle.set_pressed_no_signal(true)


func _on_sound_toggled(pressed: bool) -> void:
	if pressed:
		var volume := float(_volume_slider.value)
		if volume <= 0.0:
			volume = 0.5
			_volume_slider.set_value_no_signal(volume)
		AudioManager.set_master_volume(volume)
		SaveManager.set_setting(VOLUME_KEY, volume)
	else:
		AudioManager.set_master_volume(0.0)
		SaveManager.set_setting(VOLUME_KEY, 0.0)


func _on_reset_pressed() -> void:
	request_reset()


func _on_reset_confirmed() -> void:
	ProgressStore.reset()


func _on_back_pressed() -> void:
	Navigation.back()
