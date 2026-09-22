extends Node


signal player_health_changed(
	current_health: int,
	max_health: int
)
signal player_died
signal pause_changed(is_paused: bool)

var player: Player

var is_game_over: bool = false

var gameplay_input_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_input_enabled:
		return

	if is_game_over:
		if event.is_action_pressed("restart_game"):
			restart_current_level()

		elif event.is_action_pressed("pause"):
			go_to_main_menu()

		return

	if event.is_action_pressed("pause"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

	if event.is_action_pressed("restart_game"):
		if get_tree().paused:
			restart_current_level()


func register_player(new_player: Player) -> void:
	player = new_player

	player_health_changed.emit(
		player.current_health,
		player.max_health
	)


func update_player_health(
	current_health: int,
	max_health: int
) -> void:
	player_health_changed.emit(
		current_health,
		max_health
	)


func handle_player_death() -> void:
	is_game_over = true
	
	get_tree().paused = true
	player_died.emit()


func pause_game() -> void:
	get_tree().paused = true
	pause_changed.emit(true)


func resume_game() -> void:
	get_tree().paused = false
	pause_changed.emit(false)


func restart_current_level() -> void:
	is_game_over = false
	gameplay_input_enabled = true

	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_main_menu() -> void:
	is_game_over = false
	gameplay_input_enabled = false

	get_tree().paused = false
	get_tree().change_scene_to_file(
		"res://ui/main_menu/main_menu.tscn"
	)
