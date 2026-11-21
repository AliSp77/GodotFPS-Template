extends Node3D

var player: Player
var leacher: CharacterBody3D


func _ready() -> void:
	_add_block(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	player = preload("res://player/player.tscn").instantiate() as Player
	player.position = Vector3(1.2, 0.05, 0)
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	leacher = preload("res://enemies/leacher.tscn").instantiate() as CharacterBody3D
	leacher.position = Vector3(0, 0.05, 0)
	add_child(leacher)
	leacher.set_physics_process(false)
	leacher.get_node("BTPlayer").active = false
	call_deferred("_run_checks")


func _run_checks() -> void:
	await _frames(3)
	if not await _check_grab_safety():
		return
	player.queue_free()
	leacher.queue_free()
	await _frames(3)
	if not await _check_investigation_navigation():
		return
	print("ENEMY_MOVEMENT_SAFETY_SMOKE_OK")
	get_tree().quit(0)


func _check_grab_safety() -> bool:
	leacher.target_player = player
	leacher.chasing = true
	if not _check(leacher.grab_player(2.2), "Clear lift was rejected"):
		return false
	var wall := _add_block(Vector3(0, 1.5, -1.6), Vector3(1, 3, 0.8))
	await _frames(2)
	leacher.release_player()
	if not _check(not player.is_grabbed and not player.weapons_manager.controls_locked, "Release did not restore player controls"):
		return false
	if not _check(_player_is_clear(), "Player released inside a wall or Leacher"):
		return false
	if not _check(player.global_position.y < 0.2, "Release did not find an alternative ground position"):
		return false
	wall.queue_free()
	player.position = Vector3(1.2, 0.05, 0)
	var ceiling := _add_block(Vector3(0, 3.0, 0), Vector3(6, 0.4, 6))
	await _frames(2)
	var before := player.global_position
	if not _check(not player.begin_leacher_grab(leacher, 2.2), "Lift intersected a low ceiling"):
		return false
	if not _check(player.global_position.is_equal_approx(before) and not player.is_grabbed, "Rejected lift moved or locked the player"):
		return false
	ceiling.queue_free()
	await _frames(2)
	if not _check(player.begin_leacher_grab(leacher, 2.2), "Second clear lift was rejected"):
		return false
	var thin_wall := _add_block(Vector3(1, 3.2, 0), Vector3(0.1, 3, 4))
	await _frames(2)
	before = player.global_position
	leacher.position.x = 2.0
	if not _check(not player.sync_grab_position(), "Carry teleported through a thin wall"):
		return false
	if not _check(player.global_position.is_equal_approx(before) and _player_is_clear(), "Blocked carry changed the last safe position"):
		return false
	player.end_leacher_grab(Vector3(1, 3.2, 0))
	if not _check(player.global_position.is_equal_approx(before) and not player.weapons_manager.controls_locked, "Blocked release teleported or kept controls locked"):
		return false
	thin_wall.queue_free()
	await _frames(2)
	leacher.position = Vector3(0, 0.05, 0)
	player.position = Vector3(1.2, 0.05, 0)
	leacher.grab_cooldown_left = 0.0
	leacher.chasing = true
	if not _check(leacher.grab_player(2.2), "Clear lift before enclosed release was rejected"):
		return false
	var enclosure: Array[StaticBody3D] = []
	for side in [-1.0, 1.0]:
		enclosure.append(_add_block(Vector3(side * 0.8, 3, 0), Vector3(0.4, 6, 8)))
		enclosure.append(_add_block(Vector3(0, 3, side * 0.8), Vector3(8, 6, 0.4)))
	await _frames(2)
	before = player.global_position
	leacher.release_player()
	if not _check(player.global_position.is_equal_approx(before) and _player_is_clear(), "Enclosed release left the last safe position"):
		return false
	if not _check(not player.is_grabbed and not player.weapons_manager.controls_locked, "Enclosed release kept the player locked"):
		return false
	for block in enclosure:
		block.queue_free()
	return true


func _check_investigation_navigation() -> bool:
	# Baked meshes can sit above the physical floor; path advancement must still work.
	var mesh := NavigationMesh.new()
	mesh.set_vertices(PackedVector3Array([
		Vector3(-8, 0.6, -8), Vector3(-8, 0.6, 8),
		Vector3(8, 0.6, 8), Vector3(8, 0.6, -8)]))
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	add_child(region)
	var enemy := preload("res://FractalVaultDemo/enemies/fractal_enemy_base.tscn").instantiate() as FractalEnemyBase
	add_child(enemy)
	var sound_source := Player.new()
	await _frames(10)
	var start := enemy.global_position
	enemy._on_noise_emitted(Vector3(5, 0, 0), 24.0, sound_source)
	await _frames(90)
	var distance := Vector2(enemy.global_position.x, enemy.global_position.z).distance_to(Vector2(start.x, start.z))
	sound_source.free()
	if not _check(distance > 2.0, "Investigating enemy stayed at its first navigation waypoint: moved %.3f" % distance):
		return false
	await _frames(90)
	if not _check(absf(enemy.global_position.x - 5.0) < 0.8, "Investigating enemy failed to reach the sound"):
		return false
	await _frames(200)
	return _check(enemy.awareness == FractalEnemyBase.Awareness.IDLE, "Investigation failed to expire after sounds stopped")


func _player_is_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.get_node("CollisionShape3D").shape
	query.transform = player.get_node("CollisionShape3D").global_transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _add_block(block_position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = block_position
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)
	return body


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
