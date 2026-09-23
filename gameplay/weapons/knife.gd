extends Node2D
class_name Knife


@export var damage: int = 25


@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	hide_weapon()


func show_weapon() -> void:
	sprite.show()


func hide_weapon() -> void:
	sprite.hide()
	hitbox.monitoring = false


func enable_hitbox() -> void:
	hitbox.monitoring = true


func disable_hitbox() -> void:
	hitbox.monitoring = false
