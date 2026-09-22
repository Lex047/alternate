extends CanvasLayer
class_name GameHUD


signal completion_restart_requested
signal completion_menu_requested


@export_category("HUD")
@export var health_bar: ProgressBar
@export var health_label: Label
@export var seed_label: Label

var current_level_seed: int = 0


@export_category("Panels")
@export var game_over_panel: Control
@export var pause_panel: Control
@export var pause_settings_panel: Control
@export var settings_panel: SettingsPanel
@export var objective_message_panel: PanelContainer
@export var level_completion_panel: Control

var level_completion_active: bool = false


@export_category("Pause Menu")
@export var resume_button: Button
@export var settings_button: Button
@export var restart_button: Button
@export var main_menu_button: Button


@export_category("Objective Message")

@export var objective_title: Label
@export var objective_subtitle: Label

@export var objective_message_duration: float = 3.0

var objective_message_tween: Tween

@export_category("Audio")
@export var pause_audio: MenuAudio

var allow_focus_sound: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	objective_message_panel.hide()
	objective_message_panel.modulate.a = 0.0
	
	if level_completion_panel:
		level_completion_panel.hide()

	GameManager.player_health_changed.connect(
		_on_player_health_changed
	)
	
	SettingsManager.show_seed_changed.connect(
		_on_show_seed_changed
	)

	GameManager.player_died.connect(
		_on_player_died
	)

	GameManager.pause_changed.connect(
		_on_pause_changed
	)

	settings_panel.back_requested.connect(
		_on_settings_back_requested
	)

	settings_panel.navigation_focused.connect(
		_on_control_focused
	)

	_setup_pause_focus()

	if GameManager.player:
		_on_player_health_changed(
			GameManager.player.current_health,
			GameManager.player.max_health
		)

	if pause_panel:
		pause_panel.hide()

	if pause_settings_panel:
		pause_settings_panel.hide()

	if game_over_panel:
		game_over_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not level_completion_active:
		return

	if event.is_action_pressed("restart_game"):
		get_viewport().set_input_as_handled()
		completion_restart_requested.emit()
		return

	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		completion_menu_requested.emit()
		return


# ==================================================
# HUD
# ==================================================


func _on_player_health_changed(
	current_health: int,
	max_health: int
) -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if health_label:
		health_label.text = (
			"HP %d / %d"
			% [current_health, max_health]
		)


func set_level_seed(generation_seed: int) -> void:
	current_level_seed = generation_seed

	_update_seed_display()


func _on_show_seed_changed(
	_enabled: bool
) -> void:
	_update_seed_display()


func _update_seed_display() -> void:
	if not seed_label:
		return

	seed_label.text = (
		"SEED: %d"
		% current_level_seed
	)

	seed_label.visible = (
		SettingsManager.show_seed
		and current_level_seed != 0
	)


func _on_player_died() -> void:
	if game_over_panel:
		game_over_panel.show()


func show_completion() -> void:
	if not level_completion_panel:
		push_error(
			"GameHUD: Completion panel is not assigned."
		)
		return

	level_completion_active = true
	level_completion_panel.show()


# ==================================================
# PAUSE
# ==================================================


func _on_pause_changed(
	is_paused: bool
) -> void:
	if is_paused:
		pause_settings_panel.hide()
		pause_panel.show()

		_grab_focus_silently(resume_button)

	else:
		pause_panel.hide()
		pause_settings_panel.hide()


func _on_resume_button_pressed() -> void:
	pause_audio.play_confirm()

	GameManager.resume_game()


func _on_settings_button_pressed() -> void:
	pause_audio.play_confirm()

	pause_panel.hide()
	pause_settings_panel.show()

	settings_panel.focus_first_control_silently()


func _on_restart_button_pressed() -> void:
	pause_audio.play_confirm()

	GameManager.restart_current_level()


func _on_main_menu_button_pressed() -> void:
	pause_audio.play_confirm()

	GameManager.go_to_main_menu()


# ==================================================
# SETTINGS
# ==================================================


func _on_settings_back_requested() -> void:
	pause_audio.play_back()

	pause_settings_panel.hide()
	pause_panel.show()

	_grab_focus_silently(settings_button)


# ==================================================
# FOCUS
# ==================================================


func _setup_pause_focus() -> void:
	var focus_controls: Array[Control] = [
		resume_button,
		settings_button,
		restart_button,
		main_menu_button
	]

	for control in focus_controls:
		control.focus_entered.connect(
			_on_control_focused
		)

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

	pause_audio.play_focus()


# ==================================================
# OBJECTIVE MESSAGE
# ==================================================


func show_objective_message(
	title: String,
	subtitle: String = ""
) -> void:
	print("HUD: showing objective message")
	
	if objective_message_tween:
		objective_message_tween.kill()

	objective_title.text = title
	objective_subtitle.text = subtitle

	objective_subtitle.visible = (
		not subtitle.is_empty()
	)

	objective_message_panel.modulate.a = 0.0
	objective_message_panel.show()

	objective_message_tween = create_tween()

	objective_message_tween.tween_property(
		objective_message_panel,
		"modulate:a",
		1.0,
		0.25
	)

	objective_message_tween.tween_interval(
		objective_message_duration
	)

	objective_message_tween.tween_property(
		objective_message_panel,
		"modulate:a",
		0.0,
		0.4
	)

	objective_message_tween.tween_callback(
		objective_message_panel.hide
	)
