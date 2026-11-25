using System;
using System.IO;
using System.Linq;
using System.Text.Json.Nodes;
using Fluitown.Domain;
using Godot;

/// <summary>Saved editable Studio map. The JSON document is authoritative; meshes are derived.</summary>
[Tool, GlobalClass]
public partial class CartoonTerrainData : Resource
{
    private TerrainArtifact? _artifact;
    private string _json = "";
    private TerrainStamp? _clipboard;
    private byte[]? _clipboardUsage;

    // These settings are stored alongside the map, so a resource can be edited and
    // regenerated without keeping a separate set of controls in the editor dock.
    [ExportGroup("Map generation")]
    [Export(PropertyHint.Range, "3,512,1")] public int GenerationWidth { get; set; } = 96;
    [Export(PropertyHint.Range, "3,512,1")] public int GenerationHeight { get; set; } = 72;
    [Export] public string GenerationSeed { get; set; } = "";
    [Export] public string GenerationTheme { get; set; } = "Random";
    [Export] public string GenerationArchetype { get; set; } = "Random";
    [Export] public string GenerationFrame { get; set; } = "Random";
    [Export] public string GenerationMotif { get; set; } = "Random";

    [ExportGroup("Generation dials")]
    [Export(PropertyHint.Range, "0,1,0.05")] public double Chaos { get; set; } = 0.4;
    [Export(PropertyHint.Range, "0,2,0.05")] public double ReliefBias { get; set; } = 1.0;
    [Export(PropertyHint.Range, "0,2,0.05")] public double WaterBias { get; set; } = 1.0;
    [Export(PropertyHint.Range, "0,2,0.05")] public double RiftBias { get; set; } = 1.0;
    [Export(PropertyHint.Range, "0,2,0.05")] public double WonderBias { get; set; } = 1.0;
    [Export(PropertyHint.Range, "0,2,0.05")] public double RoadBias { get; set; } = 1.0;
    [Export(PropertyHint.Range, "0,2,0.05")] public double FloraBias { get; set; } = 1.0;
    [Export(PropertyHint.Range, "0,2,0.05")] public double LandmarkBias { get; set; } = 1.0;
    [Export] public Godot.Collections.Array<string> ExcludedWonders { get; set; } = new();

    [ExportGroup("")]

    [Export(PropertyHint.MultilineText)]
    public string ArtifactJson
    {
        get => _json;
        set
        {
            if (string.IsNullOrWhiteSpace(value)) { _json = ""; _artifact = null; EmitChanged(); return; }
            // Parse before replacing: invalid input never destroys the last valid map.
            var parsed = ReadArtifact(value);
            _artifact = parsed;
            _json = value;
            EmitChanged();
        }
    }

    public override void _ValidateProperty(Godot.Collections.Dictionary property)
    {
        string name = property["name"].AsString();
        if (name == nameof(ArtifactJson))
        {
            // The document must still be saved and loaded, but its JSON is not an
            // inspector control. Editing it directly can invalidate the map.
            property["usage"] = (int)PropertyUsageFlags.Storage;
            return;
        }
        string[]? choices = name switch
        {
            nameof(GenerationTheme) => new[] { "Random", "*blend" }.Concat(StudioGenerationThemeKeys()).ToArray(),
            nameof(GenerationArchetype) => new[] { "Random" }.Concat(MapSimulationArchetypes.MAP_SIMULATION_ARCHETYPES.Select(a => a.key)).ToArray(),
            nameof(GenerationFrame) => new[] { "Random" }.Concat(MapSimulationArchetypes.MAP_FRAME_KINDS).ToArray(),
            nameof(GenerationMotif) => new[] { "Random", "*none" }.Concat(MapSimulationMotifs.MAP_LANDFORM_MOTIFS.Select(m => m.key)).ToArray(),
            _ => null,
        };
        if (choices != null)
        {
            property["hint"] = (int)PropertyHint.Enum;
            property["hint_string"] = string.Join(",", choices);
        }
    }

    public int Width => _artifact?.width ?? 0;
    public int Height => _artifact?.height ?? 0;
    public float CellSize => (float)((_artifact?.tileSize ?? 62.5) / 25.0);
    public float LevelHeight => 0.6f;
    internal TerrainArtifact? GetArtifact() => _artifact;
    public int GetWidth() => Width;
    public int GetHeight() => Height;
    public float GetCellSize() => CellSize;
    public float GetLevelHeight() => LevelHeight;

