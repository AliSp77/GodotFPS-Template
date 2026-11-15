@tool
extends Node3D
class_name RunBuilder

const ARENA := preload("res://arena/arena_segment.gd")
const GENERATOR := preload("res://arena/run_generator.gd")
const ENEMY_SCENE := preload("res://arena/arena_ship.tscn")
const OBSTACLE_SCENE := preload("res://world/static/block.tscn")
const DIRECTIONS := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
enum RunMode { FIXED, ENDLESS }

@export_category("Run")
@export var segment_library: Array[PackedScene] = []:
	set(value):
		segment_library = value
		_queue_preview()
@export var run_seed := 42:
	set(value):
		run_seed = value
		_queue_preview()
@export_enum("Fixed", "Endless") var run_mode: int = RunMode.FIXED:
	set(value):
		run_mode = value
		_queue_preview()
@export_range(2, 50, 1) var goal_depth := 6:
	set(value):
		goal_depth = value
		_queue_preview()
@export_range(2, 200, 1) var room_budget := 24:
	set(value):
		room_budget = value
		_queue_preview()
@export_range(1, 30, 1) var preview_depth := 6:
	set(value):
		preview_depth = value
		_queue_preview()
@export_range(0.0, 1.0, 0.05) var fork_frequency := 0.6:
	set(value):
		fork_frequency = value
		_queue_preview()
@export_range(0.0, 1.0, 0.05) var dead_end_frequency := 0.3:
	set(value):
		dead_end_frequency = value
		_queue_preview()

@export_category("Targets per 100 square metres")
@export_range(0.0, 4.0, 0.1) var enemy_density := 0.5:
	set(value):
		enemy_density = value
		_queue_preview()
@export_range(0.0, 4.0, 0.1) var obstacle_density := 0.7:
	set(value):
		obstacle_density = value
		_queue_preview()

@export_category("Inspection")
@export_tool_button("Regenerate preview") var regenerate_action = regenerate_preview
@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY) var preview_report := ""

@export_category("Runtime")
@export var player_path: NodePath = ^"../Player"
@export_range(1, 8, 1) var graph_window := 3

var _generator: RunGenerator
var _live: Dictionary = {}
var _preview_queued := false
var _player: Node3D
var current_room := 0
var visited_route := PackedInt32Array()

func _ready() -> void:
	if Engine.is_editor_hint():
		_queue_preview()
		return
	_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		push_error("RunBuilder: player_path must point to the FPS player.")
		return
	_start_generation()
	if _generator == null or not _generator.errors.is_empty(): return
	visited_route.append(0)
	if run_mode == RunMode.FIXED:
		for id in _generator.nodes.size(): _instance_room(id)
	else:
		_sync_endless_window()
	preview_report = _format_report()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _generator == null or _player == null: return
	_update_current_from_position()

func regenerate_preview() -> void:
	_preview_queued = false
	_clear_instances()
	_start_generation()
	if _generator == null: return
	if not _generator.errors.is_empty():
		preview_report = "Invalid arena library or graph:\n" + "\n".join(_generator.errors)
		push_warning(preview_report)
		notify_property_list_changed()
		return
	for id in _generator.nodes.size():
		if _generator.nodes[id]["depth"] <= preview_depth: _instance_room(id)
	preview_report = _format_report()
	notify_property_list_changed()

func _queue_preview() -> void:
	if Engine.is_editor_hint() and is_inside_tree() and not _preview_queued:
		_preview_queued = true
		call_deferred("regenerate_preview")

func _start_generation() -> void:
	_clear_instances()
	_generator = GENERATOR.new(segment_library, run_seed, enemy_density, obstacle_density)
	if run_mode == RunMode.FIXED:
		_generator.build_fixed(goal_depth, room_budget, fork_frequency, dead_end_frequency)
	else:
		_generator.build_endless(preview_depth, fork_frequency, dead_end_frequency)
	for issue in _generator.errors: push_warning("RunBuilder: " + issue)

