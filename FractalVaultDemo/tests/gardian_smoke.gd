extends Node3D

const GardianScript = preload("res://FractalVaultDemo/enemies/gardian.gd")

var enemy: GardianScript
var player: Player
var shield_breaks: int = 0
var explosions: int = 0


func _ready() -> void:
	var ground := StaticBody3D.new()
	ground.position.y = -0.5
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	floor_shape.shape = floor_box
	ground.add_child(floor_shape)
	add_child(ground)

	player = preload("res://player/player.tscn").instantiate() as Player
	player.position = Vector3(0, 0, -5)
	add_child(player)
	player.set_physics_process(false)
	enemy = preload("res://FractalVaultDemo/enemies/gardian.tscn").instantiate() as GardianScript
	enemy.titan_cooldown = 100.0
	enemy.titan_charge_duration = 1.5
	enemy.wave_interval = 0.5
	enemy.wave_travel_time = 0.4
	add_child(enemy)
	enemy.shield_broken.connect(func(): shield_breaks += 1)
	enemy.titan_exploded.connect(func(): explosions += 1)
	call_deferred("_run_checks")


func _run_checks() -> void:
	await _frames(30)
	if not _check(enemy is FractalEnemyBase and enemy.phase == GardianScript.Phase.ROAM, "Gardian did not start in roaming phase"):
		return
	if not _check(not enemy.body_mesh.visible and enemy.weak_point_visuals.visible and enemy.collision_layer == 8, "Roaming body is visible or targetable"):
		return
	var body_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 0.8, -3), Vector3(0, 0.8, 3), 6)
	if not _check(get_world_3d().direct_space_state.intersect_ray(body_ray).is_empty(), "Weapon ray hit invisible body"):
		return
	var head_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.57, -3), Vector3(0, 1.57, 3), 6)
	var head_hit := get_world_3d().direct_space_state.intersect_ray(head_ray)
	if not _check(not head_hit.is_empty() and head_hit.collider == enemy.head_hurt_point, "Weapon ray missed visible weak point"):
		return
	var health_before := enemy.current_health
	enemy.head_hurt_point.get_damage(10.0, Vector3.FORWARD)
	if not _check(is_equal_approx(enemy.current_health, health_before - 20.0), "Weak point failed to damage Gardian"):
		return

	player.global_position = Vector3(0, 0, -1.4)
	var player_health := player.current_health
	await _frames(100)
	if not _check(player.current_health < player_health, "Roaming Gardian did not attack"):
		return
	player.global_position = Vector3(0, 0, -3)
	enemy._titan_left = 0.1
	await _frames(12)
	if not _check(enemy.phase == GardianScript.Phase.TITAN and enemy.titan_shield.collision_layer == 2 and not enemy.weak_point_visuals.visible, "Titan did not raise its shield"):
		return
	var shield_ray := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3(0, 1.2, -5), enemy.global_position + Vector3(0, 1.2, 5), 6)
	var shield_hit := get_world_3d().direct_space_state.intersect_ray(shield_ray)
	if not _check(not shield_hit.is_empty() and shield_hit.collider == enemy.titan_shield, "Weapon ray did not hit Titan shield"):
		return
	var titan_position := enemy.global_position
	player_health = player.current_health
	await _frames(38)
	if not _check(Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(Vector2(titan_position.x, titan_position.z)) < 0.02, "Titan moved during charge"):
		return
	if not _check(player.current_health < player_health, "Energy wave did not damage the player"):
		return
	health_before = enemy.current_health
	enemy.titan_shield.get_damage(enemy.shield_health, Vector3.FORWARD)
	await get_tree().process_frame
	if not _check(enemy.phase == GardianScript.Phase.ROAM and shield_breaks == 1 and explosions == 0, "Destroying the shield did not interrupt Titan"):
		return
	if not _check(is_equal_approx(enemy.current_health, health_before) and enemy.titan_shield.collision_layer == 0 and enemy.head_hurt_point.collision_layer == 2, "Shield damage reached body or weak points stayed hidden"):
		return

	player.current_health = 100.0
	enemy.titan_charge_duration = 0.5
	enemy.wave_damage = 0.0
	enemy._enter_titan()
	var kills_before := Global.enemies_killed
	await _frames(40)
	if not _check(explosions == 1 and enemy.awareness == FractalEnemyBase.Awareness.DEAD, "Unbroken Titan did not explode"):
		return
	if not _check(player.current_health <= 100.0 - enemy.explosion_damage and Global.enemies_killed == kills_before + 1, "Explosion failed to damage player or counted death twice"):
		return
	print("GARDIAN_SMOKE_OK")
	get_tree().quit(0)


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
