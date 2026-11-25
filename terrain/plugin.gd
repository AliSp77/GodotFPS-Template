@tool
extends EditorPlugin

const TerrainDock = preload("res://terrain/editor/terrain_dock.gd")
const TerrainInspector = preload("res://terrain/editor/terrain_inspector.gd")

var dock
var terrain
var stroke_before := ""
var stroke_active := false
var last_cell := Vector2i(-2147483648, -2147483648)
var selection_start := Vector2i(-1, -1)
var selection_end := Vector2i(-1, -1)
var visited_cells: Array[int] = []
var preview_timer: Timer
var preview_pending := false
var look_target
var look_property := ""
var look_before := Color.WHITE
var hover_camera: Camera3D
var hover_cell := Vector2i(-1, -1)
var dock_recovery_failed := false
var terrain_inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	terrain_inspector = TerrainInspector.new()
	terrain_inspector.generate_requested.connect(_generate_resource)
	add_inspector_plugin(terrain_inspector)
	_ensure_dock()
	preview_timer = Timer.new()
	preview_timer.one_shot = true
	preview_timer.wait_time = 0.2
	preview_timer.timeout.connect(_flush_preview)
	add_child(preview_timer)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()


func _exit_tree() -> void:
	_finish_look()
	if is_instance_valid(terrain_inspector):
		remove_inspector_plugin(terrain_inspector)
		terrain_inspector = null
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null


func _ensure_dock() -> bool:
	# Godot can retain the old dock instance when its script's base class changes
	# during an editor hot reload. Replace it before forwarding viewport events.
	if is_instance_valid(dock) and dock is ScrollContainer and dock.has_method("is_paint_enabled"):
		return true
	if dock_recovery_failed:
		return false
	var replacing_stale_dock := is_instance_valid(dock)
	if replacing_stale_dock:
		if dock.is_inside_tree():
			remove_control_from_docks(dock)
		dock.queue_free()
	dock = TerrainDock.new()
	if not (dock is ScrollContainer) or not dock.has_method("is_paint_enabled"):
		if is_instance_valid(dock):
			dock.queue_free()
		dock = null
		dock_recovery_failed = true
		push_error("Cartoon Terrain dock could not be reloaded. Disable and re-enable the plugin, or restart the Godot editor.")
		return false
	dock.name = "Cartoon Terrain"
	dock.action_requested.connect(_on_action)
	dock.preview_changed.connect(update_overlays)
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	if is_instance_valid(terrain):
		dock.set_terrain(terrain)
	if replacing_stale_dock:
		push_warning("Cartoon Terrain replaced an outdated dock after a script reload.")
	return true


func _handles(object: Object) -> bool:
	return object is Node3D and object.has_method("world_to_cell") and object.has_method("rebuild_visuals")


func _edit(object: Object) -> void:
	if not _ensure_dock():
		return
	_flush_preview()
	_finish_look()
	terrain = object as Node3D
	selection_start = Vector2i(-1, -1)
	selection_end = Vector2i(-1, -1)
	hover_cell = Vector2i(-1, -1)
	hover_camera = null
	dock.set_terrain(terrain)
	update_overlays()


