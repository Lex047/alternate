extends RefCounted
class_name LevelChunkUsage


var context: LevelGenerationContext
var rng: LevelGenerationRng


func _init(
	generation_context: LevelGenerationContext,
	generation_rng: LevelGenerationRng
) -> void:
	context = generation_context
	rng = generation_rng


func initialize() -> void:
	context.chunk_usage_counts.clear()

	_register_pool(context.chunk_scenes)
	_register_pool(context.horizontal_corridor_scenes)
	_register_pool(context.vertical_corridor_scenes)
	_register_pool(context.terminal_chunk_scenes)


func _register_pool(
	scenes: Array[PackedScene]
) -> void:
	for scene: PackedScene in scenes:
		var path: String = scene.resource_path

		if not context.chunk_usage_counts.has(path):
			context.chunk_usage_counts[path] = 0


func record(
	scene: PackedScene
) -> void:
	var path: String = scene.resource_path

	context.chunk_usage_counts[path] = (
		get_scene_usage(scene) + 1
	)


func get_scene_usage(
	scene: PackedScene
) -> int:
	return int(
		context.chunk_usage_counts.get(
			scene.resource_path,
			0
		)
	)


func get_prioritized_scenes(
	scenes: Array[PackedScene]
) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var usage_levels: Array[int] = []

	for scene: PackedScene in scenes:
		var usage: int = get_scene_usage(scene)

		if not usage_levels.has(usage):
			usage_levels.append(usage)

	usage_levels.sort()

	for usage: int in usage_levels:
		var usage_group: Array[PackedScene] = []

		for scene: PackedScene in scenes:
			if get_scene_usage(scene) == usage:
				usage_group.append(scene)

		rng.shuffle(
			usage_group
		)

		for scene: PackedScene in usage_group:
			result.append(scene)

	return result


func snapshot() -> Dictionary:
	return context.chunk_usage_counts.duplicate(true)


func restore(
	usage_snapshot: Dictionary
) -> void:
	context.chunk_usage_counts = (
		usage_snapshot.duplicate(true)
	)
