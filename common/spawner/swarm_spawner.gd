@tool
class_name SwarmSpawner extends Node3D

@export var enemy_scene: PackedScene = preload("res://common/enemy/swarm_enemy.tscn")
@export var enabled: bool = true
@export_range(1, 200, 1) var spawn_count: int = 32
@export_range(0.05, 10.0, 0.05) var spawn_interval: float = 0.4
@export_range(0.0, 10.0, 0.1) var spawn_radius: float = 2.0
@export var spawn_seed: int = 12345
@export_range(0.5, 50.0, 0.5) var activation_radius: float = 8.0
@export var attack_damage: float = 4.0
@export var attack_cooldown: float = 0.4
@export var separation_radius: float = 1.4

@export_group("Editor Preview")
@export var show_editor_preview: bool = true
@export var show_spawn_numbers: bool = false
@export var show_trigger_ranges: bool = true
@export_range(0, 200, 1) var preview_visual_limit: int = 32

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var swarm_visuals: MultiMeshInstance3D = $SwarmVisuals

var _enemies: Array[SwarmEnemy] = []
var _outer_enemies: Array[SwarmEnemy] = []
var _cells: Dictionary = {}
var _spawn_timer: float = 0.0
var _attack_timer: float = 0.0
var _grid_timer: float = 0.0
var _activation_timer: float = 0.0
var _spawned_total: int = 0
var _activated: bool = false
var _spawn_rng := RandomNumberGenerator.new()
var _preview_signature: Array = []
var _preview_rebuild_queued: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(true)
		_queue_editor_preview()
		return
	_spawn_rng.seed = spawn_seed
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.55
	mesh.radial_segments = 6
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.2, 0.15)
	material.roughness = 0.85
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spawn_count
	multimesh.visible_instance_count = 0
	swarm_visuals.multimesh = multimesh
	_spawn_timer = spawn_interval


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_grid_timer -= delta
	if _grid_timer <= 0.0:
		_grid_timer = 0.18
		_rebuild_grid()
	if enabled and enemy_scene and _spawned_total < spawn_count:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn_enemy()
	if not _activated and not _enemies.is_empty():
		_activation_timer -= delta
		if _activation_timer <= 0.0:
			_activation_timer = 0.1
			_check_activation()
	_update_visuals()


func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as SwarmEnemy
	if not enemy:
		push_error("Swarm spawner needs a SwarmEnemy scene.")
		enabled = false
		return
	var offset := _next_spawn_offset(_spawn_rng)
	var facing_yaw: float = _spawn_rng.randf() * TAU
	enemy.spawner = self
	enemy.visual_index = _enemies.size()
	add_child(enemy)
	enemy.global_position = spawn_point.to_global(offset)
	_apply_initial_facing(enemy, facing_yaw)
	_enemies.append(enemy)
	_refresh_outer_enemies()
	_spawned_total += 1
	if _activated:
		enemy.activate()
	swarm_visuals.multimesh.visible_instance_count = _enemies.size()


func _refresh_outer_enemies() -> void:
	_outer_enemies.clear()
	var positions: Array[Vector2] = []
	for enemy in _enemies:
		positions.append(Vector2(enemy.global_position.x, enemy.global_position.z))
	for index in _outer_hull_indices(positions):
		_outer_enemies.append(_enemies[index])


func _outer_hull_indices(positions: Array[Vector2]) -> Array[int]:
	var ordered: Array[int] = []
	for index in range(positions.size()):
		ordered.append(index)
	if ordered.size() <= 2:
		return ordered
	ordered.sort_custom(func(a: int, b: int) -> bool:
		if positions[a].x != positions[b].x:
			return positions[a].x < positions[b].x
		return positions[a].y < positions[b].y
	)
	var lower: Array[int] = []
	for index in ordered:
		while lower.size() >= 2 and _hull_cross(positions[lower[-2]], positions[lower[-1]], positions[index]) <= 0.0:
			lower.pop_back()
		lower.append(index)
	var upper: Array[int] = []
	for order_index in range(ordered.size() - 1, -1, -1):
		var index: int = ordered[order_index]
		while upper.size() >= 2 and _hull_cross(positions[upper[-2]], positions[upper[-1]], positions[index]) <= 0.0:
			upper.pop_back()
		upper.append(index)
	var outer: Array[int] = []
	for index in range(lower.size() - 1):
		outer.append(lower[index])
	for index in range(upper.size() - 1):
		outer.append(upper[index])
	return outer


func _hull_cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b - a).cross(c - a)


func _check_activation() -> void:
	var player := Global.player
	if not is_instance_valid(player) or not player.is_alive:
		return
	var radius_squared := activation_radius * activation_radius
	for enemy in _outer_enemies:
		var dx: float = player.global_position.x - enemy.global_position.x
		var dz: float = player.global_position.z - enemy.global_position.z
		if dx * dx + dz * dz <= radius_squared:
			_activated = true
			for member in _enemies:
				member.activate()
			return


