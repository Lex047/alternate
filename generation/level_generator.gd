extends Node2D
class_name LevelGenerator

signal generation_finished(seed: int)
signal generation_failed

# ==================================================
# GENERATION SETTINGS
# ==================================================

@export_category("Generation")

@export var start_chunk_scene: PackedScene

@export var chunk_scenes: Array[PackedScene] = []

@export var horizontal_corridor_scenes: Array[PackedScene] = []
@export var vertical_corridor_scenes: Array[PackedScene] = []

@export var terminal_chunk_scenes: Array[PackedScene] = []
@export var goal_chunk_scenes: Array[PackedScene] = []

@export_range(1, 100, 1)
var chunk_count: int = 8

@export_range(1, 100, 1)
var max_generation_attempts: int = 20

@export_range(1, 20, 1)
var attempts_per_graph: int = 4

@export_range(0.0, 8.0, 1.0)
var bounds_overlap_tolerance: float = 4.0


# ==================================================
# ALTERNATE SETTINGS
# ==================================================

@export_category("Alternate")

@export_range(0.1, 0.8, 0.05)
var alternate_preserve_ratio: float = 0.35


# ==================================================
# GRAPH SETTINGS
# ==================================================

@export_category("Graph")

@export_range(1, 4, 1)
var max_graph_children: int = 2

@export_range(0.0, 1.0, 0.05)
var graph_branch_chance: float = 0.35


# ==================================================
# SOLVER SETTINGS
# ==================================================

@export_category("Solver")

@export_range(1, 8, 1)
var max_local_backtrack_retries: int = 4

@export_range(1, 1000, 1)
var max_solver_backtracks: int = 250


# ==================================================
# RANDOMNESS SETTINGS
# ==================================================

@export_category("Randomness")

@export var generation_seed: int = 12345
@export var use_random_seed: bool = false


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var generated_chunks: Node2D = $GeneratedChunks
@onready var alternate_chunks: Node2D = $AlternateChunks


# ==================================================
# COMPONENTS
# ==================================================

var context: LevelGenerationContext

var rng: LevelGenerationRng
var graph_builder: LevelGraphBuilder
var chunk_usage: LevelChunkUsage
var chunk_tools: LevelChunkTools
var frontier_validator: LevelFrontierValidator
var closure_solver: LevelClosureSolver
var graph_solver: LevelGraphSolver
var generation_debug: LevelGenerationDebug

var _components_initialized: bool = false

var alternate_context: LevelGenerationContext

var alternate_rng: LevelGenerationRng
var alternate_graph_builder: LevelGraphBuilder
var alternate_chunk_usage: LevelChunkUsage
var alternate_chunk_tools: LevelChunkTools
var alternate_frontier_validator: LevelFrontierValidator
var alternate_closure_solver: LevelClosureSolver
var alternate_graph_solver: LevelGraphSolver

var alternate_layout_ready: bool = false


const ALTERNATE_STAGING_POSITION := Vector2(
	100000.0,
	100000.0
)

const ALTERNATE_SEED_SALT: int = 0x45D9F3B


func _ready() -> void:
	alternate_chunks.position = (
		ALTERNATE_STAGING_POSITION
	)

	alternate_chunks.process_mode = (
		Node.PROCESS_MODE_DISABLED
	)

	_initialize_components()