    private static TerrainArtifact ReadArtifact(string json)
    {
        var doc = JsonNode.Parse(json) ?? throw new FormatException("Empty terrain document.");
        var a = TerrainEditor.terrainArtifactFromEditorDocument(doc);
        var source = doc["artifact"] is JsonObject child ? child : doc;
        if (source["floorUsage"] is JsonArray usage)
        {
            if (usage.Count != a.width * a.height) throw new FormatException("floorUsage length does not match map dimensions.");
            a.floorUsage = usage.Select(v => checked((byte)(v?.GetValue<int>() ?? throw new FormatException("Invalid floorUsage value.")))).ToArray();
        }
        return a;
    }

    private void Commit()
    {
        if (_artifact == null) return;
        JsonObject doc;
        try { doc = JsonNode.Parse(_json) as JsonObject ?? new JsonObject(); }
        catch { doc = new JsonObject(); }
        var output = TerrainEditor.terrainArtifactToJson(_artifact);
        if (_artifact.floorUsage != null)
        {
            var values = new JsonArray();
            foreach (byte value in _artifact.floorUsage) values.Add((int)value);
            output["floorUsage"] = values;
        }
        if (doc["kind"]?.GetValue<string>() == TerrainEditor.TERRAIN_EDITOR_DOCUMENT_KIND)
            doc["artifact"] = output;
        else
        {
            doc = new JsonObject { ["kind"] = TerrainEditor.TERRAIN_EDITOR_DOCUMENT_KIND, ["version"] = TerrainEditor.TERRAIN_EDITOR_DOCUMENT_VERSION, ["artifact"] = output };
        }
        _json = doc.ToJsonString();
        EmitChanged();
    }

    /// <summary>Uses the Studio Generate tab's default recipe.</summary>
    public void Generate(int width, int height, string seed) => GenerateWithOptions(width, height, seed, new Godot.Collections.Dictionary());

    /// <summary>Generate from this resource's saved Studio settings.</summary>
    public void GenerateFromSettings()
    {
        GenerationSeed = (GenerationSeed ?? "").Trim();
        if (GenerationSeed.Length == 0) GenerationSeed = Guid.NewGuid().ToString("N")[..8];
        static string Choice(string value) => value is null or "Random" ? "" : value;
        var options = new Godot.Collections.Dictionary
        {
            ["theme"] = Choice(GenerationTheme), ["archetype"] = Choice(GenerationArchetype),
            ["frame"] = Choice(GenerationFrame), ["motif"] = Choice(GenerationMotif),
            ["chaos"] = Chaos, ["reliefBias"] = ReliefBias, ["waterBias"] = WaterBias,
            ["riftBias"] = RiftBias, ["wonderBias"] = WonderBias, ["roadBias"] = RoadBias,
            ["floraBias"] = FloraBias, ["landmarkBias"] = LandmarkBias,
            ["excludedWonders"] = ExcludedWonders,
        };
        GenerateWithOptions(GenerationWidth, GenerationHeight, GenerationSeed, options);
    }

