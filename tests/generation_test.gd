extends Node2D

@export_category("Management")

@export var tutorial_splash: TutorialSplash

@export_category("Generation")

@export var level_generator: LevelGenerator
@export var generation_splash: GenerationSplash
@export var alternate_transition: AlternateTransition
@export var game_hud: GameHUD

var is_alternate: bool = false

@export_category("Debug")

@export var debug_camera: Camera2D
@export var always_show_tutorial: bool = false

var using_debug_camera: bool = false


@export_category("Gameplay")

@export var player: Player

var alternate_player_local_position: Vector2

var level_completed: bool = false

@export_category("Audio")

@export var game_music: AudioStream


func _ready() -> void:
	GameManager.gameplay_input_enabled = true
	
	tutorial_splash.dismissed.connect(
		_on_tutorial_dismissed
	)
	
	level_generator.generation_finished.connect(
		_on_generation_finished
	)

	level_generator.generation_failed.connect(
		_on_generation_failed
	)

	alternate_transition.transition_midpoint.connect(
		_on_alternate_transition_midpoint
	)

	alternate_transition.transition_finished.connect(
		_on_alternate_transition_finished
	)
	
	game_hud.completion_restart_requested.connect(
		_on_level_completion_restart_requested
	)

	game_hud.completion_menu_requested.connect(
		_on_level_completion_menu_requested
	)
	
	debug_camera.enabled = false

	_start_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(
		"toggle_debug_camera"
	):
		_toggle_debug_camera()


func _toggle_debug_camera() -> void:
	var player_camera: Camera2D = (
		player.get_node_or_null(
			"Camera2D"
		) as Camera2D
	)

	if not player_camera:
		push_error(
			"Game: Player Camera2D not found."
		)
		return

	using_debug_camera = not using_debug_camera

	if using_debug_camera:
		debug_camera.global_position = (
			player_camera.global_position
		)

		player_camera.enabled = false
		debug_camera.enabled = true
		debug_camera.make_current()

	else:
		debug_camera.enabled = false
		player_camera.enabled = true
		player_camera.make_current()


func _start_game() -> void:
	generation_splash.show_splash()

	# Give Godot a frame to actually draw the splash.
	await get_tree().process_frame

	level_generator.generate_level()


func _on_generation_finished(
	generation_seed: int
) -> void:
	print(
		"Game: Level ready with seed ",
		generation_seed
	)

	if not _place_player_at_start():
		generation_splash.set_status(
			"PLAYER SPAWN FAILED"
		)

		push_error(
			"Game: Could not place player at start."
		)

		return
	
	if not _connect_artifact():
		generation_splash.set_status(
			"ARTIFACT SETUP FAILED"
		)

		push_error(
			"Game: Could not connect artifact."
		)

		return

	game_hud.set_level_seed(
		generation_seed
	)

	generation_splash.hide_splash()

	if (
		always_show_tutorial
		or not ProgressManager.has_seen_tutorial()
	):
		tutorial_splash.show_splash()
	else:
		_begin_gameplay()


func _place_player_at_start() -> bool:
	if not player:
		push_error(
			"Game: Player reference is missing."
		)
		return false

	var start_chunk: Chunk = (
		level_generator.get_start_chunk()
	)

	if not start_chunk:
		push_error(
			"Game: Generated start chunk not found."
		)
		return false

	var player_spawn: Marker2D = (
		start_chunk.get_node_or_null(
			"Objects/PlayerSpawn"
		) as Marker2D
	)

	if not player_spawn:
		push_error(
			"Game: PlayerSpawn marker not found "
			+ "in start chunk."
		)
		return false

	player.global_position = (
		player_spawn.global_position
	)

	return true


func _on_generation_failed() -> void:
	generation_splash.set_status(
		"GENERATION FAILED"
	)

	push_error(
		"Game: Level generation failed."
	)


func _on_tutorial_dismissed() -> void:
	_begin_gameplay()


func _begin_gameplay() -> void:
	MusicManager.play_music(
		game_music
	)


func _connect_artifact() -> bool:
	var goal_chunk: Chunk = (
		level_generator.get_goal_chunk()
	)

	if not goal_chunk:
		push_error(
			"Game: Generated goal chunk not found."
		)
		return false

	var artifact: ArtifactContainer = (
		goal_chunk.get_node_or_null(
			"Objects/ArtifactContainer"
		) as ArtifactContainer
	)

	if not artifact:
		push_error(
			"Game: ArtifactContainer not found "
			+ "in goal chunk."
		)
		return false

	if not artifact.collected.is_connected(
		_on_artifact_collected
	):
		artifact.collected.connect(
			_on_artifact_collected
		)

	return true


func _on_artifact_collected() -> void:
	if is_alternate:
		return

	var normal_goal: Chunk = (
		level_generator.get_goal_chunk()
	)

	if not normal_goal:
		push_error(
			"Game: Normal GOAL chunk was not found."
		)
		return

	alternate_player_local_position = (
		normal_goal.to_local(
			player.global_position
		)
	)

	print("Game: Artifact collected!")

	alternate_transition.play_transition()
	


func _on_alternate_transition_midpoint() -> void:
	_activate_alternate_state()


func _activate_alternate_state() -> void:
	if is_alternate:
		return

	if not player:
		push_error(
			"Game: Player reference is missing."
		)
		return

	var alternate_goal: Chunk = (
		level_generator.get_alternate_goal_chunk()
	)

	if not alternate_goal:
		push_error(
			"Game: Alternate GOAL chunk "
			+ "was not found."
		)
		return

	if not level_generator.activate_alternate_layout():
		push_error(
			"Game: Could not activate "
			+ "Alternate layout."
		)
		return

	player.velocity = Vector2.ZERO

	player.global_position = (
		alternate_goal.to_global(
			alternate_player_local_position
		)
	)

	is_alternate = true

	if not _activate_exit_portal():
		push_error(
			"Game: Could not activate exit portal."
		)

	print(
		"Game: Alternate state activated."
	)


func _on_alternate_transition_finished() -> void:
	print(
		"Game: Alternate transition finished."
	)

	if not is_alternate:
		return

	game_hud.show_objective_message(
		"ARTIFACT RETRIEVED",
		"RETURN TO THE ENTRY POINT"
	)


func _activate_exit_portal() -> bool:
	var start_chunk: Chunk = (
		level_generator.get_alternate_start_chunk()
	)

	if not start_chunk:
		push_error(
			"Game: Alternate start chunk not found."
		)
		return false

	var exit_portal: ExitPortal = (
		start_chunk.get_node_or_null(
			"Objects/ExitPortal"
		) as ExitPortal
	)

	if not exit_portal:
		push_error(
			"Game: ExitPortal not found "
			+ "in Alternate start chunk."
		)
		return false

	if not exit_portal.exited.is_connected(
		_on_exit_portal_exited
	):
		exit_portal.exited.connect(
			_on_exit_portal_exited
		)

	exit_portal.activate()

	return true


func _on_exit_portal_exited() -> void:
	if level_completed:
		return

	level_completed = true

	GameManager.gameplay_input_enabled = false

	game_hud.show_completion()

	get_tree().paused = true


func _on_level_completion_restart_requested() -> void:
	get_tree().paused = false

	GameManager.restart_current_level()


func _on_level_completion_menu_requested() -> void:
	get_tree().paused = false

	GameManager.go_to_main_menu()
