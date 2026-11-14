# Afterburn Game Design and Editing Guide

Implementation reference and practical maintenance manual

Updated 14 November 2026

This guide explains the playable Afterburn implementation, every added system, and the files you need to change to maintain it yourself. It reflects the current code, including automatic running at 16 meters per second, damage screen shake, travelling player rounds, indestructible cover, breakable panels, and laser hazards. Values below describe the stock player before permanent or temporary upgrades.

The Godot project is `D:/Soltanpoor/PersonalFiles/GODOT/GodotFPS-Template`. Open its `project.godot`. The similarly named `NeonRun/NeonRush` project is a separate project and does not contain this implementation.

All paths beginning with `res://` are relative to the Godot project root. Use the FileSystem dock to open them. Function names are included as stable search targets because line numbers change as you edit.

## 1 Start here

Press **F5** to run the project. The configured main scene is `res://afterburn/afterburn.tscn`. Start a run from the title screen. The character runs forward automatically; W has no movement or boost function in Afterburn.

The project configuration declares Godot 4.8 with the Forward Plus renderer. All added gameplay scripts are GDScript. Keep a known working engine version when making a backup, since this project was developed with a beta build and engine upgrades can change imports or rendering behavior.

The most useful starting files are `afterburn/player.gd` for movement and damage feedback, `afterburn/game.gd` for game rules and spawning, `afterburn/district.tscn` for the saved road section, and `afterburn/hud.gd` for every menu and HUD element.

Before a substantial edit, save a version of the working project. Change one system, run the isolated test scene, then play the real main scene. Start a new run when checking an edit to player defaults: the run resets the saved player instance and applies permanent ranks again. Stop and rerun the scene after changing Inspector defaults so the initial values are captured again.

### Common edits at a glance

| What you want to change | File or scene | Search for |
| --- | --- | --- |
| Automatic running speed | `afterburn/player.tscn` > Player Inspector | Run Speed |
| Strafing speed or horizontal limits | `afterburn/player.gd` | `strafe_speed`, `clampf(position.x` |
| Jump, slide, or dash | `afterburn/player.gd` | `_ready`, `_physics_process` |
| Running camera bob or footstep cadence | `afterburn/player.gd` | `RUN_STEP_INTERVAL`, `run_phase` |
| Damage screen shake | `afterburn/player.gd` | `HIT_SHAKE_DURATION`, `_update_hit_shake` |
| Starting health and armor | `afterburn/player.tscn` > Player Inspector | Starting Health, Starting Armor |
| Starting weapon | Player > WeaponsManager Inspector | Starting Weapon (node path) |
| Road appearance and permanent prop placement | `afterburn/district.tscn` | Edit the saved scene |
| Road obstacle placement and laser hazards | `afterburn/obstacles/route_pattern_0.tscn` through `route_pattern_3.tscn` | Saved obstacle instances in the 3D editor |
| Breakable health and impact damage | Obstacle prefab root Inspector | Kind, Hp, Contact Damage |
| Player round speed and visuals | Player weapon Inspector; `afterburn/projectiles/player_round.tscn` | Projectile Speed, Projectile Scene; saved Round and Trail meshes |
| Encounter sizes and enemy availability | `afterburn/game.gd` | `QUOTAS`, `_spawn_enemy` |
| Ship meshes, movement, attack timing, and boss phases | `afterburn/ship.gd` | `_ready`, `_physics_process`, `_fire` |
| Weapon damage, ammo, animations, and reloads | `weapons/*.tscn`, `common/weapon/weapon.gd` | Root weapon properties; check runtime overrides too |
| Rewards and permanent upgrades | `afterburn/game.gd` | `MODS`, `choose_upgrade`, `start_run` |
| Save file and profile format | `afterburn/game.gd` | `SAVE_PATH`, `_load_profile`, `_save_profile` |
| UI text, colors, layout, or controls legend | `afterburn/hud.gd` | `_ready`, `menu`, `workshop`, `rewards` |

## 2 Game design and current scope

Afterburn is a first person roguelite runner through a repeated industrial freight district. The player balances continuous movement, dodging road obstacles, collecting supplies, and shooting spaceships that keep pace with the runner. Distance and kills earn score. Ship kills bank credits that survive death. Between encounters, the player chooses one temporary upgrade.

The **road streams indefinitely**, but the current combat run has **six encounters followed by one boss**. Killing the boss ends that run in victory and raises the next run's threat tier. It is not currently an infinite sequence of combat waves after the boss. There is no fixed time or distance that clears an encounter: its quota must spawn, and all living ships must be destroyed.

The HTML reference supplied the runner and roguelite direction. The implemented Godot game uses the existing FPS player, weapons, supplied props, and spaceship meshes. It has no W boost, fuel meter, weapon heat system, touch controls, or HTML save import and export interface.

### Player loop

1. Start a run with the assault rifle, full magazines and reserves, and purchased permanent bonuses.
2. Run continuously along negative Z. Strafe, jump, slide, or dash while aiming and shooting.
3. Destroy ships, collect supplies, and keep the kill multiplier active.
4. Clear an encounter and choose one of three paused upgrade cards.
5. Repeat through six encounters, then fight the three phase Civic Enforcer.
6. Keep earned credits after death or victory, purchase permanent ranks, and start another run.

## 3 Controls and input routing

| Input | Current behavior | Action or handler |
| --- | --- | --- |
| No movement key | Run forward automatically | Player physics process |
| A and D | Continuous left and right strafing | `left`, `right` |
| Space | Jump while grounded | `jump` |
| S or Ctrl | Hold to slide while grounded | `backward`, `crouch` |
| Shift or Q | Dash when ready | `sprint`, `afterburn_dash` |
| Mouse movement | Aim the camera | Player unhandled input |
| Right mouse button | Hold sights | `aim_mode` |
| Left mouse button | Fire; hold for automatic weapons | `fire` |
| R | Reload a ranged weapon | `reload` |
| Mouse wheel | Previous or next weapon | `weapon_change_prev`, `weapon_change_next` |
| Escape | Pause or resume | HUD input handler using `exit` |
| Enter | Start from the initial menu or result state | HUD key handler |
| 1, 2, or 3 | Select a reward card | HUD key handler |

Change ordinary bindings under **Project Settings > Input Map**. The action named `sprint` now triggers Shift dash; it does not control running speed. The old `forward` action can remain mapped to W for compatibility with other template scenes, but the Afterburn controller does not read it.

`afterburn/input.gd` sends aim, fire, reload, and weapon switching through `Global` signals only during `play`. The player reads movement actions directly. The HUD reads Escape and reward shortcuts and keeps processing while the scene tree is paused. The inherited weapons manager handles held automatic fire.

## 4 Files and scene architecture

