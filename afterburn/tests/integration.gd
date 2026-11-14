extends Node

class GameUnderTest:
	extends "res://afterburn/game.gd"
	func _load_profile() -> void:
		pass
	func _save_profile() -> void:
		pass
	func _create_player() -> void:
		super._create_player()
		for audio in player.find_children("*", "AudioStreamPlayer3D", true, false):
			audio.stream = null

var checks: int = 0
var failures: int = 0
var game: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", description)

func _run() -> void:
	var saved_scene: Node3D = load("res://afterburn/afterburn.tscn").instantiate()
	var saved_player: CharacterBody3D = saved_scene.get_node_or_null("Player")
	check(saved_player != null and saved_player.get_script().resource_path == "res://afterburn/player.gd", "Saved main scene contains the runner before gameplay starts")
	check(saved_player.get_node("WeaponsManager/AssualtRifle").visible, "Starting rifle is visible in the saved player scene")
	check(saved_player.game == saved_scene, "Saved player references its owning game")
	game = saved_scene
	game.set_script(GameUnderTest)
	get_tree().root.add_child(game)
	await get_tree().process_frame
	check(game.state == "menu" and get_tree().paused, "Title screen freezes gameplay")
	check(get_tree().get_nodes_in_group("supplied_props").size() >= 40, "Map contains supplied collidable props")
	await _check_hud_navigation()
	var title_overlay: Control = game.hud.overlay
	game.start_run()
	check(title_overlay.is_queued_for_deletion() and not title_overlay.visible and game.hud.overlay == null, "Starting a run immediately hides the retiring menu before deferred deletion")
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.weapons_manager.set_process(false)
	check(game.state == "play" and not get_tree().paused, "Starting a run resumes gameplay")
	check(game.player.weapons_manager.current_weapon.name == "AssualtRifle", "Run starts with the existing FPS rifle")
	var original_player_id: int = game.player.get_instance_id()
	var enemy: Node3D = game._spawn_enemy("guardian")
	enemy.position = Vector3(0, 2.2, -7)
	enemy.set_physics_process(false)
	await get_tree().physics_frame
	var weapon: Node3D = game.player.weapons_manager.current_weapon
	weapon.firing_sfx = null
	weapon.standard_aim_angle = 0.0
	weapon.focused_aim_angle = 0.0
	var origin: Node3D = game.player.weapons_manager.ray_cast_origin
	origin.global_position = game.player.camera.global_position
	origin.look_at(enemy.global_position)
	var ray: RayCast3D = game.player.weapons_manager.weapon_ray_cast
	ray.force_raycast_update()
	check(ray.is_colliding() and ray.get_collider() == enemy, "Original weapon raycast hits a spaceship")
	var before_hp: float = enemy.hp
	weapon.can_fire = true
	var magazine_before: int = weapon.current_mag
	weapon.try_fire(true)
	check(is_equal_approx(enemy.hp, before_hp), "Firing a projectile deals no instant hitscan damage")
	check(weapon.current_mag == magazine_before - weapon.consume, "Projectile firing consumes the original weapon magazine")
	var player_round: Node3D = get_tree().get_nodes_in_group("afterburn_player_rounds").back()
	player_round.set_physics_process(false)
	var launch_point: Vector3 = player_round.global_position
	player_round._physics_process(0.05)
	check(player_round.global_position.distance_to(launch_point) > 4.0 and is_equal_approx(enemy.hp, before_hp), "Player round travels through space before reaching its target")
	player_round._physics_process(0.5)
	check(is_equal_approx(enemy.hp, before_hp - weapon.damage), "Player round applies weapon damage only when it reaches the spaceship")
	var before_credits: int = game.profile.credits
	enemy.get_damage(9999, Vector3.ZERO)
	check(game.kills == 1 and game.profile.credits > before_credits, "Ship kill awards score and banked credits")
	await get_tree().process_frame
	await _check_obstacle_rules()
	await _check_charger()
	game.player.current_health = 100.0
	game.player.armor = 0.0
	game.player.invulnerability = 0.0
	var emitter := StaticBody3D.new()
	game.add_child(emitter)
	game.fire_bolt(Vector3(0, 1.1, 20), Vector3.BACK, 20.0, 10.0, emitter.get_rid(), Color.ORANGE)
	var test_bolt: Node3D = get_tree().get_nodes_in_group("afterburn_bolts").back()
	test_bolt.set_physics_process(false)
	test_bolt._physics_process(0.4)
	check(game.player.current_health == 90.0, "Enemy projectile collision damages the FPS player")
	await get_tree().process_frame
	game.player.invulnerability = 0.0
	var cover: MeshInstance3D = game._box("TestCover", Vector3(3, 3, 0.5), Vector3(0, 1.5, 22), Color.GRAY, true)
	await get_tree().physics_frame
	game.fire_bolt(Vector3(0, 1.1, 20), Vector3.BACK, 20.0, 10.0, emitter.get_rid(), Color.ORANGE)
	test_bolt = get_tree().get_nodes_in_group("afterburn_bolts").back()
	test_bolt.set_physics_process(false)
	test_bolt._physics_process(0.4)
	check(game.player.current_health == 90.0, "Cover blocks enemy projectiles before they reach the player")
	cover.queue_free()
	emitter.queue_free()
	game.player.armor = 50.0
	game.player.invulnerability = 0.0
	var before_health: float = game.player.current_health
	var before_armor: float = game.player.armor
	var look_before_hit: Vector3 = game.player.camera_holder.rotation
	game.player.invulnerability = 0.0
	game.player.get_damage(20, Vector3.ZERO, true)
	check(game.player.armor < before_armor and game.player.current_health < before_health, "Armor absorbs part of incoming damage")
	check(game.player.hit_shake_time > 0.0 and game.player.camera.position.distance_to(game.player.camera_rest_position) > 0.001, "Taking damage immediately starts visible screen shake")
	check(game.player.camera_holder.rotation.is_equal_approx(look_before_hit), "Damage shake preserves the player's mouse aim")
	game.player._update_hit_shake(0.4)
	check(game.player.camera.position.is_equal_approx(game.player.camera_rest_position) and is_equal_approx(game.player.camera.rotation.z, game.player.camera_rest_roll), "Damage shake decays back to the resting camera without drift")
	game.player.invulnerability = 0.0
	game.player.armor = 0.0
	game.player.current_health = 10.0
	game.player.get_damage(10, Vector3.ZERO, true)
	check(game.state == "result" and not game.player.is_alive, "Exactly zero health ends the run")
	game.start_run()
	check(game.player.get_instance_id() == original_player_id and game.player.is_alive, "Restart keeps the authored player instance and revives it")
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.weapons_manager.set_process(false)
	game.complete_encounter()
	check(game.state == "reward" and get_tree().paused and game.choices.size() == 3, "Encounter clear pauses for three upgrade choices")
	var old_damage: float = game.player.weapons_manager.current_weapon.damage
	game.choose_upgrade("damage")
	check(game.state == "play" and not get_tree().paused and game.encounter == 1, "Choosing an upgrade starts the next encounter")
	check(game.player.weapons_manager.current_weapon.damage > old_damage, "Chosen upgrade changes combat stats")
	game.pause_run()
	check(get_tree().paused and game.state == "pause", "Pause suspends combat")
	game.resume_run()
	check(not get_tree().paused and game.state == "play", "Resume restores combat")
	game.player.current_health = 20
	game.add_pickup("health", game.player.position)
	var pickup: Node3D = game.pickups.back()
	game._collect(pickup)
	check(game.player.current_health == 50, "Repair pickups restore health")
	for wave in range(1, 6):
		game.complete_encounter()
		game.choose_upgrade("armor")
	check(game.encounter == 6, "All six encounter transitions advance in sequence")
	check(game.encounter == 6 and is_instance_valid(game.boss_ship), "Six encounters lead to the gunship boss")
	var boss: Node3D = game.boss_ship
	boss.hp = boss.max_hp * 0.6
	boss._physics_process(0.01)
	check(boss.phase == 2, "Boss enters its second phase")
	boss.hp = boss.max_hp * 0.3
	boss._physics_process(0.01)
	check(boss.phase == 3, "Boss enters its third phase")
	boss.get_damage(99999, Vector3.ZERO)
	check(game.state == "result" and game.profile.wins == 1 and game.profile.tier == 2, "Boss destruction wins the run and unlocks the next tier")
	var old_rank: int = game.profile.ranks[0]
	game.profile.credits = 1000
	game.buy_upgrade(0)
	check(game.profile.ranks[0] == old_rank + 1 and game.profile.credits == 900, "Workshop purchase spends credits and raises a persistent rank")
	var base_cooldown: float = game.base_weapon_timing["AssualtRifle"].x
	var base_reload: float = game.base_weapon_timing["AssualtRifle"].y
	game.player.weapons_manager.current_weapon.cooldown *= 0.5
	game.player.weapons_manager.current_weapon.reload_time *= 0.5
	game.player.weapons_manager.current_weapon.start_reload()
	game.player.weapons_manager.starting_weapon = NodePath("Pistol")
	game.start_run()
	check(game.player.weapons_manager.current_weapon.name == "Pistol", "Inspector starting weapon is used on the next run")
	var rifle: Node3D = game.player.get_node("WeaponsManager/AssualtRifle")
	check(is_equal_approx(rifle.cooldown, base_cooldown) and is_equal_approx(rifle.reload_time, base_reload) and is_equal_approx(game.player.damage_resistance, 1.0), "Restart clears temporary fire rate, reload, and resistance upgrades")
	check(not rifle.is_reloading and rifle.reload_timer.is_stopped() and rifle.cooldown_timer.is_stopped(), "Restart cancels old weapon reloads and cooldowns")
	game.player.weapons_manager.starting_weapon = NodePath("AssualtRifle")
	game.start_run()
	check(game.player.vital_capacity == 110, "Permanent hull upgrade applies on a new run")
	game.set_process(false)
	game.player.weapons_manager.set_process(false)
	var initial_z: float = game.player.position.z
	for frame in range(20):
		await get_tree().physics_frame
	game.player.set_physics_process(false)
	check(game.player.position.z < initial_z - 1.0, "Player runs forward automatically without movement input")
	Input.action_press("backward")
	game.player._physics_process(1.0 / 60.0)
	Input.action_release("backward")
	check(game.player.is_sliding and game.player.capsule.height < 1.0, "Slide input shrinks the actual collision capsule")
	Input.action_press("forward")
	game.player._physics_process(1.0 / 60.0)
	Input.action_release("forward")
	check(is_equal_approx(absf(game.player.velocity.z), game.player.run_speed * game.player.mobility), "W does not change the automatic running speed")
	check(absf(game.player.velocity.z) >= 16.0, "Automatic running uses the faster running pace without forward input")
	Global.aim_mode_changed.emit(true)
	game.player._physics_process(1.0 / 60.0)
	check(is_equal_approx(absf(game.player.velocity.z), game.player.run_speed * game.player.mobility), "Aiming preserves the automatic running pace")
	Global.aim_mode_changed.emit(false)
	game.player.position.z = -5200.0
	game._stream_course()
	await get_tree().process_frame
	check(game.course_chunks.size() == 4 and game.course_chunks.has(52), "Route streams to distant sections while keeping only four sections loaded")
	var floor_query := PhysicsRayQueryParameters3D.create(game.player.position + Vector3(0, 4, 0), game.player.position - Vector3(0, 4, 0), 1, [game.player.get_rid()])
	var floor_hit := game.get_world_3d().direct_space_state.intersect_ray(floor_query)
	check(not floor_hit.is_empty(), "Streamed sections keep a collidable road under the runner")
	var escort: Node3D = game._spawn_enemy("striker")
	escort.set_physics_process(false)
	var old_ship_z: float = escort.position.z
	game.player.position.z -= 50.0
	escort._physics_process(0.1)
	check(escort.position.z < old_ship_z, "Enemy ships follow the advancing runner")
	await _check_enemy_corridor()
	game._clear_combat()
	get_tree().paused = false
	for audio in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		audio.stop()
	await get_tree().create_timer(0.2).timeout
	game.queue_free()
	await get_tree().process_frame
	print("AFTERBURN_INTEGRATION: ", checks - failures, "/", checks, " passed")
	get_tree().quit(1 if failures > 0 else 0)

