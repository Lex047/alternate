extends Camera2D
class_name PlayerCamera

@export_category("Screen Shake")
@export var default_shake_strength: float = 5.0
@export var default_shake_duration: float = 0.15


var shake_strength: float = 0.0
var shake_time: float = 0.0
var base_offset: Vector2


func _ready() -> void:
	base_offset = offset


func _process(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta

		offset = base_offset + Vector2(
			roundf(randf_range(-shake_strength, shake_strength)),
			roundf(randf_range(-shake_strength, shake_strength))
		)

		if shake_time <= 0.0:
			offset = base_offset


func shake(
	strength: float = default_shake_strength,
	duration: float = default_shake_duration
) -> void:
	shake_strength = strength
	shake_time = duration
