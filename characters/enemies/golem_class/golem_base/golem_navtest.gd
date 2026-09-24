extends EnemyBase
class_name GolemNavTest


enum State {
	IDLE,
	PATROL,
	ALERT,
	CHASE,
	ATTACK,
	HURT,
	DEAD,
}


@export_category("Patrol")
@export var patrol_speed: float = 40.0
@export var patrol_duration_min: float = 2.0
@export var patrol_duration_max: float = 4.0
@export var idle_duration_min: float = 0.8
@export var idle_duration_max: float = 1.5


@export_category("Navigation")
@export var level_navigation: LevelNavigation
@export var path_refresh_interval: float = 0.25
@export var waypoint_reach_distance: float = 8.0

var current_path: PackedVector2Array = PackedVector2Array()
var current_path_index: int = 0
var path_refresh_timer: float = 0.0

@export_category("Detection")
@export var lost_player_delay: float = 1.5


@export_category("Combat")
@export var chase_speed: float = 80.0


@onready var patrol_timer: Timer = $PatrolTimer
@onready var alert_timer: Timer = $AlertTimer
@onready var lost_player_timer: Timer = $LostPlayerTimer

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@onready var floor_detector: RayCast2D = $FloorDetector
@onready var wall_detector: RayCast2D = $WallDetector
@onready var player_detector: Area2D = $PlayerDetector

@onready var attack_range: Area2D = $AttackRange
@onready var attack_hitbox: Area2D = $AttackHitbox

@onready var attack_hitbox_shape: CollisionShape2D = (
	$AttackHitbox/CollisionShape2D
)

@onready var hurtbox_shape: CollisionShape2D = (
	$Hurtbox/CollisionShape2D
)


var current_state: State = State.PATROL

var target_player: Player
var player_in_attack_range: bool = false

var move_direction: float = 1.0

var floor_detector_base_x: float
var wall_detector_base_x: float
var wall_target_base_x: float

var sprite_base_position: Vector2


func _ready() -> void:
	super._ready()

	lost_player_timer.wait_time = lost_player_delay

	floor_detector_base_x = abs(
		floor_detector.position.x
	)

	wall_detector_base_x = abs(
		wall_detector.position.x
	)

	wall_target_base_x = abs(
		wall_detector.target_position.x
	)

	sprite_base_position = sprite.position

	_update_facing()

	# current_state already starts as PATROL,
	# so initialise that state's behaviour directly.
	_enter_state(current_state)


func _physics_process(delta: float) -> void:
	apply_gravity(delta)

	match current_state:
		State.IDLE:
			_process_idle()

		State.PATROL:
			_process_patrol()

		State.ALERT:
			_process_alert()

		State.CHASE:
			_process_chase(delta)

		State.ATTACK:
			_process_attack()

		State.HURT:
			_process_hurt()

		State.DEAD:
			_process_dead()

	move_and_slide()


# ------------------------------------------------------------------
# State management
# ------------------------------------------------------------------

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	if current_state == State.DEAD:
		return

	_exit_state(current_state)

	current_state = new_state

	_enter_state(current_state)


func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			_enter_idle()

		State.PATROL:
			_enter_patrol()

		State.ALERT:
			_enter_alert()

		State.CHASE:
			_enter_chase()

		State.ATTACK:
			_enter_attack()

		State.HURT:
			_enter_hurt()

		State.DEAD:
			_enter_dead()


func _exit_state(state: State) -> void:
	if (
		state == State.IDLE
		or state == State.PATROL
	):
		if patrol_timer.is_inside_tree():
			patrol_timer.stop()

	elif state == State.ALERT:
		if alert_timer.is_inside_tree():
			alert_timer.stop()

		sprite.position = sprite_base_position

	elif state == State.CHASE:
		current_path.clear()
		current_path_index = 0

	elif state == State.ATTACK:
		attack_hitbox_shape.set_deferred(
			"disabled",
			true
		)


# ------------------------------------------------------------------
# Idle
# ------------------------------------------------------------------

func _enter_idle() -> void:
	velocity.x = 0.0

	_play_animation("idle")

	patrol_timer.start(
		randf_range(
			idle_duration_min,
			idle_duration_max
		)
	)


func _process_idle() -> void:
	velocity.x = 0.0


# ------------------------------------------------------------------
# Patrol
# ------------------------------------------------------------------

func _enter_patrol() -> void:
	_play_animation("run")

	patrol_timer.start(
		randf_range(
			patrol_duration_min,
			patrol_duration_max
		)
	)


