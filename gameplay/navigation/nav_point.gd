# Authored waypoint for LevelNavigation. Its connections become bidirectional
# links when both endpoints belong to the navigation node.
extends Marker2D
class_name NavPoint


@export var connections: Array[NavPoint] = []
