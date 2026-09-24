extends RefCounted
class_name LevelGraphNode


enum NodeType {
	START,
	GROWTH,
	GOAL,
}


var id: int = -1
var node_type: int = NodeType.GROWTH

var parent: LevelGraphNode = null
var children: Array[LevelGraphNode] = []


func _init(
	node_id: int = -1,
	type: int = NodeType.GROWTH
) -> void:
	id = node_id
	node_type = type


func get_degree() -> int:
	var degree: int = children.size()

	if parent:
		degree += 1

	return degree
