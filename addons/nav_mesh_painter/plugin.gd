@tool
extends EditorPlugin

var panel: VBoxContainer
var info: Label
var mode: OptionButton
var painting: Button
var grid: SpinBox
var brush: SpinBox
var height: SpinBox
var target: NavigationRegion3D
var marks: Dictionary = {}
var previous: Dictionary = {}
var dragging := false
var last := Vector3.INF
var overlay: MeshInstance3D

func _enter_tree() -> void:
	panel = VBoxContainer.new()
	panel.name = "Nav Mesh Paint"
	panel.custom_minimum_size.x = 230
	var label := Label.new()
	label.text = "Navigation Mesh Painter"
	panel.add_child(label)
	button("Use selected NavigationRegion3D", _select_region)
	grid = number("Grid size", 0.1, 2.0, 0.1, 0.5)
	brush = number("Brush radius", 0.25, 10.0, 0.25, 1.0)
	height = number("Local floor height", -1000, 1000, 0.1, 0)
	mode = OptionButton.new()
	mode.add_item("Remove walkable area")
	mode.add_item("Add walkable area")
	mode.add_item("Erase pending marks")
	panel.add_child(mode)
	painting = Button.new()
	painting.text = "Paint mode: OFF"
	painting.toggle_mode = true
	painting.toggled.connect(_set_paint)
	panel.add_child(painting)
	button("Apply to navigation mesh", _apply)
	button("Discard pending marks", _discard)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "Select a NavigationRegion3D, then choose it above."
	panel.add_child(info)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)

func _exit_tree() -> void:
	_remove_overlay()
	remove_control_from_docks(panel)
	panel.queue_free()

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

func _select_region() -> void:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.size() != 1 or not selection[0] is NavigationRegion3D:
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
	info.text = "Selected %s. Adjust floor height, then enable painting." % target.name

func _set_paint(on: bool) -> void:
	if on and (not is_instance_valid(target) or target.navigation_mesh == null or target.navigation_mesh.get_polygon_count() == 0):
		painting.set_pressed_no_signal(false)
		info.text = "Select a region with a baked navigation mesh first."
		return
	if not on:
		dragging = false
	painting.text = "Paint mode: ON" if on else "Paint mode: OFF"

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not painting.button_pressed or not is_instance_valid(target):
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not marks.is_empty() and (not is_equal_approx(grid.value, float(previous.size)) or not is_equal_approx(height.value, float(previous.height))):
				info.text = "Apply or discard marks before changing grid size or height."
				return AFTER_GUI_INPUT_STOP
			previous = {"size": grid.value, "height": height.value}
			dragging = true
			last = Vector3.INF
			_stamp_screen(camera, event.position)
		else:
			dragging = false
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and dragging:
		_stamp_screen(camera, event.position)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _stamp_screen(camera: Camera3D, mouse: Vector2) -> void:
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
		_stamp(point if last == Vector3.INF else last.lerp(point, float(i) / steps))
	last = point
	_rebuild_overlay()
	info.text = "%d pending cells. Apply changes or discard them." % marks.size()

func _stamp(point: Vector3) -> void:
	var size := float(grid.value)
	var radius := float(brush.value)
	for x in range(floori((point.x - radius) / size), floori((point.x + radius) / size) + 1):
		for z in range(floori((point.z - radius) / size), floori((point.z + radius) / size) + 1):
			var center := Vector2((x + 0.5) * size, (z + 0.5) * size)
			if center.distance_to(Vector2(point.x, point.z)) > radius:
				continue
			var key := Vector2i(x, z)
			if mode.selected == 2:
				marks.erase(key)
			else:
				marks[key] = mode.selected

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
	for i in range(original.get_polygon_count()):
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
		info.text = "No walkable geometry remains. The original mesh was kept."
		return
	var nav := original.duplicate(true) as NavigationMesh
	var radius := nav.agent_radius
	nav.agent_radius = 0.0
	var source := NavigationMeshSourceGeometryData3D.new()
	source.add_faces(faces, Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(nav, source)
	nav.agent_radius = radius
	if nav.get_polygon_count() == 0:
		info.text = "No polygons produced; original mesh was kept."
		return
	var undo := get_undo_redo()
	undo.create_action("Edit navigation mesh")
	undo.add_do_property(target, "navigation_mesh", nav)
	undo.add_undo_property(target, "navigation_mesh", original)
	undo.commit_action()
	_discard()
	info.text = "Applied %d polygons. Save the scene; undo restores the previous mesh." % nav.get_polygon_count()
