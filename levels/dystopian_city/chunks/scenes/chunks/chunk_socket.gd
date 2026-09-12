@tool
extends Marker2D
class_name ChunkSocket

enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN
}

@export var direction: Direction
var is_used: bool = false

var socket_gizmo_size: float = 8.0:
	set(value):
		socket_gizmo_size = value
		gizmo_extents = value

func _ready() -> void:
	gizmo_extents = socket_gizmo_size
