extends Node2D
class_name LevelGenerator


@export_category("Generation")
@export var start_chunk_scene: PackedScene

@export var chunk_scenes: Array[PackedScene] = []
@export var terminal_chunk_scenes: Array[PackedScene] = []

@export var chunk_count: int = 10

@export_range(0.0, 1.0, 0.05)
var terminal_start_ratio: float = 0.5

@export_range(0.0, 8.0, 1.0)
var bounds_overlap_tolerance: float = 4.0


@onready var generated_chunks: Node2D = $GeneratedChunks


var placed_chunks: Array[Chunk] = []

# Does not include the start chunk or terminal chunks.
var normal_chunks_placed: int = 0


func _ready() -> void:
	generate_level()


func generate_level() -> void:
	if not start_chunk_scene:
		push_error(
			"LevelGenerator: Start chunk is missing."
		)
		return

	if chunk_scenes.is_empty():
		push_error(
			"LevelGenerator: No normal generation chunks assigned."
		)
		return

	var start_chunk := _spawn_chunk(
		start_chunk_scene,
		Vector2.ZERO
	)

	if not start_chunk:
		return

	placed_chunks.append(start_chunk)

	# This queue gives us breadth-first generation.
	var chunks_to_process: Array[Chunk] = []
	chunks_to_process.append(start_chunk)

	while not chunks_to_process.is_empty():
		var current_chunk: Chunk = (
			chunks_to_process.pop_front()
		)

		var new_chunks := _process_chunk_sockets(
			current_chunk
		)

		for chunk in new_chunks:
			if chunk.chunk_type != Chunk.ChunkType.TERMINAL:
				chunks_to_process.append(chunk)

	_print_generation_result()


func _process_chunk_sockets(
	current_chunk: Chunk
) -> Array[Chunk]:
	var created_chunks: Array[Chunk] = []

	var available_sockets := (
		current_chunk.get_available_sockets()
	)

	available_sockets.shuffle()

	# We attempt EVERY socket on this chunk before moving to another chunk.
	for target_socket in available_sockets:
		if target_socket.is_used:
			continue

		var new_chunk := _try_fill_socket(
			current_chunk,
			target_socket
		)

		if new_chunk:
			created_chunks.append(new_chunk)
		else:
			push_warning(
				"Could not resolve socket on chunk: "
				+ current_chunk.name
			)

	return created_chunks


