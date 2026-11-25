@tool
class_name StudioMapGenerationSettings
extends Resource
## The finite-map recipe exposed by Cartoon Terrain Studio's Generate panel.
## Values are converted to the composer's MapSimulationOptions by
## to_simulation_options(). An empty seed is a literal empty seed here: Studio's
## Generate button instead replaces an empty seed with a new random seed.

## GenerateController passes these keys, in this order, even for a random theme.
## The order matters because choosing a theme consumes a seeded random value.
const STUDIO_THEME_KEYS: PackedStringArray = [
	"mountain", "highland_pass", "noir_sprawl", "olympian_sky_borough",
	"sakura_temple_dream", "abyssal_deepsea", "rainbowland",
	"clockwork_moon_bazaar", "sugarstorm_carnival", "prismglass_archive",
	"starforged_cathedral_endrun", "raid_holdthefort", "viking_ship_village",
	"alien_ranch",
]

@export_group("Map")
@export var seed: String = ""
@export_range(24, 384, 1) var width: int = 96
@export_range(24, 256, 1) var height: int = 72

## "random" chooses from the Studio theme pool; "*blend" requests regions.
@export_enum("random", "*blend", "mountain", "highland_pass", "noir_sprawl", "olympian_sky_borough", "sakura_temple_dream", "abyssal_deepsea", "rainbowland", "clockwork_moon_bazaar", "sugarstorm_carnival", "prismglass_archive", "starforged_cathedral_endrun", "raid_holdthefort", "viking_ship_village", "alien_ranch") var theme: String = "random"
@export_enum("random", "highland_basin", "river_delta", "rift_plateau", "island_chain", "terraced_valley", "canyon_fork", "lake_district", "crown_massif", "ruined_metropolis", "shattered_atoll", "ashen_steppe", "sky_terraces") var archetype: String = "random"
@export_enum("random", "island", "valley", "plateau", "basin", "shelf", "open") var frame: String = "random"
## "random" rolls a motif; "*none" forces a pure-landform world.
@export_enum("random", "*none", "sunken_caldera", "ringwall_citadel", "spiral_ascent", "cut_grid", "mesa_stand", "broken_plates", "canyon_lattice", "crater_field", "giant_stair", "warren_quarter") var motif: String = "random"

@export_group("Composition Dials")
## How much the world may stray from the selected landscape's authored centre.
@export_range(0.0, 1.0, 0.01) var chaos: float = 0.4
## Biases are multipliers: 1 is the archetype default, 0 removes the feature.
@export_range(0.0, 2.0, 0.01) var relief_bias: float = 1.0
@export_range(0.0, 2.0, 0.01) var water_bias: float = 1.0
@export_range(0.0, 2.0, 0.01) var rift_bias: float = 1.0
@export_range(0.0, 2.0, 0.01) var wonder_bias: float = 1.0
@export_range(0.0, 2.0, 0.01) var road_bias: float = 1.0
@export_range(0.0, 2.0, 0.01) var flora_bias: float = 1.0
@export_range(0.0, 2.0, 0.01) var landmark_bias: float = 1.0

@export_group("Advanced")
## Optional scripted-run exclusions; the Studio UI normally leaves this empty.
@export var excluded_wonders: PackedStringArray = []


## Preserve null versus empty string: the former rolls a motif, the latter
## explicitly disables motifs. These keys match Studio's MapSimulationOptions.
func to_simulation_options() -> Dictionary:
	return {
		"seed": seed,
		"width": clampi(width, 24, 384),
		"height": clampi(height, 24, 256),
		"themeKeys": Array(STUDIO_THEME_KEYS),
		"themeKey": null if theme == "random" or theme == "*blend" else theme,
		"blendThemes": true if theme == "*blend" else null,
		"archetypeKey": null if archetype == "random" else archetype,
		"frameKind": null if frame == "random" else frame,
		"motifKey": null if motif == "random" else ("" if motif == "*none" else motif),
		"chaos": clampf(chaos, 0.0, 1.0),
		"reliefBias": clampf(relief_bias, 0.0, 2.0),
		"waterBias": clampf(water_bias, 0.0, 2.0),
		"riftBias": clampf(rift_bias, 0.0, 2.0),
		"wonderBias": clampf(wonder_bias, 0.0, 2.0),
		"roadBias": clampf(road_bias, 0.0, 2.0),
		"floraBias": clampf(flora_bias, 0.0, 2.0),
		"landmarkBias": clampf(landmark_bias, 0.0, 2.0),
		"excludedWonders": Array(excluded_wonders),
	}


## Size presets used by Studio's Generate panel. This intentionally does not
## alter any other option or the seed.
func apply_size_preset(preset: String) -> void:
	match preset.to_lower():
		"s": width = 64; height = 48
		"m": width = 96; height = 72
		"l": width = 160; height = 120
		"xl": width = 256; height = 192
		_: push_warning("Unknown Studio map size preset: %s" % preset)
	emit_changed()