| File | Responsibility |
| --- | --- |
| `afterburn/afterburn.tscn` | Entry scene; saved FreightDistrict, Player, and EnemyFlightCorridor instances |
| `afterburn/enemy_corridor.gd` and `.tscn` | Invisible flight width, close spawn markers, and forward combat distance limits |
| `afterburn/player.tscn` | Saved inherited FPS player with runner script, movement defaults, weapon overrides, and editable children |
| `afterburn/weapons_manager.gd` | Inspector starting weapon, editor weapon preview, and runtime selection; extends the original manager |
| `afterburn/game.gd` | Run lifecycle, enemy director, route streaming, obstacles, pickups, upgrades, score, saves, and optional map builder |
| `afterburn/district.tscn` | Saved, editable 100 meter route section |
| `afterburn/player.gd` | Runner controller extending the original player; health, armor, dash, slide, run bob, footsteps, and hit shake |
| `afterburn/ship.gd` | Four ranged ship classes and the boss; shared damage, rewards, and labels |
| `afterburn/enemies/charger.gd` and `.tscn` | Saved charge ship, red warning path, fixed-line rush, and swept contact damage |
| `afterburn/bolt.gd` | Visible enemy bolt, swept collision, damage, impact effect, and lifetime |
| `afterburn/obstacle.gd` | Solid impacts, laser overlaps, and breakable-only destruction |
| `afterburn/obstacles/*.tscn` | Six saved obstacle prefabs and four saved route patterns |
| `afterburn/projectiles/player_round.gd` and `.tscn` | Travelling player rounds, swept collision, lifetime by range, and saved visual meshes |
| `afterburn/hud.gd` | Runtime HUD, title, workshop, rewards, pause, results, notifications, and shortcuts |
| `afterburn/input.gd` | Game state aware routing to the template weapon signals |
| `afterburn/README.md` | Short controls and launch reference |
| `afterburn/tests/integration.gd` and `.tscn` | Isolated gameplay regression suite |
| `afterburn/tests/preview.gd` | Base for isolated visual fixtures; disables profile loading and writing |
| `afterburn/tests/boss_preview.tscn` | Starts directly in a boss fight |
| `afterburn/tests/reward_preview.tscn` | Starts directly at the upgrade screen |

### What is reused from the FPS template

`res://afterburn/player.tscn` inherits `res://player/player.tscn`, which supplies the collision capsule, camera hierarchy, arms and weapons, dedicated weapon viewport, and audio manager. The runner script is attached in the saved scene. `afterburn/game.gd::_create_player()` binds the existing Player child; it only instantiates the same saved prefab when an isolated fixture has no Player. No runtime script replacement is needed. The runner extends `res://player/player.gd`, preserving mouse look, inherited references, aiming state, and `Global.player` registration.

In `afterburn.tscn`, expand **Player** in the Local scene tree. Select Player and press **F** in the 3D viewport to focus its spawn at `(0, 0.1, 24)`. The original FPS asset has arms and weapons, rather than a complete third person body mesh; the capsule and camera gizmos show the player body position. Open `afterburn/player.tscn` to edit reusable defaults. Its root exposes **Run Speed**, **Strafe Speed**, **Jump Velocity**, **Sensitivity**, **Starting Health**, and **Starting Armor**. The original Walk Speed and Sprint Speed fields are inherited but automatic movement uses Run Speed.

### Runtime structure

```text
Afterburn                         game.gd
  CourseLighting                  extracted world environment and directional lights
  Route sections                  current section plus three neighbors
    Saved district meshes         district.tscn
    RunnerHazards                 saved route_pattern_N.tscn
      Barriers and lasers         saved prefab instances using obstacle.gd
    Route pickups                 created by game.gd
  Player                          saved afterburn/player.tscn instance
    CollisionShape3D
    CameraPivot                   inherited mouse yaw and active_camera.gd
      CameraHolder                mouse pitch, running bob, gun recoil
        MainCamera                independent damage shake
    WeaponsManager                starting weapon Inspector + inherited switching/firing
      Knife, Pistol, AssualtRifle, AssualtBurstRifle, LMG
    WeaponSubViewport             separate weapon rendering camera
    AudioManager                  inherited surface and footstep audio
  Input router                    input.gd
  HUD                             hud.gd
  Ships, bolts, and effects        added as the run proceeds
```

Player and FreightDistrict are saved children of the main scene. Player has editable children enabled; expand WeaponsManager to see the five existing weapon nodes. The selected starting weapon is previewed in the editor by the Afterburn manager tool script. Obstacle rows are saved in four editable route pattern scenes, with pattern 0 instanced in district.tscn for editor inspection. Ships, additional streamed sections, pickups, and HUD controls are created at runtime. Inspect those in the **Remote** tree; Remote edits are temporary.

## 5 Run lifecycle and pause behavior

| State | Simulation | How it is entered or left |
| --- | --- | --- |
| `boot` | Initialization | `_ready()` builds references, route, player, input, and HUD |
| `menu` | Tree paused; mouse visible | Initial title screen; Start calls `start_run()` |
| `play` | Simulation active; mouse captured | Running, combat, pickups, route streaming, and score |
| `reward` | Tree paused; mouse visible | Cleared encounter; selecting a card calls `choose_upgrade()` |
| `pause` | Tree paused; mouse visible | Escape; Resume calls `resume_run()` |
| `result` | Tree paused; mouse visible | Death, abandoning from pause, or boss victory |

The workshop is a HUD overlay, not a separate state string. Likewise, drawing the title menu from the result screen does not itself change `game.state`. When adding a new screen, handle the state, pause flag, mouse capture, and overlay visibility together rather than only drawing a panel.

`start_run()` clears combat objects and the old route, creates fresh sections, resets the existing player to its authored transform, cancels weapon timers and animation state, restores the saved weapon grip, resets temporary stats, increments the started run counter, applies permanent ranks, refills ammunition, and resumes play. `finish_run()` records the best score, applies a victory tier increase if appropriate, saves the profile, pauses the tree, and shows results.

The HUD has `PROCESS_MODE_ALWAYS`. Keep this when changing its node structure, or its paused menu buttons and input may stop working.

## 6 Automatic running and movement tuning

The runner moves through the world along negative Z. The world is not moved backward around a stationary character. Aiming rotates the view while the route direction remains fixed. Strafing is in world X and is not relative to the camera's yaw.

| Setting | Stock value | Location and effect |
| --- | --- | --- |
| Forward run | 16 m/s | Player Inspector > Run Speed; multiplied by `mobility` |
| Strafe target speed | 9 m/s | `strafe_speed`; multiplied by `mobility` |
| Strafe smoothing | 15 | Physics interpolation factor before clamping |
| Horizontal center limits | -9 to +9 m | Final X clamp after movement |
| Jump velocity | 7.5 m/s upward | Player Inspector > Jump Velocity, saved in `afterburn/player.tscn` |
| Gravity | -20 m/s squared | Inherited `GRAVITY` constant in `player/player.gd` |
| Standing capsule | 1.85 m high, 0.2 m radius | Original scene; height reapplied by runner physics |
| Sliding capsule | 0.9 m high | Grounded S or Ctrl; collider center is half its height |
| Standing eye height | 1.7 m | Camera pivot target height |
| Sliding eye height | 0.85 m | Camera pivot target height |
| Mouse sensitivity | 0.0025 | Player Inspector > Sensitivity, saved in `afterburn/player.tscn` |
| Yaw limit | -1.25 to +1.25 radians | About 72 degrees either side of forward |
| Pitch limit | -60 to +60 degrees | Inherited mouse look |

Normal forward speed is `run_speed * mobility`. Holding W, releasing W, or aiming does not change it. The runner emits the inherited sprint signal on creation to select the wider running FOV, but this signal no longer chooses movement speed.

At stock gravity and jump velocity, the ideal jump rises about 1.41 meters and returns to its starting height after about 0.75 seconds. At 16 m/s this covers roughly 12 meters, before accounting for geometry or dash. Use these relationships when adjusting obstacle heights and spacing.