func _press_hud_button(text: String) -> void:
	for button in game.hud.overlay.find_children("*", "Button", true, false):
		if button.text == text:
			button.pressed.emit()
			return
	check(false, "HUD button exists: " + text)

func _check_hud_navigation() -> void:
	var retired: Array[Control] = []
	var safe: bool = true
	for index in range(8):
		var previous: Control = game.hud.overlay
		_press_hud_button("PERMANENT UPGRADES")
		retired.append(previous)
		safe = safe and is_instance_valid(previous) and previous.is_queued_for_deletion() and not previous.visible
		previous = game.hud.overlay
		_press_hud_button("BACK")
		retired.append(previous)
		safe = safe and is_instance_valid(previous) and previous.is_queued_for_deletion() and not previous.visible
	check(safe, "Menu and workshop button signals finish before old overlays are freed")
	await get_tree().process_frame
	await get_tree().process_frame
	var freed: bool = true
	for previous in retired:
		freed = freed and not is_instance_valid(previous)
	check(freed, "Retired overlays are deleted after repeated button navigation")
	var saved_profile: Dictionary = game.profile.duplicate(true)
	game.profile.credits = 1000
	game.profile.ranks[0] = 0
	_press_hud_button("PERMANENT UPGRADES")
	var previous: Control = game.hud.overlay
	_press_hud_button("100 CR / BUY")
	check(is_instance_valid(previous) and previous.is_queued_for_deletion() and not previous.visible and game.profile.credits == 900 and game.profile.ranks[0] == 1, "Purchase button safely rebuilds the workshop and applies its upgrade once")
	game.profile = saved_profile
	_press_hud_button("BACK")

