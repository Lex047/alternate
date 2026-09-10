extends CanvasLayer


@export var health_bar: ProgressBar
@export var health_label: Label
@export var game_over_panel: Control
@export var pause_panel: Control

@export var resume_button: Button
@export var restart_button: Button
@export var main_menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.player_health_changed.connect(
		_on_player_health_changed
	)

	GameManager.player_died.connect(
		_on_player_died
	)
	
	GameManager.pause_changed.connect(
		_on_pause_changed
	)

	if GameManager.player:
		_on_player_health_changed(
			GameManager.player.current_health,
			GameManager.player.max_health
		)
	
	if pause_panel:
		pause_panel.visible = false
	
	if game_over_panel:
		game_over_panel.visible = false


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


func _on_player_died() -> void:
	if game_over_panel:
		game_over_panel.visible = true


func _on_pause_changed(is_paused: bool) -> void:
	if pause_panel:
		pause_panel.visible = is_paused
	
	if is_paused and resume_button:
		resume_button.grab_focus()

func _on_resume_button_pressed() -> void:
	GameManager.resume_game()


func _on_restart_button_pressed() -> void:
	GameManager.restart_current_level()


func _on_main_menu_button_pressed() -> void:
	GameManager.go_to_main_menu()
