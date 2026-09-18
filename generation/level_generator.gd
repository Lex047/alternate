extends Node2D
class_name LevelGenerator


enum PlacementKind {
	GROWTH,
	HORIZONTAL_CORRIDOR,
	VERTICAL_CORRIDOR,
	TERMINAL,
}

# ==================================================
# RNG CONSTANTS
# ==================================================

const GRAPH_SEED_SALT: int = 0x2C9277B5
const SPATIAL_SEED_SALT: int = 0x19A4E6D3


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


# First half = expansion.
# Second half = tapering.
@export_range(0.0, 1.0, 0.05)
var terminal_start_ratio: float = 0.5


@export_range(1, 100, 1)
var max_generation_attempts: int = 20


@export_range(0.0, 8.0, 1.0)
var bounds_overlap_tolerance: float = 4.0


# ==================================================
# GRAPH SETTINGS
# ==================================================

@export_category("Graph")

# Maximum number of logical children a graph node
# may have.
#
# A non-start room also needs one connection
# back to its parent.
#
# Example:
#
# max_graph_children = 2
#
#          child
#            |
# parent -- room -- child
#
# This room therefore needs 3 physical connections.
@export_range(1, 4, 1)
var max_graph_children: int = 2


# Higher values encourage side branches.
#
# Lower values encourage longer main paths.
@export_range(0.0, 1.0, 0.05)
var graph_branch_chance: float = 0.35


# ==================================================
# SOLVER SETTINGS
# ==================================================

@export_category("Solver")

# How many times one graph node / closure decision may
# be retried locally before the solver gives up on that
# branch and propagates failure upward.
@export_range(1, 8, 1)
var max_local_backtrack_retries: int = 4

# Hard safety cap for one complete generation attempt.
@export_range(1, 1000, 1)
var max_solver_backtracks: int = 250


# ==================================================
# RANDOMNESS SETTINGS
# ==================================================

@export_category("Randomness")

@export var generation_seed: int = 12345

# When enabled, a new seed is generated each time
# generate_level() begins.
@export var use_random_seed: bool = false


# ==================================================
# NODE REFERENCES
# ==================================================

@onready var generated_chunks: Node2D = $GeneratedChunks


# ==================================================
# RANDOM STATE
# ==================================================

# Used by the abstract logical graph.
var graph_rng := RandomNumberGenerator.new()

# Used by physical chunk placement.
var generation_rng := RandomNumberGenerator.new()

# The actual seed being used for the current level.
var active_generation_seed: int = 0


# ==================================================
# SOLVER STATE
# ==================================================

var solver_backtracks: int = 0


# ==================================================
# GRAPH STATE
# ==================================================

# Maps:
#
# LevelGraphNode.id -> physical Chunk
#
# This lets us know which physical room represents
# each logical graph node.
var graph_node_chunks: Dictionary = {}

var level_graph := LevelGraph.new()


# ==================================================
# GENERATION STATE
# ==================================================

var placed_chunks: Array[Chunk] = []


# Only actual growth rooms count toward chunk_count.
var normal_chunks_placed: int = 0


# Structural connector chunks do not count toward
# chunk_count.
var horizontal_corridors_placed: int = 0
var vertical_corridors_placed: int = 0


var terminals_placed: int = 0


# ==================================================
# CHUNK USAGE STATE
# ==================================================

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
# SEEDED RNG
# ==================================================

func _initialize_generation_rng() -> void:
	if use_random_seed:
		generation_rng.randomize()

		active_generation_seed = (
			generation_rng.seed
		)
	else:
		active_generation_seed = generation_seed

	graph_rng.seed = (
		active_generation_seed
		^ GRAPH_SEED_SALT
	)

	generation_rng.seed = (
		active_generation_seed
		^ SPATIAL_SEED_SALT
	)

	print(
		"Generation seed: ",
		active_generation_seed
	)

func _shuffle_with_generation_rng(
	array: Array
) -> void:
	if array.size() <= 1:
		return

	for i in range(
		array.size() - 1,
		0,
		-1
	):
		var random_index := (
			generation_rng.randi_range(
				0,
				i
			)
		)

		var temporary_value = array[i]

		array[i] = array[random_index]
		array[random_index] = temporary_value

# ==================================================
# GRAPH GENERATION
# ==================================================

