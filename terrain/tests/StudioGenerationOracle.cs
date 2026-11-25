using System.Collections.Generic;
using Fluitown.Domain;
using Godot;

// Test-only transcription of GenerateRecipe defaults and GenerateController.Options.
// Intentionally does not call CartoonTerrainData or its option conversion.
[Tool]
public partial class StudioGenerationOracle : RefCounted
{
    public Godot.Collections.Dictionary Generate(int width, int height, string seed, Godot.Collections.Dictionary recipe)
    {
        string Read(string key) => recipe.ContainsKey(key) ? recipe[key].AsString() : "";
        double Dial(string key, double fallback) => recipe.ContainsKey(key) ? recipe[key].AsDouble() : fallback;
        string theme = Read("theme"), archetype = Read("archetype"), frame = Read("frame"), motif = Read("motif");
        List<string>? excludedWonders = null;
        if (recipe.ContainsKey("excludedWonders"))
        {
            excludedWonders = new List<string>();
            foreach (var value in recipe["excludedWonders"].AsGodotArray()) excludedWonders.Add(value.AsString());
        }
        // GeneratorArtifacts.GENERATOR_THEME_OPTIONS, in its insertion order.
        var themeKeys = new List<string> { "mountain" };
        foreach (string key in EndlessDressing.ENDLESS_DRESSING_THEMES.keys())
            if (!EndlessDressing.GENERATOR_ONLY_DRESSING_THEMES.has(key)) themeKeys.Add(key);
        themeKeys.Add("raid_holdthefort");
        foreach (var biome in Fluitown.Render.Theme.generatorOnlyBiomes()) themeKeys.Add(biome.key);
        var map = MapSimulation.simulateMap(new MapSimulationOptions
        {
            seed = seed, width = width, height = height,
            themeKeys = themeKeys,
            themeKey = theme is "" or "*blend" ? null : theme,
            blendThemes = theme == "*blend" ? true : null,
            archetypeKey = archetype == "" ? null : archetype,
            frameKind = frame == "" ? null : frame,
            motifKey = motif == "*none" ? "" : motif == "" ? null : motif,
            chaos = Dial("chaos", 0.4), reliefBias = Dial("reliefBias", 1),
            waterBias = Dial("waterBias", 1), riftBias = Dial("riftBias", 1),
            wonderBias = Dial("wonderBias", 1), excludedWonders = excludedWonders, roadBias = Dial("roadBias", 1),
            floraBias = Dial("floraBias", 1), landmarkBias = Dial("landmarkBias", 1),
        });
        var artifact = map.artifact;
        var tiles = new Godot.Collections.Array<int>();
        var elevations = new Godot.Collections.Array<int>();
        for (int i = 0; i < artifact.width * artifact.height; i++)
        {
            tiles.Add(artifact.baseTiles[i]);
            elevations.Add(artifact.elevation?[i] ?? 0);
        }
        return new Godot.Collections.Dictionary { ["width"] = artifact.width, ["height"] = artifact.height,
            ["baseTiles"] = tiles, ["elevation"] = elevations };
    }
}
