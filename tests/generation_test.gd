extends Node2D


@export_category("Generation")
@export var level_generator: LevelGenerator
@export var generation_splash: GenerationSplash
@export var hud: GameHUD


@export_category("Audio")
@export var game_music: AudioStream


func _ready() -> void:
	level_generator.generation_finished.connect(
		_on_generation_finished
	)

	level_generator.generation_failed.connect(
		_on_generation_failed
	)

	_start_game()


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
	hud.set_level_seed(generation_seed)

	generation_splash.hide_splash()

	MusicManager.play_music(
		game_music
	)


func _on_generation_failed() -> void:
	generation_splash.set_status(
		"GENERATION FAILED"
	)

	push_error(
		"Game: Level generation failed."
	)
