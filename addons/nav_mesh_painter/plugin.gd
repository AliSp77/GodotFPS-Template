@tool
extends EditorPlugin

var panel: VBoxContainer
var settings_dialog: AcceptDialog
var toolbar: HBoxContainer
var info: Label
var auto_apply: CheckBox
var paint_indicator: Label
var add_tool: Button
var remove_tool: Button
var brush_label: Label
var active_operation := -1
var grid: SpinBox
var brush: SpinBox
var height: SpinBox
var target: NavigationRegion3D
var marks: Dictionary = {}
var previous: Dictionary = {}
var dragging := false
var last := Vector3.INF
var overlay: MeshInstance3D
var applying := false

func _enter_tree() -> void:
	settings_dialog = AcceptDialog.new()
	settings_dialog.title = "Navigation Mesh Painter"
	EditorInterface.get_base_control().add_child(settings_dialog)
	panel = VBoxContainer.new()
	panel.name = "Nav Mesh Paint"
	panel.custom_minimum_size.x = 230
	var label := Label.new()
	label.text = "Navigation Mesh Painter"
	panel.add_child(label)
	grid = number("Grid size", 0.1, 2.0, 0.1, 0.5)
	brush = number("Brush radius", 0.25, 10.0, 0.25, 1.0)
	brush.value_changed.connect(func(_value: float) -> void: _update_brush_label())
	height = number("Local floor height", -1000, 1000, 0.1, 0)
	auto_apply = CheckBox.new()
	auto_apply.text = "Auto apply on mouse release"
	auto_apply.button_pressed = true
	panel.add_child(auto_apply)
	paint_indicator = Label.new()
	panel.add_child(paint_indicator)
	_update_paint_indicator(false)
	button("Apply to navigation mesh", _apply)
	button("Discard pending marks", _discard)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "Select a NavigationRegion3D and choose Add or Remove in the 3D toolbar."
	panel.add_child(info)
	settings_dialog.add_child(panel)
	add_tool_menu_item("Open Navigation Mesh Painter", _open_panel)
	toolbar = HBoxContainer.new()
	toolbar.name = "Navigation Mesh Painter"
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	add_tool = _toolbar_button("Add", "Add walkable area", _choose_tool.bind(1))
	remove_tool = _toolbar_button("Remove", "Remove walkable area (hold Shift to add)", _choose_tool.bind(0))
	add_tool.toggle_mode = true
	remove_tool.toggle_mode = true
	var base := EditorInterface.get_base_control()
	if base.has_theme_icon("Add", "EditorIcons"):
		add_tool.icon = base.get_theme_icon("Add", "EditorIcons")
		add_tool.text = ""
	if base.has_theme_icon("Remove", "EditorIcons"):
		remove_tool.icon = base.get_theme_icon("Remove", "EditorIcons")
		remove_tool.text = ""
	_toolbar_button("−", "Decrease brush radius", _change_brush.bind(-1.0))
	brush_label = Label.new()
	toolbar.add_child(brush_label)
	_update_brush_label()
	_toolbar_button("+", "Increase brush radius", _change_brush.bind(1.0))
	EditorInterface.get_selection().selection_changed.connect(_select_region)
	_select_region()

func _exit_tree() -> void:
	_remove_overlay()
	EditorInterface.get_selection().selection_changed.disconnect(_select_region)
	remove_tool_menu_item("Open Navigation Mesh Painter")
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar)
	toolbar.queue_free()
	settings_dialog.queue_free()

func _open_panel() -> void:
	settings_dialog.popup_centered()

func _handles(object: Object) -> bool:
	return object is Node3D

