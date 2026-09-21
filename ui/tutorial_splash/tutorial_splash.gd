extends CanvasLayer
class_name TutorialSplash


signal dismissed


var is_open: bool = false
var can_dismiss: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	hide()


func show_splash() -> void:
	is_open = true
	can_dismiss = false

	show()

	get_tree().paused = true

	await get_tree().create_timer(
		0.2,
		true
	).timeout

	can_dismiss = true


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if not can_dismiss:
		return

	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
	):
		get_viewport().set_input_as_handled()
		_dismiss()


func _dismiss() -> void:
	if not is_open:
		return

	is_open = false
	can_dismiss = false

	ProgressManager.mark_tutorial_seen()

	hide()

	get_tree().paused = false

	dismissed.emit()
