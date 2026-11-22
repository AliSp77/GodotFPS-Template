class_name EquipEffect
extends RunEffect

@export var weapon: WeaponDefinition

func can_apply(player: Player) -> bool:
	return weapon != null and weapon.weapon_scene != null and not player.weapons_manager.has_weapon_scene(weapon.weapon_scene)

func apply(_run: Node, player: Player) -> void:
	if weapon != null:
		player.weapons_manager.equip_weapon(weapon)
