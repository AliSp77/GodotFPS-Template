using System;
using System.Collections.Generic;
using Fluitown.Domain;
using Fluitown.GodotApp.Rendering;
using Fluitown.Render;
using Godot;

/// <summary>Adapts the Studio's terrain bake workers to the level's own 3D world.</summary>
[Tool, GlobalClass]
public partial class CartoonTerrainRenderer : Node3D
{
    private TerrainWorldSession? _session, _pendingSession;
    private WorldSink? _sink, _pendingSink;
    private double _clock;
    private string _status = "No terrain";
    private Color _groundTint = Colors.White, _waterTint = Colors.White, _foliageTint = Colors.White;

    public string Status => _status;
    public new bool Ready => _pendingSession == null && _session != null && _session.tiles.viewportReady;

    /// <summary>Apply per-level color grading without changing geometry or global materials.</summary>
    public void SetLook(Color ground, Color water, Color foliage)
    {
        _groundTint = ground; _waterTint = water; _foliageTint = foliage;
        _sink?.SetLook(ground, water, foliage);
        _pendingSink?.SetLook(ground, water, foliage);
    }

    public bool Build(CartoonTerrainData data)
    {
        var artifact = data.GetArtifact();
        if (artifact == null) { _status = "No terrain data"; return false; }
        try
        {
            var compiled = TerrainArtifactModule.compileTerrainArtifactToDungeonLayout(artifact, TerrainArtifactModule.TERRAIN_EDITOR_VALIDATION_OPTIONS);
            DungeonLayout layout = compiled.layout ?? TerrainEditor.draftDungeonLayoutFromTerrainArtifact(artifact);
            CancelPending();
            // New tiles are hidden and carry no collision markers until the complete map is ready.
            FluitownVegetation.Enabled = true;
            float scale = 1f / (float)FluitownVegetation.PxPerMetre;
            var offset = new Vector3((float)(-(layout.originX + layout.width * layout.tileSize * 0.5) * scale), 0,
                (float)(-(layout.originY + layout.height * layout.tileSize * 0.5) * scale));
            _pendingSink = new WorldSink(this, offset, scale);
            _pendingSink.SetLook(_groundTint, _waterTint, _foliageTint);
            _pendingSession = new TerrainWorldSession(new TerrainWorldSessionOptions
            {
                authoredLayout = layout,
                focusX = layout.originX + layout.width * layout.tileSize * 0.5,
                focusY = layout.originY + layout.height * layout.tileSize * 0.5,
                width = 1600, height = 900, zoom = 1, sink = _pendingSink,
            });
            _pendingSession.streamingViewOverride = new CameraView
            {
                left = layout.originX + 0.01, top = layout.originY + 0.01,
                right = layout.originX + layout.width * layout.tileSize - 0.01,
                bottom = layout.originY + layout.height * layout.tileSize - 0.01,
            };
            _pendingSession.streamingDetailZoom = 1;
            _status = "Baking terrain";
            SetProcess(true);
            return true;
        }
        catch (Exception e)
        {
            CancelPending();
            _status = "Terrain build failed: " + e.Message;
            GD.PushError(_status);
            return false;
        }
    }

    public override void _Process(double delta)
    {
        var target = _pendingSession ?? _session;
        if (target == null) return;
        try
        {
            _clock += delta;
            var readiness = target.frame(Math.Min(delta, 0.1), _clock);
            if (_pendingSession != null && readiness.ready)
            {
                // Detach the old tree before the replacement exposes any collision meshes.
                _sink?.Retire();
                _session?.dispose();
                _sink = _pendingSink;
                _session = _pendingSession;
                _pendingSink = null;
                _pendingSession = null;
                _sink!.Activate();
            }
            _status = readiness.ready ? "Terrain ready" : $"{readiness.stage}: {readiness.readyTiles}/{readiness.requiredTiles} tiles";
        }
        catch (Exception e)
        {
            CancelPending();
            _status = "Terrain bake failed: " + e.Message;
            GD.PushError(_status);
            SetProcess(false);
        }
    }

