extends Node
class_name PlayerAudio

@onready var movement_player: AudioStreamPlayer = $MovementPlayer
@onready var action_player: AudioStreamPlayer = $ActionPlayer

@export_category("Movement Sounds")
@export var footstep_sound: AudioStream
@export var jump_sound: AudioStream
@export var land_sound: AudioStream
@export var ledge_climb_sound: AudioStream
@export var attack_sound: AudioStream
@export var hurt_sound: AudioStream

func play_footstep() -> void:
	if not footstep_sound:
		return

	movement_player.stream = footstep_sound
	movement_player.play()


func play_jump() -> void:
	_play_action(jump_sound, 1.0)


func play_land() -> void:
	_play_action(land_sound, 1.5)


func play_ledge_climb() -> void:
	_play_action(ledge_climb_sound, 1.0)


func play_attack() -> void:
	_play_action(attack_sound, 1.0)

func play_hurt() -> void:
	_play_action(hurt_sound, 1.0)

func _play_action(
	sound: AudioStream,
	pitch: float = 1.0
) -> void:
	if not sound:
		return

	action_player.stream = sound
	action_player.pitch_scale = pitch
	action_player.play()
