@tool
extends RefCounted
## Derived gameplay geometry for a CartoonTerrain. Coordinates are local to the
## terrain node. The caller owns/replaces the returned nodes and baked resource.

const TILE_FLOOR := 1
const TILE_WATER := 2
const TILE_BRIDGE := 3
const TILE_CHASM := 4
const TILE_UNDERPASS := 6
const TERRAIN_LAYERS := 1 | 4 | 16
const TREE_LAYERS := 1 | 4 | 32
const HAZARD_LAYERS := 1
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func build_collision(data: Resource, visual_root: Node3D) -> Node3D:
	var result := Node3D.new()
	result.name = "TerrainCollision"
	var surface := StaticBody3D.new()
	surface.name = "Surface"
	surface.collision_layer = TERRAIN_LAYERS
	surface.collision_mask = 0
	result.add_child(surface)
	if visual_root:
		_add_marked_meshes(visual_root, surface, Transform3D.IDENTITY, true)
		if surface.get_child_count() == 0:
			result.free()
			return null
	var barriers := StaticBody3D.new()
	barriers.name = "HazardBarriers"
	barriers.collision_layer = HAZARD_LAYERS
	barriers.collision_mask = 0
	result.add_child(barriers)
	_add_hazard_barriers(data, barriers)
	var approaches := StaticBody3D.new()
	approaches.name = "BridgeApproaches"
	approaches.collision_layer = TERRAIN_LAYERS
	approaches.collision_mask = 0
	result.add_child(approaches)
	_add_bridge_approaches(data, approaches)
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	trees.collision_layer = TREE_LAYERS
	trees.collision_mask = 0
	result.add_child(trees)
	if visual_root:
		_add_tree_instances(visual_root, trees, Transform3D.IDENTITY, true)
	else:
		# Useful for offline baking when no visual renderer is available.
		for cell in _tree_cells(data):
			_add_tree_collider(trees, _cell_center(data, cell.x, cell.y) + Vector3.UP * 1.25, 0.28, 2.5)
	return result


## Meshes marked cartoon_collision=true provide the exact terrain/structure
## geometry. Water and decoration meshes must not carry this metadata.
static func _add_marked_meshes(node: Node, body: StaticBody3D, parent_transform: Transform3D, is_root: bool = false) -> void:
	var local_transform := parent_transform
	if node is Node3D and not is_root:
		local_transform = parent_transform * node.transform
	if node is MeshInstance3D and node.get_meta("cartoon_collision", false) and node.mesh:
		var shape: Shape3D = node.mesh.create_trimesh_shape()
		if shape:
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.transform = local_transform
			body.add_child(collider)
	for child in node.get_children():
		_add_marked_meshes(child, body, local_transform)


## Trunk MultiMesh transforms carry the visible trunk dimensions. The caller's
## terrain transform is outside this local coordinate system and is applied once.
static func _add_tree_instances(node: Node, body: StaticBody3D, parent_transform: Transform3D, is_root: bool = false) -> void:
	var local_transform := parent_transform
	if node is Node3D and not is_root:
		local_transform = parent_transform * node.transform
	if node is MultiMeshInstance3D and node.get_meta("cartoon_tree_collision", false) and node.multimesh:
		var multimesh: MultiMesh = node.multimesh
		# Kept on the CPU by the renderer: GPU MultiMesh reads can fail in headless builds.
		var transforms: Array = node.get_meta("cartoon_tree_transforms", [])
		var count := transforms.size()
		if multimesh.visible_instance_count >= 0:
			count = mini(count, multimesh.visible_instance_count)
		for index in count:
			var instance: Transform3D = local_transform * transforms[index]
			var radius := maxf(instance.basis.x.length(), instance.basis.z.length())
			var height := instance.basis.y.length()
			if radius > 0.001 and height > 0.001:
				_add_tree_collider(body, instance.origin, radius, height)
	for child in node.get_children():
		_add_tree_instances(child, body, local_transform)


