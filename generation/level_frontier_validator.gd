extends RefCounted
class_name LevelFrontierValidator


var context: LevelGenerationContext
var chunk_tools: LevelChunkTools


func _init(
	generation_context: LevelGenerationContext,
	level_chunk_tools: LevelChunkTools
) -> void:
	context = generation_context
	chunk_tools = level_chunk_tools


func graph_frontier_is_closable() -> bool:
	var occupied_chunks: Array[Chunk] = (
		chunk_tools.copy_chunk_array(
			context.placed_chunks
		)
	)

	for graph_node: LevelGraphNode in (
		context.level_graph.nodes
	):
		if not context.graph_node_chunks.has(
			graph_node.id
		):
			continue

		var all_children_realized: bool = true

		for child: LevelGraphNode in graph_node.children:
			if not context.graph_node_chunks.has(
				child.id
			):
				all_children_realized = false
				break

		if not all_children_realized:
			continue

		var physical_chunk: Chunk = (
			context.graph_node_chunks.get(
				graph_node.id,
				null
			) as Chunk
		)

		if not physical_chunk:
			return false

		for socket: ChunkSocket in (
			physical_chunk.get_available_sockets()
		):
			if not graph_socket_can_eventually_close(
				physical_chunk,
				socket,
				occupied_chunks
			):
				return false

	for chunk: Chunk in occupied_chunks:
		if (
			chunk.chunk_type
			!= Chunk.ChunkType.CORRIDOR
		):
			continue

		for socket: ChunkSocket in (
			chunk.get_available_sockets()
		):
			if not chunk_tools.socket_can_fit_scene_pool(
				chunk,
				socket,
				context.terminal_chunk_scenes,
				occupied_chunks,
				LevelGenerationTypes.PlacementKind.TERMINAL
			):
				return false

	return true


func graph_socket_can_eventually_close(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	occupied_chunks: Array[Chunk]
) -> bool:
	var corridor_kind: int = (
		chunk_tools.get_required_corridor_kind(
			current_chunk,
			target_socket
		)
	)

	var corridor_pool: Array[PackedScene] = []

	if (
		corridor_kind
		== LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR
	):
		corridor_pool = context.horizontal_corridor_scenes

	elif (
		corridor_kind
		== LevelGenerationTypes.PlacementKind.VERTICAL_CORRIDOR
	):
		corridor_pool = context.vertical_corridor_scenes

	else:
		return false

	for corridor_scene: PackedScene in corridor_pool:
		var test_corridor: Chunk = (
			chunk_tools.spawn_chunk(
				corridor_scene,
				Vector2.ZERO
			)
		)

		if not test_corridor:
			continue

		if not chunk_tools.scene_matches_placement_kind(
			test_corridor,
			corridor_kind
		):
			chunk_tools.discard_chunk(
				test_corridor
			)
			continue

		if not chunk_tools.chunk_types_can_connect(
			current_chunk,
			test_corridor
		):
			chunk_tools.discard_chunk(
				test_corridor
			)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			chunk_tools.find_matching_sockets(
				test_corridor,
				target_socket
			)
		)

		for corridor_entrance: ChunkSocket in matching_sockets:
			chunk_tools.align_chunk(
				test_corridor,
				corridor_entrance,
				target_socket
			)

			if chunk_tools.overlaps_chunks(
				test_corridor,
				occupied_chunks
			):
				continue

			corridor_entrance.is_used = true

			var occupied_with_corridor: Array[Chunk] = (
				chunk_tools.copy_chunk_array(
					occupied_chunks
				)
			)

			occupied_with_corridor.append(
				test_corridor
			)

			var exits: Array[ChunkSocket] = (
				test_corridor.get_available_sockets()
			)

			var corridor_can_close: bool = (
				not exits.is_empty()
			)

			for exit_socket: ChunkSocket in exits:
				if not chunk_tools.socket_can_fit_scene_pool(
					test_corridor,
					exit_socket,
					context.terminal_chunk_scenes,
					occupied_with_corridor,
					LevelGenerationTypes.PlacementKind.TERMINAL
				):
					corridor_can_close = false
					break

			corridor_entrance.is_used = false

			if corridor_can_close:
				chunk_tools.discard_chunk(
					test_corridor
				)
				return true

		chunk_tools.discard_chunk(
			test_corridor
		)

	return false
