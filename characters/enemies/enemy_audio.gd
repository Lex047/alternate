# Routes golem combat cues through a shared action player, with pitch changes
# distinguishing attack, hit, and death feedback.
extends Node
class_name EnemyAudio

@onready var movement_player: AudioStreamPlayer = $MovementPlayer
@onready var action_player: AudioStreamPlayer = $ActionPlayer

@export_category("Movement Sounds")
@export var hit_sound: AudioStream
@export var attack_sound: AudioStream
@export var death_sound: AudioStream


func play_hit() -> void:
	_play_action(attack_sound, 0.5)


func play_attack() -> void:
	_play_action(attack_sound, 2.0)


func play_death() -> void:
	_play_action(death_sound, 0.5)


func _play_action(
	sound: AudioStream,
	pitch: float = 1.0
) -> void:
	if not sound:
		return

	action_player.stream = sound
	action_player.pitch_scale = pitch
	action_player.play()
