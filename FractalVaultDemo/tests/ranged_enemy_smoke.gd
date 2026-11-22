extends Node3D

@onready var player: Player = $Player
@onready var enemy: RangedEnemyBase = $Skirmisher
@onready var cover: StaticBody3D = $Cover
@onready var rear_barrier_shape: CollisionShape3D = $RearBarrier/CollisionShape3D

var shot_count: int = 0
var last_projectile: RangedEnemyProjectile
var block_next_shot: bool = false


func _ready() -> void:
	player.set_physics_process(false)
	enemy.shot_fired.connect(_on_shot_fired)
	call_deferred("_run_checks")


func _run_checks() -> void:
	await _frames(15)
	if not _check(enemy.awareness != FractalEnemyBase.Awareness.ENGAGED and shot_count == 0, "Cover did not prevent target acquisition"):
		return
	cover.position.x = 20.0
	for attempt in 30:
		if enemy.awareness == FractalEnemyBase.Awareness.ENGAGED:
			break
		await _frames(1)
	if not _check(enemy.awareness == FractalEnemyBase.Awareness.ENGAGED, "Skirmisher did not engage a visible player"):
		return
	for attempt in 100:
		if shot_count > 0:
			break
		await _frames(1)
	if not _check(shot_count == 1 and is_instance_valid(last_projectile), "Skirmisher did not fire one visible projectile"):
		return
	await _frames(40)
	if not _check(is_equal_approx(player.current_health, 92.0), "Projectile did not damage the player exactly once"):
		return
	if not _check(shot_count == 1, "Firing cooldown allowed an immediate second shot"):
		return

	enemy._cooldown_left = 0.0
	for attempt in 20:
		if enemy._windup_left > 0.0:
			break
		await _frames(1)
	if not _check(enemy._windup_left > 0.0 and enemy.aim_indicator.visible, "Windup warning was not shown"):
		return
	cover.position.x = 0.0
	await _frames(5)
	if not _check(enemy._windup_left == 0.0 and not enemy.aim_indicator.visible and shot_count == 1, "Cover did not cancel windup"):
		return

	cover.position.x = 20.0
	enemy._cooldown_left = 0.0
	for attempt in 25:
		if enemy._windup_left > 0.0:
			break
		await _frames(1)
	if not _check(enemy._windup_left > 0.0, "Second windup did not start"):
		return
	var dodged := enemy.notify_threat(player.global_position + Vector3.UP, 0.5)
	await _frames(3)
	if not _check(dodged and enemy._windup_left == 0.0 and not enemy.aim_indicator.visible, "Dodging did not cancel windup"):
		return
	await _frames(20)
	enemy._cooldown_left = 0.0
	block_next_shot = true
	var health_before_cover := player.current_health
	for attempt in 100:
		if shot_count == 2:
			break
		await _frames(1)
	if not _check(shot_count == 2, "Second projectile was not fired"):
		return
	await _frames(35)
	if not _check(is_equal_approx(player.current_health, health_before_cover), "Projectile passed through cover"):
		return
	if not _check(not is_instance_valid(last_projectile), "Projectile did not clean up after hitting cover"):
		return

	cover.position.x = 20.0
	enemy._cooldown_left = 999.0
	enemy.move_speed = 3.8
	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.1, -13)
	await _frames(35)
	if not _check(enemy.global_position.z < -0.35, "Ranged enemy did not approach from beyond its preferred distance"):
		return

	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy._reposition_left = 0.0
	enemy._reposition_target = Vector3.INF
	player.global_position = Vector3(0, 0.1, -8)
	await _frames(30)
	if not _check(absf(enemy.global_position.x) > 0.3, "Ranged enemy did not strafe inside its preferred distance band"):
		return

	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy._reposition_left = 0.0
	enemy._reposition_target = Vector3.INF
	player.global_position = Vector3(0, 0.1, -3)
	await _frames(35)
	if not _check(enemy.global_position.z > 0.35, "Ranged enemy did not retreat from a close player"):
		return

	enemy.global_position = Vector3.ZERO
	enemy.velocity = Vector3.ZERO
	enemy._reposition_left = 0.0
	enemy._reposition_target = Vector3.INF
	rear_barrier_shape.set_deferred(&"disabled", false)
	await _frames(3)
	if not _check(enemy._pick_reposition(Vector3.BACK, 3.0) == Vector3.INF, "Blocked retreat selected an obstructed destination"):
		return

	rear_barrier_shape.set_deferred(&"disabled", true)
	await _frames(2)
	enemy._fire_projectile(Vector3.FORWARD)
	var departing_projectile := last_projectile
	enemy.get_damage(1000.0, Vector3.FORWARD)
	await _frames(3)
	if not _check(not is_instance_valid(departing_projectile), "Shooter death left a live projectile"):
		return
	for encounter_name in ["forge_assault", "relay_onslaught"]:
		var encounter: EncounterDefinition = load("res://FractalVaultDemo/stages/catalog/encounters/%s.tres" % encounter_name)
		var found := false
		for entry in encounter.entries:
			if entry.enemy_scene.resource_path.ends_with("fractal_skirmisher.tscn"):
				found = true
		if not _check(found, "Skirmisher is missing from " + encounter_name):
			return
	print("RANGED_ENEMY_SMOKE_OK")
	get_tree().quit()


func _on_shot_fired(projectile: RangedEnemyProjectile) -> void:
	shot_count += 1
	last_projectile = projectile
	if block_next_shot:
		block_next_shot = false
		cover.position.x = 0.0


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("RANGED_ENEMY_SMOKE_FAIL: " + message)
		get_tree().quit(1)
	return condition
