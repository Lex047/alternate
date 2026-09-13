extends Node2D
class_name LevelGenerator


enum PlacementKind {
	GROWTH,
	HORIZONTAL_CORRIDOR,
	VERTICAL_CORRIDOR,
	TERMINAL,
}


@export_category("Generation")

@export var start_chunk_scene: PackedScene

@export var chunk_scenes: Array[PackedScene] = []

@export var horizontal_corridor_scenes: Array[PackedScene] = []
@export var vertical_corridor_scenes: Array[PackedScene] = []

@export var terminal_chunk_scenes: Array[PackedScene] = []

@export_range(1, 100, 1)
var chunk_count: int = 8

# First half = expansion.
# Second half = tapering.
@export_range(0.0, 1.0, 0.05)
var terminal_start_ratio: float = 0.5

@export_range(1, 100, 1)
var max_generation_attempts: int = 20

@export_range(0.0, 8.0, 1.0)
var bounds_overlap_tolerance: float = 4.0


@onready var generated_chunks: Node2D = $GeneratedChunks


var placed_chunks: Array[Chunk] = []

# Only actual growth rooms count toward chunk_count.
var normal_chunks_placed: int = 0

# Structural connector chunks do not count.
var horizontal_corridors_placed: int = 0
var vertical_corridors_placed: int = 0

var terminals_placed: int = 0


# Key:
#	scene.resource_path
#
# Value:
#	how many times that scene was accepted
#	into the current generated level.
var chunk_usage: Dictionary = {}


func _ready() -> void:
	generate_level()


# ==================================================
# GENERATION
# ==================================================


func generate_level() -> void:
	if not _configuration_is_valid():
		return

	for attempt in range(
		1,
		max_generation_attempts + 1
	):
		_begin_generation_attempt()

		_generate_attempt()

		if _generation_is_complete():
			_print_generation_result(attempt)
			return

	push_warning(
		"LevelGenerator: Could not generate a complete "
		+ "level after "
		+ str(max_generation_attempts)
		+ " attempts."
	)

	_print_generation_result(
		max_generation_attempts
	)


func _configuration_is_valid() -> bool:
	if not start_chunk_scene:
		push_error(
			"LevelGenerator: Start chunk is missing."
		)
		return false

	if chunk_scenes.is_empty():
		push_error(
			"LevelGenerator: No growth chunks assigned."
		)
		return false

	if horizontal_corridor_scenes.is_empty():
		push_error(
			"LevelGenerator: No horizontal corridors assigned."
		)
		return false

	if vertical_corridor_scenes.is_empty():
		push_error(
			"LevelGenerator: No vertical corridors assigned."
		)
		return false

	if terminal_chunk_scenes.is_empty():
		push_error(
			"LevelGenerator: No terminal chunks assigned."
		)
		return false

	return true


func _begin_generation_attempt() -> void:
	_clear_generated_chunks()

	placed_chunks.clear()

	normal_chunks_placed = 0

	horizontal_corridors_placed = 0
	vertical_corridors_placed = 0

	terminals_placed = 0

	_initialize_chunk_usage()


func _generate_attempt() -> void:
	var start_chunk := _spawn_chunk(
		start_chunk_scene,
		Vector2.ZERO
	)

	if not start_chunk:
		return

	placed_chunks.append(start_chunk)

	# Breadth-first generation.
	#
	# All sockets of one chunk are handled before
	# moving deeper into newly created chunks.
	var chunks_to_process: Array[Chunk] = []
	chunks_to_process.append(start_chunk)

	while not chunks_to_process.is_empty():
		var current_chunk: Chunk = (
			chunks_to_process.pop_front()
		)

		var created_chunks := _process_chunk_sockets(
			current_chunk
		)

		for chunk in created_chunks:
			if (
				chunk.chunk_type
				!= Chunk.ChunkType.TERMINAL
			):
				chunks_to_process.append(chunk)

	# Retry anything still open.
	_resolve_remaining_sockets()


func _generation_is_complete() -> bool:
	return (
		normal_chunks_placed == chunk_count
		and _count_open_sockets() == 0
	)


