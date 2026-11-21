extends Node3D

var _doll_scene: PackedScene = preload("res://FractalVaultDemo/enemies/russian_doll_enemy.tscn")
var _player: Player


func _ready() -> void:
	var ground := StaticBody3D.new()
	ground.position.y = -0.5
	var ground_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	ground_shape.shape = floor_box
	ground.add_child(ground_shape)
	add_child(ground)

	_player = load("res://player/player.tscn").instantiate() as Player
	add_child(_player)
	_player.global_position = Vector3(0, 0, 10)
	var doll := _doll_scene.instantiate() as RussianDollEnemy
	add_child(doll)
	doll.global_position = Vector3.ZERO
	call_deferred("_check")


func _check() -> void:
	await get_tree().physics_frame
	var previous_health := INF
	var previous_damage := INF
	var previous_speed := 0.0
	var previous_radius := INF
	var expected_count := 1
	var kills_before := Global.enemies_killed

	for generation in range(RussianDollEnemy.MAX_SPLITS + 1):
		var dolls := _get_dolls()
		if dolls.size() != expected_count:
			_fail("Generation %d has %d dolls; expected %d" % [generation, dolls.size(), expected_count])
			return
		for doll in dolls:
			if doll.split_generation != generation:
				_fail("Child spawned in the wrong generation")
				return
			var shape := doll.get_node("CollisionShape3D").shape as CapsuleShape3D
			if doll.max_health >= previous_health or doll.attack_damage >= previous_damage or doll.move_speed <= previous_speed or shape.radius >= previous_radius:
				_fail("Health, damage, speed, or hitbox failed to change by generation")
				return
			if generation == 0:
				var ray := PhysicsRayQueryParameters3D.create(doll.global_position + Vector3.UP * 4.0, doll.global_position - Vector3.UP, 2)
				var hit := get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or hit.collider != doll:
					_fail("Weapon ray could not hit the doll")
					return
			doll.get_damage(doll.current_health, Vector3.FORWARD)
		previous_health = dolls[0].max_health
		previous_damage = dolls[0].attack_damage
		previous_speed = dolls[0].move_speed
		previous_radius = (dolls[0].get_node("CollisionShape3D").shape as CapsuleShape3D).radius
		await get_tree().process_frame
		await get_tree().process_frame
		expected_count *= 2

	if not _get_dolls().is_empty():
		_fail("Final generation split a fifth time")
		return
	if Global.enemies_killed != kills_before + 31:
		_fail("The full split chain did not count 31 kills")
		return

	_player.global_position = Vector3.ZERO
	var attacker := _doll_scene.instantiate() as RussianDollEnemy
	add_child(attacker)
	attacker.global_position = Vector3(0, 0, -1.5)
	var health_before := _player.current_health
	for frame in 45:
		await get_tree().physics_frame
	if _player.current_health >= health_before:
		_fail("Doll did not damage the player")
		return
	print("RUSSIAN_DOLL_MCP_SMOKE_OK")
	get_tree().quit(0)


func _get_dolls() -> Array[RussianDollEnemy]:
	var dolls: Array[RussianDollEnemy] = []
	for node in get_tree().get_nodes_in_group("russian_dolls"):
		if node is RussianDollEnemy:
			dolls.append(node)
	return dolls


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