Sliding lasts while S or Ctrl is held and the character is on the floor. There is no separate slide duration or cost. Releasing under a low obstacle does not perform an explicit head clearance check; standing can collide with it. The collision capsule is duplicated for each player so changing its height does not alter the imported scene's shared shape resource.

### Dash

Dash lasts 0.2 seconds, has a 3 second cooldown, and grants 0.24 seconds of invulnerability. With no strafe input, it travels forward at 30 m/s. With strafing, `Vector3(strafe * 1.4, 0, -1).normalized()` chooses the direction; X uses a 25 m/s scale and Z uses a 30 m/s scale.

Dash values are fixed rather than multiplied by Mobility. At very high stacked Mobility, normal running can exceed the dash's forward speed. If you want dash to remain faster at every upgrade level, scale its velocities with Mobility or derive them from `run_speed`. Update the HUD's hardcoded 3 second dash meter if you change the cooldown.

## 7 Camera movement and damage feedback

Three different systems contribute to camera feedback. They use different transforms, so tune them in the correct file.

| Effect | Implementation | Main tuning values |
| --- | --- | --- |
| Running bob | `afterburn/player.gd` changes `CameraHolder.position` | X amplitude 0.035 m; Y amplitude 0.055 m; phase uses `RUN_STEP_INTERVAL` |
| Weapon firing shake | Inherited `common/utils/active_camera.gd` changes holder rotation through a tween | `shake_intensity` 0.02 radians; `shake_duration` 0.1 s |
| Damage shake | `afterburn/player.gd` changes `MainCamera.position` and local roll | `HIT_SHAKE_DURATION` 0.34 s; strength and decay below |
| Damage tint and hit marker | `afterburn/hud.gd` | Damage alpha 0.23, fading at 0.7 per second; hit marker 0.12 s |

Damage shake starts only after a hit is accepted by `get_damage()`. Its strength is the greater of the current strength and `clamp(applied_damage * 0.003, 0.045, 0.11)`. The remaining time resets to 0.34 seconds. A squared decay envelope reduces translation and roll to their cached resting values. The player's yaw and pitch holder rotations are not changed by this damage shake.

To shorten the effect, reduce `HIT_SHAKE_DURATION`. To soften it, reduce the strength multiplier and both clamp bounds. To disable only damage shake, assign `hit_shake_strength = 0.0` where damage sets its strength. Removing the red HUD tint requires changing `damage_flash()` separately. Weapon recoil is controlled separately by the inherited camera script.

Normal running targets an 85 degree FOV. Sights take priority and use the weapon's `focused_aim_fov`; the inherited base fallback is 75 degrees. Change FOV constants in `common/utils/active_camera.gd` and weapon aim FOVs in the weapon scenes. This shared camera script also affects other template scenes.

## 8 Health armor and invulnerability

The stock player starts with 100 health and 50 armor. `start_run()` replaces those values using permanent Hull and Armor ranks. The runner's maximum is `vital_capacity`; changing the inherited `MAX_HEALTH` constant alone does not tune the new system.

An accepted hit follows these steps:

```text
applied damage = incoming damage * damage_resistance
armor absorption = min(current armor, applied damage * 0.7)
new armor = current armor - armor absorption
new health = max(0, current health - (applied damage - armor absorption))
```

For example, 20 damage against an unmodified player with enough armor removes 14 armor and 6 health. With no armor, all 20 reaches health. Accepted damage grants 0.15 seconds of invulnerability, emits the inherited health signal, flashes the HUD, and starts hit shake. Exactly zero health ends the run.

Dash grants 0.24 seconds of protection. Obstacle impact raises the remaining protection to at least 0.7 seconds. Selecting a field upgrade grants 2 seconds before the next encounter. Hits during invulnerability are ignored before armor, health, tint, and shake are updated.

Falling below Y = -10 moves the player back to Y = 1 and attempts to deal 25 damage. This recovery does not rebuild or rewind the route.

## 9 Endless route streaming

Each saved district section is 100 meters long. Section index `i` is placed at Z = `-i * 100`. At startup and after restarting, sections -1, 0, 1, and 2 are loaded.

The current section is calculated as `floor((43 - player.position.z) / 100)`. The streamer keeps the previous section, the current section, and two sections ahead. Missing sections are instantiated; out of range sections are queued for deletion. The offset 43 comes from the saved section's bounds: its ground runs from local Z = -57 to +43.

Only four section instances are tracked. This is not an object pool: sections are freed and recreated. The world's coordinates keep increasing in magnitude; there is no floating origin reset. Very long uninterrupted sessions may eventually encounter floating point precision limits.

### Geometry rules for a seamless section

The saved foundation is 72 meters wide and 100 meters long, centered at Z = -7. The visible central road is 18 meters wide. Keep a collidable surface continuous across both ends. Avoid closing the ends with walls. Most playable action happens inside X = -9 to +9.

Changing section length requires coordinated edits to placement in `_spawn_chunk()`, section calculation and retention in `_stream_course()`, the saved floor and apron geometry, and the obstacle and pickup positions in `_prepare_chunk()`. Changing only the floor size creates gaps or overlaps.

World environment and directional lights are moved out of the initial section into `CourseLighting`. Fresh sections have those root children removed to avoid multiplying the lighting. Local point lights remain in every section. Keep those global environment and directional light nodes as direct children if you want this extraction logic to recognize them.

## 10 Editing the saved map and supplied props

Open **`res://afterburn/district.tscn` directly** to change the road's permanent geometry, cargo placement, wrecks, signs, lights, and skyline. Save the scene and restart the run. Every newly instantiated section uses that saved template.

`game.gd::build_map()` was used to create the saved section. Editing that function does not automatically overwrite `district.tscn`. Treat the saved scene as the live map source unless you deliberately rebuild it using the recipe later in this guide. A rebuild replaces manual scene edits. The main scene also has an external reference to the district, and `_init_course()` loads it directly, so deleting the scene is not a reliable way to trigger regeneration.

The prop source is `res://resources/props/fps_demo_props.glb`. It contains named meshes including cargo, crate, barrel, block, and wreck. Saved barrier prefabs reuse the supplied crate and concrete block meshes. The optional map builder also looks up those names; update it if the asset names change.

Saved prop meshes created by `_prop()` belong to the persistent `supplied_props` group. For direct child meshes in that group with `abs(local X) < 10`, `_prepare_chunk()` attaches the obstacle script to direct StaticBody3D children and sets their destruction root to the mesh. These inner road props are solid impact obstacles. They survive both shots and player collisions; only the dedicated breakable barrier prefab can be destroyed. Decorative outer props remain ordinary cover.

To add a matching road prop manually, use a mesh with a direct StaticBody3D child and CollisionShape3D, add the mesh to `supplied_props`, and put it inside the inner road. Keep the floor outside that group. Props are generally fitted with simple box collision based on mesh bounds, not exact mesh collision. These boxes can block shots through visually empty parts of a wreck.

The current barrels are props or generic obstacles. They do not use the template's separate exploding barrel scene.

## 11 Obstacle patterns and destruction

Open **afterburn/obstacles/route_pattern_0.tscn** through **route_pattern_3.tscn** to edit obstacle placement in the 3D editor. The district contains a saved RunnerHazards instance of pattern 0. Streaming selects `posmod(section_index, 4)`; it retains pattern 0 where appropriate and loads the other saved patterns for other sections. Editing a pattern changes every future section that uses it.

