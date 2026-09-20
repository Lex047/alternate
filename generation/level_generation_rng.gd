extends RefCounted
class_name LevelGenerationRng


const GRAPH_SEED_SALT: int = 0x2C9277B5
const SPATIAL_SEED_SALT: int = 0x19A4E6D3

const MIN_RANDOM_SEED: int = 10000
const MAX_RANDOM_SEED: int = 999999999


var graph_rng := RandomNumberGenerator.new()
var generation_rng := RandomNumberGenerator.new()


func initialize(
	generation_seed: int,
	use_random_seed: bool
) -> int:
	var active_seed: int = generation_seed

	if use_random_seed:
		generation_rng.randomize()

		active_seed = generation_rng.randi_range(
			MIN_RANDOM_SEED,
			MAX_RANDOM_SEED
		)

	graph_rng.seed = (
		active_seed
		^ GRAPH_SEED_SALT
	)

	generation_rng.seed = (
		active_seed
		^ SPATIAL_SEED_SALT
	)

	return active_seed


func shuffle(
	array: Array
) -> void:
	if array.size() <= 1:
		return

	for i in range(
		array.size() - 1,
		0,
		-1
	):
		var random_index: int = (
			generation_rng.randi_range(
				0,
				i
			)
		)

		var temporary_value: Variant = array[i]

		array[i] = array[random_index]
		array[random_index] = temporary_value


func randf_range(
	min_value: float,
	max_value: float
) -> float:
	return generation_rng.randf_range(
		min_value,
		max_value
	)