func _build_level_graph() -> void:
	level_graph.clear()

	var start_node := level_graph.create_node(
		LevelGraphNode.NodeType.START
	)

	# Nodes which are still allowed to receive children.
	var expandable_nodes: Array[LevelGraphNode] = []
	expandable_nodes.append(start_node)

	# Usually we continue growing from the newest room,
	# producing a main path.
	#
	# Sometimes graph_branch_chance makes us pick an
	# older node instead, producing a branch.
	var latest_node: LevelGraphNode = start_node

	for i in range(chunk_count):
		var parent := _choose_graph_parent(
			expandable_nodes,
			latest_node
		)

		if not parent:
			push_error(
				"LevelGenerator: Graph ran out "
				+ "of expandable nodes."
			)
			return

		var growth_node := (
			level_graph.create_node(
				LevelGraphNode.NodeType.GROWTH
			)
		)

		level_graph.add_edge(
			parent,
			growth_node
		)

		# The new room can itself be expanded later.
		expandable_nodes.append(
			growth_node
		)

		latest_node = growth_node

		# START currently gets exactly one outgoing logical
		# branch. We can make this configurable later once
		# graph generation understands chunk socket metadata.
		if (
			parent == start_node
			or parent.children.size()
			>= max_graph_children
		):
			expandable_nodes.erase(parent)


func _choose_graph_parent(
	expandable_nodes: Array[LevelGraphNode],
	latest_node: LevelGraphNode
) -> LevelGraphNode:
	if expandable_nodes.is_empty():
		return null

	if expandable_nodes.size() == 1:
		return expandable_nodes[0]

	# Usually continue from the newest node.
	#
	# This produces a recognizable main path instead
	# of completely random bush-like graphs.
	if (
		latest_node
		and expandable_nodes.has(latest_node)
		and graph_rng.randf() >= graph_branch_chance
	):
		return latest_node

	# Otherwise branch from an older available node.
	var index := graph_rng.randi_range(
		0,
		expandable_nodes.size() - 1
	)

	return expandable_nodes[index]


func _level_graph_is_valid() -> bool:
	if not level_graph.root:
		push_error(
			"LevelGenerator: Graph has no root."
		)
		return false

	if (
		level_graph.root.node_type
		!= LevelGraphNode.NodeType.START
	):
		push_error(
			"LevelGenerator: Graph root is not START."
		)
		return false

	if level_graph.root.parent:
		push_error(
			"LevelGenerator: START has a parent."
		)
		return false

	var growth_count := (
		level_graph.count_nodes_of_type(
			LevelGraphNode.NodeType.GROWTH
		)
	)

	if growth_count != chunk_count:
		push_error(
			"LevelGenerator: Graph growth count "
			+ "does not match chunk_count."
		)
		return false

	var visited: Dictionary = {}

	var nodes_to_visit: Array[LevelGraphNode] = []
	nodes_to_visit.append(
		level_graph.root
	)

	while not nodes_to_visit.is_empty():
		var node: LevelGraphNode = (
			nodes_to_visit.pop_front() as LevelGraphNode
		)

		if visited.has(node.id):
			push_error(
				"LevelGenerator: Graph contains "
				+ "a cycle or duplicate connection."
			)
			return false

		visited[node.id] = true

		if (
			node.children.size()
			> max_graph_children
		):
			push_error(
				"LevelGenerator: Graph node exceeds "
				+ "maximum child count."
			)
			return false

		for child in node.children:
			if child.parent != node:
				push_error(
					"LevelGenerator: Broken "
					+ "parent/child relationship."
				)
				return false

			nodes_to_visit.append(child)

	if visited.size() != level_graph.nodes.size():
		push_error(
			"LevelGenerator: Graph contains "
			+ "unreachable nodes."
		)
		return false

	return true
	
func _print_level_graph() -> void:
	print(
		"================ LEVEL GRAPH ================"
	)

	print(
		"Seed: ",
		active_generation_seed,
		" | Nodes: ",
		level_graph.nodes.size(),
		" | Growth: ",
		level_graph.count_nodes_of_type(
			LevelGraphNode.NodeType.GROWTH
		)
	)

	_print_graph_subtree(
		level_graph.root,
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

	for child in node.children:
		_print_graph_subtree(
			child,
			indent + "    "
		)
		


# ==================================================
# GRAPH REALIZATION
# ==================================================


func _realize_graph_children(
	graph_node: LevelGraphNode,
	physical_chunk: Chunk,
	committed_parent_sockets: Array[ChunkSocket]
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
				physical_chunk,
				child_node,
				committed_parent_sockets
			)
		)

		if not child_chunk:
			return false

		graph_node_chunks[
			child_node.id
		] = child_chunk

		# IMPORTANT:
		#
		# Re-check previously completed graph rooms
		# after EVERY new graph placement.
		#
		# This is what prevents a new room from
		# boxing in an older unused socket.
		if not _graph_frontier_is_closable():
			return false

	return true


