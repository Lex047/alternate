extends CharacterBody2D
class_name EnemyBase

@export_category("Combat")
@export var max_health: int = 50

@export_category("Movement")
@export var gravity: float = 980.0
@export var terminal_velocity: float = 1000.0

var current_health: int
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	velocity.y += gravity * delta
	velocity.y = min(
		velocity.y,
		terminal_velocity
	)


func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health = max(
		0,
		current_health - amount
	)

	if current_health <= 0:
		is_dead = true
		die()
	else:
		hurt()


func hurt() -> void:
	pass


func die() -> void:
	queue_free()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	var damage_hitbox := area as DamageHitbox

	if not damage_hitbox:
		return

	take_damage(damage_hitbox.damage)
