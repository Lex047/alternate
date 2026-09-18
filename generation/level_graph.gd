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
	var node := LevelGraphNode.new(
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
	var count := 0

	for node in nodes:
		if node.node_type == node_type:
			count += 1

	return count
