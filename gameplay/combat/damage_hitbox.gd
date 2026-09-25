# Shared damage payload for weapon and projectile overlap areas. Receivers
# apply the damage; collision masks and attack windows control who can be hit.
extends Area2D
class_name DamageHitbox

@export var damage: int = 25
