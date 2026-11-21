class_name FractalLevelNavigationBaker
extends RefCounted


static func bake(level: Node3D) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.cell_size = 0.1
	mesh.cell_height = 0.05
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.9
	mesh.agent_max_climb = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 5
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	var source_group := StringName("_fractal_navigation_%d" % level.get_instance_id())
	mesh.geometry_source_group_name = source_group
	var sources: Array[Node] = []
	for node in level.find_children("*", "", true, false):
		if node.is_in_group(&"navigation_dynamic"):
			continue
		if node is CSGShape3D:
			if not node.is_root_shape() or not node.use_collision:
				continue
		elif not node is StaticBody3D:
			continue
		node.add_to_group(source_group)
		sources.append(node)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, geometry, level)
	for node in sources:
		node.remove_from_group(source_group)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	return mesh
