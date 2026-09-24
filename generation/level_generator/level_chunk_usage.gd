extends RefCounted
class_name LevelChunkUsage


const MIN_EFFECTIVE_WEIGHT: float = 0.01


var context: LevelGenerationContext
var rng: LevelGenerationRng

var scene_generation_weights: Dictionary = {}


func _init(
	generation_context: LevelGenerationContext,
	generation_rng: LevelGenerationRng
) -> void:
	context = generation_context
	rng = generation_rng


func initialize() -> void:
	context.chunk_usage_counts.clear()
	scene_generation_weights.clear()

	_register_pool(context.chunk_scenes)
	_register_pool(context.goal_chunk_scenes)
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

		if not scene_generation_weights.has(path):
			scene_generation_weights[path] = (
				_read_generation_weight(scene)
			)


func _read_generation_weight(
	scene: PackedScene
) -> float:
	var instance: Node = scene.instantiate()

	if not instance:
		return 1.0

	var weight: float = 1.0

	if instance is Chunk:
		weight = instance.generation_weight
	else:
		push_warning(
			"LevelChunkUsage: Scene root is not a Chunk: "
			+ scene.resource_path
		)

	instance.free()

	return maxf(
		weight,
		MIN_EFFECTIVE_WEIGHT
	)


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


func get_scene_weight(
	scene: PackedScene
) -> float:
	return float(
		scene_generation_weights.get(
			scene.resource_path,
			1.0
		)
	)


func get_effective_weight(
	scene: PackedScene
) -> float:
	var base_weight: float = get_scene_weight(scene)
	var usage: int = get_scene_usage(scene)

	return maxf(
		base_weight / float(usage + 1),
		MIN_EFFECTIVE_WEIGHT
	)


func get_prioritized_scenes(
	scenes: Array[PackedScene]
) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var remaining: Array[PackedScene] = scenes.duplicate()

	while not remaining.is_empty():
		var total_weight: float = 0.0

		for scene: PackedScene in remaining:
			total_weight += get_effective_weight(scene)

		var roll: float = rng.randf_range(
			0.0,
			total_weight
		)

		var accumulated_weight: float = 0.0
		var selected_index: int = (
			remaining.size() - 1
		)

		for i in range(remaining.size()):
			accumulated_weight += (
				get_effective_weight(
					remaining[i]
				)
			)

			if roll <= accumulated_weight:
				selected_index = i
				break

		result.append(
			remaining[selected_index]
		)

		remaining.remove_at(
			selected_index
		)

	return result


func snapshot() -> Dictionary:
	return context.chunk_usage_counts.duplicate(true)


func restore(
	usage_snapshot: Dictionary
) -> void:
	context.chunk_usage_counts = (
		usage_snapshot.duplicate(true)
	)