    /// <summary>Compose a deterministic Studio map from a recipe. An empty string rolls a choice;
    /// theme *blend mixes themes and motif *none disables the motif.</summary>
    public void GenerateWithOptions(int width, int height, string seed, Godot.Collections.Dictionary options)
    {
        if (width < 3 || height < 3 || width > 512 || height > 512) throw new ArgumentOutOfRangeException(nameof(width), "Map dimensions must be between 3 and 512.");
        string theme = Str(options, "theme", "");
        string archetype = Str(options, "archetype", "");
        string frame = Str(options, "frame", "");
        string motif = Str(options, "motif", "");
        double Dial(string key, double fallback, double max)
        {
            double value = Num(options, key, fallback);
            return double.IsFinite(value) ? Math.Clamp(value, 0, max) : fallback;
        }
        System.Collections.Generic.List<string>? excludedWonders = null;
        if (options.ContainsKey("excludedWonders"))
        {
            excludedWonders = new System.Collections.Generic.List<string>();
            foreach (var value in options["excludedWonders"].AsGodotArray()) excludedWonders.Add(value.AsString());
        }
        var generated = MapSimulation.simulateMap(new MapSimulationOptions
        {
            width = width, height = height, seed = seed,
            // GenerateController.Options supplies the Studio's full ordered candidate list,
            // which is larger than MapSimulation's own default list. Ordering matters.
            themeKeys = StudioGenerationThemeKeys(),
            themeKey = theme is "" or "*blend" ? null : theme,
            blendThemes = theme == "*blend" ? true : null,
            archetypeKey = archetype == "" ? null : archetype,
            frameKind = frame == "" ? null : frame,
            motifKey = motif == "*none" ? "" : motif == "" ? null : motif,
            chaos = Dial("chaos", 0.4, 1), reliefBias = Dial("reliefBias", 1, 2),
            waterBias = Dial("waterBias", 1, 2), riftBias = Dial("riftBias", 1, 2),
            wonderBias = Dial("wonderBias", 1, 2), excludedWonders = excludedWonders, roadBias = Dial("roadBias", 1, 2),
            floraBias = Dial("floraBias", 1, 2), landmarkBias = Dial("landmarkBias", 1, 2),
        });
        _artifact = generated.artifact;
        _json = "";
        Commit();
    }

