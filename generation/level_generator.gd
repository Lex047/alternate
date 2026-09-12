extends Node2D
class_name LevelGenerator


@export_category("Generation")
@export var start_chunk_scene: PackedScene
@export var chunk_scenes: Array[PackedScene] = []
@export var chunk_count: int = 5


@onready var generated_chunks: Node2D = $GeneratedChunks


var placed_chunks: Array[Chunk] = []


func _ready() -> void:
	generate_level()


func generate_level() -> void:
	if not start_chunk_scene:
		push_error("LevelGenerator: Start chunk is missing.")
		return

	if chunk_scenes.is_empty():
		push_error("LevelGenerator: No generation chunks assigned.")
		return

	var start_chunk := _spawn_chunk(
		start_chunk_scene,
		Vector2.ZERO
	)

	if not start_chunk:
		return

	placed_chunks.append(start_chunk)

	var current_chunk: Chunk = start_chunk

	for i in range(chunk_count):
		var next_chunk := _try_add_chunk(current_chunk)

		if not next_chunk:
			print("Generation stopped at chunk ", i)
			break

		current_chunk = next_chunk


func _spawn_chunk(
	scene: PackedScene,
	spawn_position: Vector2
) -> Chunk:
	var instance := scene.instantiate()

	if not instance is Chunk:
		push_error("Generated scene is not a Chunk.")
		instance.queue_free()
		return null

	var chunk := instance as Chunk

	generated_chunks.add_child(chunk)
	chunk.global_position = spawn_position

	return chunk


func _try_add_chunk(
	current_chunk: Chunk
) -> Chunk:
	var available_sockets := (
		current_chunk.get_available_sockets()
	)

	if available_sockets.is_empty():
		return null

	available_sockets.shuffle()

	for target_socket in available_sockets:
		var scenes := chunk_scenes.duplicate()
		scenes.shuffle()

		for scene in scenes:
			var candidate := _spawn_chunk(
				scene,
				Vector2.ZERO
			)

			if not candidate:
				continue

			# Prevent corridors from connecting directly
			# to other corridors.
			if (
				current_chunk.chunk_type
				== Chunk.ChunkType.CORRIDOR
				and candidate.chunk_type
				== Chunk.ChunkType.CORRIDOR
			):
				candidate.queue_free()
				continue

			var matching_socket := _find_matching_socket(
				candidate,
				target_socket
			)

			if not matching_socket:
				candidate.queue_free()
				continue

			_align_chunk(
				candidate,
				matching_socket,
				target_socket
			)

			if _overlaps_existing_chunks(candidate):
				candidate.queue_free()
				continue

			target_socket.is_used = true
			matching_socket.is_used = true

			placed_chunks.append(candidate)

			return candidate

	return null


func _find_matching_socket(
	chunk: Chunk,
	target_socket: ChunkSocket
) -> ChunkSocket:
	var sockets := chunk.get_available_sockets()
	sockets.shuffle()

	for socket in sockets:
		if _directions_match(
			target_socket.direction,
			socket.direction
		):
			return socket

	return null


func _directions_match(
	first: ChunkSocket.Direction,
	second: ChunkSocket.Direction
) -> bool:
	return (
		first == ChunkSocket.Direction.LEFT
		and second == ChunkSocket.Direction.RIGHT
	) or (
		first == ChunkSocket.Direction.RIGHT
		and second == ChunkSocket.Direction.LEFT
	) or (
		first == ChunkSocket.Direction.UP
		and second == ChunkSocket.Direction.DOWN
	) or (
		first == ChunkSocket.Direction.DOWN
		and second == ChunkSocket.Direction.UP
	)


func _align_chunk(
	chunk: Chunk,
	chunk_socket: ChunkSocket,
	target_socket: ChunkSocket
) -> void:
	var offset := (
		target_socket.global_position
		- chunk_socket.global_position
	)

	chunk.global_position += offset


func _overlaps_existing_chunks(
	candidate: Chunk
) -> bool:
	var candidate_bounds := candidate.get_world_bounds()

	for chunk in placed_chunks:
		if candidate_bounds.intersects(
			chunk.get_world_bounds()
		):
			return true

	return false