func _make_visible(visible: bool) -> void:
	if _ensure_dock():
		dock.set_terrain(terrain if visible else null)
	if not visible:
		_finish_look()
		terrain = null
		hover_camera = null
		hover_cell = Vector2i(-1, -1)
		update_overlays()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not is_instance_valid(terrain) or not _ensure_dock() or not dock.is_paint_enabled() or terrain.get("data") == null:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		hover_camera = camera
		hover_cell = _pick_cell(camera, event.position)
		update_overlays()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var cell := _pick_cell(camera, event.position)
			if cell.x < 0:
				return AFTER_GUI_INPUT_PASS
			stroke_before = str(terrain.data.get("ArtifactJson"))
			stroke_active = true
			visited_cells.clear()
			last_cell = Vector2i(-2147483648, -2147483648)
			if dock.selected_tool() == "select":
				selection_start = cell
			_apply_at(cell)
		else:
			if not stroke_active:
				return AFTER_GUI_INPUT_PASS
			stroke_active = false
			_flush_preview()
			_commit_change("Paint terrain", stroke_before)
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and stroke_active:
		var cell := _pick_cell(camera, event.position)
		if cell.x >= 0:
			if dock.selected_tool() == "select":
				_apply_at(cell)
			elif dock.selected_tool() not in ["fill", "paste", "structure"]:
				_apply_segment(last_cell, cell)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _forward_3d_force_draw_over_viewport(viewport_control: Control) -> void:
	if not is_instance_valid(terrain) or not _ensure_dock() or not dock.is_paint_enabled() or terrain.data == null or not is_instance_valid(hover_camera):
		return
	if dock.selected_tool() == "select" and selection_start.x >= 0 and selection_end.x >= 0:
		var selection := _selection_rect()
		for x in range(selection.position.x, selection.end.x):
			_draw_cell(viewport_control, Vector2i(x, selection.position.y), Color(1.0, 0.73, 0.2, 0.9))
			if selection.size.y > 1:
				_draw_cell(viewport_control, Vector2i(x, selection.end.y - 1), Color(1.0, 0.73, 0.2, 0.9))
		for z in range(selection.position.y + 1, selection.end.y - 1):
			_draw_cell(viewport_control, Vector2i(selection.position.x, z), Color(1.0, 0.73, 0.2, 0.9))
			if selection.size.x > 1:
				_draw_cell(viewport_control, Vector2i(selection.end.x - 1, z), Color(1.0, 0.73, 0.2, 0.9))
	if hover_cell.x < 0:
		return
	var options: Dictionary = dock.edit_options()
	var selected_tool: String = options.tool
	var size: int = int(options.brush_size) if selected_tool not in ["fill", "paste", "structure", "select"] else 1
	var half := (size - 1) / 2.0
	var reach := ceili(half)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var metric := sqrt(float(dx * dx + dz * dz))
			if options.shape == "square":
				metric = float(maxi(absi(dx), absi(dz)))
			elif options.shape == "diamond":
				metric = float(absi(dx) + absi(dz))
			if metric <= half + 0.001:
				_draw_cell(viewport_control, hover_cell + Vector2i(dx, dz), Color(0.4, 0.9, 1.0, 0.85))


func _draw_cell(overlay: Control, cell: Vector2i, color: Color) -> void:
	var data: Resource = terrain.data
	var width: int = data.call("GetWidth")
	var height: int = data.call("GetHeight")
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return
	var size: float = data.call("GetCellSize")
	var elevation: int = data.call("GetElevation", cell.x, cell.y)
	if int(data.call("GetTile", cell.x, cell.y)) == 4:
		elevation = -clampi(absi(elevation), 5, 8)
	var y: float = float(elevation) * float(data.call("GetLevelHeight")) + 0.05
	var x0 := (float(cell.x) - float(width) * 0.5) * size
	var z0 := (float(cell.y) - float(height) * 0.5) * size
	var points := PackedVector2Array()
	for corner in [Vector3(x0, y, z0), Vector3(x0 + size, y, z0), Vector3(x0 + size, y, z0 + size), Vector3(x0, y, z0 + size), Vector3(x0, y, z0)]:
		var world: Vector3 = terrain.to_global(corner)
		if hover_camera.is_position_behind(world):
			return
		points.append(hover_camera.unproject_position(world))
	overlay.draw_polyline(points, color, 1.5, true)


