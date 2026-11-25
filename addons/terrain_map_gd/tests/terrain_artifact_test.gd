extends SceneTree

const Artifact := preload("res://addons/terrain_map_gd/terrain_artifact.gd")


func _initialize() -> void:
	var reference_script := load("res://terrain/core/CartoonTerrainData.cs")
	if reference_script == null or not reference_script.can_instantiate():
		push_error("Build the C# project first to compare with the Studio blank artifact reference")
		quit(1)
		return
	for size in [Vector2i(64, 48), Vector2i(3, 3), Vector2i(11, 7), Vector2i(24, 36)]:
		var reference = reference_script.new()
		reference.CreateBlank(size.x, size.y)
		var actual: Dictionary = Artifact.document(Artifact.create({"width": size.x, "height": size.y}))
		var expected: Dictionary = JSON.parse_string(reference.ArtifactJson)
		if not _same(actual, expected):
			for key in expected.get("artifact", {}):
				if not actual["artifact"].has(key) or not _same(actual["artifact"][key], expected["artifact"][key]):
					print("Differing artifact key: ", key)
			for key in actual["artifact"]:
				if not expected["artifact"].has(key):
					print("Extra artifact key: ", key)
			push_error("Blank artifact mismatch for %s" % size)
			quit(1)
			return
	var options := {"width": 5, "height": 4, "tileSize": 20.0, "originX": 13.0,
		"originY": -3.0, "seed": 456.0, "style": 2, "biomeKey": "test", "tier": 3,
		"fillTile": 2, "borderTile": 4, "elevationLevel": 40, "withDefaultMarkers": false}
	var custom: Dictionary = Artifact.create(options)
	assert(custom.width == 5 and custom.height == 4)
	assert(custom.tileSize == 20.0 and custom.originX == 13.0 and custom.originY == -3.0)
	assert(custom.seed == 456.0 and custom.style == 2 and custom.biomeKey == "test" and custom.tier == 3)
	assert(custom.baseTiles == [4, 4, 4, 4, 4, 4, 2, 2, 2, 4, 4, 2, 2, 2, 4, 4, 4, 4, 4, 4])
	assert(custom.elevation == [25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25])
	assert(custom.markers.is_empty())
	var minimum: Dictionary = Artifact.create({"width": 1, "height": 2, "elevationLevel": -100})
	assert(minimum.width == 3 and minimum.height == 3 and minimum.elevation[0] == -30)
	assert(minimum.markers.size() == 2 and minimum.markers[0].tx == 1)
	print("Terrain artifact building block tests passed (four compared to C#)")
	quit()


func _same(a: Variant, b: Variant) -> bool:
	# JSON.parse_string reads all numbers as float; compare values recursively.
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]):
				return false
		return true
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for index in a.size():
			if not _same(a[index], b[index]):
				return false
		return true
	return a == b
