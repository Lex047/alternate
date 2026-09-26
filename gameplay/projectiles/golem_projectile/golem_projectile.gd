# Ranged golem damage area moving horizontally while gravity adds downward
# velocity. It spins for visual feedback and expires on contact or timeout;
# player damage is handled by the receiving hurtbox.
extends DamageHitbox
class_name GolemProjectile


@export_category("Projectile Visuals")
@export var projectile_variant_tint: Color = Color(
	0.55,
	0.55,
	0.55,
	1.0
)
@export var apply_tint: bool = false


@export_category("Movement")
@export var speed: float = 180.0
@export var projectile_gravity: float = 40.0
@export var terminal_velocity: float = 500.0

@export_category("Visual")
@export var spin_speed: float = 8.0

@export_category("Lifetime")
@export var lifetime: float = 4.0


@onready var sprite: Sprite2D = $Sprite2D


var direction: Vector2 = Vector2.RIGHT
var fall_velocity: float = 0.0


func _ready() -> void:
	if apply_tint:
		modulate = projectile_variant_tint

	await get_tree().create_timer(lifetime).timeout

	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	fall_velocity += projectile_gravity * delta
	fall_velocity = min(
		fall_velocity,
		terminal_velocity
	)

	global_position.x += (
		direction.x
		* speed
		* delta
	)

	global_position.y += (
		fall_velocity
		* delta
	)

	sprite.rotation += (
		spin_speed
		* direction.x
		* delta
	)


func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return

	var owner_player := area.get_parent() as Player

	if not owner_player:
		return

	queue_free()
