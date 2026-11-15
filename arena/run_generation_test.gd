extends Node

var failures := 0
var library: Array[PackedScene] = [
	preload("res://arena/arena_crossfire.tscn"),
	preload("res://arena/arena_flanks.tscn"),
	preload("res://arena/arena_columns.tscn"),
	preload("res://arena/arena_fork_crossroads.tscn"),
	preload("res://arena/arena_dead_end_cache.tscn"),
	preload("res://arena/arena_goal.tscn")
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for scene in library:
		var arena := scene.instantiate() as ArenaSegment
		_check(arena != null and arena.validation_errors().is_empty(), "Valid arena: " + scene.resource_path)
		arena.free()
	var invalid := preload("res://arena/arena_template.tscn").instantiate() as ArenaSegment
	invalid.get_node("Entry").position.x = 1.0
	_check(not invalid.validation_errors().is_empty(), "Invalid marker is rejected")
	_check(not invalid._get_configuration_warnings().is_empty(), "Invalid marker has editor warning")
	var invalid_scene := PackedScene.new()
	invalid_scene.pack(invalid)
	_check(not RunGenerator.new([invalid_scene], 1, 0.5, 0.7).errors.is_empty(), "Invalid scene is rejected by library")
	invalid.free()

	var a := RunGenerator.new(library, 42, 0.5, 0.7)
	var b := RunGenerator.new(library, 42, 0.5, 0.7)
	a.build_fixed(6, 24, 0.6, 0.3)
	b.build_fixed(6, 24, 0.6, 0.3)
	_check(a.errors.is_empty(), "Fixed graph has no errors")
	_check(a.nodes == b.nodes, "Same seed and settings reproduce graph and placements")
	_check(a.nodes.size() == 24, "Fixed graph uses room budget")
	var goals := 0
	var forks := 0
	var dead_ends := 0
	var rotations := {}
	var coords := {}
	for node in a.nodes:
		coords[node["coord"]] = true
		rotations[node["rotation"]] = true
		if node["type"] == ArenaSegment.RoomType.GOAL:
			goals += 1
			_check(node["depth"] == 5, "Goal is at configured depth")
		if node["type"] == ArenaSegment.RoomType.FORK: forks += 1
		if node["type"] == ArenaSegment.RoomType.DEAD_END: dead_ends += 1
		for direction in (node["neighbors"] as Dictionary).keys():
			var neighbor: Dictionary = a.nodes[node["neighbors"][direction]]
			_check(neighbor["coord"] == node["coord"] + RunGenerator.STEP[direction], "Linked rooms occupy adjacent cells")
			_check(neighbor["neighbors"].get((direction + 2) % 4, -1) == node["id"], "Door link is reciprocal")
	_check(coords.size() == a.nodes.size(), "Rooms never overlap")
	_check(goals == 1 and forks >= 2 and dead_ends >= 1, "Fixed graph has goal, multiple forks, and road blocks")
	_check(rotations.size() == 4, "Graph exercises all four arena rotations")

	var low := RunGenerator.new(library, 42, 0.0, 0.0)
	var high := RunGenerator.new(library, 42, 2.0, 2.0)
	low.build_fixed(6, 24, 0.6, 0.3)
	high.build_fixed(6, 24, 0.6, 0.3)
	var low_count := 0
	var high_count := 0
	for index in high.nodes.size():
		var entry: Dictionary = high.nodes[index]["entry"]
		var arena := (entry["scene"] as PackedScene).instantiate() as ArenaSegment
		_check(entry["enemies"] >= arena.authored_enemy_count(), "Authored enemies stay in place")
		_check(entry["obstacles"] >= arena.authored_obstacle_count(), "Authored obstacles stay in place")
		_check(entry["enemies"] <= arena.authored_enemy_count() + arena.enemy_slots().size(), "Enemy count respects slots")
		_check(entry["obstacles"] <= arena.authored_obstacle_count() + arena.obstacle_slots().size(), "Obstacle count respects slots")
		arena.free()
		high_count += entry["enemies"] + entry["obstacles"]
		low_count += low.nodes[index]["entry"]["enemies"] + low.nodes[index]["entry"]["obstacles"]
	_check(high_count > low_count, "High density adds more content")

	var preview := preload("res://arena/run_builder.tscn").instantiate() as RunBuilder
	preview.regenerate_preview()
	var editor_report := preview.preview_report
	_check(preview._generator.nodes == a.nodes, "Editor preview plan matches runtime generator")
	_check(preview.preview_report.contains("fork") and preview.preview_report.contains("TOTAL"), "Editor preview reports forks and totals")
	_check(preview.get_node("Generated").get_child_count() > 0, "Regenerate creates 3D preview rooms")
	preview.free()

	var playable := preload("res://arena/arena_run.tscn").instantiate()
	var fixed := playable.get_node("RunBuilder") as RunBuilder
	get_tree().root.add_child(playable)
	await get_tree().physics_frame
	_check(fixed._generator.nodes == a.nodes, "Runtime plan matches independent editor plan")
	_check(editor_report.split("Visited route")[0] == fixed._format_report().split("Visited route")[0], "Editor and runtime density reports match")
	_check(fixed.get_node("Generated").get_child_count() == a.nodes.size(), "Fixed run instances entire graph")
	_check(fixed._format_report().contains("TOTAL") and fixed._format_report().contains("Visited route"), "Report has totals and visited route")
	for node in a.nodes:
		var arena: ArenaSegment = fixed._live[node["id"]]
		var entry: Dictionary = node["entry"]
		_check(arena.authored_enemy_count() + arena.get_node("GeneratedEnemies").get_child_count() == entry["enemies"], "Enemy report matches spawned count")
		_check(arena.authored_obstacle_count() + arena.get_node("GeneratedObstacles").get_child_count() == entry["obstacles"], "Obstacle report matches spawned count")
		for enemy in arena.get_node("AuthoredEnemies").get_children() + arena.get_node("GeneratedEnemies").get_children():
			_check(enemy.player == playable.player and enemy.game == playable, "Spaceship binds to FPS player and arena game")
		for direction in (node["neighbors"] as Dictionary).keys():
			var local_direction: int = posmod(direction + node["rotation"], 4)
			if local_direction == 2: continue
			var marker_name := "Exit" if local_direction == 0 else "ExitEastMarker"
			var marker := arena.get_node(marker_name) as Marker3D
			var neighbor: ArenaSegment = fixed._live[node["neighbors"][direction]]
			_check(marker.global_position.is_equal_approx(neighbor.get_node("Entry").global_position), "Rotated doorways align")
			var from: Vector3 = marker.global_position - RunBuilder.DIRECTIONS[direction] * 0.6 + Vector3.UP
			var to: Vector3 = marker.global_position + RunBuilder.DIRECTIONS[direction] * 0.6 + Vector3.UP
			var ray := PhysicsRayQueryParameters3D.create(from, to)
			_check(fixed.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Connected doorway has no collision")
	var combat_ship: Node = fixed._live[0].get_node("AuthoredEnemies").get_child(0)
	combat_ship._fire_timer = 0.0
	await get_tree().physics_frame
	_check(get_tree().get_nodes_in_group("afterburn_bolts").size() > 0, "Spaceship fires at the FPS player")
	var fork_id := 0
	var branch_id: int = a.nodes[fork_id]["neighbors"][1]
	playable.player.global_position = Vector3(a.nodes[branch_id]["coord"].x * 24, 0.1, a.nodes[branch_id]["coord"].y * 24)
	fixed._update_current_from_position()
	_check(fixed.current_room == branch_id, "Walking into side branch changes current room")
	playable.player.global_position = Vector3(0, 0.1, 0)
	fixed._update_current_from_position()
	_check(fixed.current_room == 0, "Backtracking returns to fork")
	var goal: Dictionary = a.nodes[5]
	playable.player.global_position = Vector3(goal["coord"].x * 24, 0.1, goal["coord"].y * 24)
	fixed._update_current_from_position()
	_check(playable.state == "finished", "Entering goal completes fixed run")
	_check(fixed.visited_route.size() == 4, "Visited route tracks branch, return, and goal")
	get_tree().root.remove_child(playable)
	playable.free()

	var endless_game := preload("res://arena/arena_run.tscn").instantiate()
	var endless := endless_game.get_node("RunBuilder") as RunBuilder
	endless.run_mode = RunBuilder.RunMode.ENDLESS
	get_tree().root.add_child(endless_game)
	endless_game.player.current_health = 10000
	await get_tree().physics_frame
	var initial := endless._generator.nodes.duplicate(true)
	_check(endless._live.size() <= endless._generator.graph_distance(0, 3).size(), "Endless initially loads graph window")
	var visited := {0: true}
	var current := 0
	var traversed := 0
	while traversed < 16:
		var next := -1
		for neighbor in (endless._generator.nodes[current]["neighbors"] as Dictionary).values():
			if not visited.has(neighbor):
				next = neighbor
				break
		if next < 0:
			var parent: int = endless._generator.nodes[current]["parent"]
			if parent < 0: break
			next = parent
		var next_node: Dictionary = endless._generator.nodes[next]
		endless_game.player.global_position = Vector3(next_node["coord"].x * 24, 0.1, next_node["coord"].y * 24)
		endless._update_current_from_position()
		current = next
		visited[current] = true
		traversed += 1
		_check(endless._live.size() <= endless._generator.graph_distance(current, 3).size(), "Endless live rooms remain in graph window")
	_check(traversed >= 10, "Endless traversal advances through multiple branches")
	_check(endless._generator.nodes.size() > initial.size(), "Endless graph expands ahead of player")
	_check(endless._generator.nodes[0] == initial[0], "Expanded graph retains original room plan")
	endless_game.player.global_position = Vector3.ZERO
	endless._update_current_from_position()
	_check(endless._live.has(0) and endless._generator.nodes[0] == initial[0], "Backtracking restores original room")
	_check(endless._live.size() < endless._generator.nodes.size(), "Distant room instances are cleaned up")
	get_tree().root.remove_child(endless_game)
	endless_game.free()
	print("Branching arena tests: ", "PASS" if failures == 0 else "%d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
