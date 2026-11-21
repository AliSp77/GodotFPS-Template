extends Node3D


func _ready() -> void:
	call_deferred("_rebuild")


func _rebuild() -> void:
	var level := preload("res://FractalVaultDemo/game_scene.tscn").instantiate()
	for child in level.get_children():
		if child is CharacterBody3D:
			child.free()
	for path in ["StartingPoint/SwarmSpawner", "StartingPoint/InputManager"]:
		var node := level.get_node_or_null(path)
		if node != null:
			node.free()
	add_child(level)
	# Wait for the CSG boolean geometry and collision meshes to finish updating.
	for frame in range(12):
		await get_tree().physics_frame
	var mesh := FractalLevelNavigationBaker.bake(level)
	if mesh.get_polygon_count() == 0:
		push_error("Full-level navigation bake produced no walkable polygons")
		get_tree().quit(1)
		return
	var result := ResourceSaver.save(mesh, "res://FractalVaultDemo/navigation/game_navigation.tres")
	if result != OK:
		push_error("Could not save full-level navigation: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("LEVEL_NAVIGATION_REBUILT polygons=", mesh.get_polygon_count())
	get_tree().quit(0)
