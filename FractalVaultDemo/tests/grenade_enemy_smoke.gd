extends Node3D

@onready var player: Player = $Player
@onready var cover: StaticBody3D = $Cover

func _ready() -> void:
	player.set_physics_process(false)
	player.global_position = Vector3(8, 0.1, 0)
	call_deferred("_run_checks")

func _run_checks() -> void:
	var single_enemy := load("res://FractalVaultDemo/enemies/grenadier_single.tscn").instantiate() as Grenadier
	var square_enemy := load("res://FractalVaultDemo/enemies/grenadier_square.tscn").instantiate() as Grenadier
	if not _check(single_enemy != null and square_enemy != null, "Grenadier variants failed to load"):
		return
	if not _check(is_equal_approx(single_enemy.windup_duration, 0.65) and is_equal_approx(single_enemy.firing_cooldown, 3.5), "Grenadier attack timing is wrong"):
		return
	if not _check(single_enemy.projectile_scene.resource_path.ends_with("grenade_volley_single.tscn") and square_enemy.projectile_scene.resource_path.ends_with("grenade_volley_square.tscn"), "Variants do not assign separate authored projectile scenes"):
		return
	for variant in [single_enemy, square_enemy]:
		variant.set_physics_process(false)
		add_child(variant)
		variant.target_player = player
		variant._fire_projectile(Vector3.FORWARD)
		var fired := get_child(get_child_count() - 1) as GrenadeVolley
		var expected_cores := 1 if variant == single_enemy else 4
		if not _check(fired != null and fired.get_child_count() == expected_cores and fired.target_position.distance_to(player.global_position) < 0.001 and fired.global_position.distance_to(variant.muzzle.global_position) < 0.001, "Grenadier firing hook did not launch its authored volley from the muzzle"):
			return
		variant.queue_free()
		await _frames(2)
		if not _check(is_instance_valid(fired) and not fired.is_queued_for_deletion(), "Fired volley disappeared when its grenadier died"):
			return
		fired.queue_free()
		await _frames(2)

	var square := _volley("res://FractalVaultDemo/enemies/grenade_volley_square.tscn", Vector3(0, 1.4, 0), Vector3(0, 0.6, -8))
	if not _check(square.get_child_count() == 4 and square.is_in_group("encounter_hazard"), "Square volley must contain four hazard cores"):
		return
	for core in square.get_children():
		if not _check(core is GrenadeCore and core.global_position.distance_to(square.global_position) < 0.001 and core.flight_path.curve.point_count == 3, "Cores must start together with editable paths"):
			return
	square.target_position = Vector3(20, 0, 20)
	if not _check((square.get_child(0) as GrenadeCore).target_position.distance_to(Vector3(0, 0.6, -8)) < 0.001, "Fired cores did not snapshot the target position"):
		return
	square.shooter = null
	await _frames(28)
	if not _check(is_instance_valid(square), "Volley disappeared when shooter was absent"):
		return
	var xs: Array[float] = []
	for core in square.get_children():
		xs.append(core.global_position.x)
	if not _check(xs.min() < -0.35 and xs.max() > 0.35, "Square did not spread during flight"):
		return
	square.queue_free()
	await _frames(2)

	cover.global_position = Vector3(0, 1.25, -3)
	var bounced := _volley("res://FractalVaultDemo/enemies/grenade_volley_single.tscn", Vector3(0, 1.4, 0), Vector3(0, 0.6, -8), 0.0)
	var bounced_core := bounced.get_child(0) as GrenadeCore
	for frame in 55:
		await _frames(1)
		if bounced_core.phase == GrenadeCore.Phase.BOUNCING:
			break
	if not _check(bounced_core.phase == GrenadeCore.Phase.BOUNCING and bounced_core.bounce_velocity.z > 0.0, "Wall contact did not bounce the airborne core"):
		return
	bounced.queue_free()
	cover.global_position.x = 20.0
	await _frames(2)

	var direct := _volley("res://FractalVaultDemo/enemies/grenade_volley_single.tscn", Vector3(8, 1.1, 3), player.global_position + Vector3.UP, 0.0)
	await _frames(55)
	if not _check(is_equal_approx(player.current_health, 82.0), "Airborne core did not contact and damage player once"):
		return
	direct.queue_free()
	await _frames(2)

	player.global_position = Vector3(0, 0.1, -3)
	cover.global_position = Vector3(0, 1.25, -1.5)
	await _frames(2)
	var blast := _volley("res://FractalVaultDemo/enemies/grenade_volley_single.tscn", Vector3(0, 1, 0), Vector3(0, 0.6, 6))
	blast.apply_explosion(Vector3(0, 1, -0.8), 2.5)
	if not _check(is_equal_approx(player.current_health, 82.0), "Cover did not block explosion damage"):
		return
	cover.global_position.x = 20.0
	await _frames(2)
	blast.apply_explosion(Vector3(0, 1, -0.8), 2.5)
	blast.apply_explosion(Vector3(0, 1, -0.8), 2.5)
	if not _check(is_equal_approx(player.current_health, 64.0), "Blast damaged player more than once or failed when unobstructed"):
		return
	blast.queue_free()
	await _frames(2)

	player.global_position.x = 20.0
	var ground := _volley("res://FractalVaultDemo/enemies/grenade_volley_single.tscn", Vector3(0, 1.4, 0), Vector3(0, 0.6, -6))
	var core := ground.get_child(0) as GrenadeCore
	var settled := false
	for frame in 240:
		await _frames(1)
		if is_instance_valid(core) and core.phase == GrenadeCore.Phase.ARMED:
			settled = true
			break
	if not _check(settled and core.warning_visual.visible and is_equal_approx(core.fuse_left, 2.0), "Settled grenade did not show its warning sphere and start a two-second fuse"):
		return
	var fuse_before := core.fuse_left
	var health_before_ground_contact := player.current_health
	player.global_position = core.global_position - Vector3.UP
	await _frames(15)
	if not _check(core.phase == GrenadeCore.Phase.ARMED and core.fuse_left < fuse_before and core.warning_visual.visible and is_equal_approx(player.current_health, health_before_ground_contact), "Ground contact shortened the fuse or warning"):
		return
	await _frames(160)
	if not _check(not is_instance_valid(ground), "Grenade hazard did not clean up after detonation"):
		return
	$Floor.collision_layer = 0
	var lost := _volley("res://FractalVaultDemo/enemies/grenade_volley_single.tscn", Vector3(0, 10, 0), Vector3(0, 10, -8), 0.0)
	await _frames(310)
	if not _check(not is_instance_valid(lost), "Airborne grenade exceeded the five-second lifetime"):
		return
	print("GRENADE_ENEMY_SMOKE_OK")
	get_tree().quit()

func _volley(path: String, origin: Vector3, destination: Vector3, height: float = 2.0) -> GrenadeVolley:
	var result := load(path).instantiate() as GrenadeVolley
	result.position = origin
	result.target_position = destination
	result.speed = 10.0
	result.damage = 18.0
	result.arc_height = height
	add_child(result)
	return result

func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("GRENADE_ENEMY_SMOKE_FAIL: " + message)
	get_tree().quit(1)
	return false