The three rows are at local Z = 8, -18, and -44, with lane centers at X = -6, 0, and +6. The first row leaves one lane clear. The second row requires jumping or sliding. The third row has laser fences with a clear neighboring lane, or a high sweep that can be slid under. Rows are 26 meters apart, about 1.63 seconds at stock speed. Low and high lasers span the 18 meter road. Full-height fences occupy 5.4 meters of a single lane, leaving the open lane accessible.

| Saved prefab | Behavior | How to pass |
| --- | --- | --- |
| solid_barrier.tscn | Indestructible concrete prop; blocks movement and rounds | Strafe into the open lane |
| breakable_barrier.tscn | Mint strips; 130 HP; the only destructible obstacle type | Shoot it or collide with it; two stock rifle shots break it |
| low_beam.tscn | Indestructible supplied block mesh raised to Y = 1.25 by the pattern | Slide under it |
| low_laser.tscn | Pink Area3D hazard from Y = 0.12 to 0.45 | Jump; sliding does not avoid it |
| high_laser.tscn | Pink Area3D hazard from Y = 1.15 to 1.70 | Slide |
| laser_fence.tscn | Pink grid from Y = 0.05 to 3.40 | Strafe into the gap; a normal jump does not clear it |

Static barriers use player movement collisions. Laser fields use actual Area3D overlap with the player's capsule; they deal damage without blocking movement or bullets. Lasers and beams remain intact after contact and shots. Existing inner road props remain solid as well.

The root Inspector exposes **Kind**, **Hp**, and **Contact Damage**. Kind must be **breakable barrier** for either shots or contact to destroy it. Body impacts attempt 20 damage; laser overlaps attempt 25. Accepted impacts reset combo and grant at least 0.7 seconds of contact protection. A protected dash can still break the breakable panel. Enemy shots cannot destroy panels. Destroying a panel with player damage awards 35 score; ramming it awards no score. The knife retains its short melee hit and can damage a breakable panel.

`get_damage()` ignores damage to all other obstacle kinds. `_break()` also verifies the kind before freeing its destruction root. Avoid giving arbitrary scenery the breakable kind. Edit a prefab to change all its instances, or enable Editable Children on an instance for a local visual or collision override.

Warnings appear when a beam or laser is within 15 meters ahead. Increasing speed should be followed by a reaction time playtest. When editing patterns, preserve an open route: gaps for full-height fences, jumping clearance for low lasers, and sliding clearance for high lasers and beams.

## 12 FPS weapons and ammunition

The player uses the existing `common/weapon/weapon.gd` and `common/managers/weapons_manager.gd`. Weapons are children of the original player scene. Their array order is **Knife, Pistol, AssualtRifle, AssualtBurstRifle, LMG**. Existing files and node names spell assault as `assualt`; preserve these identifiers unless you update all references.

Select **Player > WeaponsManager** and set **Starting Weapon** to an existing weapon child, for example `AssualtRifle` (default) or `Pistol`. Use the Inspector node picker. `afterburn/weapons_manager.gd` previews that existing weapon in the editor and equips it on each new run. The path must identify a member of Weapons Array. An invalid path warns and falls back to the first entry.

### Saved weapon overrides

The Afterburn player scene saves every ranged weapon's **Is Projectile** as enabled, **Projectile Scene** as afterburn/projectiles/player_round.tscn, **Firing Distance** as **150 meters**, and **Burst Mode** as enabled except for Pistol. Change these fields on the weapon child in `afterburn/player.tscn`; startup respects them. These are inherited scene overrides, so changing the original weapon scene may be masked by the saved Afterburn override. The field `burst_mode` means held repeated firing; the named burst rifle is not a distinct three shot burst implementation.

| Weapon | Base damage | Shot cooldown | Magazine | Reload time |
| --- | --- | --- | --- | --- |
| Knife | 100 | 1.0 s | Melee, no ammo consumption | Not used |
| Pistol | 100 | 0.25 s | 12 | 1.5 s |
| AssualtRifle | 65 | 0.1 s | 40 | 1.5 s |
| AssualtBurstRifle | 100 | 0.1 s | 40 | 1.5 s |
| LMG | 60 | 0.1 s | 250 | 4.0 s |

These are inherited script defaults plus scene overrides, before upgrades. Edit a weapon scene's root properties for damage, cooldown, magazine, reload, animation names, spread, sound, and aim FOV. Edit weapon child Inspector overrides in `afterburn/player.tscn` for range and automatic fire policy. Melee keeps its scene's one meter range.

### Shot and reload flow

Input emits Global.fire_input. The manager calls the active weapon's try_fire(). An accepted shot consumes magazine ammo and plays the existing animation, sound, muzzle effect, cooldown, and recoil. Ranged Afterburn weapons call `_launch_projectile()` rather than applying immediate damage. A camera query finds the aim point for muzzle convergence; a short camera-to-muzzle query prevents firing through nearby cover. Neither query damages anything.

The round is parented to the game, so it moves independently of the running player and weapon viewport. Its next physics step sweeps only that frame's travel segment. On impact it calls get_damage() once, creates a spark, and frees itself. Solid world geometry stops rounds even if it has no damage method. Laser Areas do not stop rounds. The round disappears after travelling Firing Distance. The knife remains a short-range melee query.

| Weapon | Projectile Speed |
| --- | --- |
| Pistol | 80 m/s |
| AssualtRifle | 90 m/s |
| AssualtBurstRifle | 110 m/s |
| LMG | 85 m/s |

Change Projectile Speed on a weapon child in afterburn/player.tscn. Edit player_round.tscn for its mint Round and Trail meshes and materials. The generic weapon script keeps its hitscan path available to other template scenes whose Is Projectile is false. Keep Is Projectile enabled and Projectile Scene assigned on Afterburn ranged weapons. Damage and upgrades are copied into each round when fired; moving targets can dodge rounds already in flight.

Ammo reserves live in `common/autoloads/bullets.gd`. Reloading transfers reserves to the magazine; reserves are not reduced for each shot fired from a magazine. Starting a run or selecting any field upgrade fills every magazine and every finite reserve to its maximum. A pickup adds 80 to each finite reserve without filling magazines. The knife uses infinite ammo.

Both rifle nodes use the same assault reserve. Its maximum is 480, pistol reserve maximum is 120, and LMG reserve maximum is 400. Change reserve limits in `Bullets.ammo_inventory`, not just the weapon's magazine property.

## 13 Spaceship enemy classes

Enemy availability and threat-tier scaling are in game.gd::_spawn_enemy(). Four ranged classes and the boss use ship.gd. The Charger uses a saved enemies/charger.tscn prefab and charger.gd, extending shared ship damage and reward handling. Its base health and attack tuning are Inspector properties on that prefab.

| Class | Mesh file | Tier 1 health | Attack | Projectile |
| --- | --- | --- | --- | --- |
| Striker | `ship1.obj` | 145 | One bolt; 0.8 s telegraph | 15 m/s, 14 damage |
| Sniper | `ship3.obj` | 130 | One bolt; 1.1 s telegraph | 21 m/s, 24 damage |
| Guardian | `ship4.obj` | 320 | Three bolt spread; 0.8 s telegraph | 15 m/s, 14 damage each |
| Interceptor | `ship7.obj` | 180 | One bolt; faster, wider side motion | 15 m/s, 14 damage |
| Charger | `ship2.obj` | 195 | 1.6 s red warning, then a straight 125 m/s rush | Contact: 80 base damage |
| Civic Enforcer | `ship5.obj` | 2900 | Two to four bolts according to phase | 15 m/s, 14 damage each |

