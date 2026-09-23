extends CharacterBody2D
class_name Player

@export var player_audio: PlayerAudio
@onready var player_camera: PlayerCamera = $PlayerCamera


@export_category("Movement")
@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0
@export var acceleration: float = 1200.0
@export var friction: float = 1500.0


@export_category("Jumping")
@export var jump_velocity: float = -350.0
@export var gravity: float = 980.0
@export var terminal_velocity: float = 1000.0
@export var coyote_time: float = 0.25


@export_category("Ledge Climbing")
@export var ledge_detector: ShapeCast2D
@export var ledge_grab_point: Marker2D
@export var body_collision: CollisionShape2D

@export var ledge_search_step: float = 2.0
@export var ledge_grab_max_x_distance: float = 8.0
@export var ledge_grab_max_y_distance: float = 8.0
@export var wall_clearance: float = 2.0
@export var floor_clearance: float = 2.0
@export var ledge_regrab_delay: float = 0.25


@export_category("Combat")
@export var max_health: int = 100


var direction: float = 0.0
var is_sprinting: bool = false

var is_jumping: bool = false
var is_airborne: bool = false
var jumped_this_airtime: bool = false

var current_health: int
var coyote_timer: float = 0.0

var is_ledge_climbing: bool = false
var has_ledge_climbed: bool = false
var facing_direction: float = 1.0

var ledge_stand_position: Vector2
var ledge_cooldown: float = 0.0

var ledge_detector_base_x: float = 0.0


func _ready() -> void:
	current_health = max_health

	GameManager.register_player(self)

	if ledge_detector:
		ledge_detector_base_x = abs(ledge_detector.position.x)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_damage"):
		take_damage(10)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	var incoming_damage: int = 10

	if "damage" in area:
		incoming_damage = area.damage

	take_damage(incoming_damage)


func take_damage(amount: int) -> void:
	current_health = max(
		0,
		current_health - amount
	)
	
	player_camera.shake()

	GameManager.update_player_health(
		current_health,
		max_health
	)

	if current_health <= 0:
		_die()


func _die() -> void:
	GameManager.handle_player_death()


func _get_body_half_height() -> float:
	if not body_collision or not body_collision.shape:
		return 16.0

	if body_collision.shape is RectangleShape2D:
		var rect := body_collision.shape as RectangleShape2D
		return rect.size.y * 0.5

	if body_collision.shape is CapsuleShape2D:
		var capsule := body_collision.shape as CapsuleShape2D
		return capsule.height * 0.5

	return 16.0


func _get_body_half_width() -> float:
	if not body_collision or not body_collision.shape:
		return 8.0

	if body_collision.shape is RectangleShape2D:
		var rect := body_collision.shape as RectangleShape2D
		return rect.size.x * 0.5

	if body_collision.shape is CapsuleShape2D:
		var capsule := body_collision.shape as CapsuleShape2D
		return capsule.radius

	return 8.0


func _update_ledge_detector() -> void:
	if not ledge_detector:
		return

	ledge_detector.position.x = (
		ledge_detector_base_x * facing_direction
	)

	ledge_detector.force_shapecast_update()


func _can_attempt_ledge_climb() -> bool:
	if is_ledge_climbing:
		return false

	if ledge_cooldown > 0.0:
		return false

	if is_on_floor():
		return false

	if not jumped_this_airtime:
		return false

	if not ledge_detector:
		return false

	if not ledge_detector.is_colliding():
		return false

	return true


func _get_detector_size() -> Vector2:
	if not ledge_detector or not ledge_detector.shape:
		return Vector2.ZERO

	if ledge_detector.shape is RectangleShape2D:
		var rect := ledge_detector.shape as RectangleShape2D
		return rect.size

	return Vector2.ZERO


func _find_ledge_corner() -> Vector2:
	if not ledge_detector:
		return Vector2.INF

	var detector_size: Vector2 = _get_detector_size()

	if detector_size == Vector2.ZERO:
		return Vector2.INF

	var space_state := get_world_2d().direct_space_state
	var mask: int = ledge_detector.collision_mask
	var center: Vector2 = ledge_detector.global_position

	var half_width: float = detector_size.x * 0.5
	var half_height: float = detector_size.y * 0.5

	var left_x: float = center.x - half_width
	var right_x: float = center.x + half_width
	var top_y: float = center.y - half_height
	var bottom_y: float = center.y + half_height

	var steps: int = int(
		detector_size.x / ledge_search_step
	)

	if steps < 1:
		steps = 1

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var sample_x: float

		if facing_direction > 0.0:
			sample_x = lerpf(
				right_x,
				left_x,
				t
			)
		else:
			sample_x = lerpf(
				left_x,
				right_x,
				t
			)

		var top_from := Vector2(
			sample_x,
			top_y
		)

		var top_to := Vector2(
			sample_x,
			bottom_y
		)

		var top_query := PhysicsRayQueryParameters2D.create(
			top_from,
			top_to
		)

		top_query.collision_mask = mask
		top_query.exclude = [get_rid()]

		var top_result: Dictionary = (
			space_state.intersect_ray(top_query)
		)

		if top_result.is_empty():
			continue

		var top_normal: Vector2 = top_result["normal"]

		if top_normal.y > -0.7:
			continue

		var top_point: Vector2 = top_result["position"]
		var wall_y: float = top_point.y + 2.0

		var wall_from: Vector2
		var wall_to: Vector2

		if facing_direction > 0.0:
			wall_from = Vector2(
				left_x,
				wall_y
			)

			wall_to = Vector2(
				right_x,
				wall_y
			)
		else:
			wall_from = Vector2(
				right_x,
				wall_y
			)

			wall_to = Vector2(
				left_x,
				wall_y
			)

		var wall_query := PhysicsRayQueryParameters2D.create(
			wall_from,
			wall_to
		)

		wall_query.collision_mask = mask
		wall_query.exclude = [get_rid()]

		var wall_result: Dictionary = (
			space_state.intersect_ray(wall_query)
		)

		if wall_result.is_empty():
			continue

		var wall_normal: Vector2 = wall_result["normal"]

		if wall_normal.x * facing_direction > -0.7:
			continue

		var wall_point: Vector2 = wall_result["position"]

		return Vector2(
			wall_point.x,
			top_point.y
		)

	return Vector2.INF


