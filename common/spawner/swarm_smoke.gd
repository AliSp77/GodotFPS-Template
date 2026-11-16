extends Node3D

var _player: CharacterBody3D
var _spawner: SwarmSpawner


func _ready() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 1, 30)
	shape.shape = box
	ground.position.y = -0.5
	ground.add_child(shape)
	add_child(ground)

	_player = load("res://player/player.tscn").instantiate()
	add_child(_player)
	_player.global_position = Vector3.ZERO

	_spawner = load("res://common/spawner/swarm_spawner.tscn").instantiate()
	_spawner.spawn_count = 3
	_spawner.activation_radius = 1.0
	_spawner.spawn_interval = 0.05
	_spawner.spawn_radius = 0.2
	_spawner.attack_damage = 1.0
	_spawner.attack_cooldown = 0.2
	add_child(_spawner)
	_spawner.global_position = Vector3(3, 0, 0)
	call_deferred("_check")


func _check() -> void:
	for frame in 120:
		await get_tree().physics_frame
	if _spawner._spawned_total != 3 or _spawner._enemies.size() != 3:
		push_error("Swarm did not spawn exactly three enemies")
		return
	if _spawner._activated or _player.current_health < 100.0:
		push_error("Swarm activated before the player approached a child")
		return
	var formation: Array[Vector2] = [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2.ZERO]
	var outer_indices: Array[int] = _spawner._outer_hull_indices(formation)
	if outer_indices.size() != 4 or outer_indices.has(4):
		push_error("The outer trigger selection included an inner child")
		return
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = _spawner.spawn_seed
	for enemy in _spawner._enemies:
		var expected: Vector3 = _spawner.spawn_point.to_global(_spawner._next_spawn_offset(layout_rng))
		var expected_yaw: float = layout_rng.randf() * TAU
		var actual: Vector3 = enemy.global_position
		if Vector2(expected.x, expected.z).distance_to(Vector2(actual.x, actual.z)) > 0.01:
			push_error("A live spawn did not match the editor preview layout")
			return
		var expected_facing := Vector2(cos(expected_yaw), sin(expected_yaw))
		var actual_facing := Vector2(cos(enemy.visual.rotation.y), sin(enemy.visual.rotation.y))
		if expected_facing.distance_to(actual_facing) > 0.01:
			push_error("A live enemy's initial facing did not match the editor preview")
			return
	for enemy in _spawner._enemies:
		if enemy.activated:
			push_error("A child started chasing before activation")
			return
	_player.global_position = Vector3(3, 0, 0)
	for frame in 120:
		await get_tree().physics_frame
	if not _spawner._activated or _player.current_health >= 100.0:
		push_error("Swarm did not wake and damage the nearby player")
		return
	if _spawner.swarm_visuals.multimesh.visible_instance_count != 3:
		push_error("Swarm visuals did not match live enemies")
		return
	var victim: SwarmEnemy = _spawner._enemies[0]
	var ray := PhysicsRayQueryParameters3D.create(victim.global_position + Vector3(0, 2, 0), victim.global_position - Vector3(0, 2, 0), 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is SwarmEnemy:
		push_error("Weapon ray did not find a swarm hitbox")
		return
	var kills_before: int = Global.enemies_killed
	hit.collider.get_damage(100.0, Vector3.FORWARD)
	if Global.enemies_killed != kills_before + 1:
		push_error("Shooting did not kill a swarm enemy")
		return
	for frame in 20:
		await get_tree().physics_frame
	if _spawner._enemies.size() != 2 or _spawner._spawned_total != 3:
		push_error("Spawner replaced an enemy after reaching its lifetime spawn count")
		return
	if _spawner._outer_enemies.size() != 2:
		push_error("Outer trigger list was not refreshed after an enemy died")
		return
	for outer_enemy in _spawner._outer_enemies:
		if not is_instance_valid(outer_enemy) or not _spawner._enemies.has(outer_enemy):
			push_error("Outer trigger list contains a dead enemy")
			return
	print("SWARM_MCP_SMOKE_OK health=", _player.current_health)