func _pick_cell(camera: Camera3D, screen: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 10000.0)
	query.collide_with_areas = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3
	var collider: Node = hit.get("collider") as Node
	if collider != null and (collider == terrain or terrain.is_ancestor_of(collider)):
		point = hit.position
	else:
		# A flat fallback keeps an empty or temporarily unbuilt map editable.
		var local_origin: Vector3 = terrain.to_local(origin)
		var local_direction: Vector3 = terrain.global_transform.basis.inverse() * direction
		if absf(local_direction.y) < 0.00001:
			return Vector2i(-1, -1)
		var distance := -local_origin.y / local_direction.y
		if distance < 0.0:
			return Vector2i(-1, -1)
		point = terrain.to_global(local_origin + local_direction * distance)
	var cell: Vector2i = terrain.world_to_cell(point)
	if cell.x < 0 or cell.y < 0 or cell.x >= int(terrain.data.call("GetWidth")) or cell.y >= int(terrain.data.call("GetHeight")):
		return Vector2i(-1, -1)
	return cell


func _apply_at(cell: Vector2i) -> void:
	if cell == last_cell:
		return
	last_cell = cell
	var data: Resource = terrain.data
	if dock.selected_tool() == "select":
		selection_end = cell
		var region := _selection_rect()
		dock.set_message("Selected (%d, %d), %d × %d cells." % [region.position.x, region.position.y, region.size.x, region.size.y])
		return
	if dock.selected_tool() == "paste":
		if not data.call("PasteRegion", cell.x, cell.y):
			return
	elif data.has_method("ApplyEdit"):
		var options: Dictionary = dock.edit_options()
		options["visited"] = visited_cells
		if not data.call("ApplyEdit", cell.x, cell.y, options):
			return
	else:
		dock.set_message("The terrain data editing API is unavailable. Build the .NET project.")
		return
	terrain.mark_dirty()
	preview_pending = true
	preview_timer.start()
	if _ensure_dock():
		dock.refresh_status()


func _apply_segment(from: Vector2i, to: Vector2i) -> void:
	var delta := to - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		return
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		_apply_at(Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t))))


func _commit_change(label: String, before: String) -> void:
	if not is_instance_valid(terrain) or terrain.data == null:
		return
	var after := str(terrain.data.get("ArtifactJson"))
	if before == after:
		return
	var history := get_undo_redo()
	history.create_action(label, UndoRedo.MERGE_DISABLE, terrain)
	history.add_do_method(self, "_restore_json", terrain, after)
	history.add_undo_method(self, "_restore_json", terrain, before)
	history.commit_action(false)


func _restore_json(target, json: String) -> void:
	if not is_instance_valid(target) or target.data == null:
		return
	preview_timer.stop()
	preview_pending = false
	target.data.set("ArtifactJson", json)
	target.mark_dirty()
	target.rebuild_visuals()
	if _ensure_dock():
		dock.refresh_status()


func _flush_preview() -> void:
	if preview_timer == null or not preview_pending:
		return
	preview_timer.stop()
	preview_pending = false
	if is_instance_valid(terrain) and terrain.data != null:
		terrain.rebuild_visuals()


