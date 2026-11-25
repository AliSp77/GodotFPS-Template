extends SceneTree
## Run with a Godot .NET editor after building GodotFPS.csproj:
## --headless --path . --script res://tests/terrain_generation_parity/parity.gd
## This is a test-only dependency on the existing Studio C# port. The generator
## being tested must itself be GDScript and must not invoke the reference.

const GENERATOR_PATH := "res://addons/terrain_map_gd/map_generator.gd"
const REFERENCE_PATH := "res://terrain/core/CartoonTerrainData.cs"

const CASES := [
	{"name": "baseline", "width": 24, "height": 24, "seed": "parity-baseline", "archetype": "terraced_valley", "theme": "mountain", "chaos": 0.3},
	{"name": "flat-dry", "width": 32, "height": 24, "seed": "dry 42", "archetype": "lake_district", "theme": "mountain", "chaos": 0.3, "reliefBias": 0.0, "waterBias": 0.0, "riftBias": 0.0, "wonderBias": 0.0, "roadBias": 0.0, "floraBias": 0.0, "landmarkBias": 0.0},
	{"name": "max-dials", "width": 24, "height": 32, "seed": "parity-max", "archetype": "rift_plateau", "theme": "mountain", "chaos": 1.0, "reliefBias": 2.0, "waterBias": 2.0, "riftBias": 2.0, "wonderBias": 2.0, "roadBias": 2.0, "floraBias": 2.0, "landmarkBias": 2.0},
	{"name": "pinned-frame-and-motif", "width": 32, "height": 32, "seed": "pinned", "archetype": "highland_basin", "theme": "mountain", "frame": "basin", "motif": "sunken_caldera", "chaos": 0.0},
	{"name": "no-motif", "width": 24, "height": 24, "seed": "no-motif", "archetype": "island_chain", "theme": "mountain", "frame": "island", "motif": "*none", "chaos": 0.3},
	{"name": "unicode", "width": 24, "height": 24, "seed": "نقشه 🌿", "archetype": "river_delta", "theme": "mountain", "chaos": 0.3, "waterBias": 1.5, "floraBias": 0.5},
]


func _initialize() -> void:
	if not ResourceLoader.exists(GENERATOR_PATH):
		_fail("GDScript generator is missing: " + GENERATOR_PATH)
		return
	var generator_script: Script = load(GENERATOR_PATH)
	if generator_script == null or not generator_script.can_instantiate():
		_fail("GDScript generator failed to load or cannot be instantiated")
		return
	var generator: Variant = generator_script.new()
	if not generator.has_method("generate"):
		_fail("GDScript generator must implement generate(options: Dictionary) -> Dictionary")
		return
	if not ResourceLoader.exists(REFERENCE_PATH):
		_fail("Studio C# reference is missing: " + REFERENCE_PATH)
		return
	var reference_script: Script = load(REFERENCE_PATH)
	if reference_script == null or not reference_script.can_instantiate():
		_fail("Studio C# reference is unavailable; use Godot .NET and build GodotFPS.csproj first")
		return

	var failures := 0
	for fixture in CASES:
		var problem := _run_case(generator, reference_script, fixture)
		if problem != "":
			failures += 1
			printerr("FAIL %s: %s" % [fixture["name"], problem])
		else:
			print("PASS %s" % fixture["name"])
	if failures > 0:
		_fail("%d of %d parity cases failed" % [failures, CASES.size()])
		return
	print("TERRAIN_BASE_PARITY_OK: %d cases" % CASES.size())
	quit(0)


func _run_case(generator: Variant, reference_script: Script, options: Dictionary) -> String:
	# A defensive copy ensures an implementation cannot mutate the fixture used
	# to construct the independent reference.
	var actual: Variant = generator.generate(options.duplicate(true))
	if not actual is Dictionary:
		return "generate() did not return a Dictionary"
	if actual.has("error"):
		return "generator reported: %s" % str(actual["error"])
	for key in ["width", "height", "baseTiles", "elevation"]:
		if not actual.has(key):
			return "generated artifact is missing '%s'" % key

	var reference: Variant = reference_script.new()
	reference.GenerateWithOptions(options["width"], options["height"], options["seed"], options)
	var width: int = reference.GetWidth()
	var height: int = reference.GetHeight()
	var expected := {"width": width, "height": height, "baseTiles": [], "elevation": []}
	for z in range(height):
		for x in range(width):
			expected["baseTiles"].append(reference.GetTile(x, z))
			expected["elevation"].append(reference.GetElevation(x, z))
	return compare_artifacts(actual, expected)


static func compare_artifacts(actual: Dictionary, expected: Dictionary) -> String:
	var width: int = int(expected["width"])
	var height: int = int(expected["height"])
	if actual["width"] != width or actual["height"] != height:
		return "dimensions differ: expected %dx%d, got %sx%s" % [width, height, actual["width"], actual["height"]]
	for layer in ["baseTiles", "elevation"]:
		var values: Variant = actual[layer]
		if not (values is Array or values is PackedByteArray or values is PackedInt32Array or values is PackedInt64Array):
			return "%s must be an integer array" % layer
		if values.size() != width * height:
			return "%s length differs: expected %d, got %d" % [layer, width * height, values.size()]
		for i in range(values.size()):
			var value: Variant = values[i]
			if not (value is int or value is float) or float(value) != floor(float(value)):
				return "%s[%d] is not an integer: %s" % [layer, i, str(value)]
			var expected_value: int = int(expected[layer][i])
			if value != expected_value:
				return "%s differs at (%d,%d), index %d: expected %d, got %s" % [layer, i % width, i / width, i, expected_value, str(value)]
	return ""


func _fail(message: String) -> void:
	printerr("TERRAIN_BASE_PARITY_FAILED: " + message)
	quit(1)
