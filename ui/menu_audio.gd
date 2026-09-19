extends Node
class_name MenuAudio


@onready var focus_player: AudioStreamPlayer = $FocusPlayer
@onready var action_player: AudioStreamPlayer = $ActionPlayer


@export_category("UI Sounds")
@export var focus_sound: AudioStream
@export var confirm_sound: AudioStream
@export var back_sound: AudioStream


func play_focus() -> void:
	if not focus_sound:
		return

	focus_player.stream = focus_sound 
	focus_player.play()


func play_confirm() -> void:
	_play_action(confirm_sound)


func play_back() -> void:
	_play_action(back_sound)


func _play_action(sound: AudioStream) -> void:
	if not sound:
		return

	action_player.stream = sound
	action_player.play()
