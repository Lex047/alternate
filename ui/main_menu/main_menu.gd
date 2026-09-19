extends Control


@export_file("*.tscn") var game_scene_path: String


@export_category("Menu")
@export var main_panel: Control
@export var settings_panel: SettingsPanel

@export var start_button: Button
@export var settings_button: Button
@export var quit_button: Button


@export_category("Audio")
@export var menu_audio: MenuAudio
@export var menu_music: AudioStream


var allow_focus_sound: bool = false


func _ready() -> void:
	main_panel.show()
	settings_panel.hide()

	_setup_mouse_focus()

	settings_panel.back_requested.connect(
		_on_settings_back_requested
	)

	settings_panel.navigation_focused.connect(
		_on_control_focused
	)

	_grab_focus_silently(start_button)

	MusicManager.play_music(menu_music)


# ==================================================
# FOCUS
# ==================================================


func _setup_mouse_focus() -> void:
	var focus_controls: Array[Control] = [
		start_button,
		settings_button,
		quit_button
	]

	for control in focus_controls:
		control.mouse_entered.connect(
			control.grab_focus
		)


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

	settings_panel.focus_first_control_silently()


func _on_quit_button_pressed() -> void:
	menu_audio.play_confirm()

	get_tree().quit()


# ==================================================
# SETTINGS
# ==================================================


func _on_settings_back_requested() -> void:
	menu_audio.play_back()

	settings_panel.hide()
	main_panel.show()

	_grab_focus_silently(settings_button)
