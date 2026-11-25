extends SceneTree
## Export reference fixtures with Godot .NET. This never runs the candidate.

const TEST_SCRIPT := preload("res://tests/terrain_generation_parity/parity.gd")
const REFERENCE_PATH := "res://terrain/core/CartoonTerrainData.cs"
const OUTPUT_DIR := "res://tests/terrain_generation_parity/golden"


func _initialize() -> void:
	var reference_script: Script = load(REFERENCE_PATH)
	if reference_script == null or not reference_script.can_instantiate():
		printerr("Cannot load C# Studio reference. Build with Godot .NET first.")
		quit(1)
		return
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if error != OK:
		printerr("Cannot create golden fixture directory: ", error)
		quit(1)
		return
	for options in TEST_SCRIPT.CASES:
		var reference: Variant = reference_script.new()
		reference.GenerateWithOptions(options["width"], options["height"], options["seed"], options)
		var width: int = reference.GetWidth()
		var height: int = reference.GetHeight()
		var tiles: Array[int] = []
		var elevation: Array[int] = []
		for z in range(height):
			for x in range(width):
				tiles.append(reference.GetTile(x, z))
				elevation.append(reference.GetElevation(x, z))
		var path: String = OUTPUT_DIR.path_join(options["name"] + ".json")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write ", path, ": ", FileAccess.get_open_error())
			quit(1)
			return
		file.store_string(JSON.stringify({"options": options, "width": width, "height": height, "baseTiles": tiles, "elevation": elevation}, "\t"))
		print("Wrote ", path)
	print("REFERENCE_EXPORT_OK")
	quit(0)
