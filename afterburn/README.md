# Low Gamma — Afterburn

An endless first person runner built around the existing FPS player scene.
Press F5 in Godot to play. The entry scene is afterburn/afterburn.tscn.

## Controls
- Automatic running at 16 m/s, with running head bob and footstep cadence
- A / D: strafe
- Space: jump
- S / Ctrl: slide (shrinks the collision capsule)
- Shift / Q: dash
- Mouse: aim; right mouse: sights; left mouse: fire
- R: reload; mouse wheel: switch weapons
- Escape: pause

## Run
The route streams 100 meter district sections and keeps four loaded.
Cargo, crates, barrels, wrecks, and barriers use the supplied props collection.
Only mint breakable barriers can be destroyed, by shots or player collisions.
Solid props and overhead beams stay intact. Pink lasers include low jump hazards,
high slide hazards, and full-height fences with lane gaps. Laser contact hurts
without removing the field. Ranged player weapons launch travelling rounds;
damage occurs on impact, and solid cover blocks those rounds.

Spaceships use the supplied ship meshes. Four ranged enemy classes pace the runner
and fire visible, telegraphed projectiles. A fifth class, the Charger, marks a
fixed red path from 60 meters away, waits 1.6 seconds, then rushes at 125 m/s
for 80 base damage. Shoot it at any time or strafe clear; armor applies normally. Cover blocks those projectiles.
Six escalating encounters offer a choice of upgrades. The final gunship has
three phases. Kills bank credits; distance also earns score. Player damage adds
a brief screen shake that decays without changing mouse aim.
Repairs, armor, and ammunition can be collected along the road.
Regular enemies spawn 14–26 meters ahead and stay 12–30 meters ahead. Their
hulls and hitboxes remain inside a 16 meter invisible flight corridor.

Credits and five permanent upgrade ranks are saved to
user://afterburn_profile_v1.json. Death keeps banked credits. Winning unlocks
the next threat tier.

## Editing
- district.tscn: editable route section with supplied prop meshes and collision
- game.gd: route streaming, encounters, pickups, progression, and map builder
- player.tscn: saved Player instance; movement and starting stats in the Inspector
- Player > WeaponsManager > Starting Weapon: choose the held weapon (default AssualtRifle)
- weapons_manager.gd: editor weapon preview and starting selection
- player.gd: extends the original player/player.gd controller; resets the same player between runs
- ship.gd / bolt.gd: ship behavior and projectile collision
- enemy_corridor.tscn: invisible 16 meter bounds and editable spawn markers
- enemy_corridor.gd: width containment and near/far combat distances
- enemies/charger.tscn: editable charge ship, collider, labels, engines, and red path
- enemies/charger.gd: Inspector warning duration, spawn distance, speed, and ram damage
- obstacle.gd: solid impacts, laser overlaps, and breakable-only destruction
- obstacles/*.tscn: saved barrier and laser prefabs plus four editable route patterns
- projectiles/player_round.tscn / .gd: saved round visuals and physical travel
- hud.gd / input.gd: menus, interface, and input routing

## Validation
Run: godot --headless --path . res://afterburn/tests/integration.tscn

The isolated suite covers 83 gameplay checks and does not write profile data.
boss_preview.tscn, reward_preview.tscn, and charger_preview.tscn are isolated fixtures.
Open charger_preview.tscn and press F6 to test one immediate charge without
changing profile data. The main run introduces a Charger as its second enemy.
In afterburn.tscn, expand Player in the Local tree and press F in the 3D viewport
to focus its spawn at (0, 0.1, 24). The FPS asset has arms and weapons, not a full
third person body mesh. Open afterburn/player.tscn to edit its reusable defaults.
