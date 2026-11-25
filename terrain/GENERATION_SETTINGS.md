# Cartoon Terrain generation settings

This guide explains the settings on the `CartoonTerrainData` resource in the Godot Inspector. They control the same finite-map generator used by this copy of Cartoon Terrain Studio.

## How to use the settings

1. Select your `CartoonTerrain` node and expand its **Data** resource in the Inspector. If it has no data, create a new `CartoonTerrainData` resource there.
2. Change the settings below. Click **Generate map from these settings** in the resource Inspector, or **Generate from data settings** in the Cartoon Terrain dock.
3. Save the data resource and the scene. The resource stores the generated map and its settings.
4. After generation or painting, rebuild collision and bake navigation using the dock controls when you need the map for gameplay.

Generating again replaces the map in the resource, including manual map edits. Generation can be undone. Changing a setting alone does not regenerate the map.

To reproduce a Studio map, use the same generator version and the same seed, dimensions, landscape, theme, outline, layout, and dial values. Choose the same random or mixed options too. The saved base tiles and elevations should match; the two applications can render them differently.

## Map generation

| Inspector setting | Studio name | Default | What it controls |
| --- | --- | --- | --- |
| Generation Width | Size, width | 96 | The number of cells across the map. |
| Generation Height | Size, height | 72 | The number of cells from top to bottom. |
| Generation Seed | Seed | Empty | The starting value for the generator's repeatable random choices. |
| Generation Theme | Theme | Any theme | The biome and theme choices used to compose and dress the map. |
| Generation Archetype | Landscape | Surprise me | The overall kind of landscape and its normal feature mix. |
| Generation Frame | Outline | Natural | The treatment of the map's outer edge. |
| Generation Motif | Layout | Let the map decide | An optional large-scale landform pattern. |

### Width and height

Each cell corresponds to approximately **2.5 × 2.5 metres** in this project. For example, a 96 × 72 map covers approximately 240 × 180 metres. More cells generally mean more work for generation, rendering, collision, and navigation.

The Inspector accepts values from 3 to 512, but the shared generator currently clamps the **result** to a width of **24–384** cells and a height of **24–256** cells. For example, entering a width of 10 produces a map 24 cells wide; entering a height of 300 produces one 256 cells high. Use values within the effective limits to make the requested and generated dimensions agree.

Studio's size presets are S = 64 × 48, M = 96 × 72, L = 160 × 120, and XL = 256 × 192.

### Seed

The seed can be a word, a number, or other text. With the same seed, settings, and generator version, generating again produces the same base map. Leading and trailing spaces are removed before generation.

If the field is empty, the generator creates a new seed and writes it back to the resource. Copy that displayed seed if you want to reproduce the result in Studio. A new seed generally gives a different map even if all other settings stay the same.

### Theme

The theme chooses the map's biome identity and influences its terrain and vegetation dressing. It is not just a final colour filter: theme choices are part of generation and should be kept the same when reproducing a map.

- **Any theme:** the generator selects a theme from Studio's ordered theme list using the seed.
- **Mixed regions:** the generator selects several themes and distributes them over the map. The landscape influences how many are used.
- **A named theme:** use that theme as the map's selected theme.

The custom Inspector shows Studio's friendly names while storing the generator keys. If the terrain editor plugin is disabled, the underlying keys may be shown instead; `*blend` means Mixed regions. Appearance in the FPS project is adapted and can differ from Studio's preview.

### Landscape

The landscape establishes the map's main character: its typical outline, relief, water, chasms, routes, vegetation, and feature mix. The dials modify that starting recipe. **Surprise me** lets the seed choose a landscape; a named choice requests that specific landscape.

| Landscape | General character |
| --- | --- |
| Highland Basin | A sheltered upland floor with rock around it and meltwater. |
| River Delta | Branching water across low land and islands. |
| Rift Plateau | Raised land cut by rifts, with crossings. |
| Island Chain | Separate islands in water, connected by narrow crossings. |
| Terraced Valley | Stepped shelves descending toward a valley. |
| Canyon Fork | Intersecting canyons around a high spine. |
| Lake District | Lakes between low, wooded ridges. |
| Crown Massif | A prominent central mountain mass. |
| Ruined Metropolis | Broken, city-like ground and a street-like grid. |
| Shattered Atoll | Fragments of a flooded caldera rim. |
| Ashen Steppe | More open country beneath a wide sky. |
| Sky Terraces | High, stacked shelves with routes and spans. |

These are generation tendencies, not promises that every feature will appear. The seed, size, outline, layout, and dials also affect the result.

### Outline

The outline controls how the generator treats the map boundary. **Natural** lets the generator select an outline suited to the chosen landscape. At higher Chaos, it can choose more adventurous alternatives.

| Outline | Boundary treatment |
| --- | --- |
| Island | Water around the edge. |
| Shelf | Chasms cutting into the edge. |
| Valley, Plateau, Basin | Rock enclosing the boundary; these currently use the same boundary-building algorithm. The chosen landscape and other generation passes still shape the interior. |
| Open | No enclosing boundary frame. |

An Island outline falls back to Open when Water Bias is zero. A Shelf outline falls back to Open when Rift Bias is zero, including when either outline is explicitly selected.

### Layout

A layout, also called a **motif**, is a large landform pattern laid over the broader landscape. **Let the map decide** allows the generator to choose a layout or no layout. **Pure landform** disables the motif. A named layout is attempted, but it may not be placed if a suitable site cannot be found.

