@tool
extends RefCounted
class_name RunGenerator

const ARENA := preload("res://arena/arena_segment.gd")
const STEP := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var errors := PackedStringArray()
var nodes: Array[Dictionary] = []
var _specs: Dictionary = {}
var _occupied: Dictionary = {}
var _reserved: Dictionary = {}
var _pending: Array[Dictionary] = []
var _seed := 0
var _enemy_density := 0.5
var _obstacle_density := 0.7
var _fork_frequency := 0.6
var _dead_end_frequency := 0.3

func _init(library: Array[PackedScene], seed_value: int, enemy_density: float, obstacle_density: float) -> void:
	_seed = seed_value
	_enemy_density = maxf(enemy_density, 0.0)
	_obstacle_density = maxf(obstacle_density, 0.0)
	for type in range(4): _specs[type] = []
	for scene in library:
		if scene == null:
			errors.append("The segment library contains an empty slot.")
			continue
		var instance := scene.instantiate()
		if not instance is ArenaSegment:
			errors.append("%s does not have an ArenaSegment root." % scene.resource_path)
			instance.free()
			continue
		var arena := instance as ArenaSegment
		var issues := arena.validation_errors()
		for issue in issues: errors.append("%s: %s" % [scene.resource_path, issue])
		if issues.is_empty():
			_specs[arena.room_type].append({
				"scene": scene,
				"name": scene.resource_path.get_file().get_basename(),
				"weight": arena.selection_weight,
				"enemies": arena.authored_enemy_count(),
				"obstacles": arena.authored_obstacle_count(),
				"enemy_slots": arena.enemy_slots().size(),
				"obstacle_slots": arena.obstacle_slots().size()
			})
		instance.free()
	for type in range(4):
		if (_specs[type] as Array).is_empty():
			errors.append("The library needs at least one %s arena." % ["straight", "fork", "dead end", "goal"][type])

func build_fixed(goal_depth: int, room_budget: int, fork_frequency: float, dead_end_frequency: float) -> void:
	_reset(fork_frequency, dead_end_frequency)
	if not errors.is_empty(): return
	goal_depth = maxi(goal_depth, 2)
	room_budget = maxi(room_budget, goal_depth)
	_add_node(ARENA.RoomType.STRAIGHT, Vector2i.ZERO, 0, -1)
	for depth in range(1, goal_depth):
		var type := ARENA.RoomType.GOAL if depth == goal_depth - 1 else ARENA.RoomType.STRAIGHT
		var id := _add_node(type, Vector2i(0, -depth), 0, depth - 1)
		_connect(depth - 1, id, 0)
	for depth in range(goal_depth - 1):
		if nodes.size() + _pending.size() + 1 >= room_budget: break
		var coord := Vector2i(1, -depth)
		if _can_reserve(coord) and _roll(nodes[depth]["coord"], 17) < _fork_frequency:
			var node := nodes[depth]
			node["type"] = ARENA.RoomType.FORK
			node["entry"] = _make_entry(ARENA.RoomType.FORK, node["coord"])
			nodes[depth] = node
			_reserve(depth, 1)
	while not _pending.is_empty() and nodes.size() < room_budget:
		_fill_frontier(_pending.pop_front(), room_budget)
	if _pending.size() > 0:
		errors.append("Room budget cannot close every planned branch; increase room budget.")

func build_endless(preview_depth: int, fork_frequency: float, dead_end_frequency: float) -> void:
	_reset(fork_frequency, dead_end_frequency)
	if not errors.is_empty(): return
	var root_type := ARENA.RoomType.FORK if _roll(Vector2i.ZERO, 17) < _fork_frequency else ARENA.RoomType.STRAIGHT
	_add_node(root_type, Vector2i.ZERO, 0, -1)
	_reserve(0, 0)
	if root_type == ARENA.RoomType.FORK: _reserve(0, 1)
	expand_from(0, preview_depth)

func expand_from(current_id: int, radius: int) -> void:
	if current_id < 0 or current_id >= nodes.size() or not errors.is_empty(): return
	var queue: Array[Dictionary] = [{"id": current_id, "distance": 0}]
	var seen := {}
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		var id: int = item["id"]
		var distance: int = item["distance"]
		if seen.has(id) or distance > radius: continue
		seen[id] = true
		if distance < radius:
			var frontier_count := _pending.size()
			for index in frontier_count:
				var frontier := _pending[index]
				if frontier["parent"] == id:
					_pending.remove_at(index)
					_fill_frontier(frontier, 1000000)
					break
			# A fork can have two unexpanded doors.
			frontier_count = _pending.size()
			for index in frontier_count:
				var frontier := _pending[index]
				if frontier["parent"] == id:
					_pending.remove_at(index)
					_fill_frontier(frontier, 1000000)
					break
		for neighbor in (nodes[id]["neighbors"] as Dictionary).values():
			queue.append({"id": neighbor, "distance": distance + 1})

func graph_distance(start_id: int, radius: int) -> Dictionary:
	var distances := {start_id: 0}
	var queue := [start_id]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if distances[id] >= radius: continue
		for neighbor in (nodes[id]["neighbors"] as Dictionary).values():
			if not distances.has(neighbor):
				distances[neighbor] = distances[id] + 1
				queue.append(neighbor)
	return distances

