extends StaticBody3D

@onready var gardian: Node = get_parent()


func get_damage(amount: float, direction: Vector3, _is_enemy_damage: bool = false) -> void:
	if is_instance_valid(gardian):
		gardian.call("damage_shield", amount, direction)
