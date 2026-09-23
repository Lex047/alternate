extends Area2D
class_name Trap


@export_category("Damage")
@export var damage: int = 25
@export var damage_interval: float = 0.75


@onready var damage_timer: Timer = $DamageTimer


var player_in_trap: Player


func _ready() -> void:
	damage_timer.wait_time = damage_interval


func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return

	player_in_trap = body

	_damage_player()

	damage_timer.start()


func _on_body_exited(body: Node2D) -> void:
	if body != player_in_trap:
		return

	player_in_trap = null
	damage_timer.stop()


func _on_damage_timer_timeout() -> void:
	_damage_player()


func _damage_player() -> void:
	if not is_instance_valid(player_in_trap):
		damage_timer.stop()
		player_in_trap = null
		return

	player_in_trap.take_damage(damage)
