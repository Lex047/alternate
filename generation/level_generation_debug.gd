extends RefCounted
class_name LevelGenerationDebug


var context: LevelGenerationContext
var chunk_usage: LevelChunkUsage
var chunk_tools: LevelChunkTools


func _init(
	generation_context: LevelGenerationContext,
	usage_tracker: LevelChunkUsage,
	level_chunk_tools: LevelChunkTools
) -> void:
	context = generation_context
	chunk_usage = usage_tracker
	chunk_tools = level_chunk_tools


func print_level_graph() -> void:
	print(
		"================ LEVEL GRAPH ================"
	)

	print(
		"Seed: ",
		context.active_generation_seed,
		" | Nodes: ",
		context.level_graph.nodes.size(),
		" | Growth: ",
		context.level_graph.count_nodes_of_type(
			LevelGraphNode.NodeType.GROWTH
		),
		" | Goals: ",
		context.level_graph.count_nodes_of_type(
			LevelGraphNode.NodeType.GOAL
		)
	)

	_print_graph_subtree(
		context.level_graph.root,
		""
	)

	print(
		"============================================="
	)


func _print_graph_subtree(
	node: LevelGraphNode,
	indent: String
) -> void:
	var type_name: String = (
		str(
			LevelGraphNode.NodeType.keys()[
				node.node_type
			]
		)
	)

	print(
		indent,
		"[",
		node.id,
		"] ",
		type_name,
		" | children: ",
		node.children.size()
	)

	for child: LevelGraphNode in node.children:
		_print_graph_subtree(
			child,
			indent + "    "
		)


func print_generation_result(
	attempt: int
) -> void:
	var unresolved: int = (
		chunk_tools.count_open_sockets(
			context.placed_chunks
		)
	)

	print(
		"Seed: ",
		context.active_generation_seed,
		" | Generation attempt: ",
		attempt,
		" | Growth chunks: ",
		context.normal_chunks_placed,
		" / ",
		context.chunk_count,
		" | Goal chunks: ",
		context.goal_chunks_placed,
		" / 1",
		" | Horizontal corridors: ",
		context.horizontal_corridors_placed,
		" | Vertical corridors: ",
		context.vertical_corridors_placed,
		" | Terminals: ",
		context.terminals_placed,
		" | Total chunks: ",
		context.placed_chunks.size(),
		" | Backtracks: ",
		context.solver_backtracks,
		" | Unresolved sockets: ",
		unresolved
	)

	print("Growth chunk usage:")

	for scene: PackedScene in context.chunk_scenes:
		print(
			"  ",
			scene.resource_path.get_file(),
			": ",
			chunk_usage.get_scene_usage(
				scene
			)
		)

	print("Goal chunk usage:")

	for scene: PackedScene in context.goal_chunk_scenes:
		print(
			"  ",
			scene.resource_path.get_file(),
			": ",
			chunk_usage.get_scene_usage(
				scene
			)
		)

	if unresolved > 0:
		_print_unresolved_sockets()


func _print_unresolved_sockets() -> void:
	for chunk: Chunk in context.placed_chunks:
		for socket: ChunkSocket in (
			chunk.get_available_sockets()
		):
			var chunk_type_name: String = (
				str(
					Chunk.ChunkType.keys()[
						chunk.chunk_type
					]
				)
			)

			var direction_name: String = (
				str(
					ChunkSocket.Direction.keys()[
						socket.direction
					]
				)
			)

			print(
				"UNRESOLVED | Chunk: ",
				chunk.name,
				" | Type: ",
				chunk_type_name,
				" | Direction: ",
				direction_name,
				" | Position: ",
				socket.global_position
			)
