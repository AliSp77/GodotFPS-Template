extends SceneTree
## Compare the addon to Studio GenerateController.Options, cell by cell.
## Run in Godot .NET after building GodotFPS.csproj.

const ORACLE_PATH := "res://terrain/tests/StudioGenerationOracle.cs"
const CANDIDATE_PATH := "res://terrain/core/CartoonTerrainData.cs"
const COMPARE := preload("res://tests/terrain_generation_parity/parity.gd")

const CASES := [
	{"name": "studio-defaults", "width": 96, "height": 72, "seed": "studio-defaults"},
	{"name": "explicit-theme", "width": 32, "height": 24, "seed": "explicit-1", "theme": "mountain", "archetype": "terraced_valley"},
	{"name": "random-theme", "width": 32, "height": 24, "seed": "random-42", "theme": "", "archetype": "lake_district"},
	{"name": "random-theme-2", "width": 32, "height": 24, "seed": "random-7", "theme": "", "archetype": "rift_plateau"},
	{"name": "blend", "width": 32, "height": 32, "seed": "blend-8", "theme": "*blend", "archetype": "highland_basin"},
	{"name": "all-zero", "width": 24, "height": 24, "seed": "dry", "chaos": 0.0, "reliefBias": 0.0, "waterBias": 0.0, "riftBias": 0.0, "wonderBias": 0.0, "roadBias": 0.0, "floraBias": 0.0, "landmarkBias": 0.0},
	{"name": "all-max", "width": 24, "height": 32, "seed": "max", "theme": "mountain", "chaos": 1.0, "reliefBias": 2.0, "waterBias": 2.0, "riftBias": 2.0, "wonderBias": 2.0, "roadBias": 2.0, "floraBias": 2.0, "landmarkBias": 2.0},
	{"name": "frame-motif", "width": 32, "height": 32, "seed": "pinned", "theme": "mountain", "archetype": "highland_basin", "frame": "basin", "motif": "sunken_caldera"},
	{"name": "no-motif", "width": 24, "height": 24, "seed": "no-motif", "theme": "mountain", "archetype": "island_chain", "frame": "island", "motif": "*none"},
	{"name": "excluded-wonders", "width": 32, "height": 32, "seed": "wonders", "wonderBias": 2.0, "excludedWonders": ["sunken_arena", "sacred_grove", "lonely_spire"]},
	{"name": "unicode", "width": 32, "height": 24, "seed": "نقشه 🌿", "theme": "*blend", "archetype": "river_delta", "waterBias": 1.5, "floraBias": 0.5},
]

func _initialize() -> void:
	var oracle_script: Script = load(ORACLE_PATH)
	var candidate_script: Script = load(CANDIDATE_PATH)
	if oracle_script == null or not oracle_script.can_instantiate() or candidate_script == null or not candidate_script.can_instantiate():
		_fail("C# test scripts unavailable: use Godot .NET and build GodotFPS.csproj first")
		return
	var oracle: Variant = oracle_script.new()
	var failures := 0
	for options in CASES:
		var width: int = options["width"]
		var height: int = options["height"]
		var seed: String = options["seed"]
		var expected: Dictionary = oracle.Generate(width, height, seed, options.duplicate(true))
		var candidate: Variant = candidate_script.new()
		candidate.GenerateWithOptions(width, height, seed, options.duplicate(true))
		var actual := _snapshot(candidate)
		var problem: String = COMPARE.compare_artifacts(actual, expected)
		if problem == "":
			problem = _check_export(candidate_script, candidate, expected)
		if problem != "":
			failures += 1
			printerr("FAIL %s: %s" % [options["name"], problem])
		else:
			print("PASS %s" % options["name"])
	if failures:
		_fail("%d of %d cases differ" % [failures, CASES.size()])
		return
	print("STUDIO_GENERATOR_PARITY_OK: %d cases" % CASES.size())
	quit(0)

func _snapshot(resource: Variant) -> Dictionary:
	var result := {"width": resource.GetWidth(), "height": resource.GetHeight(), "baseTiles": [], "elevation": []}
	for z in range(result["height"]):
		for x in range(result["width"]):
			result["baseTiles"].append(resource.GetTile(x, z))
			result["elevation"].append(resource.GetElevation(x, z))
	return result

func _check_export(candidate_script: Script, candidate: Variant, expected: Dictionary) -> String:
	var path := "res://.godot/studio_addon_parity_test.json"
	if not candidate.ExportJson(path):
		return "JSON export failed"
	var text := FileAccess.get_file_as_string(path)
	var document: Variant = JSON.parse_string(text)
	if not document is Dictionary or not document.has("artifact"):
		return "export did not contain an artifact"
	var artifact: Variant = document["artifact"]
	if not artifact is Dictionary or not artifact.has_all(["width", "height", "baseTiles", "elevation"]):
		return "export omitted a base-map field"
	var problem: String = COMPARE.compare_artifacts(artifact, expected)
	if problem != "":
		return "exported JSON: " + problem
	var reloaded: Variant = candidate_script.new()
	if not reloaded.ImportJson(path):
		return "JSON import failed"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	problem = COMPARE.compare_artifacts(_snapshot(reloaded), expected)
	return "reloaded JSON: " + problem if problem != "" else ""

func _fail(message: String) -> void:
	printerr("STUDIO_GENERATOR_PARITY_FAILED: " + message)
	quit(1)
