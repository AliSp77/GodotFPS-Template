class_name StatEffect
extends RunEffect

enum Stat { HEAL, MAX_HEALTH, MOVE_SPEED, WEAPON_DAMAGE, RELOAD_SPEED, AMMO_REFILL }
@export var stat: Stat
@export var amount: float = 1.0

func can_apply(player: Player) -> bool:
	return stat != Stat.HEAL or player.current_health < player.max_health

func apply(_run: Node, player: Player) -> void:
	match stat:
		Stat.HEAL:
			player.current_health = minf(player.max_health, player.current_health + amount)
		Stat.MAX_HEALTH:
			player.max_health += amount
			player.current_health += amount
		Stat.MOVE_SPEED:
			player.walk_speed *= amount
			player.sprint_speed *= amount
		Stat.WEAPON_DAMAGE:
			for weapon in player.weapons_manager.weapons_array:
				weapon.damage *= amount
			player.weapons_manager.damage_multiplier *= amount
		Stat.RELOAD_SPEED:
			for weapon in player.weapons_manager.weapons_array:
				weapon.reload_time *= amount
			player.weapons_manager.reload_multiplier *= amount
		Stat.AMMO_REFILL:
			for key in Bullets.ammo_inventory:
				var reserve = Bullets.ammo_inventory[key]
				if reserve.max != -1:
					reserve.current = reserve.max
			for weapon in player.weapons_manager.weapons_array:
				weapon.current_mag = weapon.mag_capacity
			Global.bullets_changed.emit()
	Global.player_health_changed.emit(0.0, player.current_health, player.max_health, false)