func retire_enemy(enemy: SwarmEnemy) -> void:
	var index := enemy.visual_index
	if index < 0 or index >= _enemies.size() or _enemies[index] != enemy:
		return
	var last: SwarmEnemy = _enemies.pop_back()
	if last != enemy:
		_enemies[index] = last
		last.visual_index = index
	enemy.visual_index = -1
	_refresh_outer_enemies()
	swarm_visuals.multimesh.visible_instance_count = _enemies.size()


func try_attack(player: CharacterBody3D, attacker_position: Vector3) -> void:
	if _attack_timer > 0.0 or not player.is_alive:
		return
	_attack_timer = attack_cooldown
	var direction: Vector3 = player.global_position - attacker_position
	direction.y = 0.0
	player.get_damage(attack_damage, direction.normalized(), true)


func get_separation(enemy: SwarmEnemy) -> Vector3:
	if separation_radius <= 0.0:
		return Vector3.ZERO
	var cell := _cell_for(enemy.global_position)
	var force := Vector3.ZERO
	var neighbors := 0
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			var nearby: Array = _cells.get(Vector2i(x, y), [])
			for other in nearby:
				if not is_instance_valid(other) or other == enemy:
					continue
				var neighbor: SwarmEnemy = other
				var away: Vector3 = enemy.global_position - neighbor.global_position
				away.y = 0.0
				var distance_squared: float = away.length_squared()
				if distance_squared < 0.001 or distance_squared > separation_radius * separation_radius:
					continue
				force += away / distance_squared
				neighbors += 1
				if neighbors >= 12:
					return force.normalized()
	return force.normalized()


func _cell_for(world_position: Vector3) -> Vector2i:
	var size := maxf(separation_radius, 0.1)
	return Vector2i(floori(world_position.x / size), floori(world_position.z / size))


func _rebuild_grid() -> void:
	_cells.clear()
	var bounds := AABB(Vector3.ZERO, Vector3.ONE)
	var has_bounds := false
	for enemy in _enemies:
		var cell := _cell_for(enemy.global_position)
		if not _cells.has(cell):
			_cells[cell] = []
		_cells[cell].append(enemy)
		var local_position := to_local(enemy.global_position + Vector3.UP * 0.8)
		if has_bounds:
			bounds = bounds.expand(local_position)
		else:
			bounds = AABB(local_position, Vector3.ZERO)
			has_bounds = true
	if has_bounds:
		swarm_visuals.custom_aabb = bounds.grow(1.0)


func _update_visuals() -> void:
	var multimesh := swarm_visuals.multimesh
	for enemy in _enemies:
		multimesh.set_instance_transform(enemy.visual_index, Transform3D(Basis.IDENTITY, to_local(enemy.global_position + Vector3.UP * 0.8)))


func _next_spawn_offset(rng: RandomNumberGenerator) -> Vector3:
	var angle: float = rng.randf() * TAU
	var radius: float = sqrt(rng.randf()) * spawn_radius
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _apply_initial_facing(enemy: Node3D, yaw: float) -> void:
	var visual := enemy.get_node_or_null("undead") as Node3D
	if visual:
		visual.rotation.y = yaw
	else:
		enemy.rotation.y = yaw


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not is_instance_valid(spawn_point):
		return
	var signature: Array = [
		show_editor_preview, show_spawn_numbers, show_trigger_ranges, preview_visual_limit,
		spawn_count, spawn_radius, activation_radius, spawn_seed,
		enemy_scene, spawn_point.transform
	]
	if signature != _preview_signature:
		_preview_signature = signature
		_queue_editor_preview()


func _queue_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _preview_rebuild_queued:
		return
	_preview_rebuild_queued = true
	call_deferred("_rebuild_editor_preview")