func _on_action(action: String, arguments: Dictionary) -> void:
	if not is_instance_valid(terrain) or not _ensure_dock():
		return
	if action == "look_begin":
		_finish_look()
		look_target = terrain
		look_property = arguments.property
		look_before = terrain.get(look_property)
		return
	if action == "look_change":
		if is_instance_valid(look_target) and look_target == terrain and look_property == arguments.property:
			look_target.set(look_property, arguments.color)
		return
	if action == "look_end":
		_finish_look()
		return
	if action == "new_data":
		if terrain.data != null:
			dock.set_message("This terrain already has data. Remove it in the Inspector before creating new data.")
			return
		var script := load("res://terrain/core/CartoonTerrainData.cs")
		if script == null or not script.can_instantiate():
			dock.set_message("Build the C# project before creating terrain data.")
			return
		var history := get_undo_redo()
		history.create_action("Create terrain data", UndoRedo.MERGE_DISABLE, terrain)
		history.add_do_property(terrain, "data", script.new())
		history.add_undo_property(terrain, "data", null)
		history.commit_action()
		dock.refresh_status()
		return
	if terrain.data == null:
		dock.set_message("Create or assign terrain data first.")
		return
	var data: Resource = terrain.data
	var before := str(data.get("ArtifactJson"))
	match action:
		"generate":
			_generate_resource(data)
		"import":
			if not data.call("ImportJson", arguments.path):
				dock.set_message("Import failed. See the Output panel for details.")
				return
			terrain.mark_dirty()
			terrain.rebuild_visuals()
			_commit_change("Import terrain", before)
		"export":
			dock.set_message("Exported terrain JSON." if data.call("ExportJson", arguments.path) else "Export failed. See the Output panel for details.")
		"copy", "cut", "clear":
			if selection_start.x < 0 or selection_end.x < 0:
				dock.set_message("Drag a rectangle with the Select tool first.")
				return
			var region := _selection_rect()
			if action != "clear":
				data.call("CopyRegion", region.position.x, region.position.y, region.size.x, region.size.y)
			if action != "copy":
				data.call("ClearRegion", region.position.x, region.position.y, region.size.x, region.size.y)
				terrain.mark_dirty()
				terrain.rebuild_visuals()
				_commit_change("Edit terrain selection", before)
			dock.set_message("Selection %s." % action)
		"save_data":
			var error := ResourceSaver.save(data, arguments.path)
			dock.set_message("Saved terrain data." if error == OK else "Could not save terrain data (error %d)." % error)
		"rebuild_visuals":
			terrain.rebuild_visuals()
			dock.set_message(str(terrain.status))
		"rebuild_collision":
			terrain.rebuild_collision()
			dock.set_message(str(terrain.status))
		"bake_navigation":
			terrain.bake_navigation()
			dock.set_message(str(terrain.status))
		"validate_spawns":
			terrain.validate_spawn_markers()
			dock.set_message(str(terrain.status))
	dock.refresh_status()


func _generate_resource(data: Resource) -> void:
	if not is_instance_valid(data) or not data.has_method("GenerateFromSettings"):
		push_error("Build the C# project to enable terrain generation.")
		return
	var before := str(data.get("ArtifactJson"))
	var seed_before := str(data.get("GenerationSeed"))
	data.call("GenerateFromSettings")
	var after := str(data.get("ArtifactJson"))
	var seed_after := str(data.get("GenerationSeed"))
	if after != before or seed_after != seed_before:
		var history := get_undo_redo()
		history.create_action("Generate terrain", UndoRedo.MERGE_DISABLE, data)
		history.add_do_method(self, "_restore_generated_resource", data, after, seed_after)
		history.add_undo_method(self, "_restore_generated_resource", data, before, seed_before)
		history.commit_action(false)
	_refresh_resource_terrains(data)
	if is_instance_valid(dock):
		dock.set_message("Generated map using saved data settings. Seed: " + seed_after)


func _restore_generated_resource(data: Resource, json: String, saved_seed: String) -> void:
	if not is_instance_valid(data):
		return
	data.set("GenerationSeed", saved_seed)
	data.set("ArtifactJson", json)
	_refresh_resource_terrains(data)


func _refresh_resource_terrains(data: Resource) -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return
	var pending: Array[Node] = [scene_root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CartoonTerrain and node.data == data:
			node.mark_dirty()
			node.rebuild_visuals()
		pending.append_array(node.get_children())


func _selection_rect() -> Rect2i:
	var top_left := Vector2i(mini(selection_start.x, selection_end.x), mini(selection_start.y, selection_end.y))
	var bottom_right := Vector2i(maxi(selection_start.x, selection_end.x), maxi(selection_start.y, selection_end.y))
	return Rect2i(top_left, bottom_right - top_left + Vector2i.ONE)


func _finish_look() -> void:
	if not is_instance_valid(look_target) or look_property.is_empty():
		look_target = null
		look_property = ""
		return
	var after: Color = look_target.get(look_property)
	if after != look_before:
		var history := get_undo_redo()
		history.create_action("Change terrain tint", UndoRedo.MERGE_DISABLE, look_target)
		history.add_do_property(look_target, look_property, after)
		history.add_undo_property(look_target, look_property, look_before)
		history.commit_action(false)
	look_target = null
	look_property = ""