func _initialize_components() -> void:
	if _components_initialized:
		return

	context = LevelGenerationContext.new()

	rng = LevelGenerationRng.new()

	graph_builder = LevelGraphBuilder.new(
		context,
		rng
	)

	chunk_usage = LevelChunkUsage.new(
		context,
		rng
	)

	chunk_tools = LevelChunkTools.new(
		context
	)

	frontier_validator = LevelFrontierValidator.new(
		context,
		chunk_tools
	)

	closure_solver = LevelClosureSolver.new(
		context,
		rng,
		chunk_usage,
		chunk_tools
	)

	graph_solver = LevelGraphSolver.new(
		context,
		rng,
		chunk_usage,
		chunk_tools,
		frontier_validator,
		closure_solver
	)

	generation_debug = LevelGenerationDebug.new(
		context,
		chunk_usage,
		chunk_tools
	)
	
	alternate_context = LevelGenerationContext.new()

	alternate_rng = LevelGenerationRng.new()

	alternate_graph_builder = LevelGraphBuilder.new(
		alternate_context,
		alternate_rng
	)

	alternate_chunk_usage = LevelChunkUsage.new(
		alternate_context,
		alternate_rng
	)

	alternate_chunk_tools = LevelChunkTools.new(
		alternate_context
	)

	alternate_frontier_validator = (
		LevelFrontierValidator.new(
			alternate_context,
			alternate_chunk_tools
		)
	)

	alternate_closure_solver = (
		LevelClosureSolver.new(
			alternate_context,
			alternate_rng,
			alternate_chunk_usage,
			alternate_chunk_tools
		)
	)

	alternate_graph_solver = (
		LevelGraphSolver.new(
			alternate_context,
			alternate_rng,
			alternate_chunk_usage,
			alternate_chunk_tools,
			alternate_frontier_validator,
			alternate_closure_solver
		)
	)
	
	_components_initialized = true


func _sync_context_from_exports() -> void:
	context.generated_chunks = generated_chunks

	context.start_chunk_scene = start_chunk_scene

	context.chunk_scenes = chunk_scenes
	context.goal_chunk_scenes = goal_chunk_scenes
	context.horizontal_corridor_scenes = (
		horizontal_corridor_scenes
	)
	context.vertical_corridor_scenes = (
		vertical_corridor_scenes
	)
	context.terminal_chunk_scenes = (
		terminal_chunk_scenes
	)

	context.chunk_count = chunk_count
	context.bounds_overlap_tolerance = (
		bounds_overlap_tolerance
	)

	context.max_graph_children = max_graph_children
	context.graph_branch_chance = graph_branch_chance

	context.max_local_backtrack_retries = (
		max_local_backtrack_retries
	)
	context.max_solver_backtracks = (
		max_solver_backtracks
	)


func _sync_alternate_context_from_exports(
	rebuild_growth_count: int
) -> void:
	alternate_context.generated_chunks = (
		alternate_chunks
	)

	alternate_context.start_chunk_scene = (
		start_chunk_scene
	)

	alternate_context.chunk_scenes = (
		chunk_scenes
	)

	alternate_context.goal_chunk_scenes = (
		goal_chunk_scenes
	)

	alternate_context.horizontal_corridor_scenes = (
		horizontal_corridor_scenes
	)

	alternate_context.vertical_corridor_scenes = (
		vertical_corridor_scenes
	)

	alternate_context.terminal_chunk_scenes = (
		terminal_chunk_scenes
	)

	alternate_context.chunk_count = (
		rebuild_growth_count
	)

	alternate_context.bounds_overlap_tolerance = (
		bounds_overlap_tolerance
	)

	alternate_context.max_graph_children = (
		max_graph_children
	)

	alternate_context.graph_branch_chance = (
		graph_branch_chance
	)

	alternate_context.max_local_backtrack_retries = (
		max_local_backtrack_retries
	)

	alternate_context.max_solver_backtracks = (
		max_solver_backtracks
	)


# ==================================================
# GENERATION
# ==================================================