func _solve_graph_node(
	graph_node: LevelGraphNode,
	physical_chunk: Chunk
) -> bool:
	# Leaf nodes have no graph children.
	if graph_node.children.is_empty():
		return true

	for _retry in range(
		max_local_backtrack_retries
	):
		if (
			solver_backtracks
			>= max_solver_backtracks
		):
			return false

		# --------------------------------------
		# SNAPSHOT
		# --------------------------------------

		var placed_count_before: int = (
			placed_chunks.size()
		)

		var normal_before: int = (
			normal_chunks_placed
		)

		var horizontal_before: int = (
			horizontal_corridors_placed
		)

		var vertical_before: int = (
			vertical_corridors_placed
		)

		var terminals_before: int = (
			terminals_placed
		)

		var usage_before: Dictionary = (
			chunk_usage.duplicate(true)
		)

		var graph_map_before: Dictionary = (
			graph_node_chunks.duplicate(true)
		)

		var committed_parent_sockets: Array[ChunkSocket] = []

		# --------------------------------------
		# TRY THIS NODE
		# --------------------------------------

		var children_realized: bool = (
			_realize_graph_children(
				graph_node,
				physical_chunk,
				committed_parent_sockets
			)
		)

		var subtree_solved: bool = (
			children_realized
		)

		# --------------------------------------
		# RECURSE INTO CHILDREN
		# --------------------------------------

		if subtree_solved:
			for child: LevelGraphNode in (
				graph_node.children
			):
				var child_chunk: Chunk = (
					graph_node_chunks.get(
						child.id,
						null
					) as Chunk
				)

				if not child_chunk:
					subtree_solved = false
					break

				if not _solve_graph_node(
					child,
					child_chunk
				):
					subtree_solved = false
					break

		if subtree_solved:
			return true

		# --------------------------------------
		# BACKTRACK
		# --------------------------------------

		_rollback_solver_state(
			placed_count_before,
			normal_before,
			horizontal_before,
			vertical_before,
			terminals_before,
			usage_before,
			graph_map_before
		)

		# These sockets belong to physical chunks
		# that existed before the snapshot, so
		# freeing the newly placed children does
		# not automatically reopen them.
		for socket: ChunkSocket in (
			committed_parent_sockets
		):
			if is_instance_valid(socket):
				socket.is_used = false

		if not _register_solver_backtrack():
			return false

	return false


func _try_place_graph_child(
	parent_chunk: Chunk,
	child_node: LevelGraphNode,
	committed_parent_sockets: Array[ChunkSocket]
) -> Chunk:
	var parent_sockets: Array[ChunkSocket] = (
		parent_chunk.get_available_sockets()
	)

	_shuffle_with_generation_rng(
		parent_sockets
	)

	for target_socket: ChunkSocket in parent_sockets:
		var corridor_kind: int = (
			_get_required_corridor_kind(
				parent_chunk,
				target_socket
			)
		)

		var corridor_pool: Array[PackedScene] = []

		if (
			corridor_kind
			== PlacementKind.HORIZONTAL_CORRIDOR
		):
			corridor_pool = horizontal_corridor_scenes

		elif (
			corridor_kind
			== PlacementKind.VERTICAL_CORRIDOR
		):
			corridor_pool = vertical_corridor_scenes

		else:
			continue

		var corridor_candidates: Array[PackedScene] = (
			_get_usage_prioritized_scenes(
				corridor_pool
			)
		)

		for corridor_scene: PackedScene in corridor_candidates:
			var corridor: Chunk = _spawn_chunk(
				corridor_scene,
				Vector2.ZERO
			)

			if not corridor:
				continue

			if not _scene_matches_placement_kind(
				corridor,
				corridor_kind
			):
				_discard_chunk(corridor)
				continue

			var matching_sockets: Array[ChunkSocket] = (
				_find_matching_sockets(
					corridor,
					target_socket
				)
			)

			_shuffle_with_generation_rng(
				matching_sockets
			)

			for corridor_entrance: ChunkSocket in matching_sockets:
				_align_chunk(
					corridor,
					corridor_entrance,
					target_socket
				)

				if _overlaps_chunks(
					corridor,
					placed_chunks
				):
					continue

				# Temporarily connect parent -> corridor.
				target_socket.is_used = true
				corridor_entrance.is_used = true

				var occupied_with_corridor: Array[Chunk] = (
					_copy_chunk_array(
						placed_chunks
					)
				)

				occupied_with_corridor.append(
					corridor
				)

				var corridor_exits: Array[ChunkSocket] = (
					corridor.get_available_sockets()
				)

				_shuffle_with_generation_rng(
					corridor_exits
				)

				for corridor_exit: ChunkSocket in corridor_exits:
					var child_chunk: Chunk = (
						_try_place_graph_growth_room(
							corridor,
							corridor_exit,
							child_node,
							occupied_with_corridor
						)
					)

					if not child_chunk:
						continue

					# --------------------------------
					# COMMIT GRAPH EDGE
					# --------------------------------

					placed_chunks.append(
						corridor
					)

					placed_chunks.append(
						child_chunk
					)

					if (
						corridor_kind
						== PlacementKind.HORIZONTAL_CORRIDOR
					):
						horizontal_corridors_placed += 1
					else:
						vertical_corridors_placed += 1

					normal_chunks_placed += 1

					_record_chunk_usage(
						corridor_scene
					)

					# This socket belongs to a chunk that existed
					# before this child edge. Record it so a local
					# backtrack can reopen it after freeing the new
					# corridor / child subtree.
					committed_parent_sockets.append(
						target_socket
					)

					return child_chunk

				# This corridor alignment couldn't
				# realize the graph child.
				target_socket.is_used = false
				corridor_entrance.is_used = false

			_discard_chunk(corridor)

	return null