# ==================================================
# CHUNK PROCESSING
# ==================================================


func _process_chunk_sockets(
	current_chunk: Chunk
) -> Array[Chunk]:
	var created_chunks: Array[Chunk] = []

	var available_sockets := (
		current_chunk.get_available_sockets()
	)

	available_sockets.shuffle()

	for target_socket in available_sockets:
		if target_socket.is_used:
			continue

		var new_chunk := _try_fill_socket(
			current_chunk,
			target_socket
		)

		if new_chunk:
			created_chunks.append(new_chunk)

	return created_chunks


func _try_fill_socket(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> Chunk:
	# ------------------------------------------------
	# STRUCTURAL CORRIDOR
	# ------------------------------------------------
	#
	# Any ROOM/START horizontal opening must first
	# receive a horizontal corridor.
	#
	# Any ROOM/START vertical opening must first
	# receive a vertical corridor.
	#
	# Corridors themselves do not receive another
	# corridor.

	var required_corridor := (
		_get_required_corridor_kind(
			current_chunk,
			target_socket
		)
	)

	if (
		required_corridor
		== PlacementKind.HORIZONTAL_CORRIDOR
	):
		return _try_place_from_scenes(
			current_chunk,
			target_socket,
			horizontal_corridor_scenes,
			PlacementKind.HORIZONTAL_CORRIDOR
		)

	if (
		required_corridor
		== PlacementKind.VERTICAL_CORRIDOR
	):
		return _try_place_from_scenes(
			current_chunk,
			target_socket,
			vertical_corridor_scenes,
			PlacementKind.VERTICAL_CORRIDOR
		)

	# ------------------------------------------------
	# We are now at the EXIT of a connector corridor.
	#
	# This is where we decide whether this branch
	# continues or terminates.
	# ------------------------------------------------

	if normal_chunks_placed >= chunk_count:
		return _try_place_from_scenes(
			current_chunk,
			target_socket,
			terminal_chunk_scenes,
			PlacementKind.TERMINAL
		)

	# ------------------------------------------------
	# FIRST HALF — EXPANSION
	# ------------------------------------------------
	#
	# No terminals.
	# Every branch tries to continue growing.

	if normal_chunks_placed < _get_terminal_start_count():
		return _try_place_from_scenes(
			current_chunk,
			target_socket,
			chunk_scenes,
			PlacementKind.GROWTH
		)

	# ------------------------------------------------
	# SECOND HALF — TAPERING
	# ------------------------------------------------
	#
	# If we already have enough open branches to reach
	# the remaining growth target, terminate this one.
	#
	# Otherwise continue growing.

	if _should_continue_growth():
		var growth_chunk := _try_place_from_scenes(
			current_chunk,
			target_socket,
			chunk_scenes,
			PlacementKind.GROWTH
		)

		if growth_chunk:
			return growth_chunk

		# Growth failed physically.
		# Terminal is allowed in the taper phase.
		return _try_place_from_scenes(
			current_chunk,
			target_socket,
			terminal_chunk_scenes,
			PlacementKind.TERMINAL
		)

	# We have surplus branches.
	# Prefer closing this one.
	var terminal_chunk := _try_place_from_scenes(
		current_chunk,
		target_socket,
		terminal_chunk_scenes,
		PlacementKind.TERMINAL
	)

	if terminal_chunk:
		return terminal_chunk

	# If the terminal physically cannot fit, trying
	# growth is better than simply abandoning the
	# socket.
	return _try_place_from_scenes(
		current_chunk,
		target_socket,
		chunk_scenes,
		PlacementKind.GROWTH
	)


func _should_continue_growth() -> bool:
	var remaining_growth := (
		chunk_count - normal_chunks_placed
	)

	if remaining_growth <= 0:
		return false

	var open_branches := _count_open_sockets()

	# Example:
	#
	# 3 growth chunks still needed
	# 6 open branches available
	#
	# -> we can safely terminate some branches.
	#
	# But:
	#
	# 3 growth chunks still needed
	# 2 open branches available
	#
	# -> this branch must continue growing.

	return open_branches <= remaining_growth


# ==================================================
# PLACEMENT
# ==================================================


func _try_place_from_scenes(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	scenes: Array[PackedScene],
	placement_kind: int
) -> Chunk:
	var candidate_scenes := (
		_get_usage_prioritized_scenes(scenes)
	)

	for scene in candidate_scenes:
		var candidate := _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not candidate:
			continue

		if not _scene_matches_placement_kind(
			candidate,
			placement_kind
		):
			_discard_chunk(candidate)
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			candidate
		):
			_discard_chunk(candidate)
			continue

		var matching_sockets := (
			_find_matching_sockets(
				candidate,
				target_socket
			)
		)

		if matching_sockets.is_empty():
			_discard_chunk(candidate)
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

			# Temporarily complete the connection.
			target_socket.is_used = true
			matching_socket.is_used = true

			var projected_normal_count := (
				normal_chunks_placed
			)

			if (
				placement_kind
				== PlacementKind.GROWTH
			):
				projected_normal_count += 1

			var occupied_chunks := (
				_copy_chunk_array(placed_chunks)
			)

			occupied_chunks.append(candidate)

			# --------------------------------------
			# LOCAL ONE-STEP VIABILITY
			# --------------------------------------
			#
			# We only test sockets belonging to the
			# NEW candidate.
			#
			# An unrelated bad socket elsewhere no
			# longer prevents valid placements.

			var placement_is_valid := true

			if (
				placement_kind
				!= PlacementKind.TERMINAL
			):
				placement_is_valid = (
					_candidate_sockets_are_viable(
						candidate,
						occupied_chunks,
						projected_normal_count
					)
				)

			if not placement_is_valid:
				target_socket.is_used = false
				matching_socket.is_used = false
				continue

			# --------------------------------------
			# ACCEPT
			# --------------------------------------

			placed_chunks.append(candidate)

			match placement_kind:
				PlacementKind.GROWTH:
					normal_chunks_placed += 1

				PlacementKind.HORIZONTAL_CORRIDOR:
					horizontal_corridors_placed += 1

				PlacementKind.VERTICAL_CORRIDOR:
					vertical_corridors_placed += 1

				PlacementKind.TERMINAL:
					terminals_placed += 1

			_record_chunk_usage(scene)

			return candidate

		_discard_chunk(candidate)

	return null