func _rebuild_editor_preview() -> void:
	_preview_rebuild_queued = false
	if not Engine.is_editor_hint() or not is_inside_tree() or not is_instance_valid(spawn_point):
		return
	var old_preview := get_node_or_null("__SwarmEditorPreview") as Node3D
	if old_preview and old_preview.get_meta("swarm_editor_preview", false):
		old_preview.visible = false
		remove_child(old_preview)
		old_preview.queue_free()
	if not show_editor_preview:
		return
	var preview := Node3D.new()
	preview.name = "__SwarmEditorPreview"
	preview.set_meta("swarm_editor_preview", true)
	add_child(preview, false, Node.INTERNAL_MODE_BACK)

	var rng := RandomNumberGenerator.new()
	rng.seed = spawn_seed
	var offsets: Array[Vector3] = []
	var facings: Array[float] = []
	for index in range(spawn_count):
		offsets.append(_next_spawn_offset(rng))
		facings.append(rng.randf() * TAU)
	var layout_positions: Array[Vector2] = []
	for offset in offsets:
		var world_position := spawn_point.to_global(offset)
		layout_positions.append(Vector2(world_position.x, world_position.z))
	var outer_indices := _outer_hull_indices(layout_positions)

	var crowded: Array[bool] = []
	for index in range(spawn_count):
		crowded.append(false)
	var nearest_gap: float = INF
	for index in range(spawn_count):
		for other_index in range(index + 1, spawn_count):
			var gap: float = offsets[index].distance_to(offsets[other_index])
			nearest_gap = minf(nearest_gap, gap)
			if gap < 0.65:
				crowded[index] = true
				crowded[other_index] = true

	var guides := ImmediateMesh.new()
	guides.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material(Color(0.1, 0.9, 1.0, 1.0)))
	_append_preview_circle(guides, Vector3.ZERO, spawn_radius, 0.12, 64)
	_append_preview_cross(guides, Vector3.ZERO, 0.12, 0.35)
	guides.surface_end()
	if show_trigger_ranges:
		guides.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material(Color(1.0, 0.75, 0.1, 0.22)))
		for index in outer_indices:
			_append_preview_circle(guides, offsets[index], activation_radius, 0.05, 40)
		guides.surface_end()
	if crowded.has(false):
		guides.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material(Color(0.1, 1.0, 0.25, 1.0)))
		for index in range(spawn_count):
			if not crowded[index]:
				_append_preview_cross(guides, offsets[index], 2.0, 0.2)
		guides.surface_end()
	if crowded.has(true):
		guides.surface_begin(Mesh.PRIMITIVE_LINES, _preview_material(Color(1.0, 0.15, 0.1, 1.0)))
		for index in range(spawn_count):
			if crowded[index]:
				_append_preview_cross(guides, offsets[index], 2.0, 0.2)
		guides.surface_end()
	var guide_instance := MeshInstance3D.new()
	guide_instance.name = "SpawnAndActivationGuides"
	guide_instance.mesh = guides
	guide_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview.add_child(guide_instance, false, Node.INTERNAL_MODE_BACK)

	if enemy_scene:
		for index in range(mini(spawn_count, preview_visual_limit)):
			var enemy_preview := enemy_scene.instantiate() as Node3D
			if not enemy_preview:
				break
			enemy_preview.name = "EnemyPreview_%03d" % (index + 1)
			enemy_preview.process_mode = Node.PROCESS_MODE_DISABLED
			if enemy_preview is CollisionObject3D:
				enemy_preview.collision_layer = 0
				enemy_preview.collision_mask = 0
			preview.add_child(enemy_preview, false, Node.INTERNAL_MODE_BACK)
			enemy_preview.position = spawn_point.transform * offsets[index]
			_apply_initial_facing(enemy_preview, facings[index])

	var summary := Label3D.new()
	summary.name = "SpawnPreviewSummary"
	summary.text = "%d spawns | %d models shown\nCyan: spawn area | gold: %d outer triggers\nNearest gap: %s | red crosses: %d crowded" % [
		spawn_count, mini(spawn_count, preview_visual_limit), outer_indices.size(),
		"n/a" if nearest_gap == INF else "%.2f m" % nearest_gap,
		crowded.count(true)
	]
	summary.position = spawn_point.transform * Vector3(0.0, 2.65, 0.0)
	summary.font_size = 28
	summary.pixel_size = 0.012
	summary.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	summary.no_depth_test = true
	preview.add_child(summary, false, Node.INTERNAL_MODE_BACK)

	if show_spawn_numbers:
		for index in range(spawn_count):
			var number := Label3D.new()
			number.text = str(index + 1)
			number.position = spawn_point.transform * (offsets[index] + Vector3(0.0, 2.3, 0.0))
			number.font_size = 20
			number.pixel_size = 0.01
			number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			number.no_depth_test = true
			number.modulate = Color(1.0, 0.25, 0.2) if crowded[index] else Color(0.3, 1.0, 0.4)
			preview.add_child(number, false, Node.INTERNAL_MODE_BACK)


func _preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	return material


func _append_preview_circle(mesh: ImmediateMesh, offset: Vector3, radius: float, height: float, segments: int) -> void:
	if radius <= 0.0:
		return
	for segment in range(segments):
		var first: float = TAU * float(segment) / float(segments)
		var second: float = TAU * float(segment + 1) / float(segments)
		mesh.surface_add_vertex(spawn_point.transform * (offset + Vector3(cos(first) * radius, height, sin(first) * radius)))
		mesh.surface_add_vertex(spawn_point.transform * (offset + Vector3(cos(second) * radius, height, sin(second) * radius)))


func _append_preview_cross(mesh: ImmediateMesh, offset: Vector3, height: float, size: float) -> void:
	var center: Vector3 = spawn_point.transform * (offset + Vector3.UP * height)
	mesh.surface_add_vertex(center + Vector3.LEFT * size)
	mesh.surface_add_vertex(center + Vector3.RIGHT * size)
	mesh.surface_add_vertex(center + Vector3.FORWARD * size)
	mesh.surface_add_vertex(center + Vector3.BACK * size)