func _process_patrol() -> void:
	if is_on_floor():
		if (
			wall_detector.is_colliding()
			or not floor_detector.is_colliding()
		):
			_turn_around()

	velocity.x = move_direction * patrol_speed


# ------------------------------------------------------------------
# Alert
# ------------------------------------------------------------------

func _enter_alert() -> void:
	velocity.x = 0.0

	if is_instance_valid(target_player):
		var direction_to_player: float = sign(
			target_player.global_position.x
			- global_position.x
		)

		if direction_to_player != 0.0:
			move_direction = direction_to_player
			_update_facing()

	animation_player.play("alert")
	alert_timer.start()


func _process_alert() -> void:
	velocity.x = 0.0


# ------------------------------------------------------------------
# Chase
# ------------------------------------------------------------------

func _enter_chase() -> void:
	_play_animation("run")

	path_refresh_timer = 0.0
	_refresh_navigation_path()


func _process_chase(delta: float) -> void:
	if not is_instance_valid(target_player):
		target_player = null
		player_in_attack_range = false

		_change_state(State.PATROL)
		return

	if player_in_attack_range:
		velocity.x = 0.0
		_change_state(State.ATTACK)
		return

	# Recalculate occasionally because the player can move.
	path_refresh_timer -= delta

	if path_refresh_timer <= 0.0:
		_refresh_navigation_path()
		path_refresh_timer = path_refresh_interval

	# No navigation graph assigned yet:
	# preserve the old direct chase behaviour.
	if not level_navigation:
		_move_toward_x(
			target_player.global_position.x
		)
		return

	# A* could not find a route.
	if current_path.is_empty():
		velocity.x = 0.0
		_play_animation("idle")
		return

	# Skip navigation points we've already reached.
	while current_path_index < current_path.size():
		var point: Vector2 = current_path[current_path_index]

		# Close enough to the waypoint.
		if abs(point.x - global_position.x) <= waypoint_reach_distance:
			current_path_index += 1
			continue

		# Check whether we have already moved past this waypoint.
		if current_path_index > 0:
			var previous_point: Vector2 = (
				current_path[current_path_index - 1]
			)

			var segment_direction: float = sign(
				point.x - previous_point.x
			)

			if (
				segment_direction > 0.0
				and global_position.x >= point.x
			):
				current_path_index += 1
				continue

			if (
				segment_direction < 0.0
				and global_position.x <= point.x
			):
				current_path_index += 1
				continue

		break

	# We've reached the final navigation point.
	if current_path_index >= current_path.size():
		_move_toward_x(
			target_player.global_position.x
		)
		return

	# Move toward the next A* waypoint.
	var next_point := current_path[current_path_index]

	_move_toward_x(next_point.x)


func _refresh_navigation_path() -> void:
	current_path.clear()
	current_path_index = 0

	if not level_navigation:
		return

	if not is_instance_valid(target_player):
		return

	current_path = level_navigation.find_navigation_path(
		global_position,
		target_player.global_position
	)

	# Point 0 is the A* start point.
	# We want to move toward the next point in the route.
	if current_path.size() > 1:
		current_path_index = 1


func _move_toward_x(target_x: float) -> void:
	var distance_x: float = (
		target_x - global_position.x
	)

	var direction_to_target: float = sign(
		distance_x
	)

	if direction_to_target == 0.0:
		velocity.x = 0.0
		_play_animation("idle")
		return

	if direction_to_target != move_direction:
		move_direction = direction_to_target
		_update_facing()

	# Local safety still matters even with pathfinding.
	if (
		wall_detector.is_colliding()
		or not floor_detector.is_colliding()
	):
		velocity.x = 0.0
		_play_animation("idle")
		return

	velocity.x = move_direction * chase_speed
	_play_animation("run")


# ------------------------------------------------------------------
# Attack
# ------------------------------------------------------------------

func _enter_attack() -> void:
	velocity.x = 0.0

	animation_player.play("attack")

	_run_attack()


func _process_attack() -> void:
	velocity.x = 0.0


func _run_attack() -> void:
	# Frames 0–1: windup
	await get_tree().create_timer(0.16).timeout

	if current_state != State.ATTACK:
		return

	# Frame 2: active hit
	attack_hitbox_shape.disabled = false

	await get_tree().create_timer(0.08).timeout

	if current_state != State.ATTACK:
		return

	attack_hitbox_shape.disabled = true

	# Finish the rest of the animation.
	await get_tree().create_timer(0.16).timeout

	if current_state != State.ATTACK:
		return

	# Attack cooldown.
	await get_tree().create_timer(0.3).timeout

	if current_state != State.ATTACK:
		return

	if is_instance_valid(target_player):
		_change_state(State.CHASE)
	else:
		_change_state(State.PATROL)


