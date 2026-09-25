# One-shot artifact interaction while the player is in range. Collection
# restores health and signals the game controller to start alternation; the
# alternate room can display the broken container independently.
extends Area2D
class_name ArtifactContainer


signal collected

@export_category("Visuals")
@export var intact_texture: Texture2D
@export var broken_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var player_in_range: bool = false
var is_collected: bool = false
var player: Player = null


func _process(_delta: float) -> void:
	if (
		not is_collected
		and player_in_range
		and Input.is_action_just_pressed("interact")
	):
		is_collected = true

		if player:
			player.restore_full_health()

		collected.emit()


func show_broken_state() -> void:
	if broken_texture:
		sprite.texture = broken_texture


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body
		player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		player = null
