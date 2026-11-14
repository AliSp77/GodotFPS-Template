# Cartoon shader and outline

## Open the preview

Open `res://afterburn/shaders/cartoon_preview.tscn` and press **F6**. The saved scene contains a mint sphere, an orange crate, and the supplied ship2 hull in coral. Every object, material, light, and camera is editable in the scene tree. There is no scene construction script.

## Apply to a mesh

1. Select a **MeshInstance3D**.
2. Drag `res://afterburn/materials/cartoon_mint.tres`, `cartoon_orange.tres`, or `cartoon_coral.tres` into **Geometry > Material Override**.
3. Choose **Make Unique** on the material before changing one object's colors. To preserve different textures on individual mesh surfaces, assign a separate copy in each surface material slot instead of replacing the whole mesh material.
4. Expand **Shader Parameters** to edit the surface and lighting. Set **Albedo Texture** to the existing color texture when needed. The shader supports opaque textures and optional vertex colors.
5. Expand **Next Pass > Shader Parameters** for the outline. The three presets share this outline resource; use **Make Unique** on Next Pass for a different width on one material.

## Applied in gameplay

The cartoon shader is assigned to **enemy ship hulls, the four ranged guns and their magazines, and the hands and arms in all five weapon slots**. The map, props, knife blade, engine glows, warning beams, and HUD keep their existing materials.

| Target | Material in `afterburn/materials/` |
| --- | --- |
| Striker | `cartoon_mint.tres` |
| Sniper and Charger | `cartoon_coral.tres` |
| Guardian and boss | `cartoon_orange.tres` |
| Interceptor | `cartoon_purple.tres` |
| Pistol, assault rifle, burst rifle, LMG, and their magazines | `cartoon_gun.tres` |
| Hands and arms for all weapons, including the knife slot | `cartoon_hands.tres` |

Edit these shared material resources to change their colors and shading. Ordinary ships select them through `HULL_MATERIALS` in `afterburn/ship.gd`. The Charger uses a saved material assignment on `Hull` in `afterburn/enemies/charger.tscn`.

Gun and hand assignments are saved in `afterburn/player.tscn`. Expand `WeaponsManager > [weapon] > fps_demo_arms > Armature > Skeleton3D`; the gun mesh is under `hand_R`, and its magazine is under `Holder_R`. Their **Material Override** points to `cartoon_gun.tres`. The `fps_arms_extended` mesh uses `cartoon_hands.tres`, with a weaker highlight for the hands and sleeves. Both preserve `resources/textures/fps_demo_texture.png`. The old black outline child under each modified mesh is hidden to avoid drawing two outline styles. The original weapon scenes retain their original materials.

## Controls

| Inspector setting | Purpose |
| --- | --- |
| Base Color | Main surface color, multiplied by the texture. |
| Albedo Texture | Optional color map; defaults to white. |
| Use Vertex Color | Multiply by the mesh's vertex colors. |
| Light Bands | 2–6 discrete direct light levels. Default: 3. |
| Light Wrap | Move the light boundary slightly around the surface. |
| Shadow Tint / Shadow Fill | Color and minimum visibility of the shaded side, including areas with no direct light. Default fill: 0.28. |
| Highlight Color / Strength / Size | Hard edged glossy highlight; strength 0 disables it. |
| Rim Color / Strength / Threshold | Subtle view dependent edge accent; strength 0 disables it. |
| Next Pass > Outline Color | Dark silhouette color. Alpha is unused; this is an opaque pass. |
| Next Pass > Outline Width Pixels | Approximate thickness at the internal rendering resolution. Default: 2.5. Set 0 for no expansion, or clear Next Pass to disable the additional draw. |

## How it works

`cartoon.gdshader` uses Godot's spatial light function to quantize diffuse lighting and add a hard highlight. Real light colors, range attenuation, and shadow maps still apply. A small explicit tinted fill replaces environment ambient light on these materials. Multiple lights add together, so a single dominant directional light gives the clearest bands. Disable forced vertex shading for these materials: the custom light function requires per-pixel lighting.

`cartoon_outline.gdshader` is an inverted hull pass. It expands the projected mesh along its normals, culls front faces, and draws the remaining silhouette in a flat color. It needs no camera effect, depth texture, or runtime helper node. Its width follows the viewport's internal pixel resolution, including render scaling.

## Limits and editing tips

- This is a silhouette outline, not an internal edge detector. It does not draw every panel line or intersection.
- Smooth, closed meshes give the most continuous outline. Split normals on hard corners, open surfaces, and very thin pieces can show gaps or uneven thickness. For a polished hard surface asset, provide an outline shell with smoothed normals or author the outline into the model.
- Keep mesh scales positive and avoid extreme nonuniform scale. Winding determines which faces the outline pass culls.
- Opaque surfaces only. Transparency, alpha cutouts, normal maps, and metallic maps need extra shader support.
- An outline adds an extra mesh pass. Prefer it on ships, weapons, and prominent props; avoid assigning it to every large road surface.
- The cel material receives shadows and casts normal mesh shadows. The expanded outline does not cast an extra enlarged shadow.
- Strong glow, fog, exposure, and many lights can soften the cartoon appearance. Tune lighting in the preview first, then check the same material in the gameplay environment.

Reference: [Godot spatial shader reference](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html).