All mesh paths are under `res://resources/spaceships/`. OBJ files load as Mesh resources. The Charger has a saved Hull MeshInstance3D; the other ship classes assign their visual nodes at runtime. Replacing an OBJ with a GLB PackedScene requires adapting the loader, not only changing a file extension.

Visual width is normalized from mesh bounds: ordinary ships are 2.9 meters, Guardians 4 meters, and the boss 10.5 meters. Spherical hit radii are 1.5, 2.0, and 4.6 meters respectively. Change visual size and hit size together if you want accurate looking hits.

These ships are StaticBody3D nodes moved directly by code. The following hover description applies to the ranged ships and boss. They do not use navigation meshes, rigid body simulation, or collision avoidance. They retain their spawn X anchor and a forward offset from the runner while adding sinusoidal motion. Interceptors use more aggressive lateral motion. The boss has a wider sweep.

### Enemy flight corridor and closer spawn points

The saved main scene includes **Afterburn > EnemyFlightCorridor**. Open **afterburn/enemy_corridor.tscn** to edit its reusable defaults, or expand the instance in the main scene. It contains an invisible Area3D, a Bounds CollisionShape3D, six Marker3D children under SpawnPoints, and a separate BossSpawn marker. No runtime mesh is needed to display this volume; select Bounds to inspect the box gizmo in the editor.

The default Bounds box is 16 meters wide, slightly narrower than the 18 meter road. Its horizontal limits are X = -8 to +8. The movement rule reserves space for each ship's current rotated hull, its spherical hitbox, and a 0.15 meter edge margin. Banking and turning therefore cannot move the hull or hitbox through the side limits. Regular ships and the boss use this constraint after every movement update. The Charger is constrained before its red path is locked, then keeps that fixed X throughout the charge.

| Setting or node | Default | Edit |
| --- | --- | --- |
| Bounds > Shape > Size X | 16 m | Width of the invisible enemy corridor |
| SpawnPoints | Six saved markers | Position regular enemy arrivals in the 3D editor |
| BossSpawn | 26 m ahead, Y = 5.5 | Boss arrival marker |
| Near Distance | 12 m | Closest forward center distance for ranged enemies |
| Far Distance | 30 m | Farthest forward center distance for ranged enemies |
| Edge Margin | 0.15 m | Extra horizontal clearance outside the full ship extent |
| Follow Offset | 30 m | Corridor origin follows this far ahead of the player |

Default regular markers spawn enemies 14 to 26 meters ahead, at X = -4 to +4 and Y = 3 to 5. These replace the old off-road spawn positions and extra forward offset. Regular enemy movement stays 12 to 30 meters ahead, including after dashes or large advances, so ships cannot be left behind the camera.

Marker positions are local to the moving corridor. With Follow Offset = 30, local marker Z = 14 gives a 16 meter forward distance. Increasing marker Z brings that spawn closer. Corridor Y = 4 plus local marker Y gives the world altitude. Keep marker distances inside Near/Far Distance and keep the corridor unrotated for the current straight negative-Z road. The box's Y/Z dimensions provide editor context; horizontal Bounds width and the separate Near/Far settings enforce combat limits.

The Area has collision layer 0, collision mask 0, and monitoring disabled. It does not block the player, projectiles, or ships through physics collisions; enemy movement explicitly applies its limits. Charger rushes may pass the player as part of their attack.

### Charger: red-path rush

Open **res://afterburn/enemies/charger.tscn** to inspect and edit the ship. Its Local scene tree contains Hull, CollisionShape3D, WarningBeacon, EngineLeft, EngineRight, HealthLabel, AttackStatus, and WarningPath with its DangerStrip and two red edges. These nodes are saved in the prefab. The source mesh is the supplied ship2.obj, centered and scaled to 3.2 meters wide. Its spherical hit radius is 1.4 meters.

| Root Inspector property | Default | Purpose |
| --- | --- | --- |
| Max Hp | 195 | Three stock rifle hits at tier 1; the normal tier health multiplier still applies |
| Spawn Distance | 60 m | Closer warning arrival, inside the 150 m weapon range and 170 m camera far plane |
| Warning Duration | 1.6 s | Stationary, visible warning before acceleration into the rush |
| Charge Speed | 125 m/s | World speed toward positive Z, against the runner's negative-Z travel |
| Ram Damage | 80 | Raw tier-1 impact damage before ordinary armor, resistance, and invulnerability |
| Pass Distance | 24 m | Frees the ship once it has passed this far behind the current player |

The spawn picks the nearest lane center at X = -6, 0, or +6. It locks that X immediately. The red ground strip and edges mark a fixed world-space flight path; strafing does not retarget it. Warning width includes the ship radius plus the player's capsule radius. WarningPath is a top-level Node3D, so its position stays fixed while its parent ship rushes forward.

The collider remains on enemy layer 2 throughout the warning and charge. There is no shield or invulnerability phase: travelling player rounds can damage and destroy it even at the initial 60 m distance. Cover still blocks player rounds. Destroying the Charger immediately hides its red warning, cancels the rush, and awards the normal ship reward.

The ship sweeps a sphere against the player's capsule using relative movement over the whole physics frame. A fast rush therefore cannot skip a player between ticks. It attempts damage at most once. Armor, resistance, dash invulnerability, and hit screen shake use the normal player damage path. At tier 1, 80 raw damage leaves a full-health unarmored player at 20 health. With 50 armor, it removes that armor and 30 health.

Strafing out of the red path lets the Charger pass. Passing removes the ship and warning without granting a kill or credits. It does not block encounter completion. The charge is not a projectile and ordinary road cover does not stop its flight path; the marked line remains the dodge cue.

The director introduces a Charger as the second spawn in the first encounter and includes it in later random selections. Automatic spawning allows only one active Charger at a time. Explicit debug spawns can bypass that limit.

For an isolated test, open **afterburn/tests/charger_preview.tscn** and press F6. It starts a run with one immediate Charger and no scheduled follow-up enemies; the fixture disables profile reads and writes. Its normal warning lasts 1.6 seconds, so prepare to strafe or shoot as the scene starts.

## 14 Ship attacks and projectile collision

The ranged ship classes begin with a random 2.0 to 3.6 second shot timer. The Charger uses the separate warning-and-rush sequence above. After each ordinary salvo, the timer resets randomly to 2.5 to 4.0 seconds. A telegraph follows the timer, so the total interval between attacks includes both durations.

During a telegraph, the core pulses and the ship records the player's X and target height. When firing, it updates the forward target using the runner's current Z velocity and an approximate travel time. This gives the player a chance to dodge the locked lateral aim while the projectile leads forward motion. It is an approximation, not a full intercept solver.

`game.gd::fire_bolt()` creates a bolt and applies threat tier damage scaling. Each physics frame, `bolt.gd` raycasts from the old position to the next position, avoiding ordinary tunneling from checking only the endpoint. It excludes its shooter, checks physics bit 1, attempts damage on the first hit, spawns a spark, and frees itself. Missed bolts expire after 5 seconds.

Bolt sphere and tail dimensions, tint, emission, and lifetime are in `bolt.gd`. Attack damage and speed are passed from `ship.gd::_fire()`, so changing the bolt script's default damage alone will not rebalance spawned attacks.

## 15 Encounters boss phases and threat tiers