func _check_enemy_corridor() -> void:
	var corridor: Area3D = game.get_node("EnemyFlightCorridor")
	check(corridor.collision_layer == 0 and corridor.collision_mask == 0 and not corridor.monitoring, "Invisible flight corridor does not collide with the player or projectiles")
	check(corridor.get_node("Bounds").shape.size.x == 16.0 and corridor.get_node("SpawnPoints").get_child_count() == 6, "Saved corridor has a 16 meter width and six editable spawn markers")
	var ships: Array[Node3D] = []
	var spawn_fits: bool = true
	var moving_fits: bool = true
	var forward_fits: bool = true
	var index: int = 0
	for kind in ["striker", "interceptor", "sniper", "guardian", "boss"]:
		game.spawned = index
		var ship: Node3D = game._spawn_enemy(kind)
		ship.set_physics_process(false)
		ship.shot_timer = 99999.0
		ships.append(ship)
		var gap: float = game.player.global_position.z - ship.global_position.z
		spawn_fits = spawn_fits and gap >= 14.0 and gap <= 26.0 and _ship_fits_corridor(ship, corridor)
		index += 1
	check(spawn_fits, "All ranged classes and the boss spawn 14 to 26 meters ahead with their hulls inside the road-width corridor")
	for frame in range(80):
		game.player.position.z -= 1.6
		game.player.position.x = 9.0 if frame % 2 == 0 else -9.0
		for ship in ships:
			ship._physics_process(0.1)
			moving_fits = moving_fits and _ship_fits_corridor(ship, corridor)
			var gap: float = game.player.global_position.z - ship.global_position.z
			forward_fits = forward_fits and gap >= corridor.near_distance - 0.01 and gap <= corridor.far_distance + 0.01
	check(moving_fits, "Banking, facing, and lateral motion keep full ship hulls and hitboxes inside the invisible boundaries")
	check(forward_fits, "Ranged enemies stay 12 to 30 meters ahead as the runner advances")
	game.player.position.z -= 200.0
	for ship in ships:
		ship._physics_process(0.1)
		var gap: float = game.player.global_position.z - ship.global_position.z
		forward_fits = forward_fits and gap >= corridor.near_distance - 0.01 and gap <= corridor.far_distance + 0.01
	check(forward_fits, "A large player advance cannot leave ranged ships behind the camera")
	corridor.sync_to_player()
	check(is_equal_approx(corridor.global_position.z, game.player.global_position.z - corridor.follow_offset), "Editable flight volume follows the endless route")
	for ship in ships:
		ship.queue_free()
	await get_tree().process_frame

