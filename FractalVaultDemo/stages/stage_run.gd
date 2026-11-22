class_name StageRun
extends Node3D

const LAST_STAGE := 6

@export var profile_path := "user://fractal_stage_profile_v1.json"

@export var stage_catalog: Array[StageDefinition] = []
@export var upgrade_catalog: Array[UpgradeDefinition] = []
@export var store_catalog: Array[StoreItem] = []

@onready var player: Player = $Player
@onready var stage_container: Node3D = $Stages
@onready var hud: StageRunHUD = $StageRunHUD

var state := "setup"
var menu_mode := ""
var stage_number := 0
var current_stage: StageRoot
var current_definition: StageDefinition
var offered_stages: Array[StageDefinition] = []
var loaded_scenes: Dictionary = {}
var load_failed := false
var lever_fuel := [1.0, 1.0]
var spawn_queue: Array[EnemyEntry] = []
var spawn_timer := 0.0
var clear_grace := 0.0
var combat_time := 0.0
var damage_taken := 0.0
var run_credits := 0
var run_kills := 0
var profile: Dictionary = {"meta": 0, "unlocks": []}
var upgrade_choices: Array[UpgradeDefinition] = []
var locked_upgrades: Array[UpgradeDefinition] = []
var setup_page := 0
var store_page := 0
var players: Array[Player] = []
var _transition_stage: StageRoot
var _transition_old: StageRoot
var _transition_choice: int = -1
var _crossed: Array[Player] = []
var _finishing_transition := false
var _starting_health := 100.0
var _starting_walk := 5.0
var _starting_sprint := 10.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	players = [player]
	_starting_health = player.max_health
	_starting_walk = player.walk_speed
	_starting_sprint = player.sprint_speed
	hud.choice.connect(_on_menu_choice)
	Global.enemy_killed.connect(_on_enemy_killed)
	Global.player_health_changed.connect(_on_player_health_changed)
	Global.player_dead.connect(_on_player_dead)
	_load_profile()
	_show_setup()

func _process(delta: float) -> void:
	match state:
		"combat":
			_tick_combat(delta)
		"shop":
			_poll_loading()
			if menu_mode == "":
				_tick_shop(delta)
	_update_status()

func _show_setup() -> void:
	state = "setup"
	menu_mode = "setup"
	player.set_physics_process(false)
	player.weapons_manager.set_controls_locked(true)
	locked_upgrades.clear()
	for upgrade in upgrade_catalog:
		if upgrade.unlock_cost > 0 and not _is_unlocked(upgrade):
			locked_upgrades.append(upgrade)
	if setup_page * 3 >= locked_upgrades.size():
		setup_page = 0
	var options: Array[String] = []
	for index in range(setup_page * 3, mini(locked_upgrades.size(), setup_page * 3 + 3)):
		var upgrade := locked_upgrades[index]
		options.append("%s — %d marks\n%s" % [upgrade.title, upgrade.unlock_cost, upgrade.description])
	var next_label := "NEXT UNLOCKS" if locked_upgrades.size() > 3 else ""
	hud.show_menu("FRACTAL RUN  |  META MARKS: %d" % int(profile.get("meta", 0)), options, "START RUN", next_label)
	hud.set_prompt("")

func _on_menu_choice(index: int) -> void:
	match menu_mode:
		"setup":
			if index == 4:
				start_run()
			elif index == 3:
				setup_page = (setup_page + 1) % maxi(1, ceili(float(locked_upgrades.size()) / 3.0))
				_show_setup()
			else:
				var slot := setup_page * 3 + index
				if slot < locked_upgrades.size():
					var upgrade := locked_upgrades[slot]
					if int(profile.get("meta", 0)) >= upgrade.unlock_cost:
						profile["meta"] = int(profile.get("meta", 0)) - upgrade.unlock_cost
						var unlocks: Array = profile["unlocks"]
						unlocks.append(str(upgrade.id))
						profile["unlocks"] = unlocks
						_save_profile()
					_show_setup()
		"upgrade":
			if index < upgrade_choices.size():
				var upgrade := upgrade_choices[index]
				if upgrade.effect != null and upgrade.effect.can_apply(player):
					upgrade.effect.apply(self, player)
			_close_menu()
		"store":
			if index == 4:
				_close_menu()
			elif index == 3:
				store_page = (store_page + 1) % maxi(1, ceili(float(store_catalog.size()) / 3.0))
				_show_store()
			else:
				var slot := store_page * 3 + index
				if slot < store_catalog.size():
					var item := store_catalog[slot]
					if run_credits >= item.cost and item.effect != null and item.effect.can_apply(player):
						run_credits -= item.cost
						item.effect.apply(self, player)
					_show_store()
		"result":
			if index == 4:
				setup_page = 0
				_show_setup()

