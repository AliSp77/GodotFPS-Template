class_name FractalEnemyHurtPoint
extends AnimatableBody3D

@export_range(0.1, 10.0, 0.1) var damage_multiplier: float = 2.0

@onready var enemy: FractalEnemyBase = get_parent().get_parent() as FractalEnemyBase


func get_damage(amount: float, direction: Vector3, _is_enemy_damage: bool = false) -> void:
	if is_instance_valid(enemy):
		enemy.get_damage(amount * damage_multiplier, direction)
