extends Node3D

const DOORS := ["StartingPoint/Block/MwainHallWalls/Door", "StartingPoint/Block/StartingHallWalls/Door", "StartHall/Walls_Group/Door", "StartHall/AtomaticDoorway/Box_Group/Door"]

var level: Node3D
var sound_source: Player


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	level = preload("res://FractalVaultDemo/game_scene.tscn").instantiate()
	for child in level.get_children():
		if child is CharacterBody3D:
			child.free()
	for path in ["StartingPoint/SwarmSpawner", "StartingPoint/InputManager"]:
		var node := level.get_node_or_null(path)
		if node != null:
			node.free()
	add_child(level)
	for frame in range(12):
		await get_tree().physics_frame
	sound_source = Player.new()
	var scenes := [preload("res://FractalVaultDemo/enemies/fractal_enemy_base.tscn"), preload("res://FractalVaultDemo/enemies/fractal_leacher.tscn")]
	for scene in scenes:
		for path in DOORS:
			for side in [-1.0, 1.0]:
				if not await _walk_through(scene, level.get_node(path), side, 3.0):
					return
		# A single shot inside the starting room must stay interesting throughout the trip.
		if not await _walk_through(scene, level.get_node("StartHall/AtomaticDoorway/Box_Group/Door"), -1.0, 8.0):
			return
	sound_source.free()
	print("ROOM_NAVIGATION_SMOKE_OK")
	get_tree().quit(0)


func _walk_through(scene: PackedScene, door: Node3D, side: float, distance: float) -> bool:
	var from := _floor_at(door.global_position + door.global_basis.z.normalized() * side * distance)
	var to := _floor_at(door.global_position - door.global_basis.z.normalized() * side * distance)
	if from == Vector3.INF or to == Vector3.INF:
		return _fail("Missing floor at doorway %s" % door.get_path())
	var map := get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty() or Vector2(path[-1].x - to.x, path[-1].z - to.z).length() > 0.7:
		return _fail("Room has no complete path: %s" % door.get_path())
	var enemy := scene.instantiate() as FractalEnemyBase
	enemy.position = from + Vector3.UP * 0.05
	add_child(enemy)
	for frame in range(10):
		await get_tree().physics_frame
	Global.noise_emitted.emit(to, 100.0, sound_source)
	var reached := false
	for frame in range(600):
		await get_tree().physics_frame
		if Vector2(enemy.global_position.x - to.x, enemy.global_position.z - to.z).length() < 0.8:
			reached = true
			break
		if enemy.awareness == FractalEnemyBase.Awareness.IDLE:
			break
	if not reached:
		var detail := "%s side=%s start=%s goal=%s stopped=%s index=%s" % [door.get_path(), side, from, to, enemy.global_position, enemy.navigation_agent.get_current_navigation_path_index()]
		for index in range(enemy.get_slide_collision_count()):
			var hit := enemy.get_slide_collision(index)
			detail += " collider=%s normal=%s" % [hit.get_collider().get_path(), hit.get_normal()]
		return _fail("%s failed doorway investigation: %s" % [enemy.name, detail])
	print("DOORWAY_PASS ", scene.resource_path.get_file(), " ", door.get_path(), " side=", side, " distance=", distance)
	enemy.queue_free()
	await get_tree().physics_frame
	return true


func _floor_at(sample: Vector3) -> Vector3:
	var ground := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sample, sample + Vector3.DOWN * 10, 1))
	return ground.position if not ground.is_empty() else Vector3.INF


func _fail(message: String) -> bool:
	push_error(message)
	if is_instance_valid(sound_source):
		sound_source.free()
	get_tree().quit(1)
	return false
