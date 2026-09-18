extends Node2D
class_name LevelGenerator


# Kept for compatibility with any code that used
# LevelGenerator.PlacementKind before this refactor.
enum PlacementKind {
	GROWTH,
	HORIZONTAL_CORRIDOR,
	VERTICAL_CORRIDOR,
	TERMINAL,
}


# ==================================================
# GENERATION SETTINGS
# ==================================================

@export_category("Generation")

@export var start_chunk_scene: PackedScene

@export var chunk_scenes: Array[PackedScene] = []

@export var horizontal_corridor_scenes: Array[PackedScene] = []
@export var vertical_corridor_scenes: Array[PackedScene] = []

@export var terminal_chunk_scenes: Array[PackedScene] = []

@export_range(1, 100, 1)
var chunk_count: int = 8

@export_range(1, 100, 1)
var max_generation_attempts: int = 20

@export_range(0.0, 8.0, 1.0)
var bounds_overlap_tolerance: float = 4.0


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


func _ready() -> void:
	_initialize_components()
	generate_level()


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

	_components_initialized = true


func _sync_context_from_exports() -> void:
	context.generated_chunks = generated_chunks

	context.start_chunk_scene = start_chunk_scene

	context.chunk_scenes = chunk_scenes
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


# ==================================================
# GENERATION
# ==================================================

func generate_level() -> void:
	_initialize_components()
	_sync_context_from_exports()

	if not _configuration_is_valid():
		return

	context.active_generation_seed = rng.initialize(
		generation_seed,
		use_random_seed
	)

	print(
		"Generation seed: ",
		context.active_generation_seed
	)

	graph_builder.build()

	if not graph_builder.is_valid():
		push_error(
			"LevelGenerator: Generated graph is invalid."
		)
		return

	generation_debug.print_level_graph()

	for attempt in range(
		1,
		max_generation_attempts + 1
	):
		_begin_generation_attempt()
		_generate_attempt()

		if _generation_is_complete():
			generation_debug.print_generation_result(
				attempt
			)
			return

	push_warning(
		"LevelGenerator: Could not generate a complete "
		+ "level after "
		+ str(max_generation_attempts)
		+ " attempts."
	)

	generation_debug.print_generation_result(
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

	if (
		context.graph_node_chunks.size()
		!= context.level_graph.nodes.size()
	):
		return


func _generation_is_complete() -> bool:
	return (
		context.normal_chunks_placed
		== context.chunk_count
		and context.graph_node_chunks.size()
			== context.level_graph.nodes.size()
		and chunk_tools.count_open_sockets(
			context.placed_chunks
		) == 0
	)