func _open_menu(mode: String, title: String, options: Array[String], close_label: String, next_label: String = "") -> void:
	menu_mode = mode
	player.set_physics_process(false)
	player.weapons_manager.set_controls_locked(true)
	hud.show_menu(title, options, close_label, next_label)

func _close_menu() -> void:
	menu_mode = ""
	hud.close_menu()
	if state == "shop" or state == "combat":
		player.set_physics_process(true)
		player.weapons_manager.set_controls_locked(false)

func start_run() -> void:
	menu_mode = ""
	hud.close_menu()
	player.set_physics_process(false)
	player.weapons_manager.set_controls_locked(true)
	for child in stage_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	current_stage = null
	offered_stages.clear()
	loaded_scenes.clear()
	stage_number = 1
	run_credits = 0
	run_kills = 0
	Global.enemies_killed = 0
	Global.enemy_count_changed.emit(0)
	player.weapons_manager.reset_run_loadout()
	player.max_health = _starting_health
	player.current_health = _starting_health
	player.walk_speed = _starting_walk
	player.sprint_speed = _starting_sprint
	player.is_alive = true
	player.end_leacher_grab()
	var first: StageDefinition
	for definition in stage_catalog:
		if definition.kind == StageDefinition.Kind.REGULAR:
			first = definition
			break
	if first == null:
		_end_run(false, "NO REGULAR STAGE IN CATALOG")
		return
	var scene := load(first.scene_path) as PackedScene
	if scene == null:
		_end_run(false, "FAILED TO LOAD FIRST STAGE")
		return
	current_stage = scene.instantiate() as StageRoot
	if current_stage == null:
		_end_run(false, "INVALID STAGE SCENE")
		return
	stage_container.add_child(current_stage)
	current_definition = first
	player.global_position = current_stage.to_global(Vector3(0, 0.1, 15))
	Global.player_health_changed.emit(0.0, player.current_health, player.max_health, false)
	player.set_physics_process(true)
	player.weapons_manager.set_controls_locked(false)
	Global.bullets_changed.emit()
	_start_encounter()

func _start_encounter() -> void:
	state = "combat"
	spawn_queue.clear()
	var encounter := current_definition.encounter
	if encounter == null:
		_end_run(false, "STAGE HAS NO ENCOUNTER")
		return
	for entry in encounter.entries:
		if entry == null or entry.enemy_scene == null:
			continue
		for count in entry.count:
			spawn_queue.append(entry)
	spawn_timer = encounter.opening_delay
	clear_grace = 0.0
	combat_time = 0.0
	damage_taken = 0.0
	current_stage.set_shop_active(false)
	hud.set_prompt("Clear the stage")

func _tick_combat(delta: float) -> void:
	combat_time += delta
	if not spawn_queue.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var entry: EnemyEntry = spawn_queue.pop_front()
			_spawn_enemy(entry)
			spawn_timer = maxf(0.1, entry.interval)
		return
	var alive := 0
	for child in current_stage.enemies.get_children():
		if child is FractalEnemyBase and child.awareness != FractalEnemyBase.Awareness.DEAD:
			alive += 1
	if alive == 0:
		clear_grace += delta
		if clear_grace >= 0.45:
			_clear_stage()
	else:
		clear_grace = 0.0

func _spawn_enemy(entry: EnemyEntry) -> void:
	var enemy := entry.enemy_scene.instantiate() as FractalEnemyBase
	if enemy == null:
		return
	enemy.max_health *= maxf(0.1, entry.health_multiplier)
	current_stage.enemies.add_child(enemy)
	enemy.global_position = current_stage.spawn_position(rng, player.global_position)

func _clear_stage() -> void:
	state = "shop"
	run_credits += current_definition.clear_credits
	if current_definition.meta_reward > 0:
		profile["meta"] = int(profile.get("meta", 0)) + current_definition.meta_reward
		_save_profile()
	current_stage.vendor.set_active(true)
	if stage_number >= LAST_STAGE:
		_end_run(true, "FINAL BOSS DEFEATED")
		return
	_choose_offers()
	_start_preloading()
	_show_upgrade_choice()

