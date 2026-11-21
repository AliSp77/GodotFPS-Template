extends Node3D

var enemy: FractalLeacher
var player: Player


func _ready() -> void:
	seed(42)
	_add_block(Vector3(0, -0.5, 0), Vector3(70, 1, 70))
	var mesh := NavigationMesh.new()
	mesh.set_vertices(PackedVector3Array([
		Vector3(-30, 0.6, -30), Vector3(-30, 0.6, 30),
		Vector3(30, 0.6, 30), Vector3(30, 0.6, -30)]))
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	add_child(region)
	player = preload("res://player/player.tscn").instantiate() as Player
	player.position = Vector3(0, 0.05, 15)
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	enemy = preload("res://FractalVaultDemo/enemies/fractal_leacher.tscn").instantiate() as FractalLeacher
	enemy.move_speed = 0.0
	enemy.rush_speed = 0.0
	enemy.recover_speed = 0.0
	enemy.search_duration = 0.25
	enemy.carry_min_distance = 3.0
	enemy.carry_max_distance = 4.0
	enemy.carry_speed = 4.0
	add_child(enemy)
	call_deferred("_run_checks")


func _run_checks() -> void:
	await _frames(10)
	if not _check(enemy is FractalEnemyBase, "Leacher did not inherit the enemy base"):
		return
	Global.noise_emitted.emit(player.global_position, 24.0, player)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.INVESTIGATE, "Inherited hearing did not investigate"):
		return
	await _frames(20)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.IDLE, "Inherited investigation did not expire"):
		return
	enemy.rotation = Vector3.ZERO
	player.position = Vector3(0, 0.05, -5)
	var wall := _add_block(Vector3(0, 1.5, -2.5), Vector3(3, 3, 0.3))
	await _frames(10)
	if not _check(enemy.awareness != FractalEnemyBase.Awareness.ENGAGED, "Leacher saw through a wall"):
		return
	wall.queue_free()
	await _frames(12)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.ENGAGED, "Inherited vision did not engage"):
		return
	enemy.chase_phase = FractalLeacher.ChasePhase.RUSH
	enemy._phase_left = 0.02
	await _frames(3)
	if not _check(enemy.chase_phase == FractalLeacher.ChasePhase.RECOVER, "Rush did not enter recovery"):
		return
	enemy.get_node("HurtPoints/Head").get_damage(10.0, Vector3.FORWARD)
	if not _check(is_equal_approx(enemy.current_health, enemy.max_health - 20.0), "Inherited headshot multiplier failed"):
		return
	enemy.move_speed = 3.5
	enemy.rush_speed = 5.0
	enemy.recover_speed = 2.0
	enemy.search_duration = 4.0
	var grabs := [0]
	var releases := [0]
	enemy.player_grabbed.connect(func(_target): grabs[0] += 1)
	enemy.player_released.connect(func(_target): releases[0] += 1)
	for frame in range(180):
		await _frames(1)
		if player.is_grabbed:
			break
	if not _check(grabs[0] == 1 and player.is_grabbed and player.weapons_manager.controls_locked, "Autonomous pursuit did not grab and lock the player"):
		return
	if not _check("CARRY" in enemy.state_indicator.text, "Carry indicator was not displayed"):
		return
	var carry_start := enemy.global_position
	for frame in range(180):
		await _frames(1)
		if not player.is_grabbed:
			break
	if not _check(releases[0] == 1 and not player.is_grabbed and not player.weapons_manager.controls_locked, "Carry did not release and restore controls"):
		return
	if not _check(enemy.global_position.distance_to(carry_start) > 1.5 and _player_is_clear(), "Leacher failed to transport the player safely"):
		return
	if not _check(enemy.grab_cooldown_left > 0.0 and not enemy.can_grab_player(), "Release did not apply grab cooldown"):
		return
	_reset_close_target()
	var ceiling := _add_block(Vector3(0, 3, 0), Vector3(6, 0.4, 6))
	await _frames(3)
	if not _check(not enemy.grab_player() and not player.is_grabbed, "Leacher lifted the player into a low ceiling"):
		return
	ceiling.queue_free()
	await _frames(3)
	if not _check(enemy.grab_player(), "Clear grab after ceiling removal failed"):
		return
	enemy.carry_destination = enemy.global_position + Vector3(4, 0, 0)
	var barrier := _add_block(Vector3(0.7, 3.2, 0), Vector3(0.1, 3, 4))
	for frame in range(45):
		await _frames(1)
		if not player.is_grabbed:
			break
	if not _check(not player.is_grabbed and not player.weapons_manager.controls_locked and _player_is_clear(), "Blocked carry failed to release safely"):
		return
	barrier.queue_free()
	_reset_close_target()
	await _frames(3)
	if not _check(enemy.grab_player(), "Grab before death-release test failed"):
		return
	var kills_before: int = Global.enemies_killed
	enemy.get_damage(1000.0, Vector3.FORWARD)
	enemy.get_damage(1000.0, Vector3.FORWARD)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.DEAD and not player.is_grabbed and not player.weapons_manager.controls_locked, "Death failed to release the held player"):
		return
	if not _check(Global.enemies_killed == kills_before + 1, "Inherited death counted more than once"):
		return
	await _frames(70)
	if not _check(not is_instance_valid(enemy), "Dead Leacher was not removed"):
		return
	enemy = preload("res://FractalVaultDemo/enemies/fractal_leacher.tscn").instantiate() as FractalLeacher
	enemy.carry_min_distance = 3.0
	enemy.carry_max_distance = 4.0
	enemy.rush_speed = 0.0
	enemy.recover_speed = 0.0
	enemy._grab_attempt_left = 100.0
	player.position = Vector3(0, 0.05, -1.0)
	add_child(enemy)
	await _frames(10)
	if not _check(enemy.grab_player(), "Grab before removal-release test failed"):
		return
	enemy.queue_free()
	await _frames(2)
	if not _check(not player.is_grabbed and not player.weapons_manager.controls_locked, "Removing the Leacher left the player locked"):
		return
	print("FRACTAL_LEACHER_SMOKE_OK")
	get_tree().quit(0)


func _reset_close_target() -> void:
	enemy.position = Vector3.ZERO
	enemy.rotation = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.rush_speed = 0.0
	enemy.recover_speed = 0.0
	enemy.grab_cooldown_left = 0.0
	enemy._grab_attempt_left = 100.0
	player.position = Vector3(0, 0.05, -1.0)
	enemy.target_player = player
	enemy._set_awareness(FractalEnemyBase.Awareness.ENGAGED)


func _player_is_clear() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.body_collision.shape
	query.transform = player.body_collision.global_transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _add_block(block_position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = block_position
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
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
