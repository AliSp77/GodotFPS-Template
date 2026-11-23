# Navigation Mesh Painter

Edit an already baked `NavigationRegion3D` using a grid brush in the 3D editor.

1. Enable **Navigation Mesh Painter** under Project Settings > Plugins if the dock is not visible.
2. Select a `NavigationRegion3D` with a baked `NavigationMesh` and click **Use selected NavigationRegion3D** in the dock.
3. Switch the editor viewport to top orthographic view. Set **Local floor height** to the height of the floor you want to edit in the region's local coordinates. The initial value comes from the first mesh vertex; check it before painting.
4. Set grid size and brush radius. Choose **Remove walkable area**, **Add walkable area**, or **Erase pending marks**, and enable **Paint mode**.
5. Left-drag to paint. Red indicates removal, green indicates addition. Pending marks can be discarded before applying.
6. Click **Apply to navigation mesh** and save the scene. Editor Undo restores the mesh from before the apply. Turn paint mode off to return to normal selection.

## Important details

- Pending marks are temporary and are not saved. Apply them before closing or changing scenes. Grid size and height are fixed while marks exist.
- Applying rebuilds the selected mesh from its current polygons and the painted changes. It can adjust the original edges according to the mesh's bake voxel settings. Keep a backup for complex levels, and check paths after applying.
- To avoid shrinking an already baked mesh a second time, the rebuild uses zero agent radius and restores the resource's configured radius afterwards. Added areas are **not checked against walls, obstacles, agent clearance, or other level geometry**. Paint only where an agent can physically move.
- Additions are flat at the selected local height. They should overlap or touch existing navigation; a gap or a height difference can leave them disconnected. Verify with an agent or Godot's navigation debug display.
- Removal is applied to triangles near the selected height; overlapping floors, steep slopes, and vertically stacked surfaces need special care. Use separate regions for different floors.
- A regular Godot bake replaces these manual edits. Reapply them after rebaking the region.
- Each apply duplicates the navigation resource before changing it, so shared source meshes are not modified. The editor scene must be saved to retain the result.
