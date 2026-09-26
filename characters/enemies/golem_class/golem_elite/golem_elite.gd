# Elite golem combines the existing melee and ranged golem behavior with
# stronger stats. It aggressively pursues melee opportunities, while low
# health causes it to retreat and favor ranged combat unless cornered.
extends GolemRanged
class_name GolemElite


enum AttackChoice {
	MELEE,
	RANGED,
}


@export_category("Elite Visuals")
@export var elite_tint: Color = Color(
	0.55,
	0.55,
	0.55,
	1.0
)


@export_category("Elite Stats")
@export var elite_max_health: int = 100
@export var elite_patrol_speed: float = 60.0
@export var elite_chase_speed: float = 170.0
@export var elite_attack_cooldown: float = 0.7


@export_category("Elite Combat")
@export var melee_engage_distance: float = 90.0

@export_range(0.0, 1.0, 0.05)
var danger_health_ratio: float = 0.35


@export_category("Elite Retreat")
@export var retreat_trigger_distance: float = 90.0
@export var retreat_safe_distance: float = 130.0
@export var retreat_speed: float = 210.0


@export_category("Elite Tracking")
@export var elite_lost_player_delay: float = 3.5
@export var elite_lost_chase_speed: float = 250.0


var retreating: bool = false
var melee_committed: bool = false

var next_attack: AttackChoice = AttackChoice.RANGED


func _ready() -> void:
	max_health = elite_max_health
	patrol_speed = elite_patrol_speed
	chase_speed = elite_chase_speed
	ranged_chase_speed = elite_chase_speed
	attack_cooldown = elite_attack_cooldown

	lost_player_delay = elite_lost_player_delay

	super._ready()

	modulate = elite_tint


func _process_chase() -> void:
	if not is_instance_valid(target_player):
		target_player = null
		player_in_attack_range = false

		_reset_elite_combat()

		_change_state(State.PATROL)
		return

	if retreating:
		_process_retreat()
		return

	if melee_committed:
		if player_in_attack_range:
			melee_committed = false
			next_attack = AttackChoice.MELEE

			velocity.x = 0.0
			_change_state(State.ATTACK)
			return

		# The player is close enough for melee intent, but there is
		# no floor ahead to actually reach them. Fall back to ranged.
		if not floor_detector.is_colliding():
			melee_committed = false
			next_attack = AttackChoice.RANGED

			velocity.x = 0.0
			_change_state(State.ATTACK)
			return

		_chase_player()
		return

	var distance_to_player: float = _distance_to_player()

	if _is_endangered():
		if distance_to_player <= retreat_trigger_distance:
			_begin_retreat()
			return

		if distance_to_player <= ranged_attack_distance:
			next_attack = AttackChoice.RANGED
			_change_state(State.ATTACK)
			return

		_chase_player()
		return

	if player_in_attack_range:
		next_attack = AttackChoice.MELEE

		velocity.x = 0.0
		_change_state(State.ATTACK)
		return

	if distance_to_player <= melee_engage_distance:
		melee_committed = true
		_chase_player()
		return

	if distance_to_player <= ranged_attack_distance:
		next_attack = AttackChoice.RANGED
		_change_state(State.ATTACK)
		return

	_chase_player()


func _chase_player() -> void:
	if not is_instance_valid(target_player):
		return

	var distance_x: float = (
		target_player.global_position.x
		- global_position.x
	)

	var direction_to_player: float = sign(
		distance_x
	)

	if direction_to_player == 0.0:
		velocity.x = 0.0
		_play_animation("idle")
		return

	if direction_to_player != move_direction:
		move_direction = direction_to_player
		_update_facing()

	if (
		wall_detector.is_colliding()
		or not floor_detector.is_colliding()
	):
		velocity.x = 0.0
		_play_animation("idle")
		return

	var current_chase_speed: float = elite_chase_speed

	if not lost_player_timer.is_stopped():
		current_chase_speed = elite_lost_chase_speed

	velocity.x = move_direction * current_chase_speed
	_play_animation("run")


func _begin_retreat() -> void:
	retreating = true
	melee_committed = false

	_process_retreat()


func _process_retreat() -> void:
	if not is_instance_valid(target_player):
		target_player = null
		player_in_attack_range = false

		_reset_elite_combat()

		_change_state(State.PATROL)
		return

	var distance_to_player: float = _distance_to_player()

	var retreat_direction: float = sign(
		global_position.x
		- target_player.global_position.x
	)

	if retreat_direction == 0.0:
		retreat_direction = -move_direction

	if retreat_direction != move_direction:
		move_direction = retreat_direction
		_update_facing()

	var retreat_blocked: bool = (
		wall_detector.is_colliding()
		or not floor_detector.is_colliding()
	)

	if retreat_blocked:
		velocity.x = 0.0
		retreating = false

		_face_target()

		if distance_to_player <= melee_engage_distance:
			melee_committed = true
			_chase_player()
			return

		next_attack = AttackChoice.RANGED
		_change_state(State.ATTACK)
		return

	if distance_to_player >= retreat_safe_distance:
		velocity.x = 0.0
		retreating = false

		_face_target()

		next_attack = AttackChoice.RANGED
		_change_state(State.ATTACK)
		return

	velocity.x = retreat_direction * retreat_speed
	_play_animation("run")


func _enter_attack() -> void:
	if next_attack == AttackChoice.RANGED:
		super._enter_attack()
		return

	velocity.x = 0.0

	if golem_audio:
		golem_audio.play_attack()

	animation_player.play("attack")
	_run_attack()


func _distance_to_player() -> float:
	if not is_instance_valid(target_player):
		return INF

	return abs(
		target_player.global_position.x
		- global_position.x
	)


func _is_endangered() -> bool:
	if max_health <= 0:
		return false

	var health_ratio: float = (
		float(current_health)
		/ float(max_health)
	)

	return health_ratio <= danger_health_ratio


func _reset_elite_combat() -> void:
	retreating = false
	melee_committed = false
	next_attack = AttackChoice.RANGED


func _on_lost_player_timer_timeout() -> void:
	_reset_elite_combat()

	super._on_lost_player_timer_timeout()


func _configure_projectile(
	projectile: GolemProjectile
) -> void:
	projectile.apply_tint = true