func _scene_matches_placement_kind(
	chunk: Chunk,
	placement_kind: int
) -> bool:
	match placement_kind:
		PlacementKind.GROWTH:
			# Structural corridors now live in their
			# own pools.
			return (
				chunk.chunk_type
					== Chunk.ChunkType.ROOM
			)

		PlacementKind.HORIZONTAL_CORRIDOR:
			return (
				chunk.chunk_type
					== Chunk.ChunkType.CORRIDOR
			)

		PlacementKind.VERTICAL_CORRIDOR:
			return (
				chunk.chunk_type
					== Chunk.ChunkType.CORRIDOR
			)

		PlacementKind.TERMINAL:
			return (
				chunk.chunk_type
					== Chunk.ChunkType.TERMINAL
			)

	return false


# ==================================================
# LOCAL ONE-STEP VIABILITY
# ==================================================


func _candidate_sockets_are_viable(
	candidate: Chunk,
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> bool:
	for socket in candidate.get_available_sockets():
		# Connector corridor:
		#
		# Its remaining exit must have somewhere
		# meaningful to go.
		if (
			candidate.chunk_type
				== Chunk.ChunkType.CORRIDOR
		):
			if not _corridor_exit_is_viable(
				candidate,
				socket,
				occupied_chunks,
				projected_normal_count
			):
				return false

			continue

		# Growth room:
		#
		# Every open socket must at least have enough
		# physical room for the required connector.
		var required_corridor := (
			_get_required_corridor_kind(
				candidate,
				socket
			)
		)

		if (
			required_corridor
				== PlacementKind.HORIZONTAL_CORRIDOR
		):
			if not _socket_can_fit_scene_pool(
				candidate,
				socket,
				horizontal_corridor_scenes,
				occupied_chunks,
				PlacementKind.HORIZONTAL_CORRIDOR
			):
				return false

		elif (
			required_corridor
				== PlacementKind.VERTICAL_CORRIDOR
		):
			if not _socket_can_fit_scene_pool(
				candidate,
				socket,
				vertical_corridor_scenes,
				occupied_chunks,
				PlacementKind.VERTICAL_CORRIDOR
			):
				return false

	return true


func _corridor_exit_is_viable(
	corridor: Chunk,
	target_socket: ChunkSocket,
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> bool:
	# First half:
	# corridor must be able to continue into a room.
	if (
		projected_normal_count
		< _get_terminal_start_count()
	):
		return _socket_can_fit_scene_pool(
			corridor,
			target_socket,
			chunk_scenes,
			occupied_chunks,
			PlacementKind.GROWTH
		)

	# Second half:
	# either growth OR terminal is a legal future.
	if projected_normal_count < chunk_count:
		if _socket_can_fit_scene_pool(
			corridor,
			target_socket,
			chunk_scenes,
			occupied_chunks,
			PlacementKind.GROWTH
		):
			return true

		return _socket_can_fit_scene_pool(
			corridor,
			target_socket,
			terminal_chunk_scenes,
			occupied_chunks,
			PlacementKind.TERMINAL
		)

	# Target reached:
	# corridor must actually be terminatable.
	return _socket_can_fit_scene_pool(
		corridor,
		target_socket,
		terminal_chunk_scenes,
		occupied_chunks,
		PlacementKind.TERMINAL
	)


func _socket_can_fit_scene_pool(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	scenes: Array[PackedScene],
	occupied_chunks: Array[Chunk],
	placement_kind: int
) -> bool:
	for scene in scenes:
		var test_chunk := _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not test_chunk:
			continue

		if not _scene_matches_placement_kind(
			test_chunk,
			placement_kind
		):
			_discard_chunk(test_chunk)
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			test_chunk
		):
			_discard_chunk(test_chunk)
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
				_discard_chunk(test_chunk)
				return true

		_discard_chunk(test_chunk)

	return false


# ==================================================
# CORRIDOR GRAMMAR
# ==================================================


func _get_required_corridor_kind(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> int:
	# A connector never receives another connector.
	if (
		current_chunk.chunk_type
			== Chunk.ChunkType.CORRIDOR
	):
		return -1

	if _is_horizontal_direction(
		target_socket.direction
	):
		return PlacementKind.HORIZONTAL_CORRIDOR

	if _is_vertical_direction(
		target_socket.direction
	):
		return PlacementKind.VERTICAL_CORRIDOR

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


# ==================================================
# PHASE / TERMINAL RULES
# ==================================================


func _get_terminal_start_count() -> int:
	return int(
		ceil(
			float(chunk_count)
			* terminal_start_ratio
		)
	)


# ==================================================
# CHUNK TYPE RULES
# ==================================================


func _chunk_types_can_connect(
	first_chunk: Chunk,
	second_chunk: Chunk
) -> bool:
	# Structural corridor -> structural corridor
	# is never allowed.
	if (
		first_chunk.chunk_type
			== Chunk.ChunkType.CORRIDOR
		and second_chunk.chunk_type
			== Chunk.ChunkType.CORRIDOR
	):
		return false

	return true


# ==================================================
# SOCKET MATCHING
# ==================================================


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


# ==================================================
# POSITIONING / OVERLAP
# ==================================================


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


# ==================================================
# USAGE BALANCING
# ==================================================


func _initialize_chunk_usage() -> void:
	chunk_usage.clear()

	_register_scene_usage_pool(
		chunk_scenes
	)

	_register_scene_usage_pool(
		horizontal_corridor_scenes
	)

	_register_scene_usage_pool(
		vertical_corridor_scenes
	)

	_register_scene_usage_pool(
		terminal_chunk_scenes
	)


func _register_scene_usage_pool(
	scenes: Array[PackedScene]
) -> void:
	for scene in scenes:
		var path := scene.resource_path

		if not chunk_usage.has(path):
			chunk_usage[path] = 0


func _record_chunk_usage(
	scene: PackedScene
) -> void:
	var path := scene.resource_path

	chunk_usage[path] = (
		_get_scene_usage(scene) + 1
	)


func _get_scene_usage(
	scene: PackedScene
) -> int:
	return chunk_usage.get(
		scene.resource_path,
		0
	)


func _get_usage_prioritized_scenes(
	scenes: Array[PackedScene]
) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var usage_levels: Array[int] = []

	for scene in scenes:
		var usage := _get_scene_usage(scene)

		if not usage_levels.has(usage):
			usage_levels.append(usage)

	usage_levels.sort()

	for usage in usage_levels:
		var usage_group: Array[PackedScene] = []

		for scene in scenes:
			if _get_scene_usage(scene) == usage:
				usage_group.append(scene)

		# Same usage count remains random.
		usage_group.shuffle()

		for scene in usage_group:
			result.append(scene)

	return result


# ==================================================
# FINAL RESOLUTION
# ==================================================


func _resolve_remaining_sockets() -> void:
	while true:
		var made_progress := false

		var chunks_to_check := (
			_copy_chunk_array(placed_chunks)
		)

		for chunk in chunks_to_check:
			var open_sockets := (
				chunk.get_available_sockets()
			)

			for socket in open_sockets:
				if socket.is_used:
					continue

				var new_chunk := _try_fill_socket(
					chunk,
					socket
				)

				if new_chunk:
					made_progress = true

		if not made_progress:
			break


# ==================================================
# SPAWNING / CLEANUP
# ==================================================


func _spawn_chunk(
	scene: PackedScene,
	spawn_position: Vector2
) -> Chunk:
	var instance := scene.instantiate()

	if not instance is Chunk:
		push_error(
			"Generated scene is not a Chunk."
		)
		instance.free()
		return null

	var chunk := instance as Chunk

	generated_chunks.add_child(chunk)

	chunk.global_position = spawn_position

	return chunk


func _discard_chunk(
	chunk: Chunk
) -> void:
	if is_instance_valid(chunk):
		chunk.free()


func _clear_generated_chunks() -> void:
	for child in generated_chunks.get_children():
		child.free()


func _copy_chunk_array(
	source: Array[Chunk]
) -> Array[Chunk]:
	var result: Array[Chunk] = []

	for chunk in source:
		result.append(chunk)

	return result


# ==================================================
# DEBUG OUTPUT
# ==================================================


func _count_open_sockets() -> int:
	var count := 0

	for chunk in placed_chunks:
		count += (
			chunk.get_available_sockets().size()
		)

	return count


func _print_generation_result(
	attempt: int
) -> void:
	var unresolved := _count_open_sockets()

	print(
		"Generation attempt: ",
		attempt,
		" | Growth chunks: ",
		normal_chunks_placed,
		" / ",
		chunk_count,
		" | Horizontal corridors: ",
		horizontal_corridors_placed,
		" | Vertical corridors: ",
		vertical_corridors_placed,
		" | Terminals: ",
		terminals_placed,
		" | Total chunks: ",
		placed_chunks.size(),
		" | Unresolved sockets: ",
		unresolved
	)

	print("Growth chunk usage:")

	for scene in chunk_scenes:
		print(
			"  ",
			scene.resource_path.get_file(),
			": ",
			_get_scene_usage(scene)
		)

	if unresolved > 0:
		_print_unresolved_sockets()


func _print_unresolved_sockets() -> void:
	for chunk in placed_chunks:
		for socket in chunk.get_available_sockets():
			print(
				"UNRESOLVED | Chunk: ",
				chunk.name,
				" | Type: ",
				Chunk.ChunkType.keys()[
					chunk.chunk_type
				],
				" | Direction: ",
				ChunkSocket.Direction.keys()[
					socket.direction
				],
				" | Position: ",
				socket.global_position
			)
