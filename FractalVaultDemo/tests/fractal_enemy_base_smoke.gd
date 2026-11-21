extends Node3D

var enemy_scene: PackedScene = preload("res://FractalVaultDemo/enemies/fractal_enemy_base.tscn")
var player_scene: PackedScene = preload("res://player/player.tscn")
var enemy: FractalEnemyBase
var player: Player
var noise_radii: Array[float] = []


func _ready() -> void:
	_add_block(Vector3(0, -0.5, 0), Vector3(30, 1, 30))
	player = player_scene.instantiate() as Player
	player.position = Vector3(0, 0, 14)
	add_child(player)
	enemy = enemy_scene.instantiate() as FractalEnemyBase
	enemy.move_speed = 0.0
	enemy.search_duration = 0.25
	enemy.dodge_cooldown = 0.2
	add_child(enemy)
	Global.noise_emitted.connect(_record_noise)
	call_deferred("_run_checks")


func _run_checks() -> void:
	await _frames(8)
	if not _check(enemy.awareness != FractalEnemyBase.Awareness.ENGAGED, "Player behind cone was visually detected"):
		return

	Global.noise_emitted.emit(player.global_position, 20.0, player)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.INVESTIGATE, "Hearing did not investigate"):
		return
	if not _check(enemy.last_known_position.distance_to(player.global_position) < 0.01, "Hearing did not remember sound position"):
		return
	await _frames(20)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.IDLE, "Investigation did not time out"):
		return

	enemy.rotation.y = 0.0
	var wall := _add_block(Vector3(0, 1, -2), Vector3(3, 2, 0.25))
	player.global_position = Vector3(0, 0, -4)
	await _frames(8)
	if not _check(enemy.awareness != FractalEnemyBase.Awareness.ENGAGED, "Saw player through wall"):
		return
	wall.queue_free()
	await _frames(10)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.ENGAGED, "Clear sight did not engage"):
		return
	if not _check(enemy.target_player == player, "Engaged target was not the seen player"):
		return

	player.global_position = Vector3(0, 0, 4)
	await _frames(5)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.SEARCH, "Lost sight did not start search"):
		return
	if not _check(enemy.last_known_position.z < -3.0, "Search did not retain last seen position"):
		return
	await _frames(20)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.IDLE, "Search did not return to idle"):
		return

	var head := enemy.get_node("HurtPoints/Head")
	var head_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.7, -3), Vector3(0, 1.7, 3), 2)
	var head_hit := get_world_3d().direct_space_state.intersect_ray(head_ray)
	if not _check(not head_hit.is_empty() and head_hit.collider == head, "Weapon ray did not hit head hurt point"):
		return
	head.get_damage(10.0, Vector3.FORWARD)
	if not _check(is_equal_approx(enemy.current_health, 80.0), "Head hurt point multiplier did not apply"):
		return
	if not _check(enemy.animation_player.current_animation == "hurt", "Hurt animation was not requested"):
		return

	enemy.rotation.y = 0.0
	if not _check(enemy.notify_threat(Vector3(0, 1.4, -4), 0.5), "Visible threat did not trigger safe dodge"):
		return
	if not _check(enemy.animation_player.current_animation == "dodge", "Dodge animation was not requested"):
		return
	if not _check(not enemy.notify_threat(Vector3(0, 1.4, -4), 0.5), "Dodge cooldown did not block repeat"):
		return
	await _frames(20)
	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy.rotation.y = 0.0
	_add_block(Vector3(0.9, 1, 0), Vector3(0.2, 2, 2))
	_add_block(Vector3(-0.9, 1, 0), Vector3(0.2, 2, 2))
	await _frames(3)
	if not _check(not enemy.notify_threat(Vector3(0, 1.4, -4), 0.5), "Dodge entered blocked space"):
		return

	var animation_names := ["idle", "move", "alert", "attack_windup", "attack", "recover", "hurt", "dodge", "death"]
	for clip_name in animation_names:
		if not _check(enemy.animation_player.has_animation(clip_name), "Missing animation: " + clip_name):
			return

	var kills_before := Global.enemies_killed
	var death_count := [0]
	enemy.died.connect(func(): death_count[0] += 1)
	enemy.get_damage(1000.0, Vector3.FORWARD)
	enemy.get_damage(1000.0, Vector3.FORWARD)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.DEAD, "Lethal damage did not mark dead"):
		return
	if not _check(death_count[0] == 1 and Global.enemies_killed == kills_before + 1, "Death was emitted more than once"):
		return
	if not _check(enemy.animation_player.current_animation == "death", "Death animation was not requested"):
		return

	player.velocity = Vector3.RIGHT
	player.footstep_timer = 0.0
	player._handle_footsteps(0.016)
	if not _check(noise_radii.has(6.0), "Real walking footstep emitted no noise"):
		return
	Input.action_press("sprint")
	player.footstep_timer = 0.0
	player._handle_footsteps(0.016)
	Input.action_release("sprint")
	if not _check(noise_radii.has(10.0), "Real sprinting footstep emitted no noise"):
		return
	var pistol := player.get_node("WeaponsManager/Pistol")
	pistol.call("fire_weapon")
	if not _check(noise_radii.has(24.0), "Real gunfire emitted no noise"):
		return

	print("FRACTAL_ENEMY_BASE_MCP_SMOKE_OK")
	get_tree().quit(0)


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


func _record_noise(_noise_position: Vector3, radius: float, source: Node3D) -> void:
	if source == player:
		noise_radii.append(radius)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
