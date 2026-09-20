extends RefCounted
class_name LevelGraphSolver


var context: LevelGenerationContext
var rng: LevelGenerationRng
var chunk_usage: LevelChunkUsage
var chunk_tools: LevelChunkTools
var frontier_validator: LevelFrontierValidator
var closure_solver: LevelClosureSolver


func _init(
	generation_context: LevelGenerationContext,
	generation_rng: LevelGenerationRng,
	usage_tracker: LevelChunkUsage,
	level_chunk_tools: LevelChunkTools,
	validator: LevelFrontierValidator,
	final_closure_solver: LevelClosureSolver
) -> void:
	context = generation_context
	rng = generation_rng
	chunk_usage = usage_tracker
	chunk_tools = level_chunk_tools
	frontier_validator = validator
	closure_solver = final_closure_solver


func solve_graph_node(
	graph_node: LevelGraphNode,
	physical_chunk: Chunk
) -> bool:
	if graph_node.children.is_empty():
		return true

	for _retry in range(
		context.max_local_backtrack_retries
	):
		if (
			context.solver_backtracks
			>= context.max_solver_backtracks
		):
			return false

		var placed_count_before: int = (
			context.placed_chunks.size()
		)

		var normal_before: int = (
			context.normal_chunks_placed
		)

		var goal_before: int = (
			context.goal_chunks_placed
		)

		var horizontal_before: int = (
			context.horizontal_corridors_placed
		)

		var vertical_before: int = (
			context.vertical_corridors_placed
		)

		var terminals_before: int = (
			context.terminals_placed
		)

		var usage_before: Dictionary = (
			chunk_usage.snapshot()
		)

		var graph_map_before: Dictionary = (
			context.graph_node_chunks.duplicate(true)
		)

		var open_sockets_before: Array[ChunkSocket] = (
			chunk_tools.capture_open_sockets(
				context.placed_chunks
			)
		)

		var children_realized: bool = (
			_realize_graph_children(
				graph_node,
				physical_chunk
			)
		)

		var subtree_solved: bool = (
			children_realized
		)

		if subtree_solved:
			for child: LevelGraphNode in (
				graph_node.children
			):
				var child_chunk: Chunk = (
					context.graph_node_chunks.get(
						child.id,
						null
					) as Chunk
				)

				if not child_chunk:
					subtree_solved = false
					break

				if not solve_graph_node(
					child,
					child_chunk
				):
					subtree_solved = false
					break

		if subtree_solved:
			if graph_node == context.level_graph.root:
				if closure_solver.resolve_remaining_sockets():
					return true

				subtree_solved = false
			else:
				return true

		_rollback_solver_state(
			placed_count_before,
			normal_before,
			goal_before,
			horizontal_before,
			vertical_before,
			terminals_before,
			usage_before,
			graph_map_before
		)

		for socket: ChunkSocket in open_sockets_before:
			if is_instance_valid(socket):
				socket.is_used = false

		if not _register_solver_backtrack():
			return false

	return false


func _realize_graph_children(
	graph_node: LevelGraphNode,
	physical_chunk: Chunk
) -> bool:
	var required_children: int = (
		graph_node.children.size()
	)

	if (
		physical_chunk.get_available_sockets().size()
		< required_children
	):
		return false

	for child_node: LevelGraphNode in graph_node.children:
		var child_chunk: Chunk = (
			_try_place_graph_child(
				graph_node,
				physical_chunk,
				child_node
			)
		)

		if not child_chunk:
			return false

		context.graph_node_chunks[
			child_node.id
		] = child_chunk

		if not frontier_validator.graph_frontier_is_closable():
			return false

	return true


