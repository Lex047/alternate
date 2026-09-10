extends Control


@export_file("*.tscn") var game_scene_path: String
@export var start_button: Button

func _ready() -> void:
	start_button.grab_focus()

func _on_start_button_pressed() -> void:
	if game_scene_path.is_empty():
		return

	get_tree().change_scene_to_file(game_scene_path)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
