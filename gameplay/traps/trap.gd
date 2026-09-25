# Tracks a player hurtbox inside the hazard and requests damage on entry and
# on timer ticks. Player.take_trap_damage supplies the shared trap-hit cooldown,
# so overlapping hazards cannot bypass that protection.
extends Area2D
class_name Trap


@export_category("Damage")
@export var damage: int = 15
@export var damage_interval: float = 2.0


@onready var damage_timer: Timer = $DamageTimer


var player_hurtbox: Area2D
var player: Player


func _ready() -> void:
	damage_timer.wait_time = damage_interval


func _on_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return

	var owner_player := area.get_parent() as Player

	if not owner_player:
		return

	player_hurtbox = area
	player = owner_player

	_damage_player()
	damage_timer.start()


func _on_area_exited(area: Area2D) -> void:
	if area != player_hurtbox:
		return

	player_hurtbox = null
	player = null
	damage_timer.stop()


func _on_damage_timer_timeout() -> void:
	_damage_player()


func _damage_player() -> void:
	if not is_instance_valid(player):
		damage_timer.stop()
		player_hurtbox = null
		player = null
		return

	player.take_trap_damage(damage)
