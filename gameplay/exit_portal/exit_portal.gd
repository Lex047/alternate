# Return objective activated by the game after alternation. An in-range player
# can interact to emit exited; the game controller handles completion once.
extends Area2D
class_name ExitPortal


signal exited


@onready var animated_sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)


var player_in_range: bool = false
var is_active: bool = false


func _ready() -> void:
	animated_sprite.hide()
	animated_sprite.stop()


func _process(_delta: float) -> void:
	if not is_active:
		return

	if (
		player_in_range
		and Input.is_action_just_pressed("interact")
	):
		exited.emit()


func activate() -> void:
	if is_active:
		return

	is_active = true

	animated_sprite.show()
	animated_sprite.play()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_in_range = true


func _on_body_exited(body: Node) -> void:
	if body is Player:
		player_in_range = false
