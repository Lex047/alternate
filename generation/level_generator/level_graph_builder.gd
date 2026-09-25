# Builds a rooted room tree with one START branch, a configured number of growth
# rooms, and a GOAL attached to a deepest growth leaf. Branch probability and
# child limits shape the topology before the spatial solver chooses scenes.
extends RefCounted
class_name LevelGraphBuilder


var context: LevelGenerationContext
var rng: LevelGenerationRng


func _init(
	generation_context: LevelGenerationContext,
	generation_rng: LevelGenerationRng
) -> void:
	context = generation_context
	rng = generation_rng


func build() -> void:
	context.level_graph.clear()

	var start_node: LevelGraphNode = (
		context.level_graph.create_node(
			LevelGraphNode.NodeType.START
		)
	)

	var expandable_nodes: Array[LevelGraphNode] = []
	expandable_nodes.append(start_node)

	var latest_node: LevelGraphNode = start_node

	for _i in range(context.chunk_count):
		var parent: LevelGraphNode = _choose_parent(
			expandable_nodes,
			latest_node
		)

		if not parent:
			push_error(
				"LevelGenerator: Graph ran out "
				+ "of expandable nodes."
			)
			return

		var growth_node: LevelGraphNode = (
			context.level_graph.create_node(
				LevelGraphNode.NodeType.GROWTH
			)
		)

		context.level_graph.add_edge(
			parent,
			growth_node
		)

		expandable_nodes.append(growth_node)
		latest_node = growth_node

		# START currently gets exactly one logical
		# outgoing branch.
		if (
			parent == start_node
			or parent.children.size()
			>= context.max_graph_children
		):
			expandable_nodes.erase(parent)
		
	_add_goal_node()


func _add_goal_node() -> void:
	var goal_parent: LevelGraphNode = (
		_choose_goal_parent()
	)

	if not goal_parent:
		push_error(
			"LevelGenerator: Could not find a "
			+ "growth leaf for the GOAL node."
		)
		return

	var goal_node: LevelGraphNode = (
		context.level_graph.create_node(
			LevelGraphNode.NodeType.GOAL
		)
	)

	context.level_graph.add_edge(
		goal_parent,
		goal_node
	)


func _choose_goal_parent() -> LevelGraphNode:
	var deepest_leaves: Array[LevelGraphNode] = []
	var deepest_depth: int = -1

	for node: LevelGraphNode in context.level_graph.nodes:
		if (
			node.node_type
			!= LevelGraphNode.NodeType.GROWTH
		):
			continue

		if not node.children.is_empty():
			continue

		var depth: int = _get_node_depth(node)

		if depth > deepest_depth:
			deepest_depth = depth
			deepest_leaves.clear()
			deepest_leaves.append(node)

		elif depth == deepest_depth:
			deepest_leaves.append(node)

	if deepest_leaves.is_empty():
		return null

	if deepest_leaves.size() == 1:
		return deepest_leaves[0]

	var index: int = rng.graph_rng.randi_range(
		0,
		deepest_leaves.size() - 1
	)

	return deepest_leaves[index]


func _get_node_depth(
	node: LevelGraphNode
) -> int:
	var depth: int = 0
	var current: LevelGraphNode = node

	while current.parent:
		depth += 1
		current = current.parent

	return depth


func _choose_parent(
	expandable_nodes: Array[LevelGraphNode],
	latest_node: LevelGraphNode
) -> LevelGraphNode:
	if expandable_nodes.is_empty():
		return null

	if expandable_nodes.size() == 1:
		return expandable_nodes[0]

	if (
		latest_node
		and expandable_nodes.has(latest_node)
		and rng.graph_rng.randf()
		>= context.graph_branch_chance
	):
		return latest_node

	var index: int = rng.graph_rng.randi_range(
		0,
		expandable_nodes.size() - 1
	)

	return expandable_nodes[index]


func is_valid() -> bool:
	if not context.level_graph.root:
		push_error(
			"LevelGenerator: Graph has no root."
		)
		return false

	if (
		context.level_graph.root.node_type
		!= LevelGraphNode.NodeType.START
	):
		push_error(
			"LevelGenerator: Graph root is not START."
		)
		return false

	if context.level_graph.root.parent:
		push_error(
			"LevelGenerator: START has a parent."
		)
		return false

	var growth_count: int = (
		context.level_graph.count_nodes_of_type(
			LevelGraphNode.NodeType.GROWTH
		)
	)

	if growth_count != context.chunk_count:
		push_error(
			"LevelGenerator: Graph growth count "
			+ "does not match chunk_count."
		)
		return false
		
	var goal_count: int = (
		context.level_graph.count_nodes_of_type(
			LevelGraphNode.NodeType.GOAL
		)
	)

	if goal_count != 1:
		push_error(
			"LevelGenerator: Graph must contain "
			+ "exactly one GOAL node."
		)
		return false

	var visited: Dictionary = {}

	var nodes_to_visit: Array[LevelGraphNode] = []
	nodes_to_visit.append(
		context.level_graph.root
	)

	while not nodes_to_visit.is_empty():
		var node: LevelGraphNode = (
			nodes_to_visit.pop_front()
			as LevelGraphNode
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
			> context.max_graph_children
		):
			push_error(
				"LevelGenerator: Graph node exceeds "
				+ "maximum child count."
			)
			return false

		if node.node_type == LevelGraphNode.NodeType.GOAL:
			if not node.children.is_empty():
				push_error(
					"LevelGenerator: GOAL must be a leaf."
				)
				return false

			if (
				not node.parent
				or node.parent.node_type
				!= LevelGraphNode.NodeType.GROWTH
			):
				push_error(
					"LevelGenerator: GOAL must be "
					+ "attached to a GROWTH node."
				)
				return false

		for child: LevelGraphNode in node.children:
			if child.parent != node:
				push_error(
					"LevelGenerator: Broken "
					+ "parent/child relationship."
				)
				return false

			nodes_to_visit.append(child)

	if visited.size() != context.level_graph.nodes.size():
		push_error(
			"LevelGenerator: Graph contains "
			+ "unreachable nodes."
		)
		return false

	return true
