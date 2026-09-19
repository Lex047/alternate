extends VBoxContainer
class_name SettingsPanel


signal back_requested
signal navigation_focused


@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider

@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var show_seed_check: CheckButton = %ShowSeedCheck

@onready var back_button: Button = %BackButton


const MOUSE_FOCUS_DELAY := 0.15

var allow_focus_signal: bool = true
var allow_mouse_focus: bool = true


func _ready() -> void:
	_load_settings_into_ui()
	_connect_settings()
	_setup_focus_controls()


func _load_settings_into_ui() -> void:
	master_slider.set_value_no_signal(
		SettingsManager.master_volume
	)

	music_slider.set_value_no_signal(
		SettingsManager.music_volume
	)

	sfx_slider.set_value_no_signal(
		SettingsManager.sfx_volume
	)

	fullscreen_check.set_pressed_no_signal(
		SettingsManager.fullscreen
	)

	show_seed_check.set_pressed_no_signal(
		SettingsManager.show_seed
	)


func _connect_settings() -> void:
	master_slider.value_changed.connect(
		SettingsManager.set_master_volume
	)

	music_slider.value_changed.connect(
		SettingsManager.set_music_volume
	)

	sfx_slider.value_changed.connect(
		SettingsManager.set_sfx_volume
	)

	fullscreen_check.toggled.connect(
		SettingsManager.set_fullscreen
	)

	show_seed_check.toggled.connect(
		SettingsManager.set_show_seed
	)

	back_button.pressed.connect(
		_on_back_button_pressed
	)


func _setup_focus_controls() -> void:
	var focus_controls: Array[Control] = [
		master_slider,
		music_slider,
		sfx_slider,
		fullscreen_check,
		show_seed_check,
		back_button
	]

	for control in focus_controls:
		control.focus_entered.connect(
			_on_control_focused
		)

		control.mouse_entered.connect(
			_on_control_mouse_entered.bind(control)
		)


func _on_control_mouse_entered(
	control: Control
) -> void:
	if not allow_mouse_focus:
		return

	control.grab_focus()


func focus_first_control_silently() -> void:
	allow_focus_signal = false
	allow_mouse_focus = false

	master_slider.grab_focus()

	await get_tree().create_timer(
		MOUSE_FOCUS_DELAY
	).timeout

	allow_focus_signal = true
	allow_mouse_focus = true


func _on_control_focused() -> void:
	if not allow_focus_signal:
		return

	navigation_focused.emit()


func _on_back_button_pressed() -> void:
	back_requested.emit()