| Displayed encounter | Name | Ship quota | Simultaneous cap | Available classes |
| --- | --- | --- | --- | --- |
| 1 | Freight Arrival | 5 | 4 | Striker, Interceptor, Charger; second spawn is a Charger |
| 2 | Signal Jam | 7 | 4 | Adds Sniper |
| 3 | Container Siege | 8 | 5 | Adds Guardian |
| 4 | Dead Frequency | 9 | 5 | All five ordinary classes |
| 5 | Redline | 10 | 6 | All five ordinary classes |
| 6 | Last Transmission | 12 | 6 | All five ordinary classes |

There are 51 scheduled ordinary ships before the boss. The first run delay is 2 seconds; subsequent encounter delays are 2.3 seconds. Normal spawn spacing is 1.8 seconds, subject to the living ship cap. The internal encounter index starts at zero.

All six encounter clears offer an upgrade, including the sixth clear before the boss. Completion requires the full quota to have spawned and no living enemies to remain.

### Civic Enforcer

The boss starts after encounter index reaches 6. Phase 2 begins below 67 percent health and phase 3 below 33 percent. Each phase change attempts to spawn one Interceptor escort if fewer than five enemies are alive.

| Phase | Bolts per salvo | Shot timer after firing | Telegraph |
| --- | --- | --- | --- |
| 1 | 2 | 2.15 s | 0.8 s |
| 2 | 3 | 1.8 s | 0.8 s |
| 3 | 4 | 1.45 s | 0.8 s |

Killing the boss immediately wins the run; remaining escorts do not need to be cleared. There is no later endless combat cycle in the current director.

Winning increases the profile tier by one, capped at 10. Tier is automatically used on the next run; there is no current tier selection menu. Health is multiplied by `1 + (tier - 1) * 0.18`. Enemy bolt damage and Charger ram damage are multiplied by `1 + (tier - 1) * 0.12`. Health scaling is applied in _spawn_enemy(); damage scaling is applied in fire_bolt() or charger.gd::_sweep_player().

Changing the number of encounters requires more than editing `QUOTAS`. Update `ENCOUNTERS`, comparisons against 6 in the director and HUD, the six HUD segments, the name clamp to 0 through 5, progress text, and tests. A later refactor could derive these limits from the quota array length.

## 16 Temporary field upgrades

On an encounter clear, `MODS` is copied, shuffled, and reduced to three choices. The player installs one. All effects last only until a new run and can be chosen repeatedly across encounters.

| Upgrade ID | Display name | Implemented effect |
| --- | --- | --- |
| `damage` | Hot Chamber | Every weapon's damage multiplied by 1.25 |
| `armor` | Reactive Shell | Adds 40 armor, capped at 150; damage resistance multiplied by 0.9 |
| `health` | Second Heart | Adds 25 maximum health and fully repairs health |
| `speed` | Ghost Drive | Mobility multiplied by 1.15, affecting running and strafing |
| `reload` | Quick Feed | Reload time multiplied by 0.75 |
| `rate` | Overclock | Shot cooldown multiplied by 0.82 |

Every selection also repairs 30 health up to maximum, adds 20 armor up to 150, fills magazines and reserves, clears live enemy bolts, and grants 2 seconds of invulnerability. Reactive Shell therefore adds up to 60 armor when combined with this common resupply. Choosing health is already a full repair. These shared effects are below the `match` block in `choose_upgrade()`.

Overclock's code reduces the interval by 18 percent; this corresponds to about 22 percent more shots per second. Repeated multiplier upgrades compound. Three Hot Chambers produce `1.25 * 1.25 * 1.25` times the pre-upgrade damage, rather than adding 75 percentage points.

To add a new field upgrade, add its ID, name, and description to `MODS`, implement that ID in `choose_upgrade()`, ensure any new per-run variable resets when a new player is created or in `start_run()`, and add a gameplay check. Do not change only the card text.

## 17 Pickups score and momentum

### Supplies

| Pickup | Effect |
| --- | --- |
| Repair | Adds 30 health up to `vital_capacity` |
| Armor | Adds 30 armor up to 150 |
| Ammo | Adds 80 to every finite reserve, up to each reserve's limit |

Route supplies are placed 9 meters after each procedural row, at the nominal open lane, cycling among ammo, health, and armor. Low beam rows still use the calculated nominal lane for the following pickup. Supplies rotate and bob, and collect automatically within a 2 meter radius of the player's mid-body target.

Ordinary ship deaths have a 65 percent pickup chance. The drop type cycles using the total kill count. Its X is clamped into the running corridor. Route supplies are children of their section and disappear with it. Ship drops are children of the game root and have no age or distance expiry, so uncollected drops can accumulate during a very long run.

Add a pickup type consistently in the color map, label map, `_collect()` behavior, and whichever drop lists should use it. `add_pickup()` alone only creates its presentation.

### Score and credits

| Event | Score | Banked credits |
| --- | --- | --- |
| One new whole meter traveled | 2 | None |
| Ordinary ship kill | `round(250 * combo)` | 25 before Salvage; Guardian uses 40 |
| Boss kill | `round(5000 * combo)` | 500, not multiplied by Salvage |
| Obstacle destroyed through damage | 35 | None |

Each ship kill first adds 0.25 to combo, up to 5, then uses that updated multiplier for scoring. A kill refreshes a 6 second combo timer. Once the timer expires, combo moves toward 1 at 0.6 per second. Obstacle impact immediately resets it to 1. Distance points are not multiplied by combo.

Ordinary kill credits are `round(base_credit * (1 + Salvage_rank * 0.08))`. They are written immediately to the profile. Score and banked credits are separate currencies: spending workshop credits does not reduce score.

## 18 Permanent upgrades and saves

| Rank array index | Workshop name | Effect per rank | Application |
| --- | --- | --- | --- |
| 0 | Hull | +10 starting maximum health | `start_run()` |
| 1 | Ballistics | +6 percent base weapon damage | `start_run()` |
| 2 | Mobility | +4 percent starting Mobility | `start_run()` |
| 3 | Armor | +10 starting armor | `start_run()` |
| 4 | Salvage | +8 percent ordinary kill credits | `ship_destroyed()` |

Each track has 10 ranks. The next rank costs `100 + current_rank * 90` credits. Buying changes the saved rank; character stat bonuses are reapplied on the next run. The rank array's order is part of the save format. Reordering the workshop labels without migrating ranks gives existing players the wrong bonuses.

The save file is `user://afterburn_profile_v1.json`. On the current Windows project configuration it normally resolves below `%APPDATA%/Godot/app_userdata/fps-demo/`. You can confirm or open Godot's user data folder from the editor instead of guessing its location.

```json
{
  "credits": 0,
  "runs": 0,
  "best": 0,
  "wins": 0,
  "tier": 1,
  "ranks": [0, 0, 0, 0, 0]
}
```

This saves the profile, not a resumable run. Temporary upgrades, current health, active encounter, road position, and live enemies are not restored after quitting. The run counter counts starts. Best score is updated on a normal finish or abandon; a forced process close can keep kill credits without recording the latest best score.

Loading clamps numeric counters, tier 1 through 10, and five ranks 0 through 10. A missing or invalid profile falls back to defaults where the loader handles it. Writes replace the JSON file directly; there is no atomic replacement or built-in backup. If you extend the format, supply defaults for new fields and plan migrations before changing `ranks` or the save filename.