    public override void _ExitTree()
    {
        CancelPending();
        _sink?.Retire();
        _session?.dispose();
        _sink = null; _session = null;
        SetProcess(false);
    }

    private void CancelPending()
    {
        _pendingSink?.Retire();
        _pendingSession?.dispose();
        _pendingSink = null; _pendingSession = null;
    }

    private sealed class WorldSink : ITerrainTileSink, ITerrainTileCopyingSink
    {
        private readonly Node3D _root;
        private readonly ShaderMaterial _surface, _water;
        private readonly StandardMaterial3D _foliage = new() { VertexColorUseAsAlbedo = true, Roughness = 1 };
        private readonly StandardMaterial3D _wood = new() { VertexColorUseAsAlbedo = true, Roughness = 1 };
        private readonly Dictionary<TerrainTile, Node3D> _nodes = new();
        private bool _active;

        public WorldSink(CartoonTerrainRenderer owner, Vector3 offset, float scale)
        {
            _root = new Node3D { Name = "TerrainGeneration", Visible = false, Position = offset, Scale = Vector3.One * scale };
            owner.AddChild(_root);
            _surface = new ShaderMaterial { Shader = GD.Load<Shader>("res://terrain/render/terrain_studio_surface.gdshader") };
            _water = new ShaderMaterial { Shader = GD.Load<Shader>("res://terrain/render/terrain_water.gdshader") };
        }

        public void SetLook(Color ground, Color water, Color foliage)
        {
            _surface.SetShaderParameter("tint", ground);
            _water.SetShaderParameter("tint", water);
            _foliage.AlbedoColor = foliage;
        }

        public void Activate()
        {
            _active = true;
            foreach (var node in _nodes.Values) MarkCollision(node, true);
            _root.Visible = true;
        }
        public void Retire()
        {
            _active = false;
            if (!GodotObject.IsInstanceValid(_root)) return;
            _root.Visible = false;
            foreach (var node in _nodes.Values) MarkCollision(node, false);
            _root.GetParent()?.RemoveChild(_root);
            _root.QueueFree();
        }
        private static void MarkCollision(Node3D tile, bool active)
        {
            if (tile.GetNodeOrNull<MeshInstance3D>("Surface") is { } surface)
            {
                if (active) surface.SetMeta("cartoon_collision", true);
                else if (surface.HasMeta("cartoon_collision")) surface.RemoveMeta("cartoon_collision");
            }
            if (tile.GetNodeOrNull<MultiMeshInstance3D>("TreeTrunks") is { } trunks)
            {
                if (active) trunks.SetMeta("cartoon_tree_collision", true);
                else if (trunks.HasMeta("cartoon_tree_collision")) trunks.RemoveMeta("cartoon_tree_collision");
            }
        }
        public object beginUpload(TerrainGeometryPayload geometry) => geometry;
        public bool uploadComplete(object upload) => true;
        public void cancelUpload(object upload) { }

        public void install(TerrainTile tile)
        {
            var group = new Node3D { Name = $"Tile_{tile.tx}_{tile.ty}", Visible = false };
            _root.AddChild(group);
            var geometry = tile.geometry;
            if (geometry.surface is { } surface)
            {
                var mesh = TerrainLaneMeshes.Surface(surface.position, surface.normal, surface.color,
                    surface.surface, surface.emissive, surface.ground, surface.index);
                if (mesh != null)
                {
                    var instance = new MeshInstance3D { Name = "Surface", Mesh = mesh, MaterialOverride = _surface };
                    if (_active) instance.SetMeta("cartoon_collision", true);
                    group.AddChild(instance);
                }
            }
            if (geometry.water is { } water)
            {
                var mesh = TerrainLaneMeshes.Water(water.position, water.normal, water.color, water.water,
                    water.fold, water.reflection, water.index);
                if (mesh != null) group.AddChild(new MeshInstance3D { Name = "Water", Mesh = mesh, MaterialOverride = _water });
            }
            AddVegetation(group, geometry.vegetation);
            _nodes[tile] = group;
        }

