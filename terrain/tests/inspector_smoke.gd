extends SceneTree

## Verifies that Godot recognizes the typed resource and editor inspector classes.
func _initialize() -> void:
	var data_script := load("res://terrain/core/CartoonTerrainData.cs")
	var terrain_script := load("res://terrain/cartoon_terrain.gd")
	if data_script == null or not data_script.can_instantiate() or terrain_script == null:
		_fail("The Godot .NET assembly or terrain script is unavailable")
		return
	var data: Resource = data_script.new()
	var terrain: Node = terrain_script.new()
	var property_found := false
	for property in terrain.get_property_list():
		if property.name == "data":
			property_found = property.hint_string == "CartoonTerrainData"
	terrain.set("data", data)
	if not property_found or terrain.get("data") != data:
		_fail("Data is not a typed CartoonTerrainData property")
		return
	var demo: PackedScene = load("res://terrain/demo/terrain_demo.tscn")
	var level := demo.instantiate()
	if level.get_node("Terrain").get("data") == null:
		_fail("Existing demo terrain data did not load")
		return
	level.free()
	terrain.free()
	print("CARTOON_TERRAIN_INSPECTOR_SMOKE_OK")
	quit()


func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
