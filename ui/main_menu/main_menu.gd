extends Control


@export_file("*.tscn") var game_scene_path: String

@export_category("Music")
@export var menu_music: AudioStream


@export_category("Menu")
@export var main_panel: Control
@export var settings_panel: Control

@export var start_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var back_button: Button

@export var menu_audio: MenuAudio


@export_category("Settings")
@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider

@export var fullscreen_check: CheckButton
@export var show_seed_check: CheckButton


var allow_focus_sound: bool = false


func _ready() -> void:
	MusicManager.play_music(menu_music)
	
	main_panel.show()
	settings_panel.hide()

	_load_settings_into_ui()
	_setup_mouse_focus()

	_grab_focus_silently(start_button)


# ==================================================
# SETUP
# ==================================================


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


func _setup_mouse_focus() -> void:
	var focus_controls: Array[Control] = [
		start_button,
		settings_button,
		quit_button,
		master_slider,
		music_slider,
		sfx_slider,
		fullscreen_check,
		show_seed_check,
		back_button
	]

	for control in focus_controls:
		control.mouse_entered.connect(
			control.grab_focus
		)


# ==================================================
# FOCUS
# ==================================================


func _grab_focus_silently(
	control: Control
) -> void:
	allow_focus_sound = false

	control.grab_focus()

	allow_focus_sound = true


func _on_control_focused() -> void:
	if not allow_focus_sound:
		return

	menu_audio.play_focus()


# ==================================================
# MAIN MENU
# ==================================================


func _on_start_button_pressed() -> void:
	if game_scene_path.is_empty():
		return

	menu_audio.play_confirm()

	get_tree().change_scene_to_file(
		game_scene_path
	)


func _on_settings_button_pressed() -> void:
	menu_audio.play_confirm()

	main_panel.hide()
	settings_panel.show()

	_grab_focus_silently(master_slider)


func _on_quit_button_pressed() -> void:
	menu_audio.play_confirm()

	get_tree().quit()


# ==================================================
# SETTINGS MENU
# ==================================================


func _on_back_button_pressed() -> void:
	menu_audio.play_back()

	settings_panel.hide()
	main_panel.show()

	_grab_focus_silently(settings_button)


func _on_master_slider_value_changed(
	value: float
) -> void:
	SettingsManager.set_master_volume(value)


func _on_music_slider_value_changed(
	value: float
) -> void:
	SettingsManager.set_music_volume(value)


func _on_sfx_slider_value_changed(
	value: float
) -> void:
	SettingsManager.set_sfx_volume(value)


func _on_fullscreen_check_toggled(
	toggled_on: bool
) -> void:
	SettingsManager.set_fullscreen(toggled_on)


func _on_show_seed_check_toggled(
	toggled_on: bool
) -> void:
	SettingsManager.set_show_seed(toggled_on)