func button(text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	panel.add_child(b)

func number(text: String, low: float, high: float, step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 90
	row.add_child(spin)
	panel.add_child(row)
	return spin

func _toolbar_button(text: String, tooltip: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.tooltip_text = tooltip
	control.pressed.connect(callback)
	toolbar.add_child(control)
	return control

func _choose_tool(operation: int) -> void:
	active_operation = -1 if active_operation == operation else operation
	add_tool.button_pressed = active_operation == 1
	remove_tool.button_pressed = active_operation == 0
	_update_paint_indicator(false)
	if active_operation >= 0 and (not is_instance_valid(target) or target.navigation_mesh == null or target.navigation_mesh.get_polygon_count() == 0):
		info.text = "Select a NavigationRegion3D with a baked mesh."

func _change_brush(direction: float) -> void:
	brush.value += direction * brush.step

func _update_brush_label() -> void:
	if is_instance_valid(brush_label):
		brush_label.text = "Brush %.2f" % brush.value

func _select_region() -> void:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	toolbar.visible = selection.size() == 1 and selection[0] is NavigationRegion3D
	if applying:
		return
	if selection.size() != 1 or not selection[0] is NavigationRegion3D:
		if marks.is_empty():
			target = null
		info.text = "Select one NavigationRegion3D in the scene tree."
		return
	if not marks.is_empty() and target != selection[0]:
		info.text = "Apply or discard pending marks before switching regions."
		return
	target = selection[0]
	if target.navigation_mesh == null or target.navigation_mesh.get_polygon_count() == 0:
		info.text = "This region needs a baked navigation mesh first."
		return
	var vertices := target.navigation_mesh.get_vertices()
	if not vertices.is_empty():
		height.value = vertices[0].y
	info.text = "Selected %s. Choose Add or Remove in the 3D toolbar." % target.name

func _update_paint_indicator(shift: bool) -> void:
	var operation := 1 if shift and active_operation >= 0 else active_operation
	paint_indicator.text = "Choose Add or Remove in the 3D toolbar." if operation < 0 else ["Painting: Remove (hold Shift to add)", "Painting: Add"][operation]
	paint_indicator.modulate = Color(0.3, 1.0, 0.45) if operation == 1 else Color.WHITE

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if active_operation < 0 or not is_instance_valid(target) or target.navigation_mesh == null or target.navigation_mesh.get_polygon_count() == 0:
		return AFTER_GUI_INPUT_PASS
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.size() != 1 or selection[0] != target:
		return AFTER_GUI_INPUT_PASS
	if event is InputEventWithModifiers:
		_update_paint_indicator(event.shift_pressed)
	if applying:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			info.text = "Applying changes; wait before painting again."
			return AFTER_GUI_INPUT_STOP
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not marks.is_empty() and (not is_equal_approx(grid.value, float(previous.size)) or not is_equal_approx(height.value, float(previous.height))):
				info.text = "Apply or discard marks before changing grid size or height."
				return AFTER_GUI_INPUT_STOP
			previous = {"size": grid.value, "height": height.value}
			dragging = true
			last = Vector3.INF
			_stamp_screen(camera, event.position, event.shift_pressed)
		else:
			var had_stroke := dragging
			dragging = false
			if had_stroke and auto_apply.button_pressed and not marks.is_empty():
				_apply()
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and dragging:
		_stamp_screen(camera, event.position, event.shift_pressed)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _stamp_screen(camera: Camera3D, mouse: Vector2, shift: bool) -> void:
	var inverse := target.global_transform.affine_inverse()
	var origin := inverse * camera.project_ray_origin(mouse)
	var direction := inverse.basis * camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		info.text = "Use a top-down view to paint on the selected floor."
		return
	var t := (height.value - origin.y) / direction.y
	if t < 0.0:
		return
	var point := origin + direction * t
	var distance := 0.0 if last == Vector3.INF else Vector2(point.x - last.x, point.z - last.z).length()
	var steps := maxi(1, ceili(distance / (grid.value * 0.5)))
	for i in range(1, steps + 1):
		_stamp(point if last == Vector3.INF else last.lerp(point, float(i) / steps), 1 if shift else active_operation)
	last = point
	_rebuild_overlay()
	info.text = "%d pending cells. Apply changes or discard them." % marks.size()

func _stamp(point: Vector3, operation: int) -> void:
	var size := float(grid.value)
	var radius := float(brush.value)
	for x in range(floori((point.x - radius) / size), floori((point.x + radius) / size) + 1):
		for z in range(floori((point.z - radius) / size), floori((point.z + radius) / size) + 1):
			var center := Vector2((x + 0.5) * size, (z + 0.5) * size)
			if center.distance_to(Vector2(point.x, point.z)) > radius:
				continue
			var key := Vector2i(x, z)
			if operation == 2:
				marks.erase(key)
			else:
				marks[key] = operation

func _remove_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

func _rebuild_overlay() -> void:
	_remove_overlay()
	if not is_instance_valid(target) or marks.is_empty():
		return
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var size: float = previous.size
	for key in marks:
		mesh.surface_set_color(Color(1, 0.2, 0.16, 0.55) if marks[key] == 0 else Color(0.1, 1, 0.5, 0.55))
		var x: float = key.x * size
		var z: float = key.y * size
		var y: float = previous.height + 0.06
		for p in [Vector3(x,y,z), Vector3(x,y,z+size), Vector3(x+size,y,z+size), Vector3(x,y,z), Vector3(x+size,y,z+size), Vector3(x+size,y,z)]:
			mesh.surface_add_vertex(p)
	mesh.surface_end()
	overlay = MeshInstance3D.new()
	overlay.mesh = mesh
	target.add_child(overlay)

func _discard() -> void:
	if applying:
		return
	marks.clear()
	_remove_overlay()
	info.text = "Pending marks discarded."

# Clip a convex 3D polygon to one side of an axis-aligned plane in X/Z.
func _clip(poly: Array[Vector3], axis: int, value: float, keep_less: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if poly.is_empty():
		return result
	var a := poly.back()
	var av: float = a.x if axis == 0 else a.z
	var a_in := av <= value if keep_less else av >= value
	for b in poly:
		var bv: float = b.x if axis == 0 else b.z
		var b_in := bv <= value if keep_less else bv >= value
		if a_in != b_in and not is_equal_approx(av, bv):
			result.append(a.lerp(b, (value - av) / (bv - av)))
		if b_in:
			result.append(b)
		a = b
		av = bv
		a_in = b_in
	return result

func _outside_cell(poly: Array[Vector3], key: Vector2i, size: float) -> Array:
	# Avoid repeatedly splitting polygons that cannot overlap this cell. Apart
	# from being expensive, clipping along a shared edge creates duplicate pieces.
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for vertex in poly:
		min_x = minf(min_x, vertex.x)
		max_x = maxf(max_x, vertex.x)
		min_z = minf(min_z, vertex.z)
		max_z = maxf(max_z, vertex.z)
	if max_x <= key.x * size or min_x >= (key.x + 1) * size or max_z <= key.y * size or min_z >= (key.y + 1) * size:
		return [poly]
	var inside := poly
	var output: Array = []
	for boundary in [[0, key.x * size, false], [0, (key.x + 1) * size, true], [1, key.y * size, false], [1, (key.y + 1) * size, true]]:
		var outside := _clip(inside, boundary[0], boundary[1], not boundary[2])
		if outside.size() >= 3:
			output.append(outside)
		inside = _clip(inside, boundary[0], boundary[1], boundary[2])
		if inside.is_empty():
			break
	return output

func _append_triangle(out: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	if cross.length_squared() < 0.0000001:
		return
	# The baker expects clockwise triangles when seen from above.
	out.append(a)
	if cross.y > 0:
		out.append(c)
		out.append(b)
	else:
		out.append(b)
		out.append(c)

func _apply() -> void:
	if applying:
		return
	if not is_instance_valid(target) or target.navigation_mesh == null or marks.is_empty():
		info.text = "Select a baked region and paint some changes first."
		return
	if not is_equal_approx(grid.value, float(previous.size)) or not is_equal_approx(height.value, float(previous.height)):
		info.text = "Restore the grid size and floor height used for the pending marks."
		return
	var original := target.navigation_mesh
	var vertices := original.get_vertices()
	var faces := PackedVector3Array()
	var size: float = previous.size
	var floor_y: float = previous.height
	applying = true
	dragging = false
	info.text = "Preparing navigation mesh..."
	for i in range(original.get_polygon_count()):
		if i % 32 == 0:
			await get_tree().process_frame
			if not is_instance_valid(target) or target.navigation_mesh != original:
				applying = false
				info.text = "Region changed; apply cancelled."
				return
		var indexes := original.get_polygon(i)
		for j in range(1, indexes.size() - 1):
			var tri: Array[Vector3] = [vertices[indexes[0]], vertices[indexes[j]], vertices[indexes[j+1]]]
			var pieces: Array = [tri]
			if absf((tri[0].y + tri[1].y + tri[2].y) / 3.0 - floor_y) <= maxf(0.5, original.cell_height * 2.0):
				for key in marks:
					if marks[key] != 0:
						continue
					var next: Array = []
					for piece in pieces:
						next.append_array(_outside_cell(piece, key, size))
					pieces = next
					if pieces.is_empty():
						break
			for piece in pieces:
				for k in range(1, piece.size() - 1):
					_append_triangle(faces, piece[0], piece[k], piece[k+1])
	for key in marks:
		if marks[key] != 1:
			continue
		var x: float = key.x * size
		var z: float = key.y * size
		var a := Vector3(x, floor_y, z)
		var b := Vector3(x, floor_y, z + size)
		var c := Vector3(x + size, floor_y, z + size)
		var d := Vector3(x + size, floor_y, z)
		_append_triangle(faces, a, b, c)
		_append_triangle(faces, a, c, d)
	if faces.is_empty():
		applying = false
		info.text = "No walkable geometry remains. The original mesh was kept."
		return
	var nav := original.duplicate(true) as NavigationMesh
	var radius := nav.agent_radius
	nav.agent_radius = 0.0
	var source := NavigationMeshSourceGeometryData3D.new()
	source.add_faces(faces, Transform3D.IDENTITY)
	info.text = "Baking navigation mesh in the background..."
	NavigationServer3D.bake_from_source_geometry_data_async(nav, source, _finish_apply.bind(target, original, nav, radius, faces))

func _restore_baked_height(nav: NavigationMesh, faces: PackedVector3Array) -> void:
	# Recast raises rasterized surfaces by voxel units on each bake. Measure that
	# offset against the input triangles so successive strokes do not drift upward.
	var vertices := nav.get_vertices()
	var offsets: Array[float] = []
	var stride := maxi(1, ceili(float(vertices.size()) / 24.0))
	var max_offset := maxf(0.5, nav.cell_height * 4.0)
	for index in range(0, vertices.size(), stride):
		var point := vertices[index]
		var best := INF
		for i in range(0, faces.size(), 3):
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var ac := Vector2(c.x - a.x, c.z - a.z)
			var ap := Vector2(point.x - a.x, point.z - a.z)
			var determinant := ab.cross(ac)
			if absf(determinant) < 0.000001:
				continue
			var u := ap.cross(ac) / determinant
			var v := ab.cross(ap) / determinant
			if u < -0.001 or v < -0.001 or u + v > 1.001:
				continue
			var delta := point.y - (a.y + u * (b.y - a.y) + v * (c.y - a.y))
			if absf(delta) < absf(best):
				best = delta
		if absf(best) <= max_offset:
			offsets.append(best)
	if offsets.is_empty():
		return
	offsets.sort()
	var offset := offsets[offsets.size() / 2]
	for i in range(vertices.size()):
		vertices[i].y -= offset
	nav.set_vertices(vertices)

func _finish_apply(region: NavigationRegion3D, original: NavigationMesh, nav: NavigationMesh, radius: float, faces: PackedVector3Array) -> void:
	applying = false
	if not is_instance_valid(region) or region.navigation_mesh != original:
		info.text = "Region changed; apply cancelled."
		return
	nav.agent_radius = radius
	if nav.get_polygon_count() == 0:
		info.text = "No polygons produced; original mesh was kept."
		return
	_restore_baked_height(nav, faces)
	var undo := get_undo_redo()
	undo.create_action("Edit navigation mesh")
	undo.add_do_property(region, "navigation_mesh", nav)
	undo.add_do_method(region, "update_gizmos")
	undo.add_undo_property(region, "navigation_mesh", original)
	undo.add_undo_method(region, "update_gizmos")
	undo.commit_action()
	_discard()
	info.text = "Applied %d polygons. Save the scene; undo restores the previous mesh." % nav.get_polygon_count()