func generate_level() -> void:
	_initialize_components()
	_sync_context_from_exports()
	
	alternate_layout_ready = false

	generated_chunks.position = Vector2.ZERO
	generated_chunks.process_mode = (
		Node.PROCESS_MODE_INHERIT
	)

	alternate_chunks.position = (
		ALTERNATE_STAGING_POSITION
	)

	alternate_chunks.process_mode = (
		Node.PROCESS_MODE_DISABLED
	)

	_clear_alternate_chunks()
	
	if not _configuration_is_valid():
		generation_failed.emit()
		return

	context.active_generation_seed = rng.initialize(
		generation_seed,
		use_random_seed
	)

	print(
		"Generation seed: ",
		context.active_generation_seed
	)

	var total_attempts: int = 0
	var graph_number: int = 0

	var max_graphs: int = ceili(
		float(max_generation_attempts)
		/ float(attempts_per_graph)
	)

	for graph_index in range(max_graphs):
		if total_attempts >= max_generation_attempts:
			break

		graph_number += 1

		print(
			"Building level graph ",
			graph_number,
			"..."
		)

		graph_builder.build()

		if not graph_builder.is_valid():
			push_warning(
				"LevelGenerator: Generated graph "
				+ str(graph_number)
				+ " is invalid."
			)

			continue

		generation_debug.print_level_graph()

		var remaining_attempts: int = (
			max_generation_attempts
			- total_attempts
		)

		var attempts_for_graph: int = mini(
			attempts_per_graph,
			remaining_attempts
		)

		for local_attempt in range(
			1,
			attempts_for_graph + 1
		):
			total_attempts += 1

			_begin_generation_attempt()
			_generate_attempt()

			if _generation_is_complete():
				print(
					"Graph ",
					graph_number,
					" succeeded on local attempt ",
					local_attempt,
					"."
				)

				generation_debug.print_generation_result(
					total_attempts
				)

				_print_alternate_plan()
				_print_alternate_rebuild_plan()
				_print_closure_branches()
				_print_alternate_physical_partition()
				
				if not _prepare_alternate_layout():
					push_error(
						"LevelGenerator: Failed to prepare "
						+ "Alternate layout."
					)
					generation_failed.emit()
					return
				
				generation_finished.emit(
					context.active_generation_seed
				)

				return

		print(
			"Graph ",
			graph_number,
			" failed after ",
			attempts_for_graph,
			" placement attempts."
		)

	push_warning(
		"LevelGenerator: Could not generate a complete "
		+ "level after "
		+ str(total_attempts)
		+ " placement attempts across "
		+ str(graph_number)
		+ " graphs."
	)

	generation_debug.print_generation_result(
		total_attempts
	)

	generation_failed.emit()


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

	if goal_chunk_scenes.is_empty():
		push_error(
			"LevelGenerator: No goal chunks assigned."
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
	chunk_tools.clear_generated_chunks()

	context.reset_attempt_state()
	chunk_usage.initialize()


func _generate_attempt() -> void:
	var start_chunk: Chunk = (
		chunk_tools.spawn_chunk(
			context.start_chunk_scene,
			Vector2.ZERO
		)
	)

	if not start_chunk:
		return

	context.placed_chunks.append(
		start_chunk
	)

	context.graph_node_chunks[
		context.level_graph.root.id
	] = start_chunk

	if not graph_solver.solve_graph_node(
		context.level_graph.root,
		start_chunk
	):
		return

	if (
		context.normal_chunks_placed
		!= context.chunk_count
	):
		return

	if context.goal_chunks_placed != 1:
		return

	if (
		context.graph_node_chunks.size()
		!= context.level_graph.nodes.size()
	):
		return


func _generation_is_complete() -> bool:
	return (
		context.normal_chunks_placed
		== context.chunk_count
		and context.goal_chunks_placed == 1
		and context.graph_node_chunks.size()
			== context.level_graph.nodes.size()
		and chunk_tools.count_open_sockets(
			context.placed_chunks
		) == 0
	)


func get_start_chunk() -> Chunk:
	if not context:
		return null

	if not context.level_graph:
		return null

	if not context.level_graph.root:
		return null

	return (
		context.graph_node_chunks.get(
			context.level_graph.root.id,
			null
		) as Chunk
	)


# ==================================================
# ALTERNATION
# ==================================================


func get_goal_chunk() -> Chunk:
	if not context:
		return null

	if not context.level_graph:
		return null

	for graph_node: LevelGraphNode in context.level_graph.nodes:
		if (
			graph_node.node_type
			!= LevelGraphNode.NodeType.GOAL
		):
			continue

		return (
			context.graph_node_chunks.get(
				graph_node.id,
				null
			) as Chunk
		)

	return null


func get_goal_route() -> Array[LevelGraphNode]:
	if not context:
		return []

	return (
		context.level_graph
		.get_start_to_goal_route()
	)


func get_alternate_cut_node() -> LevelGraphNode:
	var route: Array[LevelGraphNode] = (
		get_goal_route()
	)

	# We need at least:
	# START -> GROWTH -> GOAL
	if route.size() < 3:
		return null

	var last_growth_index: int = (
		route.size() - 2
	)

	var cut_index: int = roundi(
		float(last_growth_index)
		* alternate_preserve_ratio
	)

	cut_index = clampi(
		cut_index,
		1,
		last_growth_index
	)

	return route[cut_index]


func get_alternate_rebuild_nodes() -> Array[LevelGraphNode]:
	var cut_node: LevelGraphNode = (
		get_alternate_cut_node()
	)

	if not cut_node:
		return []

	return context.level_graph.get_descendants(
		cut_node
	)


func _get_alternate_rebuild_growth_count() -> int:
	var count: int = 0

	for node: LevelGraphNode in (
		get_alternate_rebuild_nodes()
	):
		if (
			node.node_type
			== LevelGraphNode.NodeType.GROWTH
		):
			count += 1

	return count


func get_alternate_rebuild_chunks() -> Array[Chunk]:
	var result: Array[Chunk] = []

	var rebuild_nodes: Array[LevelGraphNode] = (
		get_alternate_rebuild_nodes()
	)

	var rebuild_rooms: Dictionary = {}

	for node: LevelGraphNode in rebuild_nodes:
		var room: Chunk = (
			context.graph_node_chunks.get(
				node.id,
				null
			) as Chunk
		)

		if room:
			result.append(room)
			rebuild_rooms[room] = true

		var corridor: Chunk = (
			context.graph_edge_corridors.get(
				node.id,
				null
			) as Chunk
		)

		if corridor:
			result.append(corridor)

	for branch: Dictionary in context.closure_branches:
		var source: Chunk = (
			branch["source_chunk"] as Chunk
		)

		if not rebuild_rooms.has(source):
			continue

		var closure_corridor: Chunk = (
			branch["corridor"] as Chunk
		)

		var terminal: Chunk = (
			branch["terminal"] as Chunk
		)

		if closure_corridor:
			result.append(
				closure_corridor
			)

		if terminal:
			result.append(
				terminal
			)

	return result


func get_alternate_preserved_chunks() -> Array[Chunk]:
	var rebuild_chunks: Array[Chunk] = (
		get_alternate_rebuild_chunks()
	)

	var rebuild_lookup: Dictionary = {}

	for chunk: Chunk in rebuild_chunks:
		rebuild_lookup[chunk] = true

	var result: Array[Chunk] = []

	for chunk: Chunk in context.placed_chunks:
		if not rebuild_lookup.has(chunk):
			result.append(chunk)

	return result


func _clear_alternate_chunks() -> void:
	for child: Node in alternate_chunks.get_children():
		child.free()


func _copy_chunk_for_alternate(
	source: Chunk
) -> Chunk:
	if not source:
		return null

	if source.scene_file_path.is_empty():
		push_error(
			"LevelGenerator: Preserved chunk has no "
			+ "scene file path."
		)
		return null

	var scene: PackedScene = load(
		source.scene_file_path
	) as PackedScene

	if not scene:
		push_error(
			"LevelGenerator: Could not load preserved "
			+ "chunk scene."
		)
		return null

	var instance: Node = scene.instantiate()

	if not instance is Chunk:
		push_error(
			"LevelGenerator: Alternate copy is not "
			+ "a Chunk."
		)

		instance.free()
		return null

	var copy: Chunk = instance as Chunk

	alternate_chunks.add_child(
		copy
	)

	# AlternateChunks is staged elsewhere, so preserve
	# the source chunk's local transform rather than
	# its global position.
	copy.transform = source.transform

	_copy_socket_states(
		source,
		copy
	)

	return copy


func _copy_socket_states(
	source: Chunk,
	copy: Chunk
) -> void:
	for source_socket: ChunkSocket in source.get_sockets():
		var socket_path: NodePath = (
			source.get_path_to(
				source_socket
			)
		)

		var copied_socket: ChunkSocket = (
			copy.get_node_or_null(
				socket_path
			) as ChunkSocket
		)

		if not copied_socket:
			push_warning(
				"LevelGenerator: Could not copy "
				+ "socket state for "
				+ str(socket_path)
			)
			continue

		copied_socket.is_used = (
			source_socket.is_used
		)


func _build_alternate_preserved_copy() -> Dictionary:
	_clear_alternate_chunks()

	var copy_map: Dictionary = {}

	var preserved_chunks: Array[Chunk] = (
		get_alternate_preserved_chunks()
	)

	for source: Chunk in preserved_chunks:
		var copy: Chunk = (
			_copy_chunk_for_alternate(
				source
			)
		)

		if not copy:
			_clear_alternate_chunks()
			return {}

		copy_map[source] = copy

	print(
		"Alternate: copied ",
		copy_map.size(),
		" preserved physical chunks."
	)

	return copy_map


func _open_alternate_cut_sockets(
	copy_map: Dictionary
) -> bool:
	var cut_node: LevelGraphNode = (
		get_alternate_cut_node()
	)

	if not cut_node:
		return false

	var normal_cut_chunk: Chunk = (
		context.graph_node_chunks.get(
			cut_node.id,
			null
		) as Chunk
	)

	if not normal_cut_chunk:
		return false

	var alternate_cut_chunk: Chunk = (
		copy_map.get(
			normal_cut_chunk,
			null
		) as Chunk
	)

	if not alternate_cut_chunk:
		return false

	for child: LevelGraphNode in cut_node.children:
		var socket_path: NodePath = (
			context.graph_edge_parent_socket_paths.get(
				child.id,
				NodePath()
			)
		)

		if socket_path.is_empty():
			push_error(
				"LevelGenerator: Missing Alternate "
				+ "cut socket path."
			)
			return false

		var socket: ChunkSocket = (
			alternate_cut_chunk.get_node_or_null(
				socket_path
			) as ChunkSocket
		)

		if not socket:
			push_error(
				"LevelGenerator: Alternate cut socket "
				+ "could not be found."
			)
			return false

		socket.is_used = false

	return true


func _prepare_alternate_layout() -> bool:
	alternate_layout_ready = false

	var rebuild_growth_count: int = (
		_get_alternate_rebuild_growth_count()
	)

	if rebuild_growth_count < 1:
		push_error(
			"LevelGenerator: Alternate rebuild has "
			+ "no growth nodes."
		)
		return false

	_sync_alternate_context_from_exports(
		rebuild_growth_count
	)

	var alternate_seed: int = (
		context.active_generation_seed
		^ ALTERNATE_SEED_SALT
	)

	alternate_context.active_generation_seed = (
		alternate_rng.initialize(
			alternate_seed,
			false
		)
	)

	print(
		"Alternate generation seed: ",
		alternate_context.active_generation_seed
	)

	print(
		"Alternate rebuild growth count: ",
		rebuild_growth_count
	)

	var total_attempts: int = 0
	var graph_number: int = 0

	var max_graphs: int = ceili(
		float(max_generation_attempts)
		/ float(attempts_per_graph)
	)

	for _graph_index in range(max_graphs):
		if total_attempts >= max_generation_attempts:
			break

		graph_number += 1

		print(
			"Building Alternate graph ",
			graph_number,
			"..."
		)

		alternate_graph_builder.build()

		if not alternate_graph_builder.is_valid():
			push_warning(
				"LevelGenerator: Alternate graph "
				+ str(graph_number)
				+ " is invalid."
			)
			continue

		var remaining_attempts: int = (
			max_generation_attempts
			- total_attempts
		)

		var attempts_for_graph: int = mini(
			attempts_per_graph,
			remaining_attempts
		)

		for local_attempt in range(
			1,
			attempts_for_graph + 1
		):
			total_attempts += 1

			var copy_map: Dictionary = (
				_begin_alternate_generation_attempt()
			)

			if copy_map.is_empty():
				push_error(
					"LevelGenerator: Could not build "
					+ "Alternate preserved copy."
				)
				return false

			var cut_node: LevelGraphNode = (
				get_alternate_cut_node()
			)

			if not cut_node:
				return false

			var normal_cut_chunk: Chunk = (
				context.graph_node_chunks.get(
					cut_node.id,
					null
				) as Chunk
			)

			if not normal_cut_chunk:
				return false

			var alternate_cut_chunk: Chunk = (
				copy_map.get(
					normal_cut_chunk,
					null
				) as Chunk
			)

			if not alternate_cut_chunk:
				return false

			var alternate_root: LevelGraphNode = (
				alternate_context.level_graph.root
			)

			# The Alternate graph START is synthetic.
			# Physically, its root is the copied cut room.
			alternate_context.graph_node_chunks[
				alternate_root.id
			] = alternate_cut_chunk

			if not alternate_graph_solver.solve_graph_node(
				alternate_root,
				alternate_cut_chunk
			):
				continue

			if not _alternate_generation_is_complete():
				continue

			alternate_layout_ready = true

			print(
				"Alternate graph ",
				graph_number,
				" succeeded on local attempt ",
				local_attempt,
				"."
			)

			print(
				"Alternate: Growth chunks: ",
				alternate_context.normal_chunks_placed,
				" / ",
				alternate_context.chunk_count,
				" | Goal chunks: ",
				alternate_context.goal_chunks_placed,
				" / 1",
				" | Total physical chunks: ",
				alternate_context.placed_chunks.size(),
				" | Backtracks: ",
				alternate_context.solver_backtracks,
				" | Unresolved sockets: ",
				alternate_chunk_tools.count_open_sockets(
					alternate_context.placed_chunks
				)
			)

			print(
				"Alternate: complete layout ready."
			)

			return true

		print(
			"Alternate graph ",
			graph_number,
			" failed after ",
			attempts_for_graph,
			" placement attempts."
		)

	_clear_alternate_chunks()

	push_warning(
		"LevelGenerator: Could not generate "
		+ "Alternate layout after "
		+ str(total_attempts)
		+ " attempts."
	)

	return false


func _begin_alternate_generation_attempt() -> Dictionary:
	alternate_context.reset_attempt_state()

	alternate_chunk_usage.initialize()

	var copy_map: Dictionary = (
		_build_alternate_preserved_copy()
	)

	if copy_map.is_empty():
		return {}

	if not _open_alternate_cut_sockets(
		copy_map
	):
		_clear_alternate_chunks()
		return {}

	for value: Variant in copy_map.values():
		var copied_chunk: Chunk = (
			value as Chunk
		)

		if copied_chunk:
			alternate_context.placed_chunks.append(
				copied_chunk
			)

	return copy_map


func _alternate_generation_is_complete() -> bool:
	return (
		alternate_context.normal_chunks_placed
			== alternate_context.chunk_count
		and alternate_context.goal_chunks_placed == 1
		and alternate_context.graph_node_chunks.size()
			== alternate_context.level_graph.nodes.size()
		and alternate_chunk_tools.count_open_sockets(
			alternate_context.placed_chunks
		) == 0
	)


func get_alternate_goal_chunk() -> Chunk:
	if not alternate_context:
		return null

	for graph_node: LevelGraphNode in (
		alternate_context.level_graph.nodes
	):
		if (
			graph_node.node_type
			!= LevelGraphNode.NodeType.GOAL
		):
			continue

		return (
			alternate_context.graph_node_chunks.get(
				graph_node.id,
				null
			) as Chunk
		)

	return null


func activate_alternate_layout() -> bool:
	if not alternate_layout_ready:
		push_error(
			"LevelGenerator: Alternate layout is not ready."
		)
		return false

	generated_chunks.position = (
		ALTERNATE_STAGING_POSITION
	)

	generated_chunks.process_mode = (
		Node.PROCESS_MODE_DISABLED
	)

	alternate_chunks.position = Vector2.ZERO

	alternate_chunks.process_mode = (
		Node.PROCESS_MODE_INHERIT
	)

	print(
		"LevelGenerator: Alternate layout activated."
	)

	return true


func get_alternate_start_chunk() -> Chunk:
	if not alternate_context:
		return null

	for chunk: Chunk in alternate_context.placed_chunks:
		if chunk.chunk_type == Chunk.ChunkType.START:
			return chunk

	return null


func _print_alternate_plan() -> void:
	var route: Array[LevelGraphNode] = (
		get_goal_route()
	)

	var cut_node: LevelGraphNode = (
		get_alternate_cut_node()
	)

	print(
		"============ ALTERNATE PLAN ============"
	)

	print(
		"Goal route length: ",
		route.size()
	)

	print(
		"Preserve ratio: ",
		alternate_preserve_ratio
	)

	for node: LevelGraphNode in route:
		var marker: String = ""

		if node == cut_node:
			marker = "  <-- CUT"

		print(
			"[",
			node.id,
			"] ",
			LevelGraphNode.NodeType.keys()[
				node.node_type
			],
			marker
		)

	print(
		"========================================"
	)


func _print_alternate_rebuild_plan() -> void:
	var cut_node: LevelGraphNode = (
		get_alternate_cut_node()
	)

	if not cut_node:
		print(
			"Alternate: No valid cut node."
		)
		return

	var rebuild_nodes: Array[LevelGraphNode] = (
		get_alternate_rebuild_nodes()
	)

	print(
		"========= ALTERNATE REBUILD ========="
	)

	print(
		"Preserved cut node: ",
		cut_node.id
	)

	for node: LevelGraphNode in rebuild_nodes:
		var room: Chunk = (
			context.graph_node_chunks.get(
				node.id,
				null
			) as Chunk
		)

		var corridor: Chunk = (
			context.graph_edge_corridors.get(
				node.id,
				null
			) as Chunk
		)

		var room_name: String = "MISSING"
		var corridor_name: String = "MISSING"

		if room:
			room_name = room.scene_file_path.get_file()

		if corridor:
			corridor_name = (
				corridor.scene_file_path.get_file()
			)

		print(
			"Node ",
			node.id,
			" | ",
			LevelGraphNode.NodeType.keys()[
				node.node_type
			],
			" | Room: ",
			room_name,
			" | Parent corridor: ",
			corridor_name
		)

	print(
		"====================================="
	)


func _print_closure_branches() -> void:
	print(
		"========== CLOSURE BRANCHES =========="
	)

	print(
		"Recorded branches: ",
		context.closure_branches.size(),
		" | Terminals: ",
		context.terminals_placed
	)

	for branch: Dictionary in context.closure_branches:
		var source: Chunk = (
			branch["source_chunk"] as Chunk
		)

		var corridor: Chunk = (
			branch["corridor"] as Chunk
		)

		var terminal: Chunk = (
			branch["terminal"] as Chunk
		)

		var corridor_name: String = "DIRECT"

		if corridor:
			corridor_name = (
				corridor.scene_file_path.get_file()
			)

		print(
			"Source: ",
			source.scene_file_path.get_file(),
			" | Corridor: ",
			corridor_name,
			" | Terminal: ",
			terminal.scene_file_path.get_file()
		)

	print(
		"======================================"
	)


func _print_alternate_physical_partition() -> void:
	var preserved: Array[Chunk] = (
		get_alternate_preserved_chunks()
	)

	var rebuilt: Array[Chunk] = (
		get_alternate_rebuild_chunks()
	)

	print(
		"====== ALTERNATE PHYSICAL PARTITION ======"
	)

	print(
		"Total physical chunks: ",
		context.placed_chunks.size()
	)

	print(
		"Preserved chunks: ",
		preserved.size()
	)

	print(
		"Rebuild chunks: ",
		rebuilt.size()
	)

	print(
		"Accounted chunks: ",
		preserved.size() + rebuilt.size()
	)

	print(
		"=========================================="
	)
