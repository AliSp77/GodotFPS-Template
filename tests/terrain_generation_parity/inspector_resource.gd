extends SceneTree
## Verify inspector settings survive a resource round trip and reproduce Studio's base map.
## Run after building with Godot .NET: --headless --path . --script res://tests/terrain_generation_parity/inspector_resource.gd

const DATA_SCRIPT := "res://terrain/core/CartoonTerrainData.cs"
const ORACLE_SCRIPT := "res://terrain/tests/StudioGenerationOracle.cs"
const COMPARE := preload("res://tests/terrain_generation_parity/parity.gd")
const TEST_PATH := "res://.godot/cartoon_terrain_inspector_resource_test.tres"

const SETTINGS := {
	"GenerationWidth": 32, "GenerationHeight": 24, "GenerationSeed": "resource-parity-42",
	"GenerationTheme": "*blend", "GenerationArchetype": "lake_district",
	"GenerationFrame": "island", "GenerationMotif": "*none",
	"Chaos": 0.7, "ReliefBias": 1.5, "WaterBias": 0.25, "RiftBias": 0.8,
	"WonderBias": 1.2, "RoadBias": 0.4, "FloraBias": 1.3, "LandmarkBias": 0.6,
}

func _initialize() -> void:
	var data_script: Script = load(DATA_SCRIPT)
	var oracle_script: Script = load(ORACLE_SCRIPT)
	if data_script == null or not data_script.can_instantiate() or oracle_script == null or not oracle_script.can_instantiate():
		_fail("C# classes unavailable; build the project with Godot .NET")
		return
	var data: Variant = data_script.new()
	var old_demo: Variant = ResourceLoader.load("res://terrain/demo/demo_terrain.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if old_demo == null or old_demo.GetWidth() != 24 or old_demo.GetHeight() != 18 or str(old_demo.ArtifactJson).is_empty():
		_fail("the existing demo resource did not load its map")
		return
	var visible_properties: Dictionary = {}
	for entry in data.get_property_list():
		if entry.usage & PROPERTY_USAGE_EDITOR:
			visible_properties[entry.name] = true
	for key in SETTINGS:
		if not visible_properties.has(key):
			_fail("setting is missing from the inspector: " + key)
			return
		data.set(key, SETTINGS[key])
	if not visible_properties.has("ExcludedWonders"):
		_fail("excluded wonders is missing from the inspector")
		return
	var excluded: Array[String] = ["sunken_arena", "sacred_grove"]
	data.set("ExcludedWonders", excluded)
	data.GenerateFromSettings()
	var expected: Dictionary = oracle_script.new().Generate(32, 24, "resource-parity-42", {
		"theme": "*blend", "archetype": "lake_district", "frame": "island", "motif": "*none",
		"chaos": 0.7, "reliefBias": 1.5, "waterBias": 0.25, "riftBias": 0.8,
		"wonderBias": 1.2, "roadBias": 0.4, "floraBias": 1.3, "landmarkBias": 0.6,
		"excludedWonders": excluded,
	})
	var issue: String = COMPARE.compare_artifacts(_snapshot(data), expected)
	if issue != "":
		_fail("settings generation differs from Studio: " + issue)
		return
	var before_json: String = data.ArtifactJson
	if before_json.is_empty() or ResourceSaver.save(data, TEST_PATH) != OK:
		_fail("could not save generated terrain resource")
		return
	var restored: Variant = ResourceLoader.load(TEST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if restored == null:
		_fail("could not reload terrain resource")
		return
	for key in SETTINGS:
		var actual: Variant = restored.get(key)
		var original: Variant = SETTINGS[key]
		if (original is float and not is_equal_approx(actual, original)) or (not original is float and actual != original):
			_fail("setting did not survive save/load: %s (got %s, expected %s)" % [key, actual, original])
			return
	if restored.ArtifactJson != before_json:
		_fail("generated map did not survive save/load")
		return
	if restored.ExcludedWonders != excluded:
		_fail("excluded wonders did not survive save/load")
		return
	restored.GenerateFromSettings()
	issue = COMPARE.compare_artifacts(_snapshot(restored), expected)
	if issue != "":
		_fail("saved settings do not reproduce the map: " + issue)
		return
	restored.GenerationSeed = ""
	restored.GenerateFromSettings()
	if str(restored.GenerationSeed).is_empty():
		_fail("empty seed did not result in a visible reproducible seed")
		return
	var rolled := _snapshot(restored)
	restored.GenerateFromSettings()
	issue = COMPARE.compare_artifacts(_snapshot(restored), rolled)
	if issue != "":
		_fail("the generated seed does not reproduce the map: " + issue)
		return
	print("INSPECTOR_RESOURCE_OK: existing map, settings, Studio parity, save/reload, reproducibility")
	quit(0)

func _snapshot(resource: Variant) -> Dictionary:
	var result := {"width": resource.GetWidth(), "height": resource.GetHeight(), "baseTiles": [], "elevation": []}
	for z in range(result["height"]):
		for x in range(result["width"]):
			result["baseTiles"].append(resource.GetTile(x, z))
			result["elevation"].append(resource.GetElevation(x, z))
	return result

func _fail(message: String) -> void:
	printerr("INSPECTOR_RESOURCE_FAILED: " + message)
	quit(1)
