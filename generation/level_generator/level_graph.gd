extends RefCounted
class_name LevelGraph


var root: LevelGraphNode = null
var nodes: Array[LevelGraphNode] = []


func clear() -> void:
	root = null
	nodes.clear()


func create_node(
	node_type: int
) -> LevelGraphNode:
	var node: LevelGraphNode = LevelGraphNode.new(
		nodes.size(),
		node_type
	)

	nodes.append(node)

	if node_type == LevelGraphNode.NodeType.START:
		root = node

	return node


func add_edge(
	parent: LevelGraphNode,
	child: LevelGraphNode
) -> void:
	if not parent:
		return

	if not child:
		return

	if parent.children.has(child):
		return

	parent.children.append(child)
	child.parent = parent


func count_nodes_of_type(
	node_type: int
) -> int:
	var count: int = 0

	for node: LevelGraphNode in nodes:
		if node.node_type == node_type:
			count += 1

	return count


func get_goal_node() -> LevelGraphNode:
	for node: LevelGraphNode in nodes:
		if node.node_type == LevelGraphNode.NodeType.GOAL:
			return node

	return null


func get_descendants(
	node: LevelGraphNode
) -> Array[LevelGraphNode]:
	var result: Array[LevelGraphNode] = []

	if not node:
		return result

	var nodes_to_visit: Array[LevelGraphNode] = []

	for child: LevelGraphNode in node.children:
		nodes_to_visit.append(
			child
		)

	while not nodes_to_visit.is_empty():
		var current: LevelGraphNode = (
			nodes_to_visit.pop_front()
			as LevelGraphNode
		)

		result.append(
			current
		)

		for child: LevelGraphNode in current.children:
			nodes_to_visit.append(
				child
			)

	return result


func get_route_to_node(
	target: LevelGraphNode
) -> Array[LevelGraphNode]:
	var route: Array[LevelGraphNode] = []

	if not target:
		return route

	var current: LevelGraphNode = target

	while current:
		route.push_front(
			current
		)

		current = current.parent

	return route


func get_start_to_goal_route() -> Array[LevelGraphNode]:
	var goal_node: LevelGraphNode = (
		get_goal_node()
	)

	if not goal_node:
		return []

	return get_route_to_node(
		goal_node
	)
