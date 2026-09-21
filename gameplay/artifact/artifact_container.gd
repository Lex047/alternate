extends Area2D
class_name ArtifactContainer


signal collected


var player_in_range: bool = false
var is_collected: bool = false


func _process(_delta: float) -> void:
	if (
		not is_collected
		and player_in_range
		and Input.is_action_just_pressed("interact")
	):
		is_collected = true

		print(
			"ArtifactContainer: collected signal emitted"
		)

		collected.emit()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		print("ArtifactContainer: player entered range")


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		print("ArtifactContainer: player left range")
