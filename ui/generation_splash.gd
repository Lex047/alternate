extends CanvasLayer
class_name GenerationSplash


@onready var overlay: Control = $Overlay
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	overlay.hide()


func show_splash(
	status: String = "GENERATING DISTRICT..."
) -> void:
	status_label.text = status
	overlay.show()


func hide_splash() -> void:
	overlay.hide()


func set_status(
	status: String
) -> void:
	status_label.text = status
