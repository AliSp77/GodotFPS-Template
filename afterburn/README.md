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
Road obstacles can be dodged, jumped, slid under, or shot apart. Impacts deal
damage and clear the obstacle so the runner keeps moving.

Spaceships use the supplied ship meshes. Four enemy classes pace the runner
and fire visible, telegraphed projectiles. Cover blocks those projectiles.
Six escalating encounters offer a choice of upgrades. The final gunship has
three phases. Kills bank credits; distance also earns score. Player damage adds
a brief screen shake that decays without changing mouse aim.
Repairs, armor, and ammunition can be collected along the road.

Credits and five permanent upgrade ranks are saved to
user://afterburn_profile_v1.json. Death keeps banked credits. Winning unlocks
the next threat tier.

## Editing
- district.tscn: editable route section with supplied prop meshes and collision
- game.gd: route streaming, encounters, pickups, progression, and map builder
- player.gd: extends the original player/player.gd controller
- ship.gd / bolt.gd: ship behavior and projectile collision
- obstacle.gd: destructible runner obstacles
- hud.gd / input.gd: menus, interface, and input routing

## Validation
Run: godot --headless --path . res://afterburn/tests/integration.tscn

The isolated suite covers 35 gameplay checks and does not write profile data.
boss_preview.tscn and reward_preview.tscn are isolated visual fixtures.