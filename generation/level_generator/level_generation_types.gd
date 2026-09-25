# Physical placement categories shared by the solvers and scene-pool checks.
# Corridor orientation selects a pool; both orientations use ChunkType.CORRIDOR.
extends RefCounted
class_name LevelGenerationTypes


enum PlacementKind {
	GROWTH,
	HORIZONTAL_CORRIDOR,
	VERTICAL_CORRIDOR,
	TERMINAL,
}
