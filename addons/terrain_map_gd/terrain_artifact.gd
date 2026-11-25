extends RefCounted
## Port of TerrainEditor.createTerrainArtifact: creates an empty editable canvas.
## This is a generator building block; it does not simulate a Studio map.

const Js := preload("res://addons/terrain_map_gd/js_compat.gd")
const DOCUMENT_KIND := "fluitown.terrain-artifact"
const DOCUMENT_VERSION := 1


static func create(options: Dictionary = {}) -> Dictionary:
	var width: int = maxi(3, int(_option(options, "width", 64)))
	var height: int = maxi(3, int(_option(options, "height", 48)))
	var tile_size: float = float(_option(options, "tileSize", 62.5))
	var fill_tile: int = Js.uint8(_option(options, "fillTile", 1))
	var border_tile: int = Js.uint8(_option(options, "borderTile", 0))
	var level: int = clampi(int(_option(options, "elevationLevel", 0)), -30, 25)
	var count := width * height
	var tiles: Array = []
	var elevations: Array = []
	var surfaces: Array = []
	var variants: Array = []
	tiles.resize(count)
	elevations.resize(count)
	surfaces.resize(count)
	variants.resize(count)
	tiles.fill(fill_tile)
	elevations.fill(level)
	surfaces.fill(0)
	variants.fill(0)
	for x in width:
		tiles[x] = border_tile
		tiles[(height - 1) * width + x] = border_tile
	for y in height:
		tiles[y * width] = border_tile
		tiles[y * width + width - 1] = border_tile
	var markers: Array = []
	if bool(_option(options, "withDefaultMarkers", true)):
		var start_x := maxi(1, floori(width * 0.25))
		var start_y := maxi(1, floori(height * 0.5))
		var boss_x := mini(width - 2, maxi(1, floori(width * 0.75)))
		var boss_y := mini(height - 2, maxi(1, floori(height * 0.5)))
		tiles[start_y * width + start_x] = 1
		tiles[boss_y * width + boss_x] = 1
		markers = [
			{"type": 0, "tx": start_x, "ty": start_y, "id": "start"},
			{"type": 1, "tx": boss_x, "ty": boss_y, "id": "boss"},
		]
	return {
		"schemaVersion": 1,
		"width": width,
		"height": height,
		"tileSize": tile_size,
		"originX": _option(options, "originX", -(width * tile_size) / 2.0),
		"originY": _option(options, "originY", -(height * tile_size) / 2.0),
		"index": 0,
		"seed": _option(options, "seed", 0),
		"style": _option(options, "style", 0),
		"biomeKey": _option(options, "biomeKey", "mountain"),
		"tier": _option(options, "tier", 1),
		"baseTiles": tiles,
		"elevation": elevations,
		"surface": surfaces,
		"variant": variants,
		"markers": markers,
		"decorations": [],
	}


static func document(artifact: Dictionary) -> Dictionary:
	return {"kind": DOCUMENT_KIND, "version": DOCUMENT_VERSION, "artifact": artifact.duplicate(true)}


static func _option(options: Dictionary, key: String, fallback: Variant) -> Variant:
	var value: Variant = options.get(key)
	return fallback if value == null else value