To reset your own test progress, stop the game, back up this specific JSON file, then rename or remove that file. Do not remove the whole `fps-demo` user data folder: other project data and Ziva data can live alongside it. Renaming the project can change the user data path and make the existing profile appear missing.

## 19 HUD menus and presentation

The interface is built in `afterburn/hud.gd`; there is no saved HUD layout scene for Afterburn. `_ready()` builds gameplay elements, while `menu()`, `workshop()`, `rewards()`, `paused()`, and `result()` build overlays. `new_overlay()` hides gameplay elements and creates the backdrop. `clear_overlay()` restores the gameplay elements.

| Constant | Color | Use |
| --- | --- | --- |
| `INK` | `#10141b` | Dark UI background and primary button text |
| `PAPER` | `#f1eddf` | Main text |
| `MINT` | `#a4ffcb` | Health, primary actions, and highlights |
| `ORANGE` | `#ffaf74` | Warnings, rewards, and momentum |
| `MUTED` | `#98a7ad` | Supporting text |

The font is `resources/fonts/ShareTech-Regular.ttf`. The logical UI reference is 1280 by 720, with `canvas_items` stretch in Project Settings. Some controls use anchors, but many menu dimensions and offsets are fixed pixels. Longer labels, more cards, or a different aspect ratio require a layout check.

The top HUD shows distance and speed, encounter segments, live hostiles, score, and credits. The bottom shows health, armor, momentum, dash readiness, and current weapon ammunition. Sights hide the normal crosshair. Boss health uses a separate bar and phase label.

When changing dash cooldown, update both `player.gd` and the HUD's `dash_bar.max_value` and subtraction. When changing encounter count, update segment creation and the HUD's fixed boss checks. Keep progress bar style padding at zero; button style padding is larger and can force meters to become unexpectedly thick.

## 20 Audio visual effects and rendering layers

Footstep assets and AudioStreamPlayer3D volumes are in `player/player.tscn` under `AudioManager`. The new runner's cadence is 0.27 seconds divided by `sqrt(mobility)`. Footsteps stop during slides; landing uses the existing jump and landing sound. Surface detection comes from `common/managers/audio_manager.gd` and tests the collider's `metal` group. The inherited metal branch currently plays the ground sound alongside the metal sound.

Existing weapon sounds, muzzle effects, and reload animations are reused. Player projectile impacts use spark effects; the generic hitscan path in other template scenes can still create decals. `game.gd::spark()` adds six emissive fragments with tweens and removes their parent after 0.6 seconds. The template bullet decal script removes decals after 5 seconds.

### Physics layers and render layers are different systems

Physics masks are integer bitmasks. A value of 5 means bits for layers 1 and 3, not physics layer 5.

| Object or query | Physics configuration | Purpose |
| --- | --- | --- |
| Player | Layer 1; original default floor mask | Stand on the road and receive enemy bolt hits |
| Ships | Layer 2; mask 0 | Receive player rounds without physical movement collision |
| Road, solid cover, and breakable panels | Layer value 5, meaning layers 1 and 3 | Block player movement and both factions' rounds |
| Laser Areas | Layer value 16 (physics layer 5), mask 1 | Detect the player without blocking rounds |
| Player round sweep and aim queries | Mask value 7; exclude player RID | Detect world, cover, and ships; apply damage only on round impact |
| Player weapon ray | Mask value 6, meaning layers 2 and 3 | Hit ships and cover while ignoring the player layer |
| Enemy bolt ray | Mask value 1 | Hit player and world; pass through ships |

Render layer 1 is the world and render layer 2 is used by first person weapon visuals. The main camera excludes the weapon render layer. The transparent weapon SubViewport camera renders layer 2 and copies the main camera transform. Keep its container's stretch behavior; manually assigning a SubViewport size while its parent stretches it is rejected by Godot.

The district directional lights use render layer value 3 so they are available in both world and weapon views. If the weapon goes dark while the map looks correct, check those light visibility layers and the two camera cull masks before replacing materials.

## 21 Practical editing recipes

### Make the runner faster or slower

Change Run Speed on the root Inspector in afterburn/player.tscn. Review the minimum speed assertion in the integration test if you deliberately go below 16. Playtest the 26 meter obstacle spacing, 15 meter beam warning, strafe response, jump distance, and fixed dash speed. A slower footstep interval means a larger `RUN_STEP_INTERVAL`; bob and cadence both use it.

### Make hit shake gentler without changing aiming

Reduce `HIT_SHAKE_DURATION`, the `applied * 0.003` multiplier, and the 0.045 to 0.11 strength limits in `get_damage()`. Leave the cached rest position and roll reset in `_update_hit_shake()` intact. Test a hit during mouse movement, repeated hits, an invulnerable hit, and the return to rest. The gun recoil effect is a different script.

### Add a new spaceship class

1. Add or import the mesh under `resources/spaceships`.
2. Add its class key and health to `_spawn_enemy()` and include it in the availability list when desired.
3. Extend `ship.gd` mesh and tint maps. The current mesh lookup builds `ship%d.obj`; alter that loader if your asset uses another naming or resource type.
4. Define its width, hit radius, movement, telegraph, salvo, damage, and speed rather than relying accidentally on the default branches.
5. Decide its score, credit value, and drop behavior in `ship_destroyed()` if it differs from ordinary ships.
6. Test it with the original weapon ray and with the moving runner. Check health scaling at later tiers.

### Add a weapon or change the starting weapon

1. Duplicate a compatible weapon scene and set its root properties and arms, animation, sound, and muzzle references.
2. Add the new instance under WeaponsManager in `afterburn/player.tscn` (or the original player scene if it should be shared with other template scenes).
3. Add it to the manager's exported `weapons_array` in the desired wheel order.
4. Add or reuse an ammo type in `Bullets` and check reserve limits.
5. Set Firing Distance, Burst Mode, Is Projectile, Projectile Scene, and Projectile Speed on the new weapon child in the Afterburn player scene.
6. Select WeaponsManager and choose the new child in Starting Weapon. Verify the editor preview, starting selection, switching, and reloading. Update the stock rifle test if you intentionally change the project default.

### Change map art without changing the runner course

Edit `district.tscn`, keep the 100 meter seams and center corridor, then restart. Move background props, retint cargo, adjust local lights, or replace signs there. Keep low road collision shapes aligned with their visual meshes. Edit obstacle rows in the four saved afterburn/obstacles/route_pattern_N.tscn scenes. Their saved instances are visible in the Local scene tree. Pattern 0 is also instanced under district.tscn > RunnerHazards.

### Rebuild the district from code

Use this only when you want `build_map()` to replace the saved map. Save a copy of `district.tscn` first. Create a temporary EditorScript in Godot, paste the code below, and run it from the Script editor's Run command. Run it with gameplay stopped, then reload the saved district scene.

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder := Node3D.new()
	builder.set_script(load("res://afterburn/game.gd"))
	var district: Node3D = builder.build_map()
	_assign_owner(district, district)
	var packed := PackedScene.new()
	var result := packed.pack(district)
	if result == OK:
		result = ResourceSaver.save(packed, "res://afterburn/district.tscn")
	print("District rebuild result: ", result)
	builder.free()

