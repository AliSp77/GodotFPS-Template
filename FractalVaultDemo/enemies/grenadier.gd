class_name Grenadier
extends RangedEnemyBase


func _fire_projectile(_shot_direction: Vector3) -> void:
	if projectile_scene == null or not is_instance_valid(target_player) or not target_player.is_alive:
		return
	var volley := projectile_scene.instantiate() as GrenadeVolley
	if volley == null:
		push_error("Grenadier projectile_scene must use GrenadeVolley.")
		return
	volley.shooter = self
	volley.shooter_rid = get_rid()
	volley.speed = projectile_speed
	volley.max_distance = projectile_distance
	volley.damage = projectile_damage
	volley.target_position = target_player.global_position
	volley.position = get_parent().to_local(muzzle.global_position)
	get_parent().add_child(volley)
	shot_fired.emit(volley)
