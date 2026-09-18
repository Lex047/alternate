extends RefCounted
class_name LevelClosureSolver


var context: LevelGenerationContext
var rng: LevelGenerationRng
var chunk_usage: LevelChunkUsage
var chunk_tools: LevelChunkTools


func _init(
	generation_context: LevelGenerationContext,
	generation_rng: LevelGenerationRng,
	usage_tracker: LevelChunkUsage,
	level_chunk_tools: LevelChunkTools
) -> void:
	context = generation_context
	rng = generation_rng
	chunk_usage = usage_tracker
	chunk_tools = level_chunk_tools


func resolve_remaining_sockets() -> bool:
	while (
		chunk_tools.count_open_sockets(
			context.placed_chunks
		)
		> 0
	):
		var made_progress: bool = false

		var chunks_to_check: Array[Chunk] = (
			chunk_tools.copy_chunk_array(
				context.placed_chunks
			)
		)

		rng.shuffle(
			chunks_to_check
		)

		for chunk: Chunk in chunks_to_check:
			var open_sockets: Array[ChunkSocket] = (
				chunk.get_available_sockets()
			)

			rng.shuffle(
				open_sockets
			)

			for socket: ChunkSocket in open_sockets:
				if socket.is_used:
					continue

				if try_close_graph_socket(
					chunk,
					socket
				):
					made_progress = true

		if not made_progress:
			return false

	return true


func try_close_graph_socket(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> bool:
	if (
		current_chunk.chunk_type
		== Chunk.ChunkType.TERMINAL
	):
		return false

	if (
		current_chunk.chunk_type
		== Chunk.ChunkType.CORRIDOR
	):
		return _try_place_graph_terminal(
			current_chunk,
			target_socket
		)

	var corridor_kind: int = (
		chunk_tools.get_required_corridor_kind(
			current_chunk,
			target_socket
		)
	)

	if (
		corridor_kind
		== LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR
	):
		return _try_place_graph_closure_corridor(
			current_chunk,
			target_socket,
			context.horizontal_corridor_scenes,
			LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR
		)

	if (
		corridor_kind
		== LevelGenerationTypes.PlacementKind.VERTICAL_CORRIDOR
	):
		return _try_place_graph_closure_corridor(
			current_chunk,
			target_socket,
			context.vertical_corridor_scenes,
			LevelGenerationTypes.PlacementKind.VERTICAL_CORRIDOR
		)

	return false


func _try_place_graph_closure_corridor(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	corridor_scenes: Array[PackedScene],
	corridor_kind: int
) -> bool:
	var candidate_scenes: Array[PackedScene] = (
		chunk_usage.get_prioritized_scenes(
			corridor_scenes
		)
	)

	for scene: PackedScene in candidate_scenes:
		var corridor: Chunk = (
			chunk_tools.spawn_chunk(
				scene,
				Vector2.ZERO
			)
		)

		if not corridor:
			continue

		if not chunk_tools.scene_matches_placement_kind(
			corridor,
			corridor_kind
		):
			chunk_tools.discard_chunk(
				corridor
			)
			continue

		if not chunk_tools.chunk_types_can_connect(
			current_chunk,
			corridor
		):
			chunk_tools.discard_chunk(
				corridor
			)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			chunk_tools.find_matching_sockets(
				corridor,
				target_socket
			)
		)

		rng.shuffle(
			matching_sockets
		)

		for corridor_entrance: ChunkSocket in matching_sockets:
			chunk_tools.align_chunk(
				corridor,
				corridor_entrance,
				target_socket
			)

			if chunk_tools.overlaps_chunks(
				corridor,
				context.placed_chunks
			):
				continue

			target_socket.is_used = true
			corridor_entrance.is_used = true

			var corridor_exits: Array[ChunkSocket] = (
				corridor.get_available_sockets()
			)

			if corridor_exits.size() != 1:
				target_socket.is_used = false
				corridor_entrance.is_used = false
				continue

			var corridor_exit: ChunkSocket = (
				corridor_exits[0]
			)

			context.placed_chunks.append(
				corridor
			)

			if _try_place_graph_terminal(
				corridor,
				corridor_exit
			):
				if (
					corridor_kind
					== LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR
				):
					context.horizontal_corridors_placed += 1
				else:
					context.vertical_corridors_placed += 1

				chunk_usage.record(
					scene
				)

				return true

			context.placed_chunks.erase(
				corridor
			)

			target_socket.is_used = false
			corridor_entrance.is_used = false

		chunk_tools.discard_chunk(
			corridor
		)

	return false


func _try_place_graph_terminal(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> bool:
	var candidate_scenes: Array[PackedScene] = (
		chunk_usage.get_prioritized_scenes(
			context.terminal_chunk_scenes
		)
	)

	for scene: PackedScene in candidate_scenes:
		var terminal: Chunk = (
			chunk_tools.spawn_chunk(
				scene,
				Vector2.ZERO
			)
		)

		if not terminal:
			continue

		if not chunk_tools.scene_matches_placement_kind(
			terminal,
			LevelGenerationTypes.PlacementKind.TERMINAL
		):
			chunk_tools.discard_chunk(
				terminal
			)
			continue

		if not chunk_tools.chunk_types_can_connect(
			current_chunk,
			terminal
		):
			chunk_tools.discard_chunk(
				terminal
			)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			chunk_tools.find_matching_sockets(
				terminal,
				target_socket
			)
		)

		rng.shuffle(
			matching_sockets
		)

		for terminal_entrance: ChunkSocket in matching_sockets:
			chunk_tools.align_chunk(
				terminal,
				terminal_entrance,
				target_socket
			)

			if chunk_tools.overlaps_chunks(
				terminal,
				context.placed_chunks
			):
				continue

			target_socket.is_used = true
			terminal_entrance.is_used = true

			if not terminal.get_available_sockets().is_empty():
				target_socket.is_used = false
				terminal_entrance.is_used = false
				continue

			context.placed_chunks.append(
				terminal
			)

			context.terminals_placed += 1

			chunk_usage.record(
				scene
			)

			return true

		chunk_tools.discard_chunk(
			terminal
		)

	return false