static func _add_tree_collider(body: StaticBody3D, center: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = center
	body.add_child(collider)


static func _add_hazard_barriers(data: Resource, body: StaticBody3D) -> void:
	var size: float = data.GetCellSize()
	for z in range(data.GetHeight()):
		for x in range(data.GetWidth()):
			if not _walkable(data.GetTile(x, z)):
				continue
			for direction: Vector2i in DIRECTIONS:
				var nx: int = x + direction.x
				var nz: int = z + direction.y
				if nx < 0 or nz < 0 or nx >= data.GetWidth() or nz >= data.GetHeight():
					continue
				var neighbor: int = data.GetTile(nx, nz)
				if neighbor != TILE_WATER and neighbor != TILE_CHASM:
					continue
				# Generate only the shared boundary: bridge-to-floor approaches stay open.
				var collider := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.12, 3.0, size) if direction.x != 0 else Vector3(size, 3.0, 0.12)
				collider.shape = box
				collider.position = _cell_center(data, x, z) + Vector3(direction.x * size * 0.5, 1.5, direction.y * size * 0.5)
				body.add_child(collider)


## Bridge planks sit slightly above neighbouring ground. A shallow wedge on
## each landward edge prevents character capsules snagging on the plank lip.
## The far edge is buried under the terrain to avoid introducing a new step.
static func _add_bridge_approaches(data: Resource, body: StaticBody3D) -> void:
	var size: float = data.GetCellSize()
	for z in range(data.GetHeight()):
		for x in range(data.GetWidth()):
			if data.GetTile(x, z) != TILE_BRIDGE:
				continue
			var bridge := _cell_center(data, x, z)
			for direction: Vector2i in DIRECTIONS:
				var nx: int = x + direction.x
				var nz: int = z + direction.y
				if nx < 0 or nz < 0 or nx >= data.GetWidth() or nz >= data.GetHeight():
					continue
				var tile: int = data.GetTile(nx, nz)
				if tile != TILE_FLOOR and tile != TILE_UNDERPASS:
					continue
				var land := _cell_center(data, nx, nz)
				# A neighbouring elevation change too steep for this short ramp
				# should stay blocked instead of creating an unsafe traversal.
				if absf(land.y - bridge.y) > 0.3:
					continue
				var dir := Vector3(direction.x, 0, direction.y)
				var tangent := Vector3(-direction.y, 0, direction.x) * (size * 0.5 - 0.03)
				var edge := bridge + dir * (size * 0.5 - 0.05)
				var far := edge + dir * minf(size * 0.5, 1.25)
				edge.y = bridge.y + 0.13
				far.y = land.y - 0.3
				var bottom := minf(edge.y, far.y) - 0.5
				var points := PackedVector3Array([edge + tangent, edge - tangent, far + tangent, far - tangent])
				for top in [edge + tangent, edge - tangent, far + tangent, far - tangent]:
					points.append(Vector3(top.x, bottom, top.z))
				var shape := ConvexPolygonShape3D.new()
				shape.points = points
				var collider := CollisionShape3D.new()
				collider.shape = shape
				body.add_child(collider)


## Bake into a fresh resource so a failed/empty bake never replaces the last
## good NavigationRegion3D mesh. Returns null if there is no traversable area.
static func bake_navigation(data: Resource, collision_root: Node3D = null) -> NavigationMesh:
	var geometry := NavigationMeshSourceGeometryData3D.new()
	var faces := PackedVector3Array()
	var size: float = data.GetCellSize()
	if collision_root:
		faces = _collision_walkable_faces(data, collision_root)
		_append_approach_faces(faces, collision_root)
	else:
		# Offline callers have no visual collision geometry to sample.
		for z in range(data.GetHeight()):
			for x in range(data.GetWidth()):
				if not _walkable(data.GetTile(x, z)):
					continue
				var center := _cell_center(data, x, z)
				var half := size * 0.5
				var a := center + Vector3(-half, 0, -half)
				var b := center + Vector3(-half, 0, half)
				var c := center + Vector3(half, 0, half)
				var d := center + Vector3(half, 0, -half)
				faces.append_array(PackedVector3Array([a, c, b, a, d, c]))
	if faces.is_empty():
		return null
	geometry.add_faces(faces, Transform3D.IDENTITY)
	# Projected obstructions are CPU-side, including in headless editor builds.
	if collision_root:
		var trees := collision_root.get_node_or_null("Trees")
		if trees:
			for collider in trees.get_children():
				if collider is CollisionShape3D and collider.shape is CylinderShape3D:
					_add_tree_obstruction(geometry, collider.position, collider.shape.radius, collider.shape.height)
	else:
		for cell in _tree_cells(data):
			_add_tree_obstruction(geometry, _cell_center(data, cell.x, cell.y) + Vector3.UP * 1.25, 0.28, 2.5)
	var mesh := NavigationMesh.new()
	# A region's voxel sizes must match its world's NavigationServer map.
	mesh.cell_size = float(ProjectSettings.get_setting("navigation/3d/default_cell_size", 0.25))
	mesh.cell_height = float(ProjectSettings.get_setting("navigation/3d/default_cell_height", 0.25))
	mesh.agent_height = ceilf(1.8 / mesh.cell_height) * mesh.cell_height
	mesh.agent_radius = ceilf(0.35 / mesh.cell_size) * mesh.cell_size
	mesh.agent_max_climb = floorf(0.3 / mesh.cell_height) * mesh.cell_height
	mesh.agent_max_slope = 45.0
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	return mesh if mesh.get_polygon_count() > 0 else null


