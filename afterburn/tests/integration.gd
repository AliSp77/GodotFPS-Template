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
	game = GameUnderTest.new()
	get_tree().root.add_child(game)
	await get_tree().process_frame
	check(game.state == "menu" and get_tree().paused, "Title screen freezes gameplay")
	check(get_tree().get_nodes_in_group("supplied_props").size() >= 40, "Map contains supplied collidable props")
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.weapons_manager.set_process(false)
	check(game.state == "play" and not get_tree().paused, "Starting a run resumes gameplay")
	check(game.player.weapons_manager.current_weapon.name == "AssualtRifle", "Run starts with the existing FPS rifle")
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
	weapon.try_fire(true)
	check(is_equal_approx(enemy.hp, before_hp - weapon.damage), "Original FPS weapon damage reaches the spaceship")
	var before_credits: int = game.profile.credits
	enemy.get_damage(9999, Vector3.ZERO)
	check(game.kills == 1 and game.profile.credits > before_credits, "Ship kill awards score and banked credits")
	await get_tree().process_frame
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
	game._clear_combat()
	get_tree().paused = false
	for audio in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		audio.stop()
	await get_tree().create_timer(0.2).timeout
	game.queue_free()
	await get_tree().process_frame
	print("AFTERBURN_INTEGRATION: ", checks - failures, "/", checks, " passed")
	get_tree().quit(1 if failures > 0 else 0)