func _instance_room(id: int) -> void:
	if _live.has(id): return
	var node: Dictionary = _generator.nodes[id]
	var entry: Dictionary = node["entry"]
	var arena := (entry["scene"] as PackedScene).instantiate() as ArenaSegment
	if arena == null: return
	var container := get_node_or_null("Generated") as Node3D
	if container == null:
		push_error("RunBuilder requires a Generated Node3D child.")
		arena.free()
		return
	arena.name = "Room_%03d_%s" % [id, entry["name"]]
	arena.position = Vector3(node["coord"].x * ARENA.SIZE, 0, node["coord"].y * ARENA.SIZE)
	arena.rotation.y = float(node["rotation"]) * PI * 0.5
	container.add_child(arena)
	var spawned_enemies := Node3D.new()
	spawned_enemies.name = "GeneratedEnemies"
	arena.add_child(spawned_enemies)
	var spawned_obstacles := Node3D.new()
	spawned_obstacles.name = "GeneratedObstacles"
	arena.add_child(spawned_obstacles)
	var enemy_markers := arena.enemy_slots()
	for slot in entry["enemy_slots"]:
		var enemy := ENEMY_SCENE.instantiate() as Node3D
		enemy.transform = enemy_markers[slot].transform
		if not Engine.is_editor_hint(): _bind_enemy(enemy)
		spawned_enemies.add_child(enemy)
	var obstacle_markers := arena.obstacle_slots()
	for slot in entry["obstacle_slots"]:
		var obstacle := OBSTACLE_SCENE.instantiate() as Node3D
		obstacle.transform = obstacle_markers[slot].transform
		spawned_obstacles.add_child(obstacle)
	if not Engine.is_editor_hint():
		for enemy in arena.get_node("AuthoredEnemies").get_children(): _bind_enemy(enemy)
		for direction in (node["neighbors"] as Dictionary).keys():
			_add_door_trigger(arena, id, direction, node["rotation"])
	_live[id] = arena

func _bind_enemy(enemy: Node) -> void:
	for property in enemy.get_property_list():
		if property["name"] == "player": enemy.set("player", _player)
		if property["name"] == "game": enemy.set("game", get_parent())

func _add_door_trigger(arena: ArenaSegment, id: int, world_direction: int, rotation_quarters: int) -> void:
	var local_direction: int = posmod(world_direction + rotation_quarters, 4)
	var area := Area3D.new()
	area.name = "DoorTrigger_%d" % world_direction
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	area.position = DIRECTIONS[local_direction] * 10.8 + Vector3.UP
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 2.5, 2) if local_direction % 2 == 0 else Vector3(2, 2.5, 4)
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(_on_door_entered.bind(id))
	arena.add_child(area)

func _on_door_entered(body: Node3D, id: int) -> void:
	if body == _player: _enter_room(id)

func _update_current_from_position() -> void:
	var coord := Vector2i(roundi(_player.global_position.x / ARENA.SIZE), roundi(_player.global_position.z / ARENA.SIZE))
	for node in _generator.nodes:
		if node["coord"] == coord:
			if node["id"] != current_room: _enter_room(node["id"])
			return

func _enter_room(id: int) -> void:
	if id == current_room or id < 0 or id >= _generator.nodes.size(): return
	current_room = id
	visited_route.append(id)
	if run_mode == RunMode.ENDLESS: _sync_endless_window()
	preview_report = _format_report()
	if _generator.nodes[id]["type"] == ARENA.RoomType.GOAL:
		var game := get_parent()
		if game != null and game.has_method("finish_run"): game.finish_run(true)

func _sync_endless_window() -> void:
	_generator.expand_from(current_room, graph_window)
	var distances := _generator.graph_distance(current_room, graph_window)
	for id in distances.keys(): _instance_room(id)
	for id in _live.keys():
		if not distances.has(id):
			var arena := _live[id] as Node3D
			_live.erase(id)
			arena.get_parent().remove_child(arena)
			arena.queue_free()

func _clear_instances() -> void:
	_live.clear()
	var container := get_node_or_null("Generated")
	if container != null:
		for child in container.get_children():
			container.remove_child(child)
			child.free()

func _format_report() -> String:
	var title := "Fixed" if run_mode == RunMode.FIXED else "Endless"
	var lines := PackedStringArray(["%s graph | seed %d | %d rooms" % [title, run_seed, _generator.nodes.size()], "Counts actual/target; density per 100 m²."])
	var totals := [0, 0, 0, 0]
	for node in _generator.nodes:
		var entry: Dictionary = node["entry"]
		var type_name: String = ["straight", "fork", "dead end", "goal"][node["type"]]
		var e: int = entry["enemies"]
		var o: int = entry["obstacles"]
		var et: int = entry["enemy_target"]
		var ot: int = entry["obstacle_target"]
		totals[0] += e
		totals[1] += et
		totals[2] += o
		totals[3] += ot
		lines.append("%02d %s %s rot%d %s | E %d/%d (%.2f) | O %d/%d (%.2f)" % [node["id"], type_name, node["coord"], node["rotation"], entry["name"], e, et, e * 100.0 / ARENA.AREA, o, ot, o * 100.0 / ARENA.AREA])
	var area := maxf(_generator.nodes.size() * ARENA.AREA, 1.0)
	lines.append("TOTAL | E %d/%d (%.2f) | O %d/%d (%.2f)" % [totals[0], totals[1], totals[0] * 100.0 / area, totals[2], totals[3], totals[2] * 100.0 / area])
	lines.append("Difference | E %+d | O %+d" % [totals[0] - totals[1], totals[2] - totals[3]])
	var route := PackedStringArray()
	for id in visited_route: route.append(str(id))
	lines.append("Visited route | " + (" -> ".join(route) if not route.is_empty() else "editor preview"))
	return "\n".join(lines)
