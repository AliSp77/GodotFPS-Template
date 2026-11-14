# Afterburn — gameplay direction

Updated 14 November 2026.

This document records confirmed preferences and proposed design work. Proposed features below are not implemented by this document.

## Confirmed direction

- First-person endless runner: the character runs automatically.
- Manual mouse aim with light aim assist, selected by the user.
- Roboquest is the art reference.
- Whisker Squadron: Survivor is the reference for overall gameplay feel.
- Borrow the variety and mechanical ideas of Roboquest weapons; create original weapon designs.
- Keep travelling player projectiles, readable enemy attacks, jumping, sliding, strafing, and dash.
- Ordinary solid cover, overhead beams, and laser barriers remain intact. Only the designated breakable barrier type breaks from shots or player collisions.
- Roads and challenges should be editable saved Godot scenes.

## Proposed visual treatment

Use bold silhouettes, broad colour areas, restrained surface detail, and stylized lighting. Keep enemy projectiles, supplies, breakable panels, and laser hazards visually distinct. Preserve consistent hazard colours across road themes. Outline and shading treatments should be evaluated in a small playable scene before applying them throughout the project.

Weapons may have their own original visual identity. Each needs a clear muzzle, distinct firing feedback, and a silhouette that communicates its role.

## Proposed combat feel

Most combat should be readable in the forward view. Replace long periods of independent ship hovering with authored formations and attack sequences: a crossing squad, a shield carrier with escorts, a diving attacker, and a heavy ship with exposed attack windows.

Alternate aiming-intensive sections with movement-intensive sections. A difficult jump/slide sequence gets lighter enemy pressure; a dense enemy formation gets simpler terrain. Recovery stretches support reloads, collecting supplies, and anticipating the next challenge.

Destruction should communicate impact through brief flashes, fragments, audio, and clear enemy reactions. Keep the view readable while the player continues to run.

## Aim assist proposal

- The player controls camera direction and chooses targets.
- Apply modest projectile convergence toward a visible enemy close to the crosshair.
- Do not move the camera or select enemies far from the crosshair.
- Require an unobstructed view; respect solid cover between muzzle and target.
- Assistance helps launch direction. Rounds still travel and can miss a moving enemy.
- Expose enable/disable, strength, and cone settings for playtesting and player preference.
- Give weak-point targeting clear rules; avoid silently redirecting an intentional weak-point shot onto another target.

Exact assistance values require playtesting at real running speeds and target distances.

## Original weapon concepts

| Weapon concept | Projectile behaviour | Decision it creates |
| --- | --- | --- |
| Pulse carbine | Fast, accurate repeated bolts | Track individual enemies and exposed cores |
| Scrap cannon | Short-range spread of physical pellets | Close distance and catch crossing formations |
| Burst mortar | Arcing explosive rounds | Lead groups and trade precision for area damage |
| Seeker launcher | Mark targets, then release a limited missile salvo | Spend time acquiring targets before returning attention to the road |
| Ricochet driver | Bolts bounce from eligible solid surfaces | Use cover and geometry to reach awkward targets |
| Charge lance | Charge and release a fast piercing round | Choose the firing window and line up enemies |

These are proposed concepts, not a list of weapons currently implemented in Afterburn or a claim that these exact weapons exist in Roboquest.

Upgrades should visibly change behaviour as well as strength: extra ricochets, additional pellets, controlled fragmentation, piercing, or different missile targeting. Keep trade-offs legible and prevent combinations from obscuring enemy attacks.

## Proposed first playable milestone

Build one short, repeatable combat section with a pulse carbine and seeker launcher, two distinct enemy formations, one simple laser choice, and a recovery stretch. Test running, manual aiming, light assistance, projectile travel, and hit feedback together. Use existing assets while evaluating combat; apply a limited art treatment to the same section afterward.

Success means the player can identify targets and hazards quickly, explain why they took damage, distinguish each weapon's purpose, and want another attempt. Expand the road library and weapon roster after that loop works.

## Current implementation and gaps

The project already has automatic running, saved player and road scenes, basic travelling rounds, destructible panels, intact solid cover, laser hazards, spaceship enemies, upgrades, and a boss.

The ranged weapons currently share a straight-projectile implementation. Standard ships mainly hover and fire independently. The implemented Charger adds a visible red-path warning and a fast straight-line ram, using a saved editable enemy scene. The saved EnemyFlightCorridor confines hulls to a 16 meter width; ranged ships spawn 14–26 meters ahead and stay 12–30 meters ahead, while the Charger starts 60 meters ahead. Road patterns repeat in a fixed four-pattern sequence. Light aim assist, the proposed weapon behaviours, formation scripting, the new pacing rules, and the art treatment remain design work.

## Reference sources

- [Roboquest — official game description](https://store.steampowered.com/app/692890/Roboquest/): movement, weapon variety, builds, and a mixture of pre-placed and randomized level chunks.
- [Whisker Squadron: Survivor — official game description](https://store.steampowered.com/app/2140100/Whisker_Squadron_Survivor/): waves, randomized runs, branching route choices, weapons, and permanent upgrades.

The specific visual treatment, aim-assist rules, formations, and weapon concepts above are proposals for Afterburn.