func _try_place_graph_growth_room(
	corridor: Chunk,
	target_socket: ChunkSocket,
	graph_node: LevelGraphNode,
	occupied_chunks: Array[Chunk]
) -> Chunk:
	var candidate_scenes: Array[PackedScene] = (
		_get_usage_prioritized_scenes(
			chunk_scenes
		)
	)

	for scene: PackedScene in candidate_scenes:
		var candidate: Chunk = _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not candidate:
			continue

		if not _scene_matches_placement_kind(
			candidate,
			PlacementKind.GROWTH
		):
			_discard_chunk(candidate)
			continue

		if not _chunk_types_can_connect(
			corridor,
			candidate
		):
			_discard_chunk(candidate)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			_find_matching_sockets(
				candidate,
				target_socket
			)
		)

		_shuffle_with_generation_rng(
			matching_sockets
		)

		for entrance_socket: ChunkSocket in matching_sockets:
			_align_chunk(
				candidate,
				entrance_socket,
				target_socket
			)

			if _overlaps_chunks(
				candidate,
				occupied_chunks
			):
				continue

			# Temporarily establish corridor -> room.
			target_socket.is_used = true
			entrance_socket.is_used = true

			# --------------------------------------
			# GRAPH DEGREE CHECK
			# --------------------------------------
			#
			# The room must have enough sockets left
			# to physically represent all of this
			# graph node's children.

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

			# Accepted.
			_record_chunk_usage(scene)

			return candidate

		_discard_chunk(candidate)

	return null


func _graph_frontier_is_closable() -> bool:
	var occupied_chunks: Array[Chunk] = (
		_copy_chunk_array(placed_chunks)
	)

	# ------------------------------------------
	# COMPLETED LOGICAL ROOMS
	# ------------------------------------------
	#
	# Once all logical children of a graph node
	# have been physically realized, every socket
	# still open on that room is an EXTRA socket.
	#
	# Therefore every remaining socket must still
	# be capable of eventually becoming:
	#
	# ROOM -> CORRIDOR -> TERMINAL

	for graph_node: LevelGraphNode in level_graph.nodes:
		if not graph_node_chunks.has(graph_node.id):
			continue

		var all_children_realized: bool = true

		for child: LevelGraphNode in graph_node.children:
			if not graph_node_chunks.has(child.id):
				all_children_realized = false
				break

		# This node still needs logical children,
		# so some of its sockets are reserved for
		# future graph growth.
		if not all_children_realized:
			continue

		var physical_chunk: Chunk = (
			graph_node_chunks.get(
				graph_node.id,
				null
			) as Chunk
		)

		if not physical_chunk:
			return false

		for socket: ChunkSocket in (
			physical_chunk.get_available_sockets()
		):
			if not _graph_socket_can_eventually_close(
				physical_chunk,
				socket,
				occupied_chunks
			):
				return false
				
	
	

	# ------------------------------------------
	# EXTRA CORRIDOR EXITS
	# ------------------------------------------
	#
	# A graph corridor normally has its entrance
	# and graph-child exit consumed.
	#
	# If a corridor scene exposes any additional
	# exits, those exits must be terminatable.

	for chunk: Chunk in occupied_chunks:
		if (
			chunk.chunk_type
			!= Chunk.ChunkType.CORRIDOR
		):
			continue

		for socket: ChunkSocket in (
			chunk.get_available_sockets()
		):
			if not _socket_can_fit_scene_pool(
				chunk,
				socket,
				terminal_chunk_scenes,
				occupied_chunks,
				PlacementKind.TERMINAL
			):
				return false

	return true


