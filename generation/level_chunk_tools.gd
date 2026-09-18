extends RefCounted
class_name LevelChunkTools


var context: LevelGenerationContext


func _init(
	generation_context: LevelGenerationContext
) -> void:
	context = generation_context


func spawn_chunk(
	scene: PackedScene,
	spawn_position: Vector2
) -> Chunk:
	var instance: Node = scene.instantiate()

	if not instance is Chunk:
		push_error(
			"Generated scene is not a Chunk."
		)
		instance.free()
		return null

	var chunk: Chunk = instance as Chunk

	context.generated_chunks.add_child(chunk)
	chunk.global_position = spawn_position

	return chunk


func discard_chunk(
	chunk: Chunk
) -> void:
	if is_instance_valid(chunk):
		chunk.free()


func clear_generated_chunks() -> void:
	for child: Node in context.generated_chunks.get_children():
		child.free()


func copy_chunk_array(
	source: Array[Chunk]
) -> Array[Chunk]:
	var result: Array[Chunk] = []

	for chunk: Chunk in source:
		result.append(chunk)

	return result


func count_open_sockets(
	chunks: Array[Chunk]
) -> int:
	var count: int = 0

	for chunk: Chunk in chunks:
		count += (
			chunk.get_available_sockets().size()
		)

	return count


func capture_open_sockets(
	chunks: Array[Chunk]
) -> Array[ChunkSocket]:
	var result: Array[ChunkSocket] = []

	for chunk: Chunk in chunks:
		for socket: ChunkSocket in (
			chunk.get_available_sockets()
		):
			result.append(socket)

	return result


func scene_matches_placement_kind(
	chunk: Chunk,
	placement_kind: int
) -> bool:
	match placement_kind:
		LevelGenerationTypes.PlacementKind.GROWTH:
			return (
				chunk.chunk_type
				== Chunk.ChunkType.ROOM
			)

		LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR:
			return (
				chunk.chunk_type
				== Chunk.ChunkType.CORRIDOR
			)

		LevelGenerationTypes.PlacementKind.VERTICAL_CORRIDOR:
			return (
				chunk.chunk_type
				== Chunk.ChunkType.CORRIDOR
			)

		LevelGenerationTypes.PlacementKind.TERMINAL:
			return (
				chunk.chunk_type
				== Chunk.ChunkType.TERMINAL
			)

	return false


func get_required_corridor_kind(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> int:
	if (
		current_chunk.chunk_type
		== Chunk.ChunkType.CORRIDOR
	):
		return -1

	if _is_horizontal_direction(
		target_socket.direction
	):
		return LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR

	if _is_vertical_direction(
		target_socket.direction
	):
		return LevelGenerationTypes.PlacementKind.VERTICAL_CORRIDOR

	return -1


func _is_horizontal_direction(
	direction: ChunkSocket.Direction
) -> bool:
	return (
		direction == ChunkSocket.Direction.LEFT
		or direction == ChunkSocket.Direction.RIGHT
	)


func _is_vertical_direction(
	direction: ChunkSocket.Direction
) -> bool:
	return (
		direction == ChunkSocket.Direction.UP
		or direction == ChunkSocket.Direction.DOWN
	)


func chunk_types_can_connect(
	first_chunk: Chunk,
	second_chunk: Chunk
) -> bool:
	if (
		first_chunk.chunk_type
		== Chunk.ChunkType.CORRIDOR
		and second_chunk.chunk_type
		== Chunk.ChunkType.CORRIDOR
	):
		return false

	return true


func find_matching_sockets(
	chunk: Chunk,
	target_socket: ChunkSocket
) -> Array[ChunkSocket]:
	var result: Array[ChunkSocket] = []

	for socket: ChunkSocket in (
		chunk.get_available_sockets()
	):
		if directions_match(
			target_socket.direction,
			socket.direction
		):
			result.append(socket)

	return result


func directions_match(
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


func align_chunk(
	chunk: Chunk,
	chunk_socket: ChunkSocket,
	target_socket: ChunkSocket
) -> void:
	var offset: Vector2 = (
		target_socket.global_position
		- chunk_socket.global_position
	)

	chunk.global_position += offset


func overlaps_chunks(
	candidate: Chunk,
	occupied_chunks: Array[Chunk]
) -> bool:
	var candidate_bounds: Rect2 = (
		candidate.get_world_bounds()
	)

	if context.bounds_overlap_tolerance > 0.0:
		candidate_bounds = candidate_bounds.grow(
			-context.bounds_overlap_tolerance
		)

	for chunk: Chunk in occupied_chunks:
		if candidate_bounds.intersects(
			chunk.get_world_bounds()
		):
			return true

	return false


func socket_can_fit_scene_pool(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	scenes: Array[PackedScene],
	occupied_chunks: Array[Chunk],
	placement_kind: int
) -> bool:
	for scene: PackedScene in scenes:
		var test_chunk: Chunk = spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not test_chunk:
			continue

		if not scene_matches_placement_kind(
			test_chunk,
			placement_kind
		):
			discard_chunk(test_chunk)
			continue

		if not chunk_types_can_connect(
			current_chunk,
			test_chunk
		):
			discard_chunk(test_chunk)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			find_matching_sockets(
				test_chunk,
				target_socket
			)
		)

		for matching_socket: ChunkSocket in matching_sockets:
			align_chunk(
				test_chunk,
				matching_socket,
				target_socket
			)

			if not overlaps_chunks(
				test_chunk,
				occupied_chunks
			):
				discard_chunk(test_chunk)
				return true

		discard_chunk(test_chunk)

	return false
