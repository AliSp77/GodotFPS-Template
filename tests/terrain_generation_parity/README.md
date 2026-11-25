# Studio base-map parity test

## Studio addon against Studio Generate settings

The addon uses the same C# map generator as Studio. To check its recipe
conversion independently against the Studio Generate UI's defaults, theme
candidate order, and `GenerateController.Options` mapping, build the
test-only oracle and run:

```text
dotnet build GodotFPS.csproj -p:IncludeTerrainTestOracle=true
Godot_v4.7.2-stable_mono_win64_console.exe --headless --path . --script res://tests/terrain_generation_parity/studio_addon_parity.gd
```

The oracle is excluded from ordinary builds. The eleven cases compare every
`baseTiles` and `elevation` cell in memory, the exported JSON, and a reimport
of that JSON. They cover Studio defaults, explicit/random/blended themes,
minimum and maximum dials, frame/motif selection, excluded wonders, and Unicode seeds. They
exercise examples, not every possible seed or option, and do not compare
other artifact layers, rendering, or editor interaction. The oracle and
vendored generator must be checked against Studio when Studio is updated.

## Historical GDScript port checks

The following checks were written for an experimental GDScript reimplementation
and predate the corrected Studio defaults in the C# addon. Their old fixtures
and descriptions are retained for that separate experiment; they are not the
parity test for the current editor addon.

Run from the project root after building `GodotFPS.csproj`, using the Godot
4.7.2 **.NET** console executable:

```text
Godot_v4.7.2-stable_mono_win64_console.exe --headless --path . --script res://tests/terrain_generation_parity/parity.gd
```

The unfinished candidate was intended to be `res://addons/terrain_map_gd/map_generator.gd`;
that file does not currently exist, so these commands cannot pass yet. It is
instantiated and receives `generate(options: Dictionary)`. Its returned
dictionary must contain `width`, `height`, `baseTiles` and `elevation`; an
`error` result fails the test. Every cell is compared against
`CartoonTerrainData.GenerateWithOptions`, which invokes the existing vendored
Studio C# `MapSimulation` implementation. This C# dependency is for testing
only, not a valid implementation of the candidate. The test reports the first
different coordinate and exits nonzero on missing components or differences.

At the time these fixtures were written, the reference wrapper used its own
option contract: omitted `motif` and the
empty string both mean a randomly selected motif, while `"*none"` forces the
Studio `motifKey` to `""` (no motif). Keep those distinct. Omitted dials get
the wrapper's defaults, including `chaos = 0.3`; an omitted theme and archetype
default to `mountain` and `terraced_valley`. `"*blend"` selects blended themes.
All included fixtures explicitly pin a theme and chaos. The old wrapper passed a
different candidate theme pool from Studio, so these fixtures do not cover
random or blended theme parity. The wrapper has since been corrected; do not
assume its current defaults match the old fixtures.

To export the reference maps as reproducible, full-cell golden fixtures, run:

```text
Godot_v4.7.2-stable_mono_win64_console.exe --headless --path . --script res://tests/terrain_generation_parity/export_reference.gd
```

This writes the six fixture files under `golden/`, each including the options,
dimensions, base tiles and elevations. Export them only from the intended
Studio version; do not replace expectations with candidate output.

To compare the candidate to the checked-in golden fixtures without invoking
C#, use:

```text
godot --headless --path . --script res://tests/terrain_generation_parity/golden_parity.gd
```

These examples are regression cases, not a proof of parity for all seeds and
settings. Passing them covers dimensions, every tile and every elevation only;
other layers such as themes, decorations, surface and floor usage require
additional tests if they become part of the promised output. To verify the
reference still represents the user's Studio version, compare the vendored
domain/runtime source against `cartoon-terrain-studio/src` after Studio updates.
