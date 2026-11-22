extends Node3D

@onready var run: StageRun = $StageRun

func _enter_tree() -> void:
	$StageRun.profile_path = "user://fractal_stage_smoke_profile.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path($StageRun.profile_path))

func _ready() -> void:
	call_deferred("_check_run")

func _check_run() -> void:
	run.stage_catalog.insert(0, load("res://FractalVaultDemo/tests/fixtures/expansion_stage.tres"))
	run.upgrade_catalog.append(load("res://FractalVaultDemo/tests/fixtures/expansion_upgrade.tres"))
	run.store_catalog.append(load("res://FractalVaultDemo/tests/fixtures/expansion_item.tres"))
	run.start_run()
	await _frames(5)
	if not _check(run.stage_number == 1 and run.state == "combat" and run.current_stage != null and run.current_definition.id == &"expansion_map", "Config-only test map did not start"):
		return
	run.spawn_queue.clear()
	for opening_enemy in run.current_stage.enemies.get_children():
		opening_enemy.queue_free()
	var active_hazard := Node3D.new()
	active_hazard.add_to_group("encounter_hazard")
	run.current_stage.enemies.add_child(active_hazard)
	run._tick_combat(1.0)
	if not _check(run.state == "combat" and run.clear_grace == 0.0, "Active grenade hazard allowed the stage to clear"):
		return
	active_hazard.queue_free()
	await _frames(2)
	for cleared_stage in range(1, 6):
		run.spawn_queue.clear()
		for enemy in run.current_stage.enemies.get_children():
			enemy.queue_free()
		run._clear_stage()
		await _frames(5)
		if not _check(run.state == "shop" and run.offered_stages.size() == 2, "Stage did not offer two choices"):
			return
		if not _check(run.offered_stages[0].scene_path != run.offered_stages[1].scene_path, "Both choices point to one map"):
			return
		var expected_kind := StageDefinition.Kind.REGULAR
		if cleared_stage == 3:
			expected_kind = StageDefinition.Kind.MID_BOSS
		elif cleared_stage == 5:
			expected_kind = StageDefinition.Kind.FINAL_BOSS
		if not _check(run.offered_stages[0].kind == expected_kind and run.offered_stages[1].kind == expected_kind, "Wrong boss milestone"):
			return
		for attempt in 120:
			if run.loaded_scenes.size() == 2 or run.load_failed:
				break
			await _frames(1)
		if not _check(run.loaded_scenes.size() == 2 and not run.load_failed, "Next maps did not preload"):
			return
		if cleared_stage == 1:
			run._on_menu_choice(0)
			run.player.current_health = run.player.max_health - 10.0
			var fixture_upgrade: UpgradeDefinition = run.upgrade_catalog.back()
			if not _check(run._is_unlocked(fixture_upgrade) and fixture_upgrade.effect.can_apply(run.player), "Config-only upgrade unavailable"):
				return
			var before_fixture := run.player.current_health
			fixture_upgrade.effect.apply(run, run.player)
			if not _check(run.player.current_health == before_fixture + 5.0, "Config-only upgrade effect failed"):
				return
		else:
			run._on_menu_choice(4)
		if cleared_stage == 1:
			run.player.rotation.y = 0.0
			run.player.camera_pivot.rotation.y = 0.0
			run.player.camera_holder.rotation.x = 0.0
			run.player.global_position = run.current_stage.to_global(Vector3(0, 0.1, -8))
			await _frames(2)
			if not _check(run._looked_interactable() is StageVendor, "Vendor cannot be aimed at"):
				return
			Input.action_press("activate")
			run._tick_shop(0.016)
			Input.action_release("activate")
			if not _check(run.menu_mode == "store", "Vendor interaction did not open the store"):
				return
			run._on_menu_choice(4)
			run.player.global_position = run.current_stage.to_global(Vector3(-8, 0.1, -12))
			await _frames(2)
			if not _check(run._looked_interactable() is StageLever, "Lever cannot be aimed at"):
				return
		if cleared_stage == 2:
			run.player.current_health = 40.0
			run.run_credits += 100
			run._show_store()
			var before_health := run.player.current_health
			var before_credits := run.run_credits
			run._on_menu_choice(0)
			if not _check(run.player.current_health > before_health and run.run_credits == before_credits - 30, "Vendor medkit did not work"):
				return
			run._on_menu_choice(2)
			if not _check(run.player.weapons_manager.weapons_array.size() == 3, "Purchased rifle did not equip"):
				return
			run._on_menu_choice(3)
			run._on_menu_choice(0)
			if not _check(run.player.weapons_manager.weapons_array.size() == 4, "Paged config-only weapon item did not equip"):
				return
			run._on_menu_choice(4)
		if cleared_stage == 2:
			run.lever_fuel = [1.0, 1.0]
			if not _check(run.advance_levers([2, 1], 3, 2.3) == 0, "Two holders did not beat one holder"):
				return
			run.lever_fuel = [0.5, 0.5]
			run.advance_levers([0, 0], 3, 1.0)
			if not _check(run.lever_fuel[0] > 0.5 and run.lever_fuel[1] > 0.5, "Unattended levers did not refill"):
				return
		run.lever_fuel = [1.0, 1.0]
		var branch := (cleared_stage - 1) % 2
		if cleared_stage == 1:
			Input.action_press("activate")
			run._tick_shop(3.1)
			Input.action_release("activate")
		else:
			run._commit_branch(branch)
		if not _check(run.state == "transition" and run._transition_stage != null, "Branch did not instantiate the next stage"):
			return
		var old_stage := run._transition_old
		await _frames(2)
		if not _check(old_stage.doors[branch].collision_shape.disabled and not old_stage.doors[1 - branch].collision_shape.disabled and run._transition_stage.entry_door.collision_shape.disabled, "Selected doorway collision did not open correctly"):
			return
		var doorway := old_stage.exits[branch].global_position
		var passage_ray := PhysicsRayQueryParameters3D.create(doorway + Vector3(0, 1.0, 3), doorway + Vector3(0, 1.0, -3), 1, [run.player.get_rid()])
		if not _check(get_world_3d().direct_space_state.intersect_ray(passage_ray).is_empty(), "Selected doorway is physically blocked"):
			return
		run.player.global_position = run._transition_stage.to_global(Vector3(0, 0.1, 17))
		for attempt in 120:
			if run.stage_number == cleared_stage + 1:
				break
			await _frames(1)
		if not _check(run.stage_number == cleared_stage + 1 and run.state == "combat", "Doorway crossing did not finish"):
			return
		if not _check(not is_instance_valid(old_stage), "Old stage remained after door closed"):
			return
	if not _check(run.stage_number == 6 and run.current_definition.kind == StageDefinition.Kind.FINAL_BOSS, "Final boss stage missing"):
		return
	run.spawn_queue.clear()
	run._clear_stage()
	if not _check(run.state == "result" and int(run.profile["meta"]) == 4, "Final result or boss rewards missing"):
		return
	run._on_menu_choice(4)
	if not _check(run.menu_mode == "setup", "Result did not return to setup"):
		return
	run._on_menu_choice(0)
	if not _check((run.profile["unlocks"] as Array).has("quick_reload"), "Meta unlock purchase failed"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run.profile_path))
	print("STAGE_RUN_SMOKE_OK")
	get_tree().quit()

func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("STAGE_RUN_SMOKE_FAIL: " + message)
		get_tree().quit(1)
	return condition
