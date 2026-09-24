extends EnemyBase
class_name Golem

@export_category("Patrol")
@export var patrol_speed: float = 40.0
@export var patrol_duration_min: float = 2.0
@export var patrol_duration_max: float = 4.0
@export var idle_duration_min: float = 0.8
@export var idle_duration_max: float = 1.5

@onready var patrol_timer: Timer = $PatrolTimer

var is_patrolling: bool = true

@export_category("Combat")
@export var chase_speed: float = 80.0

@onready var attack_hitbox_shape: CollisionShape2D = (
	$AttackHitbox/CollisionShape2D
)
@onready var hurtbox_shape: CollisionShape2D = (
	$Hurtbox/CollisionShape2D
)
var player_in_attack_range: bool = false
var is_attacking: bool = false
var is_hurt: bool = false


@onready var sprite: Sprite2D = $Sprite2D
@onready var floor_detector: RayCast2D = $FloorDetector
@onready var wall_detector: RayCast2D = $WallDetector
@onready var player_detector: Area2D = $PlayerDetector

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var move_direction: float = 1.0

var floor_detector_base_x: float
var wall_detector_base_x: float
var wall_target_base_x: float

var target_player: Player


func _ready() -> void:
	super._ready()

	floor_detector_base_x = abs(floor_detector.position.x)
	wall_detector_base_x = abs(wall_detector.position.x)
	wall_target_base_x = abs(wall_detector.target_position.x)

	_update_facing()
	_start_patrol()


func _physics_process(delta: float) -> void:
	apply_gravity(delta)

	if is_dead:
		velocity.x = 0.0

	elif is_hurt:
		velocity.x = 0.0

	elif is_attacking:
		velocity.x = 0.0

	elif target_player and player_in_attack_range:
		velocity.x = 0.0
		_attack()

	elif target_player:
		_chase_player()

	else:
		_patrol()

	move_and_slide()
	_update_animation()


func _patrol() -> void:
	if not is_patrolling:
		velocity.x = 0.0
		return

	if is_on_floor():
		if (
			wall_detector.is_colliding()
			or not floor_detector.is_colliding()
		):
			_turn_around()

	velocity.x = move_direction * patrol_speed


func _start_patrol() -> void:
	is_patrolling = true

	patrol_timer.start(
		randf_range(
			patrol_duration_min,
			patrol_duration_max
		)
	)


func _start_idle() -> void:
	is_patrolling = false
	velocity.x = 0.0

	patrol_timer.start(
		randf_range(
			idle_duration_min,
			idle_duration_max
		)
	)


func _chase_player() -> void:
	if not is_instance_valid(target_player):
		target_player = null
		return

	var distance_x: float = (
		target_player.global_position.x - global_position.x
	)

	var direction_to_player: float = sign(distance_x)

	if direction_to_player == 0.0:
		velocity.x = 0.0
		return

	if direction_to_player != move_direction:
		move_direction = direction_to_player
		_update_facing()

	if (
		wall_detector.is_colliding()
		or not floor_detector.is_colliding()
	):
		velocity.x = 0.0
		return

	velocity.x = move_direction * chase_speed


func _attack() -> void:
	if is_attacking or is_hurt or is_dead:
		return

	is_attacking = true
	velocity.x = 0.0

	animation_player.play("attack")

	# Windup to strike frame
	await get_tree().create_timer(0.16).timeout

	if is_hurt or is_dead:
		return

	attack_hitbox_shape.disabled = false

	# Active hit frame
	await get_tree().create_timer(0.08).timeout

	attack_hitbox_shape.disabled = true

	if is_hurt or is_dead:
		return

	# Finish remaining animation
	await get_tree().create_timer(0.16).timeout

	if is_hurt or is_dead:
		return

	# Attack cooldown
	await get_tree().create_timer(0.3).timeout

	if is_hurt or is_dead:
		return

	is_attacking = false


func hurt() -> void:
	if is_dead:
		return

	is_hurt = true
	is_attacking = false

	velocity.x = 0.0
	attack_hitbox_shape.set_deferred("disabled", true)

	animation_player.play("hurt")


func die() -> void:
	is_hurt = false
	is_attacking = false
	velocity.x = 0.0

	attack_hitbox_shape.set_deferred("disabled", true)
	hurtbox_shape.set_deferred("disabled", true)

	animation_player.play("death")


func _turn_around() -> void:
	move_direction *= -1.0
	_update_facing()


func _update_facing() -> void:
	sprite.flip_h = move_direction < 0.0
	
	$AttackRange.scale.x = move_direction
	$AttackHitbox.scale.x = move_direction

	floor_detector.position.x = (
		floor_detector_base_x * move_direction
	)

	wall_detector.position.x = (
		wall_detector_base_x * move_direction
	)

	wall_detector.target_position.x = (
		wall_target_base_x * move_direction
	)

	player_detector.scale.x = move_direction


func _on_player_detector_body_entered(body: Node2D) -> void:
	if body is Player:
		target_player = body


func _on_player_detector_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null


func _update_animation() -> void:
	if is_dead or is_hurt or is_attacking:
		return

	if abs(velocity.x) > 1.0:
		_play_animation("run")
	else:
		_play_animation("idle")


func _play_animation(animation_name: String) -> void:
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)


func _on_patrol_timer_timeout() -> void:
	if is_patrolling:
		_start_idle()
	else:
		_start_patrol()


func _on_attack_range_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return

	var owner_player := area.get_parent() as Player

	if not owner_player:
		return

	if owner_player == target_player:
		player_in_attack_range = true


func _on_attack_range_area_exited(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return

	var owner_player := area.get_parent() as Player

	if not owner_player:
		return

	if owner_player == target_player:
		player_in_attack_range = false


func _on_animation_player_animation_finished(
	anim_name: StringName
) -> void:
	if anim_name == &"hurt":
		is_hurt = false

	elif anim_name == &"death":
		queue_free()
