extends Node2D
class_name PlayerAnimator

@export var player: Player
@export var animation_player: AnimationPlayer
@export var sprite: Sprite2D
@export var hurtbox: Area2D

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

func _process(_delta: float) -> void:
	if not player or not animation_player or not sprite:
		return

	_handle_flip()
	_handle_animations()

func _handle_flip() -> void:
	if player.facing_direction < 0.0:
		sprite.flip_h = true
		sprite.position.x = base_offset_x

		if hurtbox:
			hurtbox.scale.x = -1.0
	else:
		sprite.flip_h = false
		sprite.position.x = -base_offset_x

		if hurtbox:
			hurtbox.scale.x = 1.0

func _handle_animations() -> void:
	# Ledge Climb State
	if player.is_ledge_climbing:
		_play_animation("ledge_climb")
		return

	# Attack State
	if player.is_attacking:
		_play_animation("knife_stab")
		return
	
	# Aerial / Jump State
	if not player.is_on_floor():
		# Only play 'fall' if we are dropping
		# AND not already playing 'jump'
		if (
			not player.is_jumping
			and animation_player.current_animation != "jump"
		):
			_play_animation("fall")
		elif player.is_jumping:
			_play_animation("jump")

		return
	
	# Ground State
	if player.direction != 0.0:
		if player.is_sprinting:
			_play_animation("run")
		else:
			_play_animation("walk")
	else:
		_play_animation("idle")

func _play_animation(animation_name: String) -> void:
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)

func _on_animation_player_animation_finished(
	anim_name: StringName
) -> void:
	if anim_name == &"ledge_climb":
		player.finish_ledge_climb()
