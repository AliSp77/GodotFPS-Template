# Stage run authoring

`stage_run.tscn` is the FPS entry scene. Its exported catalogs contain the stage, upgrade, and store item resources. The player and run manager persist while stage scenes are swapped.

## Add a map or encounter

1. Create a `StageRoot` scene with the same node contract as `maps/forge_vault.tscn`: `Entry`, `ExitLeft`, `ExitRight`, `EntryDoor`, `EntryArea`, `Doors/Left`, `Doors/Right`, `Levers/Left`, `Levers/Right`, `Vendor`, `EnemySpawns`, `Enemies`, and `NavigationRegion3D`.
2. Instance the reusable `modules/vault_architecture.tscn`, door, lever, and vendor scenes in the editor. The run scene owns `modules/vault_atmosphere.tres`; give each map authored collision and navigation. Keep `Entry` on the rear doorway and both exits on the front doorways so the manager can align scenes during a transition.
3. Create an `EncounterDefinition` resource with `EnemyEntry` resources. Each entry selects an enemy scene, count, spawn interval, and health multiplier. Enemies spawn at authored markers or validated random navigation points.
4. Create a `StageDefinition` resource with a unique ID, map scene path, encounter, kind, threat, and rewards. Add it to `StageRun.stage_catalog` in the editor. Regular choices need at least two distinct map paths; the same applies to each boss kind.

The director chooses two resources after each clear. It loads their map scenes during shopping and instances only the chosen one. The unchosen `PackedScene` reference is released; Godot may retain shared resources in its cache.

## Add progression content

- **Ability:** Create an `UpgradeDefinition` resource with a `RunEffect`. Cost `0` makes it available at the start; a positive `unlock_cost` puts it in the pre-run meta menu. Add it to `upgrade_catalog`.
- **Store item:** Create a `StoreItem` resource with a cost and `RunEffect`, then add it to `store_catalog`. The vendor menu pages automatically when there are more than three entries.
- **Weapon:** Author the weapon as a separate scene using the existing weapon script, create a `WeaponDefinition` pointing to it, and reference it from a store item with `EquipEffect`. The purchased scene is equipped at runtime; starting weapons remain authored in `player.tscn`.
- **New effect behavior:** Derive a resource script from `RunEffect` and implement `can_apply()` and `apply()`. The run manager does not need a new item or upgrade branch.

`tests/stage_run_smoke.tscn` exercises a six-stage run and adds an extra map, ability, store item, and weapon from `tests/fixtures` without editing the manager.