func _try_fill_socket(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> Chunk:
	var scenes := _get_candidate_scenes(
		normal_chunks_placed
	)

	if scenes.is_empty():
		return null

	scenes.shuffle()

	for scene in scenes:
		var candidate := _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not candidate:
			continue

		# Existing rule:
		# corridor cannot connect directly to corridor.
		if not _chunk_types_can_connect(
			current_chunk,
			candidate
		):
			candidate.queue_free()
			continue

		var matching_sockets := (
			_find_matching_sockets(
				candidate,
				target_socket
			)
		)

		if matching_sockets.is_empty():
			candidate.queue_free()
			continue

		matching_sockets.shuffle()

		for matching_socket in matching_sockets:
			_align_chunk(
				candidate,
				matching_socket,
				target_socket
			)

			if _overlaps_chunks(
				candidate,
				placed_chunks
			):
				continue

			# Temporarily treat this connection
			# as completed while we test whether the resulting level is still viable.
			target_socket.is_used = true
			matching_socket.is_used = true

			var projected_normal_count := (
				normal_chunks_placed
			)

			if (
				candidate.chunk_type
				!= Chunk.ChunkType.TERMINAL
			):
				projected_normal_count += 1

			var occupied_chunks: Array[Chunk] = []

			for chunk in placed_chunks:
				occupied_chunks.append(chunk)

			occupied_chunks.append(candidate)

			var level_still_viable := (
				_all_open_sockets_are_viable(
					occupied_chunks,
					projected_normal_count
				)
			)

			if not level_still_viable:
				target_socket.is_used = false
				matching_socket.is_used = false
				continue

			# Candidate is valid.
			placed_chunks.append(candidate)

			if (
				candidate.chunk_type
				!= Chunk.ChunkType.TERMINAL
			):
				normal_chunks_placed += 1

			return candidate

		candidate.queue_free()

	return null


func _get_candidate_scenes(
	current_normal_count: int
) -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []

	var terminal_start_count := int(
		ceil(
			float(chunk_count)
			* terminal_start_ratio
		)
	)

	# First half:
	# only rooms/corridors.
	if current_normal_count < terminal_start_count:
		for scene in chunk_scenes:
			scenes.append(scene)

		return scenes

	# Second half:
	# rooms/corridors AND terminals are legal.
	if current_normal_count < chunk_count:
		for scene in chunk_scenes:
			scenes.append(scene)

		for scene in terminal_chunk_scenes:
			scenes.append(scene)

		return scenes

	# Target reached:
	# stop growing the dungeon.
	# Remaining openings must terminate.
	for scene in terminal_chunk_scenes:
		scenes.append(scene)

	return scenes


func _chunk_types_can_connect(
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


func _find_matching_sockets(
	chunk: Chunk,
	target_socket: ChunkSocket
) -> Array[ChunkSocket]:
	var result: Array[ChunkSocket] = []

	for socket in chunk.get_available_sockets():
		if _directions_match(
			target_socket.direction,
			socket.direction
		):
			result.append(socket)

	return result


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


func _overlaps_chunks(
	candidate: Chunk,
	occupied_chunks: Array[Chunk]
) -> bool:
	var candidate_bounds := (
		candidate.get_world_bounds()
	)

	# Allows a tiny amount of accidental
	# GenerationBounds overlap.
	if bounds_overlap_tolerance > 0.0:
		candidate_bounds = candidate_bounds.grow(
			-bounds_overlap_tolerance
		)

	for chunk in occupied_chunks:
		if candidate_bounds.intersects(
			chunk.get_world_bounds()
		):
			return true

	return false


func _all_open_sockets_are_viable(
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> bool:
	# This is the one-step lookahead.
	#
	# Every currently open socket must have
	# at least ONE possible future chunk.
	for chunk in occupied_chunks:
		for socket in chunk.get_available_sockets():
			if not _socket_has_valid_attachment(
				chunk,
				socket,
				occupied_chunks,
				projected_normal_count
			):
				return false

	return true


func _socket_has_valid_attachment(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> bool:
	var scenes := _get_candidate_scenes(
		projected_normal_count
	)

	for scene in scenes:
		var test_chunk := _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not test_chunk:
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			test_chunk
		):
			test_chunk.queue_free()
			continue

		var matching_sockets := (
			_find_matching_sockets(
				test_chunk,
				target_socket
			)
		)

		for matching_socket in matching_sockets:
			_align_chunk(
				test_chunk,
				matching_socket,
				target_socket
			)

			if not _overlaps_chunks(
				test_chunk,
				occupied_chunks
			):
				test_chunk.queue_free()
				return true

		test_chunk.queue_free()

	return false


func _spawn_chunk(
	scene: PackedScene,
	spawn_position: Vector2
) -> Chunk:
	var instance := scene.instantiate()

	if not instance is Chunk:
		push_error(
			"Generated scene is not a Chunk."
		)
		instance.queue_free()
		return null

	var chunk := instance as Chunk

	generated_chunks.add_child(chunk)
	chunk.global_position = spawn_position

	return chunk


func _count_open_sockets() -> int:
	var count := 0

	for chunk in placed_chunks:
		count += (
			chunk.get_available_sockets().size()
		)

	return count


func _print_generation_result() -> void:
	print(
		"Generation finished. Normal chunks: ",
		normal_chunks_placed,
		" | Total chunks: ",
		placed_chunks.size(),
		" | Unresolved sockets: ",
		_count_open_sockets()
	)
