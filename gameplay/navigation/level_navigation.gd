extends Node2D
class_name LevelNavigation


var astar: AStar2D = AStar2D.new()

var nav_points: Array[NavPoint] = []
var point_ids: Dictionary = {}


func _ready() -> void:
	build_graph()


func build_graph() -> void:
	astar.clear()
	nav_points.clear()
	point_ids.clear()

	for child in get_children():
		if child is NavPoint:
			nav_points.append(child)

	for nav_point in nav_points:
		var point_id: int = astar.get_available_point_id()

		point_ids[nav_point] = point_id

		astar.add_point(
			point_id,
			nav_point.global_position
		)

	for nav_point in nav_points:
		var from_id: int = point_ids[nav_point]

		for connection in nav_point.connections:
			if not is_instance_valid(connection):
				continue

			if not point_ids.has(connection):
				continue

			var to_id: int = point_ids[connection]

			if astar.are_points_connected(
				from_id,
				to_id
			):
				continue

			astar.connect_points(
				from_id,
				to_id,
				true
			)


func find_navigation_path(
	from_position: Vector2,
	to_position: Vector2
) -> PackedVector2Array:
	if astar.get_point_count() == 0:
		return PackedVector2Array()

	var from_id: int = astar.get_closest_point(
		from_position
	)

	var to_id: int = astar.get_closest_point(
		to_position
	)

	if from_id == -1 or to_id == -1:
		return PackedVector2Array()

	return astar.get_point_path(
		from_id,
		to_id
	)