# ------------------------------------------------------------------
# Hurt
# ------------------------------------------------------------------

func hurt() -> void:
	if current_state == State.DEAD:
		return

	_change_state(State.HURT)


func _enter_hurt() -> void:
	velocity.x = 0.0

	attack_hitbox_shape.set_deferred(
		"disabled",
		true
	)

	animation_player.play("hurt")


func _process_hurt() -> void:
	velocity.x = 0.0


# ------------------------------------------------------------------
# Death
# ------------------------------------------------------------------

func die() -> void:
	is_dead = true

	_change_state(State.DEAD)


func _enter_dead() -> void:
	velocity.x = 0.0

	if patrol_timer.is_inside_tree():
		patrol_timer.stop()

	if lost_player_timer.is_inside_tree():
		lost_player_timer.stop()

	if alert_timer.is_inside_tree():
		alert_timer.stop()

	attack_hitbox_shape.set_deferred(
		"disabled",
		true
	)

	hurtbox_shape.set_deferred(
		"disabled",
		true
	)

	animation_player.play("death")


func _process_dead() -> void:
	velocity.x = 0.0


# ------------------------------------------------------------------
# Facing
# ------------------------------------------------------------------

func _turn_around() -> void:
	move_direction *= -1.0
	_update_facing()


func _update_facing() -> void:
	sprite.flip_h = move_direction < 0.0

	attack_range.scale.x = move_direction
	attack_hitbox.scale.x = move_direction

	floor_detector.position.x = (
		floor_detector_base_x
		* move_direction
	)

	wall_detector.position.x = (
		wall_detector_base_x
		* move_direction
	)

	wall_detector.target_position.x = (
		wall_target_base_x
		* move_direction
	)

	player_detector.scale.x = move_direction


# ------------------------------------------------------------------
# Player detection
# ------------------------------------------------------------------

func _on_player_detector_body_entered(
	body: Node2D
) -> void:
	if body is not Player:
		return

	if current_state == State.DEAD:
		return

	lost_player_timer.stop()

	if target_player == body:
		return

	target_player = body

	if (
		current_state == State.IDLE
		or current_state == State.PATROL
	):
		_change_state(State.ALERT)


func _on_player_detector_body_exited(
	body: Node2D
) -> void:
	if body != target_player:
		return

	if current_state == State.DEAD:
		return

	if not lost_player_timer.is_inside_tree():
		return

	lost_player_timer.start()


# ------------------------------------------------------------------
# Attack range
# ------------------------------------------------------------------

func _on_attack_range_area_entered(
	area: Area2D
) -> void:
	if area.name != "Hurtbox":
		return

	var owner_player := area.get_parent() as Player

	if not owner_player:
		return

	if owner_player == target_player:
		player_in_attack_range = true


func _on_attack_range_area_exited(
	area: Area2D
) -> void:
	if area.name != "Hurtbox":
		return

	var owner_player := area.get_parent() as Player

	if not owner_player:
		return

	if owner_player == target_player:
		player_in_attack_range = false


# ------------------------------------------------------------------
# Animation
# ------------------------------------------------------------------

func _play_animation(
	animation_name: String
) -> void:
	if animation_player.current_animation != animation_name:
		animation_player.play(animation_name)


func _on_animation_player_animation_finished(
	anim_name: StringName
) -> void:
	if (
		anim_name == &"hurt"
		and current_state == State.HURT
	):
		if is_instance_valid(target_player):
			_change_state(State.CHASE)
		else:
			_change_state(State.PATROL)

	elif (
		anim_name == &"death"
		and current_state == State.DEAD
	):
		queue_free()


# ------------------------------------------------------------------
# Timers
# ------------------------------------------------------------------

func _on_patrol_timer_timeout() -> void:
	if current_state == State.PATROL:
		_change_state(State.IDLE)

	elif current_state == State.IDLE:
		_change_state(State.PATROL)


func _on_alert_timer_timeout() -> void:
	if current_state != State.ALERT:
		return

	if is_instance_valid(target_player):
		_change_state(State.CHASE)
	else:
		_change_state(State.PATROL)


func _on_lost_player_timer_timeout() -> void:
	target_player = null
	player_in_attack_range = false

	if (
		current_state == State.ALERT
		or current_state == State.CHASE
	):
		_change_state(State.PATROL)