    public Godot.Collections.Array<string> GetGenerationArchetypes()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var entry in MapSimulationArchetypes.MAP_SIMULATION_ARCHETYPES) result.Add(entry.key);
        return result;
    }
    public Godot.Collections.Array<string> GetGenerationArchetypeNames()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var entry in MapSimulationArchetypes.MAP_SIMULATION_ARCHETYPES) result.Add(entry.name);
        return result;
    }
    public Godot.Collections.Array<string> GetGenerationFrames()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var entry in MapSimulationArchetypes.MAP_FRAME_KINDS) result.Add(entry);
        return result;
    }
    public Godot.Collections.Array<string> GetGenerationMotifs()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var entry in MapSimulationMotifs.MAP_LANDFORM_MOTIFS) result.Add(entry.key);
        return result;
    }
    public Godot.Collections.Array<string> GetGenerationMotifNames()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var entry in MapSimulationMotifs.MAP_LANDFORM_MOTIFS) result.Add(entry.name);
        return result;
    }
    public Godot.Collections.Array<string> GetGenerationWonders()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var wonder in MapSetPieces.MAP_WONDERS) result.Add(wonder.key);
        return result;
    }
    public Godot.Collections.Array<string> GetGenerationThemes()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var key in StudioGenerationThemeKeys()) result.Add(key);
        return result;
    }
    public Godot.Collections.Array<string> GetGenerationThemeNames()
    {
        var result = new Godot.Collections.Array<string>();
        foreach (var key in StudioGenerationThemeKeys()) result.Add(StudioThemeName(key));
        return result;
    }

    // Same display-name rules as Studio's ThemeCatalog.Pretty and
    // GeneratorArtifacts.runThemeLabel; keep the generator key as item metadata.
    private static string StudioThemeName(string key)
    {
        if (key == "mountain") return "Classic Mountain";
        string name = Fluitown.Render.Theme.biomeForKey(key).name ?? "";
        if (name.Length == 0)
        {
            string spaced = key.Replace('_', ' ');
            var sb = new System.Text.StringBuilder(spaced.Length);
            static bool IsWord(char c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
            for (int i = 0; i < spaced.Length; i++)
            {
                char c = spaced[i];
                bool boundary = IsWord(c) && (i == 0 || !IsWord(spaced[i - 1]));
                sb.Append(boundary && c >= 'a' && c <= 'z' ? (char)(c - 32) : c);
            }
            name = sb.ToString();
        }
        foreach (string suffix in new[] { " Endrun", " Run" })
            if (name.EndsWith(suffix, StringComparison.Ordinal)) name = name[..^suffix.Length];
        if (name.StartsWith("The ", StringComparison.Ordinal)) name = name[4..];
        return name;
    }

    // Mirrors GeneratorArtifacts.buildGeneratorThemeOptions in Studio, including order
    // and any duplicate keys: deduplicating changes random-theme selection.
    private static System.Collections.Generic.List<string> StudioGenerationThemeKeys()
    {
        var result = new System.Collections.Generic.List<string> { "mountain" };
        result.AddRange(MapSimulation.generatorThemeKeys());
        result.Add("raid_holdthefort");
        foreach (var biome in Fluitown.Render.Theme.generatorOnlyBiomes()) result.Add(biome.key);
        return result;
    }
    public void CreateBlank(int width, int height)
    {
        if (width < 3 || height < 3 || width > 512 || height > 512) throw new ArgumentOutOfRangeException(nameof(width));
        _artifact = TerrainEditor.createTerrainArtifact(new CreateTerrainArtifactOptions { width = width, height = height });
        _json = "";
        Commit();
    }

    public bool ImportJson(string path)
    {
        try { ArtifactJson = File.ReadAllText(ProjectSettings.GlobalizePath(path)); return true; }
        catch (Exception e) { GD.PushError($"Terrain import failed: {e.Message}"); return false; }
    }
    public bool ExportJson(string path)
    {
        try { if (_artifact == null) return false; File.WriteAllText(ProjectSettings.GlobalizePath(path), _json); return true; }
        catch (Exception e) { GD.PushError($"Terrain export failed: {e.Message}"); return false; }
    }
    public int GetTile(int x, int z) => InBounds(x, z) ? _artifact!.baseTiles[z * Width + x] : TileType.Solid;
    public int GetElevation(int x, int z) => InBounds(x, z) ? _artifact!.elevation?[z * Width + x] ?? 0 : 0;
    private bool InBounds(int x, int z) => _artifact != null && x >= 0 && z >= 0 && x < Width && z < Height;

    public void SetCell(int x, int z, int tile, int elevation)
    {
        if (!InBounds(x, z) || tile < 0 || tile > 6) return;
        TerrainEditor.ensureTerrainEditorLayers(_artifact!);
        int i = z * Width + x;
        _artifact!.baseTiles[i] = (byte)tile;
        _artifact.elevation![i] = (sbyte)TerrainEditor.terrainStoredElevationFromEditorHeight(tile, elevation);
        Commit();
    }

    private static string Str(Godot.Collections.Dictionary o, string k, string d) => o.ContainsKey(k) ? o[k].AsString() : d;
    private static int Int(Godot.Collections.Dictionary o, string k, int d) => o.ContainsKey(k) ? o[k].AsInt32() : d;
    private static double Num(Godot.Collections.Dictionary o, string k, double d) => o.ContainsKey(k) ? o[k].AsDouble() : d;
    private static bool Bool(Godot.Collections.Dictionary o, string k, bool d) => o.ContainsKey(k) ? o[k].AsBool() : d;

    public bool ApplyEdit(int x, int z, Godot.Collections.Dictionary options)
    {
        if (!InBounds(x, z)) return false;
        var a = _artifact!;
        var brush = new TerrainBrush { size = Math.Clamp(Int(options, "brush_size", 1), 1, 99), shape = Str(options, "shape", "circle"), soft = Bool(options, "soft", false), strength = Math.Clamp(Num(options, "strength", 1), 0, 1) };
        var tool = Str(options, "tool", "paint");
        int material = Math.Clamp(Int(options, "material", TileType.Floor), 0, 6);
        int height = Int(options, "height", 0);
        string theme = Str(options, "theme", a.biomeKey ?? "mountain");
        TerrainEditResult result;
        switch (tool)
        {
            case "paint": result = TerrainEditor.applyTerrainPaintBrush(a, new TerrainPaintBrushEdit { tx = x, ty = z, tile = material, height = height, themeKey = theme, brush = brush }); break;
            case "fill": result = TerrainEditor.floodFillTerrainPaint(a, new TerrainPaintFillEdit { tx = x, ty = z, tile = material, height = height, themeKey = theme }); break;
            case "theme": result = TerrainEditor.applyTerrainThemeBrush(a, new TerrainThemeBrushEdit { tx = x, ty = z, themeKey = theme, brush = brush }); break;
            case "smooth": result = TerrainEditor.applyTerrainElevationSmooth(a, new TerrainSmoothEdit { tx = x, ty = z, brush = brush, passes = 1 }); break;
            case "decorate": result = TerrainEditor.applyTerrainDecorationBrush(a, new TerrainDecorationBrushEdit { tx = x, ty = z, kind = Str(options, "nature", "tree"), themeKey = theme, brush = brush }); break;
            case "decoration_erase": result = TerrainEditor.eraseTerrainDecorationBrush(a, new TerrainDecorationEraseEdit { tx = x, ty = z, brush = brush }); break;
            case "structure":
                var structure = TerrainEditor.applyTerrainDepthStructureBrush(a, new TerrainDepthStructureBrushEdit { tx = x, ty = z, kind = Str(options, "structure", "cleft"), themeKey = theme });
                if (structure.rejection != null) GD.PushWarning(structure.rejection);
                result = structure; break;
            case "raise": case "lower": case "flatten":
                TerrainEditor.ensureTerrainEditorLayers(a);
                result = new TerrainEditResult();
                var visited = options.ContainsKey("visited") ? options["visited"].AsGodotArray() : null;
                foreach (var cell in TerrainEditor.terrainBrushCells(Width, Height, x, z, brush))
                {
                    if (tool != "flatten" && visited != null && visited.Contains(cell.index)) continue;
                    int tile = a.baseTiles[cell.index];
                    if (tile is TileType.Chasm or TileType.Cleft or TileType.Underpass) continue;
                    int current = a.elevation![cell.index];
                    int goal = tool == "flatten" ? height : current + (tool == "raise" ? 1 : -1);
                    var range = TerrainEditor.terrainEditorHeightRangeForTile(tile);
                    int next = Math.Clamp((int)Math.Round(current + (goal - current) * cell.weight, MidpointRounding.AwayFromZero), range.min, range.max);
                    if (next == current) continue;
                    a.elevation[cell.index] = (sbyte)next;
                    result.changed.Add(cell.index);
                    visited?.Add(cell.index);
                }
                break;
            default: return false;
        }
        if (result.changed.Count == 0) return false;
        Commit();
        return true;
    }

    public void CopyRegion(int x, int z, int width, int height)
    {
        if (_artifact == null || width <= 0 || height <= 0) return;
        var rect = TerrainEditor.normalizeTerrainRect(new TerrainRect(x, z, width, height), Width, Height);
        _clipboard = TerrainEditor.copyTerrainStamp(_artifact, rect);
        _clipboardUsage = _artifact.floorUsage == null ? null : new byte[rect.tw * rect.th];
        if (_clipboardUsage != null)
            for (int dz = 0; dz < rect.th; dz++) for (int dx = 0; dx < rect.tw; dx++) _clipboardUsage[dz * rect.tw + dx] = _artifact.floorUsage![(rect.ty + dz) * Width + rect.tx + dx];
    }
    public bool PasteRegion(int x, int z)
    {
        if (_artifact == null || _clipboard == null) return false;
        var result = TerrainEditor.applyTerrainStamp(_artifact, _clipboard, x, z);
        bool usageChanged = false;
        if (_clipboardUsage != null)
        {
            _artifact.floorUsage ??= new byte[Width * Height];
            for (int dz = 0; dz < _clipboard.height; dz++) for (int dx = 0; dx < _clipboard.width; dx++)
                if (InBounds(x + dx, z + dz)) { int i = (z + dz) * Width + x + dx; byte v = _clipboardUsage[dz * _clipboard.width + dx]; usageChanged |= _artifact.floorUsage[i] != v; _artifact.floorUsage[i] = v; }
        }
        if (result.changed.Count > 0 || usageChanged) Commit(); return result.changed.Count > 0 || usageChanged;
    }
    public bool ClearRegion(int x, int z, int width, int height)
    {
        if (_artifact == null || width <= 0 || height <= 0) return false;
        var rect = TerrainEditor.normalizeTerrainRect(new TerrainRect(x, z, width, height), Width, Height);
        var cells = new System.Collections.Generic.List<int>();
        for (int dz = 0; dz < rect.th; dz++) for (int dx = 0; dx < rect.tw; dx++) cells.Add((rect.ty + dz) * Width + rect.tx + dx);
        var result = TerrainEditor.clearTerrainSelection(_artifact, cells);
        bool usageChanged = false;
        if (_artifact.floorUsage != null) foreach (int i in cells) { usageChanged |= _artifact.floorUsage[i] != 0; _artifact.floorUsage[i] = 0; }
        if (result.changed.Count > 0 || usageChanged) Commit(); return result.changed.Count > 0 || usageChanged;
    }
}





