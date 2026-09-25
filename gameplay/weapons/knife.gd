# Player-controlled knife presentation and damage window. Player opens and
# closes the hitbox during attacks; hiding the weapon also disables collisions.
extends Node2D
class_name Knife

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: DamageHitbox = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	hide_weapon()


func show_weapon() -> void:
	sprite.show()


func hide_weapon() -> void:
	sprite.hide()
	hitbox_shape.disabled = true


func enable_hitbox() -> void:
	hitbox_shape.disabled = false


func disable_hitbox() -> void:
	hitbox_shape.disabled = true