func _try_place_graph_child(
	parent_node: LevelGraphNode,
	parent_chunk: Chunk,
	child_node: LevelGraphNode
) -> Chunk:
	var parent_sockets: Array[ChunkSocket] = (
		parent_chunk.get_available_sockets()
	)

	rng.shuffle(
		parent_sockets
	)

	for target_socket: ChunkSocket in parent_sockets:
		var corridor_kind: int = (
			chunk_tools.get_required_corridor_kind(
				parent_chunk,
				target_socket
			)
		)

		var corridor_pool: Array[PackedScene] = []

		if (
			corridor_kind
			== LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR
		):
			corridor_pool = (
				context.horizontal_corridor_scenes
			)

		elif (
			corridor_kind
			== LevelGenerationTypes.PlacementKind.VERTICAL_CORRIDOR
		):
			corridor_pool = (
				context.vertical_corridor_scenes
			)

		else:
			continue

		var corridor_candidates: Array[PackedScene] = (
			chunk_usage.get_prioritized_scenes(
				corridor_pool
			)
		)

		for corridor_scene: PackedScene in corridor_candidates:
			var corridor: Chunk = (
				chunk_tools.spawn_chunk(
					corridor_scene,
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

				var occupied_with_corridor: Array[Chunk] = (
					chunk_tools.copy_chunk_array(
						context.placed_chunks
					)
				)

				occupied_with_corridor.append(
					corridor
				)

				var corridor_exits: Array[ChunkSocket] = (
					corridor.get_available_sockets()
				)

				rng.shuffle(
					corridor_exits
				)

				for corridor_exit: ChunkSocket in corridor_exits:
					var child_chunk: Chunk = (
						_try_place_graph_room(
							parent_node,
							parent_chunk,
							corridor,
							corridor_exit,
							child_node,
							occupied_with_corridor
						)
					)

					if not child_chunk:
						continue

					context.placed_chunks.append(
						corridor
					)

					context.placed_chunks.append(
						child_chunk
					)

					if (
						corridor_kind
						== LevelGenerationTypes.PlacementKind.HORIZONTAL_CORRIDOR
					):
						context.horizontal_corridors_placed += 1
					else:
						context.vertical_corridors_placed += 1

					match child_node.node_type:
						LevelGraphNode.NodeType.GROWTH:
							context.normal_chunks_placed += 1

						LevelGraphNode.NodeType.GOAL:
							context.goal_chunks_placed += 1

						_:
							push_error(
								"LevelGraphSolver: Unsupported "
								+ "graph child type."
							)

					chunk_usage.record(
						corridor_scene
					)

					return child_chunk

				target_socket.is_used = false
				corridor_entrance.is_used = false

			chunk_tools.discard_chunk(
				corridor
			)

	return null


func _try_place_graph_room(
	parent_node: LevelGraphNode,
	parent_chunk: Chunk,
	corridor: Chunk,
	target_socket: ChunkSocket,
	graph_node: LevelGraphNode,
	occupied_chunks: Array[Chunk]
) -> Chunk:
	var room_pool: Array[PackedScene] = []

	match graph_node.node_type:
		LevelGraphNode.NodeType.GROWTH:
			room_pool = context.chunk_scenes

		LevelGraphNode.NodeType.GOAL:
			room_pool = context.goal_chunk_scenes

		_:
			return null

	var candidate_scenes: Array[PackedScene] = (
		chunk_usage.get_prioritized_scenes(
			room_pool
		)
	)

	for scene: PackedScene in candidate_scenes:
		# Do not place the same growth room directly
		# after itself.
		#
		# Physical structure:
		# GROWTH ROOM -> CORRIDOR -> GROWTH ROOM
		if (
			graph_node.node_type
			== LevelGraphNode.NodeType.GROWTH
			and parent_node.node_type
			== LevelGraphNode.NodeType.GROWTH
			and scene.resource_path
			== parent_chunk.scene_file_path
		):
			continue

		var candidate: Chunk = (
			chunk_tools.spawn_chunk(
				scene,
				Vector2.ZERO
			)
		)

		if not candidate:
			continue

		if not chunk_tools.scene_matches_placement_kind(
			candidate,
			LevelGenerationTypes.PlacementKind.GROWTH
		):
			chunk_tools.discard_chunk(
				candidate
			)
			continue

		if not chunk_tools.chunk_types_can_connect(
			corridor,
			candidate
		):
			chunk_tools.discard_chunk(
				candidate
			)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			chunk_tools.find_matching_sockets(
				candidate,
				target_socket
			)
		)

		rng.shuffle(
			matching_sockets
		)

		for entrance_socket: ChunkSocket in matching_sockets:
			chunk_tools.align_chunk(
				candidate,
				entrance_socket,
				target_socket
			)

			if chunk_tools.overlaps_chunks(
				candidate,
				occupied_chunks
			):
				continue

			target_socket.is_used = true
			entrance_socket.is_used = true

			var remaining_sockets: int = (
				candidate
				.get_available_sockets()
				.size()
			)

			if (
				remaining_sockets
				< graph_node.children.size()
			):
				target_socket.is_used = false
				entrance_socket.is_used = false
				continue

			chunk_usage.record(
				scene
			)

			return candidate

		chunk_tools.discard_chunk(
			candidate
		)

	return null


func _rollback_solver_state(
	placed_count_before: int,
	normal_before: int,
	goal_before: int,
	horizontal_before: int,
	vertical_before: int,
	terminals_before: int,
	usage_before: Dictionary,
	graph_map_before: Dictionary
) -> void:
	while (
		context.placed_chunks.size()
		> placed_count_before
	):
		var chunk_to_remove: Chunk = (
			context.placed_chunks.pop_back()
			as Chunk
		)

		if chunk_to_remove:
			chunk_tools.discard_chunk(
				chunk_to_remove
			)

	context.normal_chunks_placed = normal_before
	context.goal_chunks_placed = goal_before
	context.horizontal_corridors_placed = (
		horizontal_before
	)
	context.vertical_corridors_placed = (
		vertical_before
	)
	context.terminals_placed = terminals_before

	chunk_usage.restore(
		usage_before
	)

	context.graph_node_chunks = (
		graph_map_before.duplicate(true)
	)


func _register_solver_backtrack() -> bool:
	context.solver_backtracks += 1

	return (
		context.solver_backtracks
		<= context.max_solver_backtracks
	)