func _assign_owner(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_assign_owner(child, scene_root)
```

Assigning owners is necessary so generated children are included in the packed scene. Do not call the game's `_ready()` to perform a rebake: it initializes a playable run and UI rather than only map geometry.

### Make combat endless after the boss

This is a design extension, not a current toggle. Replace the boss death path that calls `finish_run(true)` with an explicit cycle transition. Reset wave counters, clean remaining escorts and bolts according to your rules, decide which temporary upgrades persist, and update the tier and HUD. Keep arrays and the fixed encounter checks consistent. Do not simply increment the encounter index indefinitely: normal quota indexing and the HUD assume six encounters.

## 22 Testing and diagnosing edits

Open `res://afterburn/tests/integration.tscn` and run that scene, or use the command below from the project root with your Godot executable on PATH. If it is not on PATH, replace `godot` with the full executable path.

```text
godot --headless --path . res://afterburn/tests/integration.tscn
```

The last successful suite reported **83 of 83 checks passed**. It checks the saved scene contains the runner and visible rifle before startup, the saved game reference, reuse and revival of the same player, Inspector starting weapon changes, clearing temporary weapon stats and timers, projectile launch without instant damage, visible travel and delayed ship damage, intact solid cover stopping rounds, breakable-only shots and ramming, enemy fire leaving panels intact, laser overlap damage and jump/slide/gap clearance, projectile hits and cover blocking, armor, death at zero health, immediate damage shake and return without aim drift, rewards, pause and resume, pickups, six encounter transitions, boss phases and victory, permanent ranks, automatic running, slide collision height, unchanged speed while W is held or sights are used, distant route streaming, road collision, ship following, the Charger's saved scene, projectile vulnerability at the closer spawn distance, warning delay, fixed flight path, charge vulnerability, safe strafing, 80-damage swept impact, one-hit limit, screen shake, pause, rewards, cleanup, saved corridor and spawn markers, closer arrivals, full hull and hitbox containment while moving, forward distance limits, and following the endless route.

The integration fixture overrides profile load and save, and mutes player audio streams. It does not alter your banked credits. The boss, reward, and charger preview scenes also disable profile loading and writing; they use stock preview progress. Run the actual main scene afterward to check real progression and saves.

### Manual checks after a meaningful edit

1. Start without holding W and confirm continuous running and the expected speed display.
2. Cross road seams, strafe around solids and full-height laser fences, jump low lasers, and slide under high lasers and beams.
3. Shoot a ship and a mint breakable panel; confirm delayed projectile impacts. Shoot and collide with solid cover and verify it stays intact. Reload, aim, and switch weapons.
4. Take damage, observe armor and health, and confirm hit shake settles while you continue aiming.
5. Clear an encounter, choose an upgrade, pause, resume, and restart after death.
6. Use previews to inspect long UI text and the boss. Verify a workshop purchase on a disposable or backed up profile when changing save logic.

| Symptom | First places to check |
| --- | --- |
| Changing walk speed has no effect | Edit runner `run_speed`; original player movement is overridden |
| A weapon still fires automatically or has unexpected range | Saved child overrides under WeaponsManager in `afterburn/player.tscn` |
| Map code edits do not appear | Saved `district.tscn` still used; edit the scene or deliberately rebake |
| New prop is not breakable | Expected for ordinary scenery; use breakable_barrier.tscn for the only destructible obstacle type |
| No projectile appears | Ranged weapon Is Projectile, Projectile Scene, and Projectile Speed in the Afterburn player scene |
| A laser is missing | Saved route pattern selection and RunnerHazards instance; keep its meshes visible and Area mask 1 |
| Bullets pass through a ship or cover | Physics bitmask values and `get_damage()` method on the hit body |
| Bolt passes through the player | Player physics layer and bolt mask 1; exclude only the shooter |
| A road seam catches or drops the player | Section length, the 43 meter offset, floor collision bounds, and section transform |
| Menus stop responding while paused | HUD process mode and input state routing |
| Hit shake never appears | Accepted damage path, invulnerability, strength assignment, player process state |
| Damage shake leaves a camera offset | Cached rest transform and zero-time reset in `_update_hit_shake()` |
| Wrong persistent bonuses appear | Five rank array indices and any save migration |
| Weapon view is black | Directional light render layers and camera cull masks |
| Ziva live preview fails to connect | Run F5 directly; an external tool connection error does not by itself prove a game error |

## 23 Current limitations and useful next refactors

The road repeats one saved district with deterministic procedural obstacle variations. It is not a library of independently authored biomes or randomized section scenes. Sections instantiate synchronously; adding much more geometry or scripts can cause a hitch when a new section loads. Profile and measure before introducing pooling or background loading.

The four section limit bounds section instances, not every possible object in the game. Uncollected ship drops have no expiry. Effects, decals, enemy bolts, and active enemy counts use their own cleanup or limits. Add distance cleanup for ship drops if you expand the game into much longer survival sessions.

Several rules are duplicated as literals: six encounters, 100 meter sections, the 43 meter boundary offset, three second dash cooldown, and lane boundaries. Centralizing these into configuration resources would make future editing safer. Enemy definitions and upgrade data are currently dictionaries and branches rather than custom Resources edited in the Inspector.

There is no floating origin, resumable active run, tier selection screen, dedicated accessibility menu, multiplayer system, or touch control implementation in Afterburn. A shake toggle would be a useful addition if you want players to control the new damage effect. The inherited FPS files remain shared with the original template, so edits there can change both experiences.

## 24 Source map and maintenance checklist

The implementation described here was checked against the files on 14 November 2026. For future changes, source code and saved scenes take precedence over this snapshot. Update this guide whenever you change rules or expose a new tuning variable.

| Topic | Authoritative source |
| --- | --- |
| Startup and player construction | `afterburn/game.gd::_ready`, `_create_player`, `start_run` |
| Route streaming and obstacle pattern | `game.gd::_init_course`, `_spawn_chunk`, `_prepare_chunk`, `_stream_course` |
| Saved map and builder | `afterburn/district.tscn`, `game.gd::build_map` |
| Motion and accepted damage | `afterburn/player.gd::_physics_process`, `get_damage`, `_update_hit_shake` |
| Camera FOV and gun recoil | `common/utils/active_camera.gd` |
| Weapon rules | `afterburn/player.tscn`, `afterburn/weapons_manager.gd`, `common/weapon/weapon.gd`, `common/managers/weapons_manager.gd`, `weapons/*.tscn` |
| Ammo reserves | `common/autoloads/bullets.gd` |
| Global event contract | `common/autoloads/global.gd` |
| Enemy identity and health | `game.gd::_spawn_enemy`, `ship.gd::_ready` |
| Enemy spawn placement and flight limits | `afterburn/enemy_corridor.tscn` and `.gd`; `ship.gd::_physics_process` |
| Enemy movement and attacks | `ship.gd::_physics_process`, `_fire`; `bolt.gd::_physics_process`; `enemies/charger.gd` and `.tscn` |
| Barrier rules and placement | `afterburn/obstacle.gd`, `afterburn/obstacles/*.tscn`, `game.gd::_prepare_chunk` |
| Player rounds | `common/weapon/weapon.gd::_launch_projectile`, `afterburn/projectiles/player_round.gd` and `.tscn` |
| Rewards score pickups and persistence | `game.gd::choose_upgrade`, `ship_destroyed`, `_collect`, `_load_profile`, `_save_profile` |
| UI and menu input | `afterburn/hud.gd`, `afterburn/input.gd` |
| Regression checks and preview fixtures | `afterburn/tests/` |

After an edit, check the changed default, any runtime override, any matching HUD text or meter, any serialized save field, and the corresponding test. This catches the most common cases where the game appears to ignore a change or the UI describes an older rule.
