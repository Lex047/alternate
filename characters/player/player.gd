extends CharacterBody2D
class_name Player

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

@export_category("Combat")
@export var max_health: int = 100

# Player State variables
var direction: float = 0.0
var is_sprinting: bool = false
var is_jumping: bool = false
var current_health: int
var coyote_timer: float = 0.0

func _ready() -> void:
	current_health = max_health

func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Generic damage extraction: reads .damage if it exists, otherwise defaults to 10
	var incoming_damage: int = 10
	if "damage" in area:
		incoming_damage = area.damage
		
	take_damage(incoming_damage)

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	print("Player took ", amount, " damage. HP left: ", current_health)
	
	if current_health <= 0:
		_die()

func _die() -> void:
	print("Player died!")
	# Handle respawn, death animation, or scene reload later

func _physics_process(delta: float) -> void:
	# 1. Read Inputs First
	direction = Input.get_axis("move_left", "move_right")
	is_sprinting = Input.is_action_pressed("sprint")
	
	# 2. Update Coyote Timer (Refill while on floor, drain while airborne)
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)
	
	# 3. Check for Jump Execution
	if Input.is_action_just_pressed("jump") and coyote_timer > 0.0:
		velocity.y = jump_velocity
		coyote_timer = 0.0
		is_jumping = true
	
	# 4. Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > terminal_velocity:
			velocity.y = terminal_velocity
	
	# 5. Horizontal Velocity
	var current_target_speed: float = run_speed if is_sprinting else walk_speed
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * current_target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	# 6. Apply Physics Movement
	move_and_slide()
	
	# 7. Check Jump End
	if is_jumping and velocity.y >= 0.0:
		is_jumping = false
	
	# 8. Respawn Debug Code
	if global_position.y > 600:
		get_tree().reload_current_scene()