        // Reuse Studio's deterministic plant placement, sizing and pigments. These simple
        // instanced crowns are a lightweight presentation, not Studio's full plant mesher.
        private void AddVegetation(Node3D group, TerrainVegetationLane? lane)
        {
            if (lane == null) return;
            var trees = new List<int>(); var bushes = new List<int>();
            var records = lane.records;
            for (int i = 0; i + FluitownVegetation.Stride <= records.Length; i += FluitownVegetation.Stride)
            {
                int kind = (int)MathF.Round(records[i + FluitownVegetation.Kind]);
                if (kind == FluitownVegetation.KindTree) trees.Add(i);
                else if (kind == FluitownVegetation.KindBush) bushes.Add(i);
            }
            if (trees.Count > 0) { AddPlants(group, records, trees, true, false); AddPlants(group, records, trees, true, true); }
            if (bushes.Count > 0) AddPlants(group, records, bushes, false, true);
        }
        private void AddPlants(Node3D group, float[] records, List<int> indices, bool tree, bool crown)
        {
            Mesh mesh = crown
                ? new SphereMesh { Radius = 1, Height = 2, RadialSegments = 8, Rings = 4 }
                : new CylinderMesh { TopRadius = 0.7f, BottomRadius = 1, Height = 1, RadialSegments = 6 };
            var instances = new MultiMesh { TransformFormat = MultiMesh.TransformFormatEnum.Transform3D, UseColors = true, Mesh = mesh, InstanceCount = indices.Count };
            var trunkTransforms = new Godot.Collections.Array<Transform3D>();
            for (int n = 0; n < indices.Count; n++)
            {
                int i = indices[n];
                float height = records[i + FluitownVegetation.Height], radius = records[i + FluitownVegetation.Radius];
                var foot = new Vector3(records[i + FluitownVegetation.X], records[i + FluitownVegetation.Y], records[i + FluitownVegetation.Z]);
                Vector3 size = crown ? new Vector3(radius, height * (tree ? 0.32f : 0.5f), radius)
                    : new Vector3(Math.Max(radius * 0.12f, 1), height * 0.65f, Math.Max(radius * 0.12f, 1));
                float centre = crown ? height * (tree ? 0.72f : 0.5f) : height * 0.325f;
                var transform = new Transform3D(Basis.Identity.Scaled(size), foot + Vector3.Up * centre);
                instances.SetInstanceTransform(n, transform);
                if (tree && !crown) trunkTransforms.Add(transform);
                int hex = (int)MathF.Round(records[i + (crown ? FluitownVegetation.ColourLeaf : FluitownVegetation.ColourWood)]);
                instances.SetInstanceColor(n, new Color(((hex >> 16) & 255) / 255f, ((hex >> 8) & 255) / 255f, (hex & 255) / 255f));
            }
            var instance = new MultiMeshInstance3D
            {
                Name = tree ? (crown ? "TreeCrowns" : "TreeTrunks") : "Bushes", Multimesh = instances,
                MaterialOverride = crown ? _foliage : _wood,
            };
            if (tree && !crown) instance.SetMeta("cartoon_tree_transforms", trunkTransforms);
            if (_active && tree && !crown) instance.SetMeta("cartoon_tree_collision", true);
            group.AddChild(instance);
        }
        public void setShown(TerrainTile tile, bool shown) { if (_nodes.TryGetValue(tile, out var node)) node.Visible = shown; }
        public void setCasterMounted(TerrainTile tile, bool mounted) { }
        public void destroy(TerrainTile tile)
        {
            if (_nodes.Remove(tile, out var node) && GodotObject.IsInstanceValid(node)) node.QueueFree();
        }
    }
}