func _choose_offers() -> void:
	offered_stages.clear()
	var next_number := stage_number + 1
	var kind := StageDefinition.Kind.REGULAR
	if next_number == 4:
		kind = StageDefinition.Kind.MID_BOSS
	elif next_number == 6:
		kind = StageDefinition.Kind.FINAL_BOSS
	var health_pressure := 1.0 - player.current_health / maxf(1.0, player.max_health)
	var damage_pressure := clampf(damage_taken / 100.0, 0.0, 1.0)
	var time_pressure := clampf((combat_time - 45.0) / 90.0, 0.0, 1.0)
	var target_threat := clampf(3.2 - health_pressure - damage_pressure - time_pressure, 1.0, 5.0)
	var scored: Array[Dictionary] = []
	for definition in stage_catalog:
		if definition.kind == kind:
			scored.append({"definition": definition, "score": absf(definition.threat - target_threat) + rng.randf_range(0.0, 0.3)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	for candidate in scored:
		var definition: StageDefinition = candidate["definition"]
		var duplicate_scene := false
		for chosen in offered_stages:
			if chosen.scene_path == definition.scene_path:
				duplicate_scene = true
		if not duplicate_scene:
			offered_stages.append(definition)
		if offered_stages.size() == 2:
			break
	if offered_stages.size() < 2:
		_end_run(false, "STAGE CATALOG NEEDS TWO DISTINCT MAPS")

func _start_preloading() -> void:
	loaded_scenes.clear()
	load_failed = false
	lever_fuel = [1.0, 1.0]
	if offered_stages.size() != 2:
		return
	current_stage.set_offers(offered_stages[0].title, offered_stages[1].title)
	for definition in offered_stages:
		var error := ResourceLoader.load_threaded_request(definition.scene_path, "PackedScene")
		if error != OK:
			var fallback := load(definition.scene_path) as PackedScene
			if fallback == null:
				load_failed = true
			else:
				loaded_scenes[definition.scene_path] = fallback

func _poll_loading() -> void:
	if offered_stages.size() != 2 or load_failed:
		return
	for definition in offered_stages:
		if loaded_scenes.has(definition.scene_path):
			continue
		var status := ResourceLoader.load_threaded_get_status(definition.scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(definition.scene_path) as PackedScene
			if scene != null:
				loaded_scenes[definition.scene_path] = scene
			else:
				load_failed = true
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			load_failed = true
	if loaded_scenes.size() == 2:
		current_stage.set_shop_active(true)

func _show_upgrade_choice() -> void:
	upgrade_choices.clear()
	var pool: Array[UpgradeDefinition] = []
	for upgrade in upgrade_catalog:
		if _is_unlocked(upgrade):
			pool.append(upgrade)
	var options: Array[String] = []
	while not pool.is_empty() and upgrade_choices.size() < 3:
		var index := rng.randi_range(0, pool.size() - 1)
		var upgrade := pool[index]
		pool.remove_at(index)
		upgrade_choices.append(upgrade)
		options.append("%s\n%s" % [upgrade.title, upgrade.description])
	_open_menu("upgrade", "STAGE CLEAR  |  CHOOSE AN ABILITY", options, "SKIP")

func _show_store() -> void:
	var options: Array[String] = []
	for index in range(store_page * 3, mini(store_catalog.size(), store_page * 3 + 3)):
		var item := store_catalog[index]
		options.append("%s — %d credits\n%s" % [item.title, item.cost, item.description])
	var next_label := "NEXT ITEMS" if store_catalog.size() > 3 else ""
	_open_menu("store", "VENDOR  |  %d CREDITS" % run_credits, options, "LEAVE", next_label)

func _tick_shop(delta: float) -> void:
	var target := _looked_interactable()
	var branch := -1
	if target is StageVendor and target.active:
		hud.set_prompt("[F] Shop")
		if Input.is_action_just_pressed("activate"):
			store_page = 0
			_show_store()
	elif target is StageLever and target.active and loaded_scenes.size() == 2:
		branch = target.branch
		hud.set_prompt("Hold [F] to choose %s" % offered_stages[branch].title)
	else:
		hud.set_prompt("Shop, choose an upgrade, then hold [F] at an exit lever")
	if load_failed:
		hud.set_prompt("Stage load failed. Press [F] to retry.")
		if Input.is_action_just_pressed("activate"):
			_start_preloading()
	if branch >= 0 and Input.is_action_pressed("activate"):
		var holders: Array[int] = [0, 0]
		holders[branch] = 1
		var winner := advance_levers(holders, players.size(), delta)
		if winner >= 0:
			_commit_branch(winner)
	else:
		advance_levers([0, 0], players.size(), delta)

func advance_levers(holders: Array[int], player_count: int, delta: float) -> int:
	var total := maxi(1, player_count)
	var participation := holders[0] + holders[1]
	var multiplier := 1.0 if total == 1 else (2.0 if participation >= total else 0.35)
	for branch in 2:
		if holders[branch] > 0:
			lever_fuel[branch] = maxf(0.0, lever_fuel[branch] - delta * float(holders[branch]) / total * multiplier / 3.0)
		else:
			lever_fuel[branch] = minf(1.0, lever_fuel[branch] + delta * 0.1)
		if current_stage != null:
			current_stage.levers[branch].set_fuel(lever_fuel[branch])
	if lever_fuel[0] <= 0.0 and lever_fuel[1] <= 0.0:
		return 0 if holders[0] >= holders[1] else 1
	if lever_fuel[0] <= 0.0:
		return 0
	if lever_fuel[1] <= 0.0:
		return 1
	return -1

func _looked_interactable() -> Object:
	var from := player.camera.global_position
	var to := from - player.camera.global_transform.basis.z * 5.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 9, [player.get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider")

func _commit_branch(branch: int) -> void:
	if state != "shop" or offered_stages.size() != 2:
		return
	var selected := offered_stages[branch]
	var scene := loaded_scenes.get(selected.scene_path) as PackedScene
	if scene == null:
		return
	var next_stage := scene.instantiate() as StageRoot
	if next_stage == null:
		return
	state = "transition"
	_transition_choice = branch
	_transition_old = current_stage
	_transition_stage = next_stage
	_crossed.clear()
	_finishing_transition = false
	current_stage.set_shop_active(false)
	next_stage.position = current_stage.exits[branch].global_position - (next_stage.get_node("Entry") as Marker3D).position
	stage_container.add_child(next_stage)
	next_stage.player_entered.connect(_on_transition_entry)
	current_stage.doors[branch].set_open(true)
	next_stage.entry_door.set_open(true)
	hud.set_prompt("Move through the selected doorway")

func _on_transition_entry(body: Player) -> void:
	if state != "transition" or not players.has(body) or _crossed.has(body):
		return
	_crossed.append(body)
	for member in players:
		if member.is_alive and not _crossed.has(member):
			return
	if not _finishing_transition:
		_finishing_transition = true
		call_deferred("_finish_transition")

func _finish_transition() -> void:
	if state != "transition":
		return
	_transition_stage.entry_door.set_open(false)
	await _transition_stage.entry_door.closed
	_transition_old.queue_free()
	await get_tree().process_frame
	current_stage = _transition_stage
	current_definition = offered_stages[_transition_choice]
	stage_number += 1
	_transition_old = null
	_transition_stage = null
	offered_stages.clear()
	loaded_scenes.clear()
	_start_encounter()

func _on_enemy_killed() -> void:
	if state == "combat":
		run_kills += 1
		run_credits += 10

func _on_player_health_changed(change: float, _current: float, _maximum: float, _enemy_damage: bool) -> void:
	if state == "combat" and change < 0.0:
		damage_taken -= change

func _on_player_dead() -> void:
	if state == "combat" or state == "shop" or state == "transition":
		_end_run(false, "RUN ENDED")

func _end_run(_won: bool, message: String) -> void:
	state = "result"
	for child in stage_container.get_children():
		if child is StageRoot:
			child.set_shop_active(false)
			child.process_mode = Node.PROCESS_MODE_DISABLED
	player.set_physics_process(false)
	player.weapons_manager.set_controls_locked(true)
	menu_mode = "result"
	var options: Array[String] = []
	hud.show_menu("%s  |  %d KILLS  |  %d META MARKS" % [message, run_kills, int(profile.get("meta", 0))], options, "RETURN TO SETUP")
	hud.set_prompt("")
	_save_profile()

func _update_status() -> void:
	if state == "combat" or state == "shop" or state == "transition":
		hud.set_status("STAGE %d/%d  |  %s  |  %d CREDITS  |  %d KILLS" % [stage_number, LAST_STAGE, current_definition.title, run_credits, run_kills])
	else:
		hud.set_status("FRACTAL STAGE RUN")

func _is_unlocked(upgrade: UpgradeDefinition) -> bool:
	return upgrade.unlock_cost == 0 or (profile.get("unlocks", []) as Array).has(str(upgrade.id))

func _load_profile() -> void:
	if not FileAccess.file_exists(profile_path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	if parsed is Dictionary:
		profile["meta"] = maxi(0, int(parsed.get("meta", 0)))
		profile["unlocks"] = parsed.get("unlocks", [])

func _save_profile() -> void:
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile))
