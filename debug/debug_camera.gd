# Free camera for inspecting generated layouts with keyboard movement, mouse
# panning, and wheel zoom. Movement scales with zoom to keep screen-space travel
# consistent; the game controller switches between this and the player camera.
extends Camera2D
class_name DebugCamera


@export var pan_speed: float = 1.0

@export var min_zoom: float = 0.05
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.1


var dragging: bool = false
var last_mouse_position: Vector2

@export var keyboard_speed: float = 800.0


func _process(delta: float) -> void:
	var movement := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		movement.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		movement.y += 1.0

	if Input.is_key_pressed(KEY_A):
		movement.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		movement.x += 1.0

	if movement != Vector2.ZERO:
		movement = movement.normalized()

		global_position += (
			movement
			* keyboard_speed
			* delta
			/ zoom.x
		)

func _ready() -> void:
	enabled = true

	zoom = Vector2(0.2, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)

	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(
	event: InputEventMouseButton
) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		dragging = event.pressed

		if dragging:
			last_mouse_position = event.position

		return

	if (
		event.button_index == MOUSE_BUTTON_WHEEL_UP
		and event.pressed
	):
		_change_zoom(zoom_step)

	elif (
		event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		and event.pressed
	):
		_change_zoom(-zoom_step)


func _handle_mouse_motion(
	event: InputEventMouseMotion
) -> void:
	if not dragging:
		return

	var mouse_delta := (
		event.position - last_mouse_position
	)

	global_position -= (
		mouse_delta
		/ zoom.x
		* pan_speed
	)

	last_mouse_position = event.position


func _change_zoom(amount: float) -> void:
	var new_zoom := clampf(
		zoom.x + amount,
		min_zoom,
		max_zoom
	)

	zoom = Vector2(
		new_zoom,
		new_zoom
	)