func _graph_socket_can_eventually_close(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	occupied_chunks: Array[Chunk]
) -> bool:
	var corridor_kind: int = (
		_get_required_corridor_kind(
			current_chunk,
			target_socket
		)
	)

	var corridor_pool: Array[PackedScene] = []

	if (
		corridor_kind
		== PlacementKind.HORIZONTAL_CORRIDOR
	):
		corridor_pool = horizontal_corridor_scenes

	elif (
		corridor_kind
		== PlacementKind.VERTICAL_CORRIDOR
	):
		corridor_pool = vertical_corridor_scenes

	else:
		return false

	for corridor_scene: PackedScene in corridor_pool:
		var test_corridor: Chunk = _spawn_chunk(
			corridor_scene,
			Vector2.ZERO
		)

		if not test_corridor:
			continue

		if not _scene_matches_placement_kind(
			test_corridor,
			corridor_kind
		):
			_discard_chunk(test_corridor)
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			test_corridor
		):
			_discard_chunk(test_corridor)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			_find_matching_sockets(
				test_corridor,
				target_socket
			)
		)

		for corridor_entrance: ChunkSocket in matching_sockets:
			_align_chunk(
				test_corridor,
				corridor_entrance,
				target_socket
			)

			if _overlaps_chunks(
				test_corridor,
				occupied_chunks
			):
				continue

			# Hide the entrance so only actual
			# corridor exits are examined.
			corridor_entrance.is_used = true

			var occupied_with_corridor: Array[Chunk] = (
				_copy_chunk_array(
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
				if not _socket_can_fit_scene_pool(
					test_corridor,
					exit_socket,
					terminal_chunk_scenes,
					occupied_with_corridor,
					PlacementKind.TERMINAL
				):
					corridor_can_close = false
					break

			corridor_entrance.is_used = false

			if corridor_can_close:
				_discard_chunk(test_corridor)
				return true

		_discard_chunk(test_corridor)

	return false


# ==================================================
# GENERATION
# ==================================================

func generate_level() -> void:
	if not _configuration_is_valid():
		return

	_initialize_generation_rng()

	# ------------------------------------------
	# LOGICAL GRAPH GENERATION
	# ------------------------------------------

	_build_level_graph()

	if not _level_graph_is_valid():
		push_error(
			"LevelGenerator: Generated graph is invalid."
		)
		return

	_print_level_graph()

	# ------------------------------------------
	# PHYSICAL LEVEL GENERATION
	# ------------------------------------------

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
	graph_node_chunks.clear()

	normal_chunks_placed = 0

	horizontal_corridors_placed = 0
	vertical_corridors_placed = 0

	terminals_placed = 0

	solver_backtracks = 0

	_initialize_chunk_usage()


func _generate_attempt() -> void:
	var start_chunk: Chunk = _spawn_chunk(
		start_chunk_scene,
		Vector2.ZERO
	)

	if not start_chunk:
		return

	placed_chunks.append(start_chunk)

	graph_node_chunks[
		level_graph.root.id
	] = start_chunk

	# ------------------------------------------
	# GRAPH SOLVER
	# ------------------------------------------

	if not _solve_graph_node(
		level_graph.root,
		start_chunk
	):
		return

	if normal_chunks_placed != chunk_count:
		return

	if (
		graph_node_chunks.size()
		!= level_graph.nodes.size()
	):
		return

	# ------------------------------------------
	# DEAD-END CLEANUP
	# ------------------------------------------
	#
	# NOT recursive.
	#
	# If cleanup fails, the whole attempt can
	# currently retry. We'll improve this later.

	_resolve_remaining_sockets()


func _generation_is_complete() -> bool:
	return (
		normal_chunks_placed == chunk_count
		and graph_node_chunks.size()
			== level_graph.nodes.size()
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

	_shuffle_with_generation_rng(
		available_sockets
	)

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

	var growth_capable_branches := (
		_count_growth_capable_branches(
			placed_chunks,
			normal_chunks_placed
		)
	)

	# Important:
	#
	# An open socket is not automatically a useful
	# growth branch. It only counts here if it can
	# physically reach another growth room under the
	# current map state.
	#
	# If the number of growth-capable branches is less
	# than or equal to the number of growth rooms still
	# required, this branch should try to keep growing.
	#
	# If we have surplus growth-capable branches, this
	# branch may safely try to terminate.

	return growth_capable_branches <= remaining_growth


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

		_shuffle_with_generation_rng(
			matching_sockets
		)

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

			# Temporarily complete the connection so the
			# frontier check sees the exact state that would
			# exist if this candidate were accepted.
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
			# GLOBAL FRONTIER VIABILITY
			# --------------------------------------
			#
			# Do not only validate sockets belonging to the
			# new candidate. A newly placed chunk can make an
			# older open socket impossible by occupying the
			# last space that socket could use.
			#
			# This also runs for TERMINAL placement because a
			# terminal can physically block unrelated sockets.

			var placement_is_valid := (
				_all_open_sockets_are_viable(
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
# FRONTIER VIABILITY
# ==================================================


func _all_open_sockets_are_viable(
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> bool:
	# Re-check the entire unresolved frontier after a
	# tentative placement.
	#
	# This catches the important case where the new
	# candidate is fine itself but blocks the final
	# possible continuation of an older socket.
	for chunk in occupied_chunks:
		if not _candidate_sockets_are_viable(
			chunk,
			occupied_chunks,
			projected_normal_count
		):
			return false

	# If growth is still required, never accept a state
	# that has closed or blocked every path to another
	# growth room. One viable branch can still produce
	# several rooms sequentially, so we only require at
	# least one here.
	if projected_normal_count < chunk_count:
		if _count_growth_capable_branches(
			occupied_chunks,
			projected_normal_count
		) <= 0:
			return false

	return true


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

		# ROOM / START:
		#
		# Do not stop at "a corridor fits". Prove that
		# at least one corridor can fit AND that all of the
		# corridor's resulting exits have a legal next
		# destination under the current generation phase.
		if not _room_socket_has_viable_path(
			candidate,
			socket,
			occupied_chunks,
			projected_normal_count
		):
			return false

	return true


func _room_socket_has_viable_path(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> bool:
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
		return _socket_has_viable_corridor_path(
			current_chunk,
			target_socket,
			horizontal_corridor_scenes,
			occupied_chunks,
			PlacementKind.HORIZONTAL_CORRIDOR,
			projected_normal_count
		)

	if (
		required_corridor
			== PlacementKind.VERTICAL_CORRIDOR
	):
		return _socket_has_viable_corridor_path(
			current_chunk,
			target_socket,
			vertical_corridor_scenes,
			occupied_chunks,
			PlacementKind.VERTICAL_CORRIDOR,
			projected_normal_count
		)

	return false


func _socket_has_viable_corridor_path(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	corridor_scenes: Array[PackedScene],
	occupied_chunks: Array[Chunk],
	corridor_kind: int,
	projected_normal_count: int
) -> bool:
	for scene in corridor_scenes:
		var test_corridor := _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not test_corridor:
			continue

		if not _scene_matches_placement_kind(
			test_corridor,
			corridor_kind
		):
			_discard_chunk(test_corridor)
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			test_corridor
		):
			_discard_chunk(test_corridor)
			continue

		var matching_sockets := (
			_find_matching_sockets(
				test_corridor,
				target_socket
			)
		)

		for matching_socket in matching_sockets:
			_align_chunk(
				test_corridor,
				matching_socket,
				target_socket
			)

			if _overlaps_chunks(
				test_corridor,
				occupied_chunks
			):
				continue

			# Hide the entrance socket so only the corridor
			# exits are evaluated below.
			matching_socket.is_used = true

			var occupied_with_corridor := (
				_copy_chunk_array(occupied_chunks)
			)
			occupied_with_corridor.append(test_corridor)

			var exit_sockets := (
				test_corridor.get_available_sockets()
			)

			# A structural corridor that has no remaining
			# exit cannot continue the branch.
			var corridor_is_viable := (
				not exit_sockets.is_empty()
			)

			if corridor_is_viable:
				for exit_socket in exit_sockets:
					if not _corridor_exit_is_viable(
						test_corridor,
						exit_socket,
						occupied_with_corridor,
						projected_normal_count
					):
						corridor_is_viable = false
						break

			matching_socket.is_used = false

			if corridor_is_viable:
				_discard_chunk(test_corridor)
				return true

		_discard_chunk(test_corridor)

	return false


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
# GROWTH-CAPABLE FRONTIER
# ==================================================


func _count_growth_capable_branches(
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> int:
	var count := 0

	for chunk in occupied_chunks:
		for socket in chunk.get_available_sockets():
			if _socket_can_reach_growth(
				chunk,
				socket,
				occupied_chunks,
				projected_normal_count
			):
				count += 1

	return count


func _socket_can_reach_growth(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	occupied_chunks: Array[Chunk],
	projected_normal_count: int
) -> bool:
	# Corridor exits connect directly to growth rooms.
	if (
		current_chunk.chunk_type
			== Chunk.ChunkType.CORRIDOR
	):
		return _socket_can_fit_scene_pool(
			current_chunk,
			target_socket,
			chunk_scenes,
			occupied_chunks,
			PlacementKind.GROWTH
		)

	# ROOM / START sockets first need their structural
	# corridor. Count the branch as growth-capable only
	# if some legal corridor can fit and that corridor
	# still has at least one exit that can accept a
	# growth room.
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
		return _room_socket_can_reach_growth_through_pool(
			current_chunk,
			target_socket,
			horizontal_corridor_scenes,
			occupied_chunks,
			PlacementKind.HORIZONTAL_CORRIDOR,
			projected_normal_count
		)

	if (
		required_corridor
			== PlacementKind.VERTICAL_CORRIDOR
	):
		return _room_socket_can_reach_growth_through_pool(
			current_chunk,
			target_socket,
			vertical_corridor_scenes,
			occupied_chunks,
			PlacementKind.VERTICAL_CORRIDOR,
			projected_normal_count
		)

	return false


func _room_socket_can_reach_growth_through_pool(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	corridor_scenes: Array[PackedScene],
	occupied_chunks: Array[Chunk],
	corridor_kind: int,
	projected_normal_count: int
) -> bool:
	for scene in corridor_scenes:
		var test_corridor := _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not test_corridor:
			continue

		if not _scene_matches_placement_kind(
			test_corridor,
			corridor_kind
		):
			_discard_chunk(test_corridor)
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			test_corridor
		):
			_discard_chunk(test_corridor)
			continue

		var matching_sockets := (
			_find_matching_sockets(
				test_corridor,
				target_socket
			)
		)

		for matching_socket in matching_sockets:
			_align_chunk(
				test_corridor,
				matching_socket,
				target_socket
			)

			if _overlaps_chunks(
				test_corridor,
				occupied_chunks
			):
				continue

			matching_socket.is_used = true

			var occupied_with_corridor := (
				_copy_chunk_array(occupied_chunks)
			)
			occupied_with_corridor.append(test_corridor)

			var exit_sockets := (
				test_corridor.get_available_sockets()
			)

			var all_exits_viable := (
				not exit_sockets.is_empty()
			)
			var has_growth_exit := false

			for exit_socket in exit_sockets:
				if not _corridor_exit_is_viable(
					test_corridor,
					exit_socket,
					occupied_with_corridor,
					projected_normal_count
				):
					all_exits_viable = false
					break

				if _socket_can_fit_scene_pool(
					test_corridor,
					exit_socket,
					chunk_scenes,
					occupied_with_corridor,
					PlacementKind.GROWTH
				):
					has_growth_exit = true

			matching_socket.is_used = false

			if all_exits_viable and has_growth_exit:
				_discard_chunk(test_corridor)
				return true

		_discard_chunk(test_corridor)

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

		# Same usage count remains random,
		# but is now deterministic for the seed.
		_shuffle_with_generation_rng(
			usage_group
		)

		for scene in usage_group:
			result.append(scene)

	return result


# ==================================================
# FINAL RESOLUTION
# ==================================================


func _resolve_remaining_sockets() -> bool:
	while true:
		if _count_open_sockets() == 0:
			return true

		var made_progress: bool = false

		var chunks_to_check: Array[Chunk] = (
			_copy_chunk_array(placed_chunks)
		)

		_shuffle_with_generation_rng(
			chunks_to_check
		)

		for chunk: Chunk in chunks_to_check:
			var open_sockets: Array[ChunkSocket] = (
				chunk.get_available_sockets()
			)

			_shuffle_with_generation_rng(
				open_sockets
			)

			for socket: ChunkSocket in open_sockets:
				if socket.is_used:
					continue

				if _try_close_graph_socket(
					chunk,
					socket
				):
					made_progress = true

		# Nothing else can be closed.
		if not made_progress:
			return false

	return true

func _try_close_graph_socket(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> bool:
	# A correctly authored terminal must never expose an
	# unused socket after its entrance is connected.
	if (
		current_chunk.chunk_type
		== Chunk.ChunkType.TERMINAL
	):
		return false

	# An open structural corridor exits directly into
	# a terminal.
	if (
		current_chunk.chunk_type
		== Chunk.ChunkType.CORRIDOR
	):
		return _try_place_graph_terminal(
			current_chunk,
			target_socket
		)

	# Any non-corridor room/start socket first receives
	# the required structural corridor. The corridor's
	# remaining exit will be handled by the next cleanup
	# iteration and closed with a terminal.
	var corridor_kind: int = (
		_get_required_corridor_kind(
			current_chunk,
			target_socket
		)
	)

	if (
		corridor_kind
		== PlacementKind.HORIZONTAL_CORRIDOR
	):
		return _try_place_graph_closure_corridor(
			current_chunk,
			target_socket,
			horizontal_corridor_scenes,
			PlacementKind.HORIZONTAL_CORRIDOR
		)

	if (
		corridor_kind
		== PlacementKind.VERTICAL_CORRIDOR
	):
		return _try_place_graph_closure_corridor(
			current_chunk,
			target_socket,
			vertical_corridor_scenes,
			PlacementKind.VERTICAL_CORRIDOR
		)

	return false


func _try_place_graph_closure_corridor(
	current_chunk: Chunk,
	target_socket: ChunkSocket,
	corridor_scenes: Array[PackedScene],
	corridor_kind: int
) -> bool:
	var candidate_scenes: Array[PackedScene] = (
		_get_usage_prioritized_scenes(
			corridor_scenes
		)
	)

	for scene: PackedScene in candidate_scenes:
		var corridor: Chunk = _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not corridor:
			continue

		if not _scene_matches_placement_kind(
			corridor,
			corridor_kind
		):
			_discard_chunk(corridor)
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			corridor
		):
			_discard_chunk(corridor)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			_find_matching_sockets(
				corridor,
				target_socket
			)
		)

		_shuffle_with_generation_rng(
			matching_sockets
		)

		for corridor_entrance: ChunkSocket in matching_sockets:
			_align_chunk(
				corridor,
				corridor_entrance,
				target_socket
			)

			if _overlaps_chunks(
				corridor,
				placed_chunks
			):
				continue

			# Temporarily connect the room
			# to this corridor.
			target_socket.is_used = true
			corridor_entrance.is_used = true

			var corridor_exits: Array[ChunkSocket] = (
				corridor.get_available_sockets()
			)

			# Closure corridors should lead to exactly
			# one terminal destination.
			if corridor_exits.size() != 1:
				target_socket.is_used = false
				corridor_entrance.is_used = false
				continue

			var corridor_exit: ChunkSocket = (
				corridor_exits[0]
			)

			# Temporarily add the corridor so terminal
			# collision checks include it.
			placed_chunks.append(corridor)

			# --------------------------------------
			# ATOMIC CLOSURE
			# --------------------------------------
			#
			# Do NOT accept the corridor unless its
			# terminal can also be placed immediately.

			if _try_place_graph_terminal(
				corridor,
				corridor_exit
			):
				if (
					corridor_kind
					== PlacementKind.HORIZONTAL_CORRIDOR
				):
					horizontal_corridors_placed += 1
				else:
					vertical_corridors_placed += 1

				_record_chunk_usage(scene)

				return true

			# --------------------------------------
			# ROLLBACK FAILED CLOSURE
			# --------------------------------------

			placed_chunks.erase(corridor)

			target_socket.is_used = false
			corridor_entrance.is_used = false

		_discard_chunk(corridor)

	return false


func _try_place_graph_terminal(
	current_chunk: Chunk,
	target_socket: ChunkSocket
) -> bool:
	var candidate_scenes: Array[PackedScene] = (
		_get_usage_prioritized_scenes(
			terminal_chunk_scenes
		)
	)

	for scene: PackedScene in candidate_scenes:
		var terminal: Chunk = _spawn_chunk(
			scene,
			Vector2.ZERO
		)

		if not terminal:
			continue

		if not _scene_matches_placement_kind(
			terminal,
			PlacementKind.TERMINAL
		):
			_discard_chunk(terminal)
			continue

		if not _chunk_types_can_connect(
			current_chunk,
			terminal
		):
			_discard_chunk(terminal)
			continue

		var matching_sockets: Array[ChunkSocket] = (
			_find_matching_sockets(
				terminal,
				target_socket
			)
		)

		_shuffle_with_generation_rng(
			matching_sockets
		)

		for terminal_entrance: ChunkSocket in matching_sockets:
			_align_chunk(
				terminal,
				terminal_entrance,
				target_socket
			)

			if _overlaps_chunks(
				terminal,
				placed_chunks
			):
				continue

			target_socket.is_used = true
			terminal_entrance.is_used = true

			# A terminal is an actual dead end. If the scene
			# exposes another unused socket, reject it here.
			if not terminal.get_available_sockets().is_empty():
				target_socket.is_used = false
				terminal_entrance.is_used = false
				continue

			placed_chunks.append(terminal)
			terminals_placed += 1

			_record_chunk_usage(scene)

			return true

		_discard_chunk(terminal)

	return false


# ==================================================
# SOLVER ROLLBACK
# ==================================================


func _rollback_solver_state(
	placed_count_before: int,
	normal_before: int,
	horizontal_before: int,
	vertical_before: int,
	terminals_before: int,
	usage_before: Dictionary,
	graph_map_before: Dictionary
) -> void:
	while placed_chunks.size() > placed_count_before:
		var chunk_to_remove: Chunk = (
			placed_chunks.pop_back() as Chunk
		)

		if chunk_to_remove:
			_discard_chunk(chunk_to_remove)

	normal_chunks_placed = normal_before
	horizontal_corridors_placed = horizontal_before
	vertical_corridors_placed = vertical_before
	terminals_placed = terminals_before

	chunk_usage = usage_before.duplicate(true)
	graph_node_chunks = graph_map_before.duplicate(true)


func _register_solver_backtrack() -> bool:
	solver_backtracks += 1

	return (
		solver_backtracks
		<= max_solver_backtracks
	)


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
		"Seed: ",
		active_generation_seed,
		" | Generation attempt: ",
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
		" | Backtracks: ",
		solver_backtracks,
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