func _get_grab_offset() -> Vector2:
	if not ledge_grab_point:
		return Vector2.ZERO

	return Vector2(
		abs(ledge_grab_point.position.x) * facing_direction,
		ledge_grab_point.position.y
	)


func _is_valid_ledge_reach(
	ledge_corner: Vector2
) -> bool:
	if not ledge_grab_point:
		return false

	var grab_position: Vector2 = (
		global_position + _get_grab_offset()
	)

	var difference: Vector2 = (
		ledge_corner - grab_position
	)

	if abs(difference.x) > ledge_grab_max_x_distance:
		return false

	if abs(difference.y) > ledge_grab_max_y_distance:
		return false

	return true


func _start_ledge_climb(
	ledge_corner: Vector2
) -> void:
	if not ledge_grab_point:
		return

	is_ledge_climbing = true
	is_jumping = false
	velocity = Vector2.ZERO

	if player_audio:
		player_audio.play_ledge_climb()

	var grab_offset: Vector2 = _get_grab_offset()

	var hang_position: Vector2 = (
		ledge_corner - grab_offset
	)

	var body_half_width: float = _get_body_half_width()
	var body_half_height: float = _get_body_half_height()

	var collision_offset_y: float = 0.0

	if body_collision:
		collision_offset_y = body_collision.position.y

	var stand_x: float = (
		ledge_corner.x
		+ facing_direction
		* (body_half_width + wall_clearance)
	)

	var stand_y: float = (
		ledge_corner.y
		- collision_offset_y
		- body_half_height
		- floor_clearance
	)

	ledge_stand_position = Vector2(
		stand_x,
		stand_y
	)

	global_position = hang_position


func finish_ledge_climb() -> void:
	global_position = ledge_stand_position
	velocity = Vector2.ZERO

	is_ledge_climbing = false
	has_ledge_climbed = true
	jumped_this_airtime = false
	ledge_cooldown = ledge_regrab_delay


func teleport_to(
	target_position: Vector2
) -> void:
	velocity = Vector2.ZERO
	global_position = target_position

	player_camera.reset_smoothing()
	player_camera.force_update_scroll()


func _physics_process(delta: float) -> void:
	if ledge_cooldown > 0.0:
		ledge_cooldown = max(
			0.0,
			ledge_cooldown - delta
		)

	direction = Input.get_axis(
		"move_left",
		"move_right"
	)

	is_sprinting = Input.is_action_pressed(
		"sprint"
	)

	if direction != 0.0 and not is_ledge_climbing:
		facing_direction = sign(direction)

	_update_ledge_detector()

	if is_ledge_climbing:
		velocity = Vector2.ZERO
		return

	if is_on_floor():
		coyote_timer = coyote_time
		jumped_this_airtime = false
	
		if is_airborne and not has_ledge_climbed:
			if player_audio:
				player_audio.play_land()
	
		is_airborne = false
		has_ledge_climbed = false
	
	else:
		coyote_timer = max(
			0.0,
			coyote_timer - delta
		)

	if (
		Input.is_action_just_pressed("jump")
		and coyote_timer > 0.0
	):
		velocity.y = jump_velocity
		coyote_timer = 0.0
	
		is_jumping = true
		jumped_this_airtime = true

		if player_audio:
			player_audio.play_jump()

	if not is_on_floor():
		if velocity.y != 0.0:
			is_airborne = true

		velocity.y += gravity * delta

		if velocity.y > terminal_velocity:
			velocity.y = terminal_velocity

	if _can_attempt_ledge_climb():
		var ledge_corner: Vector2 = (
			_find_ledge_corner()
		)

		if (
			ledge_corner != Vector2.INF
			and _is_valid_ledge_reach(ledge_corner)
		):
			_start_ledge_climb(ledge_corner)
			return

	var current_target_speed: float = (
		run_speed
		if is_sprinting
		else walk_speed
	)

	if direction != 0.0:
		velocity.x = move_toward(
			velocity.x,
			direction * current_target_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			friction * delta
		)

	move_and_slide()

	if is_jumping and velocity.y >= 0.0:
		is_jumping = false
