extends Node2D
class_name PlayerAnimator

@export var player: Player
@export var animation_player: AnimationPlayer
@export var sprite: Sprite2D
@export var hurtbox: Area2D # Drag your Hurtbox node here in Inspector

var base_offset_x: float = 0.0

func _ready() -> void:
	# Automatic fallback if exports are left empty in the Inspector
	if not player and get_parent() is Player:
		player = get_parent() as Player
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer")
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not hurtbox and player:
		hurtbox = player.get_node_or_null("Hurtbox")
		
	if sprite:
		base_offset_x = abs(sprite.position.x)

func _physics_process(_delta: float) -> void:
	if not player or not animation_player or not sprite:
		return

	_handle_flip()
	_handle_animations()

func _handle_flip() -> void:
	if player.direction < 0:
		# Facing Left
		sprite.flip_h = true
		sprite.position.x = base_offset_x
		if hurtbox:
			hurtbox.scale.x = -1.0
	elif player.direction > 0:
		# Facing Right
		sprite.flip_h = false
		sprite.position.x = -base_offset_x
		if hurtbox:
			hurtbox.scale.x = 1.0

func _handle_animations() -> void:
	# Aerial / Jump State
	if not player.is_on_floor():
		if animation_player.has_animation("jump"):
			animation_player.play("jump")
		return

	# Ground State
	if player.direction != 0.0:
		if player.is_sprinting and animation_player.has_animation("run"):
			animation_player.play("run")
		elif animation_player.has_animation("walk"):
			animation_player.play("walk")
	else:
		if animation_player.has_animation("idle"):
			animation_player.play("idle")