static func _append_approach_faces(faces: PackedVector3Array, collision_root: Node3D) -> void:
	var approaches := collision_root.get_node_or_null("BridgeApproaches")
	if not approaches:
		return
	for collider in approaches.get_children():
		if not collider is CollisionShape3D or not collider.shape is ConvexPolygonShape3D:
			continue
		var points: PackedVector3Array = collider.shape.points
		if points.size() < 4:
			continue
		var a: Vector3 = collider.transform * points[0]
		var b: Vector3 = collider.transform * points[1]
		var c: Vector3 = collider.transform * points[3]
		var d: Vector3 = collider.transform * points[2]
		if (b - a).cross(c - a).y > 0:
			faces.append_array(PackedVector3Array([a, c, b, a, d, c]))
		else:
			faces.append_array(PackedVector3Array([a, b, c, a, c, d]))


## Clip collision triangles to walkable cells and a narrow band around their
## authored elevation. This excludes the large off-map apron, chasm bottoms,
## deep water beds and solid-cell tops while retaining actual slopes and decks.
static func _collision_walkable_faces(data: Resource, collision_root: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	var surface := collision_root.get_node_or_null("Surface")
	if not surface:
		return result
	var width: int = data.GetWidth()
	var height: int = data.GetHeight()
	var size: float = data.GetCellSize()
	var origin_x := -width * size * 0.5
	var origin_z := -height * size * 0.5
	for collider in surface.get_children():
		if not collider is CollisionShape3D or not collider.shape is ConcavePolygonShape3D:
			continue
		var triangles: PackedVector3Array = collider.shape.get_faces()
		for i in range(0, triangles.size(), 3):
			var a: Vector3 = collider.transform * triangles[i]
			var b: Vector3 = collider.transform * triangles[i + 1]
			var c: Vector3 = collider.transform * triangles[i + 2]
			# Ground-facing triangles are clockwise in the renderer. Ignore vertical
			# walls and downward faces so cliff or apron backs cannot become a floor.
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 0.0000001 or normal.normalized().y > -0.6:
				continue
			var min_x := maxi(0, floori((minf(a.x, minf(b.x, c.x)) - origin_x) / size))
			var max_x := mini(width - 1, floori((maxf(a.x, maxf(b.x, c.x)) - origin_x) / size))
			var min_z := maxi(0, floori((minf(a.z, minf(b.z, c.z)) - origin_z) / size))
			var max_z := mini(height - 1, floori((maxf(a.z, maxf(b.z, c.z)) - origin_z) / size))
			if min_x > max_x or min_z > max_z:
				continue
			for z in range(min_z, max_z + 1):
				for x in range(min_x, max_x + 1):
					if not _walkable(data.GetTile(x, z)):
						continue
					var ground: float = float(data.GetElevation(x, z)) * float(data.GetLevelHeight())
					var poly: Array[Vector3] = [a, b, c]
					poly = _clip_polygon(poly, 0, origin_x + x * size, true)
					poly = _clip_polygon(poly, 0, origin_x + (x + 1) * size, false)
					poly = _clip_polygon(poly, 2, origin_z + z * size, true)
					poly = _clip_polygon(poly, 2, origin_z + (z + 1) * size, false)
					poly = _clip_polygon(poly, 1, ground - 0.75, true)
					poly = _clip_polygon(poly, 1, ground + 0.75, false)
					for j in range(1, poly.size() - 1):
						if (poly[j] - poly[0]).cross(poly[j + 1] - poly[0]).length_squared() > 0.0000001:
							result.append_array(PackedVector3Array([poly[0], poly[j], poly[j + 1]]))
	return result


static func _clip_polygon(poly: Array[Vector3], axis: int, bound: float, keep_greater: bool) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if poly.is_empty():
		return result
	var previous: Vector3 = poly[poly.size() - 1]
	var previous_inside: bool = previous[axis] >= bound if keep_greater else previous[axis] <= bound
	for current in poly:
		var inside: bool = current[axis] >= bound if keep_greater else current[axis] <= bound
		if inside != previous_inside:
			var t := (bound - previous[axis]) / (current[axis] - previous[axis])
			result.append(previous.lerp(current, t))
		if inside:
			result.append(current)
		previous = current
		previous_inside = inside
	return result


static func _add_tree_obstruction(geometry: NavigationMeshSourceGeometryData3D, center: Vector3, radius: float, height: float) -> void:
	var footprint := PackedVector3Array([
		center + Vector3(-radius, 0, -radius), center + Vector3(radius, 0, -radius),
		center + Vector3(radius, 0, radius), center + Vector3(-radius, 0, radius)])
	geometry.add_projected_obstruction(footprint, center.y - height * 0.5, height, false)


## Pass the player marker first, followed by enemy markers. Call after the
## navigation map synchronizes (at least one physics frame after a rebake).
## Diagnostics are empty only when each marker is near navigation and reachable
## from the first valid marker. Positions are global, as required by the server.
static func validate_spawns(terrain: Node3D, markers: Array) -> PackedStringArray:
	var issues := PackedStringArray()
	if not terrain.is_inside_tree() or not terrain.get_world_3d():
		issues.append("Spawn validation requires terrain inside a 3D world.")
		return issues
	var map := terrain.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		issues.append("Navigation is not synchronized yet; validate again after the next physics frame.")
		return issues
	var anchor := Vector3.ZERO
	var has_anchor := false
	for marker in markers:
		if not is_instance_valid(marker) or not marker is Node3D or not marker.is_inside_tree():
			issues.append("A spawn marker is missing or outside the scene tree.")
			continue
		var point: Vector3 = marker.global_position
		var nearest := NavigationServer3D.map_get_closest_point(map, point)
		var horizontal := Vector2(point.x - nearest.x, point.z - nearest.z).length()
		if horizontal > 0.75 or absf(point.y - nearest.y) > 2.0:
			issues.append("%s is not on a walkable navigation surface." % marker.name)
			continue
		if not has_anchor:
			anchor = nearest
			has_anchor = true
			continue
		var path := NavigationServer3D.map_get_path(map, anchor, nearest, true)
		if path.is_empty() or path[path.size() - 1].distance_to(nearest) > 0.5:
			issues.append("%s cannot be reached from the first valid spawn." % marker.name)
	return issues


static func _walkable(tile: int) -> bool:
	return tile == TILE_FLOOR or tile == TILE_BRIDGE or tile == TILE_UNDERPASS


static func _cell_center(data: Resource, x: int, z: int) -> Vector3:
	return Vector3((x + 0.5 - data.GetWidth() * 0.5) * data.GetCellSize(),
		data.GetElevation(x, z) * data.GetLevelHeight(),
		(z + 0.5 - data.GetHeight() * 0.5) * data.GetCellSize())


static func _tree_cells(data: Resource) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var document: Variant = JSON.parse_string(data.ArtifactJson)
	if not document is Dictionary:
		return cells
	var artifact: Variant = document.get("artifact", document)
	if not artifact is Dictionary:
		return cells
	for item in artifact.get("decorations", []):
		if item is Dictionary and item.get("kind", "") == "tree":
			var x := int(item.get("tx", -1))
			var z := int(item.get("ty", -1))
			if x >= 0 and z >= 0 and x < data.GetWidth() and z < data.GetHeight():
				var cell := Vector2i(x, z)
				if not cells.has(cell):
					cells.append(cell)
	return cells
