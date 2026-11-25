extends SceneTree
## Compare GDScript output to fixtures previously exported from the Studio C#
## reference. This runner does not instantiate or call C#.

const TEST_SCRIPT := preload("res://tests/terrain_generation_parity/parity.gd")
const OUTPUT_DIR := "res://tests/terrain_generation_parity/golden"


func _initialize() -> void:
	if not ResourceLoader.exists(TEST_SCRIPT.GENERATOR_PATH):
		_fail("GDScript generator is missing: " + TEST_SCRIPT.GENERATOR_PATH)
		return
	var generator_script: Script = load(TEST_SCRIPT.GENERATOR_PATH)
	if generator_script == null or not generator_script.can_instantiate():
		_fail("GDScript generator failed to load or cannot be instantiated")
		return
	var generator: Variant = generator_script.new()
	if not generator.has_method("generate"):
		_fail("GDScript generator must implement generate(options: Dictionary) -> Dictionary")
		return
	var failures := 0
	for options in TEST_SCRIPT.CASES:
		var path: String = OUTPUT_DIR.path_join(options["name"] + ".json")
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("FAIL %s: missing reference fixture %s" % [options["name"], path])
			failures += 1
			continue
		var expected: Variant = JSON.parse_string(file.get_as_text())
		if not expected is Dictionary or not expected.has_all(["options", "width", "height", "baseTiles", "elevation"]) or expected["options"] != options:
			printerr("FAIL %s: corrupt fixture or fixture options changed; regenerate from Studio" % options["name"])
			failures += 1
			continue
		if expected["baseTiles"].size() != int(expected["width"]) * int(expected["height"]) or expected["elevation"].size() != int(expected["width"]) * int(expected["height"]):
			printerr("FAIL %s: corrupt fixture layer length" % options["name"])
			failures += 1
			continue
		var actual: Variant = generator.generate(options.duplicate(true))
		var problem := ""
		if not actual is Dictionary:
			problem = "generate() did not return a Dictionary"
		elif actual.has("error"):
			problem = "generator reported: %s" % str(actual["error"])
		elif not actual.has_all(["width", "height", "baseTiles", "elevation"]):
			problem = "generated artifact is missing a required base-map field"
		else:
			problem = TEST_SCRIPT.compare_artifacts(actual, expected)
		if problem != "":
			printerr("FAIL %s: %s" % [options["name"], problem])
			failures += 1
		else:
			print("PASS %s" % options["name"])
	if failures > 0:
		_fail("%d of %d parity cases failed" % [failures, TEST_SCRIPT.CASES.size()])
		return
	print("TERRAIN_GOLDEN_PARITY_OK: %d cases" % TEST_SCRIPT.CASES.size())
	quit(0)


func _fail(message: String) -> void:
	printerr("TERRAIN_GOLDEN_PARITY_FAILED: " + message)
	quit(1)