| Layout | Intended pattern |
| --- | --- |
| Sunken Caldera | A ring of high ground around a lower heart. |
| Ringwall Citadel | Concentric ramparts and offset gates. |
| Spiral Ascent | A route spiralling towards a summit. |
| Cut Grid | Blocks and avenues cut at right angles. |
| Mesa Stand | Flat-topped towers above lower ground. |
| Broken Plates | Large slabs at different heights. |
| Canyon Lattice | Ravines crossing in both directions. |
| Crater Field | Overlapping basins across the land. |
| Giant Stair | Broad steps climbing across the map. |
| Warren Quarter | A winding, braided area in one part of the map. |

## Generation dials

The Inspector uses decimal values. Studio displays these controls as percentages: **1.0 = 100%**, **0.5 = 50%**, and **2.0 = 200%**. Surprises is the exception: its maximum is 1.0, or 100%.

Except for Chaos, a value of **1.0** means the landscape's normal setting; **2.0** increases that influence relative to the landscape. These are not exact percentages of the map, and a value of 2.0 does not guarantee twice as many visible features. Placement rules, map size, other dials, and the seed all matter.

| Inspector setting | Studio name | Range | Default | Effect |
| --- | --- | --- | --- | --- |
| Chaos | Surprises | 0–1 | 0.4 | How far the generator can vary from the landscape's usual recipe. Higher values allow wilder outlines, make large layouts more likely, and unlock some rarer wonders. Zero does not remove all randomness. |
| Relief Bias | Mountains | 0–2 | 1.0 | Scales rocky terrain, cliffs, terraces, and height variation. At zero the generator treats the world as flat. |
| Water Bias | Water | 0–2 | 1.0 | Scales generated water such as lakes, rivers, and seas. At zero, the generator removes water and cannot use an Island frame. |
| Rift Bias | Chasms | 0–2 | 1.0 | Scales rifts, chasms, and ravines. At zero, the generator removes chasms and cannot use a Shelf frame. |
| Wonder Bias | Wonders | 0–2 | 1.0 | Scales large set pieces such as craters, arenas, groves, and spires. Zero disables wonder placement. |
| Road Bias | Roads | 0–2 | 1.0 | Scales generated roads, plazas, and connecting routes. Roads can also level terrain and attempt crossing repairs. Zero disables the road pass. |
| Flora Bias | Forests | 0–2 | 1.0 | Scales the regular vegetation pass, including trees, thickets, and stumps. Zero disables that pass. |
| Landmark Bias | Landmarks | 0–2 | 1.0 | Scales a separate pass for prominent solitary trees, often on high ground. Zero disables that pass. |

Forest and landmark placement are separate. Setting **Flora Bias** to zero does not necessarily remove landmark trees; setting **Landmark Bias** to zero does not remove forest trees. Some wonders can also place vegetation. If you want as little generated vegetation as possible, lower both dials and consider the Wonders setting as well.

Water and rift settings also affect which wonders are eligible: a wonder that requires water or a chasm cannot be selected if that feature is disabled. A high Wonders value does not guarantee a wonder on every map, particularly on small maps or where no suitable site is found.

## Excluded wonders

**Excluded Wonders** is an advanced list of exact, lowercase generator keys. Any key in the list is removed from the pool of possible wonders. It does not force the generator to create a replacement. Leave the list empty for the Studio Generate panel's normal behaviour.

For example, add `sunken_arena` to prevent a Sunken Arena, or `sacred_grove` to prevent a Sacred Grove. Keys are different from display names: use underscores and the spelling shown below.

| Wonder | Key | Wonder | Key |
| --- | --- | --- | --- |
| Sunken Arena | `sunken_arena` | Impact Crater | `impact_crater` |
| Drowned Caldera | `drowned_caldera` | Step Ziggurat | `step_ziggurat` |
| Great Causeway | `great_causeway` | Spiral Sinkhole | `spiral_sinkhole` |
| Broken Quarter | `broken_quarter` | Labyrinth Court | `labyrinth_court` |
| Terraced Quarry | `terraced_quarry` | Lonely Spire | `lonely_spire` |
| Boiling Springs | `boiling_springs` | Sacred Grove | `sacred_grove` |
| Watch Gate | `watch_gate` | Cliff Switchback | `cliff_switchback` |
| Sky Observatory | `sky_observatory` | | |

Studio's normal Generate panel does not expose this list; exclusions are available for scripted Studio runs. Leave it empty when matching an ordinary Studio map.

## A practical starting point

Start with a **96 × 72** map and a fixed seed, leave the four choice settings on their default random options, and keep the dials at their defaults. Generate once. Change one setting at a time and regenerate with the same seed to see its effect. Try a named landscape first, then adjust mountains, water, and chasms; use the outline and layout if you want more control over the overall shape.

For an FPS level, generated routes are a starting point. Check walkable areas and bridge access in the editor, rebuild collision and navigation after edits, and test enemy paths before relying on the map.

## Source references

- Resource properties, defaults, ranges, and generation mapping: [CartoonTerrainData.cs](core/CartoonTerrainData.cs).
- Studio's dial labels and descriptions: [GeneratePanel.cs](../cartoon-terrain-studio/src/Studio/Modes/Generate/GeneratePanel.cs).
- Landscape and outline definitions: [MapSimulationArchetypes.cs](vendor/Domain/Dungeon/MapSimulationArchetypes.cs).
- Layout definitions: [MapSimulationMotifs.cs](vendor/Domain/Dungeon/MapSimulationMotifs.cs).
- Wonder keys: [MapSetPieces.cs](vendor/Domain/Dungeon/MapSetPieces.cs).
- Generator rules: [MapSimulation.cs](vendor/Domain/Dungeon/MapSimulation.cs) and [MapSimulation.Places.cs](vendor/Domain/Dungeon/MapSimulation.Places.cs).
