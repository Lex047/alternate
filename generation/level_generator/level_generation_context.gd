extends RefCounted
class_name LevelGenerationContext

# Scene configuration data
var generated_chunks: Node2D

var start_chunk_scene: PackedScene

var chunk_scenes: Array[PackedScene] = []
var goal_chunk_scenes: Array[PackedScene] = []
var horizontal_corridor_scenes: Array[PackedScene] = []
var vertical_corridor_scenes: Array[PackedScene] = []
var terminal_chunk_scenes: Array[PackedScene] = []

var chunk_count: int = 8
var bounds_overlap_tolerance: float = 4.0

var max_graph_children: int = 2
var graph_branch_chance: float = 0.35

var max_local_backtrack_retries: int = 4
var max_solver_backtracks: int = 250


# Runtime generation state.
var active_generation_seed: int = 0
var solver_backtracks: int = 0

var level_graph := LevelGraph.new()
var graph_node_chunks: Dictionary = {}
var graph_edge_corridors: Dictionary = {}
var graph_edge_parent_socket_paths: Dictionary = {}

var closure_branches: Array[Dictionary] = []

var placed_chunks: Array[Chunk] = []

var normal_chunks_placed: int = 0
var goal_chunks_placed: int = 0
var horizontal_corridors_placed: int = 0
var vertical_corridors_placed: int = 0
var terminals_placed: int = 0

var chunk_usage_counts: Dictionary = {}


func reset_attempt_state() -> void:
	placed_chunks.clear()
	graph_node_chunks.clear()
	graph_edge_corridors.clear()
	graph_edge_parent_socket_paths.clear()
	closure_branches.clear()

	normal_chunks_placed = 0
	goal_chunks_placed = 0
	horizontal_corridors_placed = 0
	vertical_corridors_placed = 0
	terminals_placed = 0

	solver_backtracks = 0


func snapshot_closure_branches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for branch: Dictionary in closure_branches:
		result.append(
			branch.duplicate()
		)

	return result


func restore_closure_branches(
	snapshot: Array[Dictionary]
) -> void:
	closure_branches.clear()

	for branch: Dictionary in snapshot:
		closure_branches.append(
			branch.duplicate()
		)
