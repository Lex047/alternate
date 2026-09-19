extends Node2D


@export_category("Audio")
@export var game_music: AudioStream


func _ready() -> void:
	MusicManager.play_music(game_music)