func _reset(fork_frequency: float, dead_end_frequency: float) -> void:
	nodes.clear()
	_occupied.clear()
	_reserved.clear()
	_pending.clear()
	_fork_frequency = clampf(fork_frequency, 0.0, 1.0)
	_dead_end_frequency = clampf(dead_end_frequency, 0.0, 1.0)

func _add_node(type: int, coord: Vector2i, rotation_quarters: int, parent: int) -> int:
	var id := nodes.size()
	var depth := 0 if parent < 0 else int(nodes[parent]["depth"]) + 1
	nodes.append({
		"id": id, "coord": coord, "rotation": rotation_quarters,
		"type": type, "parent": parent, "depth": depth,
		"neighbors": {}, "entry": _make_entry(type, coord)
	})
	_occupied[coord] = id
	_reserved.erase(coord)
	return id

func _connect(parent: int, child: int, direction: int) -> void:
	var a := nodes[parent]
	var b := nodes[child]
	a["neighbors"][direction] = child
	b["neighbors"][(direction + 2) % 4] = parent
	nodes[parent] = a
	nodes[child] = b

func _reserve(parent: int, local_direction: int) -> void:
	var node := nodes[parent]
	var direction: int = posmod(local_direction - int(node["rotation"]), 4)
	var coord: Vector2i = node["coord"] + STEP[direction]
	if not _can_reserve(coord): return
	_reserved[coord] = true
	_pending.append({"parent": parent, "direction": direction, "coord": coord})

func _can_reserve(coord: Vector2i) -> bool:
	return not _occupied.has(coord) and not _reserved.has(coord)

func _fill_frontier(frontier: Dictionary, budget: int) -> void:
	var coord: Vector2i = frontier["coord"]
	var direction: int = frontier["direction"]
	var rotation_quarters: int = posmod(4 - direction, 4)
	var forward: Vector2i = coord + STEP[direction]
	var side: Vector2i = coord + STEP[(direction + 1) % 4]
	var remaining := budget - nodes.size()
	var type := ARENA.RoomType.DEAD_END
	if remaining > _pending.size() + 1 and _can_reserve(forward) and _roll(coord, 31) >= _dead_end_frequency:
		type = ARENA.RoomType.STRAIGHT
		if remaining > _pending.size() + 2 and _can_reserve(side) and _roll(coord, 17) < _fork_frequency:
			type = ARENA.RoomType.FORK
	var id := _add_node(type, coord, rotation_quarters, frontier["parent"])
	_connect(frontier["parent"], id, direction)
	if type == ARENA.RoomType.STRAIGHT or type == ARENA.RoomType.FORK:
		_reserve(id, 0)
	if type == ARENA.RoomType.FORK:
		_reserve(id, 1)

func _make_entry(type: int, coord: Vector2i) -> Dictionary:
	var specs: Array = _specs[type]
	var enemy_target := roundi(_enemy_density * ARENA.AREA / 100.0)
	var obstacle_target := roundi(_obstacle_density * ARENA.AREA / 100.0)
	var rng := _rng(coord, 89)
	var weights: Array[float] = []
	var total := 0.0
	for spec in specs:
		var gap := _unreachable_gap(enemy_target, spec["enemies"], spec["enemy_slots"]) + _unreachable_gap(obstacle_target, spec["obstacles"], spec["obstacle_slots"])
		var weight: float = spec["weight"] / (1.0 + 4.0 * gap)
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	var chosen := specs.size() - 1
	for index in weights.size():
		roll -= weights[index]
		if roll <= 0.0:
			chosen = index
			break
	var spec: Dictionary = specs[chosen]
	var enemy_extra: int = clampi(enemy_target - spec["enemies"], 0, spec["enemy_slots"])
	var obstacle_extra: int = clampi(obstacle_target - spec["obstacles"], 0, spec["obstacle_slots"])
	return {
		"scene": spec["scene"], "name": spec["name"],
		"enemy_slots": _choose_slots(spec["enemy_slots"], enemy_extra, rng),
		"obstacle_slots": _choose_slots(spec["obstacle_slots"], obstacle_extra, rng),
		"enemies": spec["enemies"] + enemy_extra,
		"obstacles": spec["obstacles"] + obstacle_extra,
		"enemy_target": enemy_target, "obstacle_target": obstacle_target
	}

func _unreachable_gap(target: int, authored: int, slots: int) -> int:
	return authored - target if target < authored else maxi(target - authored - slots, 0)

func _choose_slots(slot_count: int, chosen_count: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index in slot_count: indices.append(index)
	for index in range(slot_count - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var old := indices[index]
		indices[index] = indices[swap_index]
		indices[swap_index] = old
	indices.resize(chosen_count)
	indices.sort()
	return indices

func _roll(coord: Vector2i, salt: int) -> float:
	return _rng(coord, salt).randf()

func _rng(coord: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ (coord.x * 73856093) ^ (coord.y * 19349663) ^ salt
	return rng
