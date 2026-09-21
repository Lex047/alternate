extends CanvasLayer
class_name AlternateTransition


signal transition_midpoint
signal transition_finished


@export_category("Transition")
@export var fade_in_duration: float = 0.35
@export var hold_duration: float = 0.15
@export var fade_out_duration: float = 0.45

@export var transition_color: Color = Color(
	0.02,
	0.03,
	0.06,
	1.0
)


@onready var overlay: ColorRect = $Overlay


var is_playing: bool = false


func _ready() -> void:
	overlay.color = transition_color
	overlay.modulate.a = 0.0
	overlay.hide()


func play_transition() -> void:
	if is_playing:
		return

	is_playing = true

	overlay.show()
	overlay.modulate.a = 0.0

	var fade_in := create_tween()

	fade_in.tween_property(
		overlay,
		"modulate:a",
		1.0,
		fade_in_duration
	)

	await fade_in.finished

	transition_midpoint.emit()

	await get_tree().create_timer(
		hold_duration
	).timeout

	var fade_out := create_tween()

	fade_out.tween_property(
		overlay,
		"modulate:a",
		0.0,
		fade_out_duration
	)

	await fade_out.finished

	overlay.hide()

	is_playing = false

	transition_finished.emit()
