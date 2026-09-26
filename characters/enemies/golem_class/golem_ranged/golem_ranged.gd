# Ranged golem specialization using the base detection and damage states. It
# chases until within firing distance, then releases a horizontal projectile
# after a windup and waits through recovery and cooldown before chasing again.
extends Golem
class_name GolemRanged


@export_category("Ranged Combat")
@export var ranged_chase_speed: float = 65.0
@export var ranged_attack_distance: float = 140.0

@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 1.0

@onready var projectile_spawn: Marker2D = $ProjectileSpawn


func _enter_chase() -> void:
	velocity.x = 0.0
	_play_animation("idle")


func _process_chase() -> void:
	if not is_instance_valid(target_player):
		target_player = null
		_change_state(State.PATROL)
		return

	_face_target()

	var distance_to_player: float = abs(
		target_player.global_position.x
		- global_position.x
	)

	if distance_to_player <= ranged_attack_distance:
		velocity.x = 0.0
		_change_state(State.ATTACK)
		return

	if (
		wall_detector.is_colliding()
		or not floor_detector.is_colliding()
	):
		velocity.x = 0.0
		_play_animation("idle")
		return

	velocity.x = move_direction * ranged_chase_speed
	_play_animation("run")


func _face_target() -> void:
	if not is_instance_valid(target_player):
		return

	var direction_to_player: float = sign(
		target_player.global_position.x - global_position.x
	)

	if direction_to_player == 0.0:
		return

	if direction_to_player != move_direction:
		move_direction = direction_to_player
		_update_facing()


func _enter_attack() -> void:
	velocity.x = 0.0

	_face_target()
	
	if golem_audio:
		golem_audio.play_attack()
	
	_play_animation("Ranged/attack_ranged")

	_run_ranged_attack()


# Projectile release is timed to the ranged animation, followed by recovery
# and the configured shot cooldown. State checks cancel the remaining sequence
# when hurt or death interrupts the attack.
func _run_ranged_attack() -> void:
	await get_tree().create_timer(0.26).timeout

	if current_state != State.ATTACK:
		return

	_fire_projectile()

	await get_tree().create_timer(0.52).timeout

	if current_state != State.ATTACK:
		return

	await get_tree().create_timer(attack_cooldown).timeout

	if current_state != State.ATTACK:
		return

	if is_instance_valid(target_player):
		_change_state(State.CHASE)
	else:
		_change_state(State.PATROL)


func _fire_projectile() -> void:
	if not projectile_scene:
		return

	if not is_instance_valid(target_player):
		return

	var projectile := (
		projectile_scene.instantiate()
		as GolemProjectile
	)

	if not projectile:
		return

	_configure_projectile(projectile)

	get_tree().current_scene.add_child(projectile)

	projectile.global_position = (
		projectile_spawn.global_position
		+ Vector2(0, -16)
	)

	projectile.direction = Vector2(
		move_direction,
		0.0
	)

	projectile.direction = Vector2(
		move_direction,
		0.0
	)


func _configure_projectile(
	_projectile: GolemProjectile
) -> void:
	pass