func _ship_fits_corridor(ship: Node3D, corridor: Area3D) -> bool:
	var limits: Vector2 = corridor.horizontal_limits()
	var bounds: AABB = ship.visual.global_transform * ship.visual.get_aabb()
	return bounds.position.x >= limits.x - 0.01 and bounds.end.x <= limits.y + 0.01 and ship.global_position.x - ship.radius >= limits.x - 0.01 and ship.global_position.x + ship.radius <= limits.y + 0.01

func _check_charger() -> void:
	var player_transform: Transform3D = game.player.transform
	var old_health: float = game.player.current_health
	var old_armor: float = game.player.armor
	game.player.current_health = 100.0
	game.player.armor = 0.0
	game.player.invulnerability = 0.0
	var charger: Node3D = game._spawn_enemy("charger")
	charger.set_physics_process(false)
	var start: Vector3 = charger.global_position
	var path_start: Vector3 = charger.warning_path.global_position
	check(charger.scene_file_path == "res://afterburn/enemies/charger.tscn" and charger.has_node("Hull") and charger.has_node("WarningPath/DangerStrip"), "Charger uses saved editable hull, hit shape, and red warning nodes")
	check(charger.attack_state == "warning" and charger.warning_path.visible and is_equal_approx(game.player.position.z - start.z, 60.0), "Charger appears 60 meters ahead with its red flight path immediately visible")
	check(charger.get_node("Hull").to_global(charger.get_node("Hull").mesh.get_aabb().get_center()).distance_to(start) < 0.01, "Charger hull is centered on its shootable collision body")
	check(charger.collision_layer == 2 and charger.spawn_distance < game.player.camera.far and charger.spawn_distance < game.player.weapons_manager.current_weapon.firing_distance, "Distant charger remains inside camera and weapon range with an active hitbox")
	charger._physics_process(0.6)
	check(charger.global_position.is_equal_approx(start) and game.player.current_health == 100.0, "Warning gives reaction time before the ship moves or deals damage")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var round_node: Node3D = load("res://afterburn/projectiles/player_round.tscn").instantiate()
	round_node.game = game
	round_node.shooter = game.player.get_rid()
	round_node.damage = 65.0
	round_node.position = game.player.camera.global_position
	round_node.direction = (charger.global_position - round_node.position).normalized()
	game.add_child(round_node)
	round_node.set_physics_process(false)
	round_node._physics_process(1.2)
	check(round_node.impacted and is_equal_approx(charger.hp, charger.max_hp - 65.0), "A travelling player round can damage the waiting ship at 60 meters")
	game.player.position.x += 6.0
	charger._physics_process(1.0)
	check(charger.attack_state == "charging" and is_equal_approx(charger.position.x, start.x) and charger.warning_path.global_position.is_equal_approx(path_start), "Charge locks to the marked straight line and does not follow a strafe")
	var moving_hp: float = charger.hp
	charger.get_damage(10, Vector3.ZERO)
	check(charger.hp == moving_hp - 10.0 and charger.collision_layer == 2, "Charger also remains vulnerable while rushing")
	var kills_before_escape: int = game.kills
	charger._physics_process(1.0)
	check(charger.attack_state == "passed" and game.player.current_health == 100.0 and charger.is_queued_for_deletion(), "Strafing clear avoids the rush and the passed ship cleans itself up")
	check(game.kills == kills_before_escape and not charger.warning_path.visible, "Dodging a charge removes its warning without awarding a kill")
	game.player.transform = player_transform
	var rammer: Node3D = game._spawn_enemy("charger")
	rammer.set_physics_process(false)
	game.player.position.z -= 15.0
	rammer._physics_process(rammer.warning_duration)
	game.player.position.z -= 16.0
	rammer._physics_process(1.0)
	check(rammer.hit_player and game.player.current_health == 20.0, "Fast swept charge accounts for player movement and deals 80 unarmored damage")
	rammer._physics_process(1.0)
	check(game.player.current_health == 20.0, "A charge damages the player at most once")
	check(game.player.hit_shake_time > 0.0, "Charger impact uses existing damage screen shake")
	game.player.transform = player_transform
	var stopped: Node3D = game._spawn_enemy("charger")
	stopped.set_physics_process(false)
	var before_kills: int = game.kills
	stopped.get_damage(99999, Vector3.ZERO)
	check(stopped.dying and not stopped.warning_path.visible and stopped.collision_layer == 0 and game.kills == before_kills + 1, "Shooting down a charger cancels its attack and awards a normal ship kill")
	var paused: Node3D = game._spawn_enemy("charger")
	paused.set_physics_process(false)
	var remaining: float = paused.warning_remaining
	game.pause_run()
	paused._physics_process(5.0)
	check(is_equal_approx(paused.warning_remaining, remaining), "Pausing freezes the charger warning")
	game.resume_run()
	paused.queue_free()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("afterburn_chargers").is_empty(), "Charger death and pass cleanup leave no active ships or orphan warning paths")
	game.player.transform = player_transform
	game.player.current_health = old_health
	game.player.armor = old_armor
	game.player.invulnerability = 0.0
	game.player._update_hit_shake(1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

func _check_obstacle_rules() -> void:
	var player_transform: Transform3D = game.player.transform
	var old_health: float = game.player.current_health
	game.player.current_health = 100.0
	game.player.armor = 0.0
	var solid: Node3D = load("res://afterburn/obstacles/solid_barrier.tscn").instantiate()
	solid.position = Vector3(60, 0, 0)
	game.add_child(solid)
	var solid_hp: float = solid.hp
	game.player.invulnerability = 0.0
	solid.get_damage(10000, Vector3.ZERO)
	solid.strike_player()
	check(not solid.spent and solid.hp == solid_hp and not solid.is_queued_for_deletion(), "Solid cover survives shots and player collisions")
	check(game.player.current_health < 100.0 and solid.collision_layer == 5, "Solid collision hurts the player and keeps physical collision")
	var fracture: Node3D = load("res://afterburn/obstacles/breakable_barrier.tscn").instantiate()
	fracture.position = Vector3(60, 0, -5)
	game.add_child(fracture)
	fracture.get_damage(65, Vector3.ZERO)
	check(not fracture.spent and fracture.hp == 65.0, "Breakable panel survives the first stock rifle shot")
	fracture.get_damage(65, Vector3.ZERO)
	check(fracture.spent and fracture.is_queued_for_deletion(), "Breakable panel is destroyed by two stock rifle shots")
	var ram_panel: Node3D = load("res://afterburn/obstacles/breakable_barrier.tscn").instantiate()
	ram_panel.position = Vector3(65, 0, -5)
	game.add_child(ram_panel)
	ram_panel.strike_player()
	check(ram_panel.spent, "Breakable panel can also be destroyed by player collision")
	var enemy_panel: Node3D = load("res://afterburn/obstacles/breakable_barrier.tscn").instantiate()
	enemy_panel.position = Vector3(65, 0, -10)
	game.add_child(enemy_panel)
	enemy_panel.get_damage(10000, Vector3.ZERO, true)
	check(not enemy_panel.spent and enemy_panel.hp == 130.0, "Enemy fire cannot clear the player's breakable obstacle")
	var beam: Node3D = load("res://afterburn/obstacles/low_beam.tscn").instantiate()
	beam.position = Vector3(65, 1.25, -15)
	game.add_child(beam)
	beam.get_damage(10000, Vector3.ZERO)
	beam.strike_player()
	check(not beam.spent and not beam.is_queued_for_deletion(), "Overhead beam stays intact after shots and contact")
	# Test a real player round against cover with an enemy behind it.
	var target: Node3D = game._spawn_enemy("guardian")
	target.position = Vector3(60, 0.8, -6)
	target.set_physics_process(false)
	var target_hp: float = target.hp
	await get_tree().physics_frame
	var round_node: Node3D = load("res://afterburn/projectiles/player_round.tscn").instantiate()
	round_node.game = game
	round_node.shooter = game.player.get_rid()
	round_node.position = Vector3(60, 0.8, 5)
	round_node.direction = Vector3.FORWARD
	game.add_child(round_node)
	round_node.set_physics_process(false)
	round_node._physics_process(0.2)
	check(round_node.impacted and target.hp == target_hp and not solid.spent, "Solid cover stops a travelling player round before it can hit a ship")
	solid.queue_free()
	target.queue_free()
	enemy_panel.queue_free()
	beam.queue_free()
	var high: Area3D = load("res://afterburn/obstacles/high_laser.tscn").instantiate()
	high.position = Vector3(60, 0, 0)
	game.add_child(high)
	high.set_physics_process(false)
	game.player.position = Vector3(60, 0.1, 0)
	game.player.capsule.height = 1.85
	game.player.get_node("CollisionShape3D").position.y = 0.925
	await get_tree().physics_frame
	await get_tree().physics_frame
	game.player.invulnerability = 0.0
	game.player.current_health = 100.0
	high._physics_process(0.0)
	check(game.player.current_health == 75.0, "High laser damages a standing player through a real Area3D overlap")
	high.get_damage(10000, Vector3.ZERO)
	high.strike_player()
	check(not high.spent and not high.is_queued_for_deletion(), "Lasers survive bullets and player contact")
	game.player.capsule.height = 0.9
	game.player.get_node("CollisionShape3D").position.y = 0.45
	# The real runner moves every tick; refresh the body's broadphase transform.
	game.player.position.z += 0.02
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not high.get_overlapping_bodies().has(game.player), "Sliding capsule fits safely under the high laser")
	high.queue_free()
	var low: Area3D = load("res://afterburn/obstacles/low_laser.tscn").instantiate()
	low.position = Vector3(60, 0, 0)
	game.add_child(low)
	low.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(low.get_overlapping_bodies().has(game.player), "Low laser still detects a sliding player")
	game.player.position.y = 0.8
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not low.get_overlapping_bodies().has(game.player), "Jumping clears the low laser hazard")
	low.queue_free()
	var fence: Area3D = load("res://afterburn/obstacles/laser_fence.tscn").instantiate()
	fence.position = Vector3(60, 0, 0)
	game.add_child(fence)
	fence.set_physics_process(false)
	game.player.position.y = 1.4
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(fence.get_overlapping_bodies().has(game.player), "Full-height laser fence cannot be cleared with a normal jump")
	game.player.position.x = 66.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not fence.get_overlapping_bodies().has(game.player), "Moving into the neighboring lane clears the laser fence")
	fence.queue_free()
	game.player.transform = player_transform
	game.player.capsule.height = 1.85
	game.player.get_node("CollisionShape3D").position.y = 0.925
	game.player.current_health = old_health
	game.player.invulnerability = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
