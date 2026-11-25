@tool
class_name CartoonTerrain
extends Node3D
## A finite editable map. User-authored scene children are never replaced by rebuilds.

const Gameplay = preload("res://terrain/gameplay/terrain_gameplay.gd")
const RENDERER_SCRIPT = "res://terrain/render/CartoonTerrainRenderer.cs"

@export var data: CartoonTerrainData:
	set(value):
		if data == value:
			return
		if data and data.changed.is_connected(_on_data_changed):
			data.changed.disconnect(_on_data_changed)
		data = value
		if data and not data.changed.is_connected(_on_data_changed):
			data.changed.connect(_on_data_changed)
		mark_dirty()
		if is_inside_tree():
			call_deferred("rebuild_visuals")

@export_storage var collision_stale := true
@export_storage var nav_stale := true
@export_storage var baked_navigation: NavigationMesh
@export_group("Appearance")
@export var ground_tint := Color.WHITE:
	set(value):
		ground_tint = value
		_apply_look()
@export var water_tint := Color.WHITE:
	set(value):
		water_tint = value
		_apply_look()
@export var foliage_tint := Color.WHITE:
	set(value):
		foliage_tint = value
		_apply_look()
var status := "No terrain data"
var _renderer: Node3D


func _ready() -> void:
	if data and not data.changed.is_connected(_on_data_changed):
		data.changed.connect(_on_data_changed)
	_ensure_navigation()
	if data:
		call_deferred("rebuild_visuals")


func _on_data_changed() -> void:
	mark_dirty()


func mark_dirty() -> void:
	collision_stale = true
	nav_stale = true
	update_configuration_warnings()


func world_to_cell(point: Vector3) -> Vector2i:
	if not data:
		return Vector2i(-1, -1)
	var local := to_local(point)
	var size: float = data.GetCellSize()
	if size <= 0.0:
		return Vector2i(-1, -1)
	return Vector2i(floori(local.x / size + data.GetWidth() * 0.5), floori(local.z / size + data.GetHeight() * 0.5))


func rebuild_visuals() -> bool:
	if not data:
		status = "Assign or create terrain data first."
		return false
	if not is_instance_valid(_renderer):
		var script := load(RENDERER_SCRIPT)
		if script == null or not script.can_instantiate():
			status = "Build the Godot .NET project to enable the terrain renderer."
			push_warning(status)
			return false
		_renderer = script.new()
		_renderer.name = "TerrainPreview"
		add_child(_renderer)
	_apply_look()
	var ok: bool = _renderer.Build(data)
	status = _renderer.Status
	return ok


func rebuild_collision() -> bool:
	if not data or not is_instance_valid(_renderer) or not _renderer.Ready:
		status = "Wait for the terrain visual bake to finish before building collision."
		return false
	var replacement: Node3D = Gameplay.build_collision(data, self)
	if replacement == null:
		status = "Collision build failed; previous collision was retained."
		return false
	var previous := get_node_or_null("TerrainCollision")
	if previous:
		remove_child(previous)
		previous.queue_free()
	add_child(replacement)
	_set_scene_owner(replacement)
	collision_stale = false
	nav_stale = true
	status = "Collision built; navigation needs a bake."
	update_configuration_warnings()
	return true


func bake_navigation() -> bool:
	if not data or collision_stale:
		status = "Build collision before baking navigation."
		return false
	var baked: NavigationMesh = Gameplay.bake_navigation(data, get_node_or_null("TerrainCollision"))
	if baked == null or baked.get_polygon_count() == 0:
		status = "Navigation bake returned no walkable polygons; previous navigation was retained."
		return false
	baked_navigation = baked
	_ensure_navigation().navigation_mesh = baked
	nav_stale = false
	status = "Navigation baked."
	update_configuration_warnings()
	call_deferred("validate_spawn_markers")
	return true


func _apply_look() -> void:
	if is_instance_valid(_renderer) and _renderer.has_method("SetLook"):
		_renderer.SetLook(ground_tint, water_tint, foliage_tint)


func validate_spawn_markers() -> void:
	if not is_inside_tree() or nav_stale:
		return
	# NavigationServer synchronizes regions after physics frames.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or nav_stale:
		return
	var markers := get_tree().get_nodes_in_group("cartoon_terrain_spawn")
	if markers.is_empty():
		status = "No spawn markers to validate; add markers to the cartoon_terrain_spawn group."
		return
	var issues: PackedStringArray = Gameplay.validate_spawns(self, markers)
	status = "Spawn markers are reachable." if issues.is_empty() else "; ".join(issues)
	if not issues.is_empty():
		push_warning("Cartoon terrain: " + status)


func _ensure_navigation() -> NavigationRegion3D:
	var region := get_node_or_null("TerrainNavigation") as NavigationRegion3D
	if region == null:
		region = NavigationRegion3D.new()
		region.name = "TerrainNavigation"
		add_child(region)
		_set_scene_owner(region)
	region.navigation_mesh = baked_navigation
	return region


func _set_scene_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var scene_root := get_tree().edited_scene_root
	if scene_root == null or not (scene_root == self or scene_root.is_ancestor_of(self)):
		return
	node.owner = scene_root
	for child in node.get_children():
		_set_scene_owner(child)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if data == null:
		warnings.append("Assign a CartoonTerrainData resource in the inspector or create one using the terrain dock.")
	if collision_stale:
		warnings.append("Terrain collision is stale. Rebuild it after the visual bake finishes.")
	if nav_stale:
		warnings.append("Terrain navigation is stale. Bake navigation after rebuilding collision.")
	return warnings
