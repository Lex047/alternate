# Authored enemy placement marker carrying type and probability. EnemySpawner
# resolves each marker once, including rolls that produce no enemy.
extends Marker2D
class_name EnemySpawn


enum SpawnType {
	ANY,
	MELEE,
	RANGED,
}


@export_category("Enemy Spawn")
@export var spawn_type: SpawnType = SpawnType.ANY

@export_range(0.0, 1.0, 0.05)
var spawn_chance: float = 0.65


var has_been_resolved: bool = false
