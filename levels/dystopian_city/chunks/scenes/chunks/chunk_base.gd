extends Node2D
class_name Chunk


enum ChunkType {
	START,
	ROOM,
	CORRIDOR
}


@export_category("Generation")
@export var chunk_type: ChunkType = ChunkType.ROOM
@export var generation_weight: float = 1.0


@onready var sockets: Node2D = $Sockets
@onready var generation_bounds: ReferenceRect = $GenerationBounds


func get_sockets() -> Array[ChunkSocket]:
	var result: Array[ChunkSocket] = []

	for child in sockets.get_children():
		if child is ChunkSocket:
			result.append(child)

	return result


func get_available_sockets() -> Array[ChunkSocket]:
	var result: Array[ChunkSocket] = []

	for socket in get_sockets():
		if not socket.is_used:
			result.append(socket)

	return result


func get_local_bounds() -> Rect2:
	return Rect2(
		generation_bounds.position,
		generation_bounds.size
	)


func get_world_bounds() -> Rect2:
	var local_bounds := get_local_bounds()

	return Rect2(
		global_position + local_bounds.position,
		local_bounds.size
	)
