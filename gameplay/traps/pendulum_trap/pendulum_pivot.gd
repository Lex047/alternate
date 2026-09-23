extends Node2D


@export_category("Swing")
@export_range(1.0, 90.0, 1.0) var swing_angle: float = 45.0
@export var swing_duration: float = 1.2


func _ready() -> void:
	_start_swing()


func _start_swing() -> void:
	var angle := deg_to_rad(swing_angle)

	rotation = -angle

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		self,
		"rotation",
		angle,
		swing_duration
	)

	tween.tween_property(
		self,
		"rotation",
		-angle,
		swing_duration
	)
