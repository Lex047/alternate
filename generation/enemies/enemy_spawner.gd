extends Node
class_name EnemySpawner


const ENEMY_SEED_SALT: int = 0x45A1B2C3


@export_category("Enemy Scenes")
@export var melee_enemy_scene: PackedScene
@export var ranged_enemy_scene: PackedScene

@export_category("Generation")
@export_range(0.0, 1.0, 0.05)
var ranged_enemy_chance: float = 0.40


func populate_level(
	level_root: Node,
	generation_seed: int
) -> void:
	if not level_root:
		return

	var enemy_rng := RandomNumberGenerator.new()

	enemy_rng.seed = (
		generation_seed
		^ ENEMY_SEED_SALT
	)

	var spawn_points: Array[EnemySpawn] = (
		_collect_spawn_points(level_root)
	)

	# Keep RNG consumption deterministic.
	spawn_points.sort_custom(
		_sort_spawn_points
	)

	for spawn_point in spawn_points:
		_resolve_spawn(
			spawn_point,
			enemy_rng
		)


func _collect_spawn_points(
	root: Node
) -> Array[EnemySpawn]:
	var result: Array[EnemySpawn] = []

	_collect_spawn_points_recursive(
		root,
		result
	)

	return result


func _collect_spawn_points_recursive(
	node: Node,
	result: Array[EnemySpawn]
) -> void:
	for child in node.get_children():
		if child is EnemySpawn:
			result.append(child)

		_collect_spawn_points_recursive(
			child,
			result
		)


func _sort_spawn_points(
	a: EnemySpawn,
	b: EnemySpawn
) -> bool:
	if not is_equal_approx(
		a.global_position.y,
		b.global_position.y
	):
		return (
			a.global_position.y
			< b.global_position.y
		)

	return (
		a.global_position.x
		< b.global_position.x
	)


func _resolve_spawn(
	spawn_point: EnemySpawn,
	enemy_rng: RandomNumberGenerator
) -> void:
	if spawn_point.has_been_resolved:
		return

	spawn_point.has_been_resolved = true

	if enemy_rng.randf() > spawn_point.spawn_chance:
		return

	var enemy_scene: PackedScene = (
		_choose_enemy_scene(
			spawn_point.spawn_type,
			enemy_rng
		)
	)

	if not enemy_scene:
		return

	var enemy := (
		enemy_scene.instantiate()
		as Node2D
	)

	if not enemy:
		return

	# The enemy and spawn point use the same parent,
	# so the marker's local position can be copied directly.
	enemy.position = spawn_point.position

	spawn_point.get_parent().add_child(
		enemy
	)


func _choose_enemy_scene(
	spawn_type: EnemySpawn.SpawnType,
	enemy_rng: RandomNumberGenerator
) -> PackedScene:
	match spawn_type:
		EnemySpawn.SpawnType.MELEE:
			return melee_enemy_scene

		EnemySpawn.SpawnType.RANGED:
			return ranged_enemy_scene

		EnemySpawn.SpawnType.ANY:
			if (
				enemy_rng.randf()
				< ranged_enemy_chance
			):
				return ranged_enemy_scene

			return melee_enemy_scene

	return null
