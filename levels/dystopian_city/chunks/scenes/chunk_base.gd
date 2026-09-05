extends Node2D

@onready var sockets: Node2D = $Sockets


func get_sockets() -> Array[Node]:
	return sockets.get_children()


func get_socket_direction(socket: Marker2D) -> String:
	if socket.name.begins_with("Left"):
		return "left"

	if socket.name.begins_with("Right"):
		return "right"

	if socket.name.begins_with("Up"):
		return "up"

	if socket.name.begins_with("Down"):
		return "down"

	return ""
