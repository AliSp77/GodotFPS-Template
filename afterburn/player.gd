extends "res://player/player.gd"

var game: Node
var armor: float = 50.0
var vital_capacity: float = 100.0
@export var run_speed: float = 16.0
@export var strafe_speed: float = 9.0
const RUN_STEP_INTERVAL: float = 0.27
const HIT_SHAKE_DURATION: float = 0.34
var run_phase: float = 0.0
var hit_shake_time: float = 0.0
var hit_shake_strength: float = 0.0
var camera_rest_position := Vector3.ZERO
var camera_rest_roll: float = 0.0
var dash_cooldown: float = 0.0
var dash_time: float = 0.0
var dash_vector := Vector3.ZERO
var mobility: float = 1.0
var damage_resistance: float = 1.0
var invulnerability: float = 0.0
var is_sliding: bool = false
var capsule: CapsuleShape3D

func _ready() -> void:
	super._ready()
	walk_speed = run_speed
	sprint_speed = run_speed
	camera_rest_position = camera.position
	camera_rest_roll = camera.rotation.z
	Global.player_sprinting_changed.emit(true)
	jump_velocity = 7.5
	capsule = $CollisionShape3D.shape.duplicate()
	$CollisionShape3D.shape = capsule

func _unhandled_input(event: InputEvent) -> void:
	if game and game.state == "play" and is_alive:
		super._unhandled_input(event)
		camera_pivot.rotation.y = clampf(camera_pivot.rotation.y, -1.25, 1.25)

func _physics_process(delta: float) -> void:
	if not game or game.state != "play" or not is_alive:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if is_on_floor() and not was_on_floor:
		audio_manager.play_footstep(true)
	was_on_floor = is_on_floor()
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	speed = run_speed * mobility
	is_sliding = (Input.is_action_pressed("crouch") or Input.is_action_pressed("backward")) and is_on_floor()
	var body_height: float = 0.9 if is_sliding else 1.85
	capsule.height = body_height
	$CollisionShape3D.position.y = body_height * 0.5
	camera_pivot.position.y = lerpf(camera_pivot.position.y, 0.85 if is_sliding else 1.7, minf(1.0, delta * 18.0))
	var strafe: float = Input.get_axis("left", "right")
	if (Input.is_action_just_pressed("afterburn_dash") or Input.is_action_just_pressed("sprint")) and dash_cooldown <= 0.0:
		dash_vector = Vector3(strafe * 1.4, 0, -1).normalized()
		dash_time = 0.2
		dash_cooldown = 3.0
		invulnerability = 0.24
	if dash_time > 0.0:
		velocity.x = dash_vector.x * 25.0
		velocity.z = dash_vector.z * 30.0
	else:
		velocity.x = lerpf(velocity.x, strafe * strafe_speed * mobility, minf(1.0, delta * 15.0))
		velocity.z = -speed
	run_phase += delta * TAU / RUN_STEP_INTERVAL * sqrt(mobility)
	var bob := Vector3(sin(run_phase * 0.5) * 0.035, sin(run_phase) * 0.055, 0.0)
	camera_holder.position = bob * (0.2 if is_sliding else float(is_on_floor()))
	_handle_runner_footsteps(delta)
	Global.player_velocity_changed.emit(velocity)
	move_and_slide()
	position.x = clampf(position.x, -9.0, 9.0)
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var collider: Object = collision.get_collider()
		if absf(collision.get_normal().y) < 0.5 and collider and collider.has_method("strike_player"):
			collider.strike_player()
	if position.y < -10.0:
		position.y = 1.0
		get_damage(25, Vector3.ZERO, true)

func _handle_runner_footsteps(delta: float) -> void:
	if is_on_floor() and not is_sliding:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = RUN_STEP_INTERVAL / sqrt(mobility)
			audio_manager.play_footstep(false)

func get_damage(damage: float, _direction: Vector3, is_enemy_damage: bool = false) -> void:
	if not is_alive or not game or game.state != "play" or invulnerability > 0.0:
		return
	var applied: float = damage * damage_resistance
	var absorbed: float = minf(armor, applied * 0.7)
	armor -= absorbed
	current_health = maxf(0.0, current_health - (applied - absorbed))
	invulnerability = 0.15
	Global.player_health_changed.emit(-applied, current_health, vital_capacity, is_enemy_damage)
	game.hud.damage_flash()
	hit_shake_time = HIT_SHAKE_DURATION
	hit_shake_strength = maxf(hit_shake_strength, clampf(applied * 0.003, 0.045, 0.11))
	_update_hit_shake(0.0)
	if current_health <= 0.0:
		is_alive = false
		Global.player_dead.emit()
		game.finish_run(false)

func _process(delta: float) -> void:
	if game and game.state == "play":
		_update_hit_shake(delta)

func _update_hit_shake(delta: float) -> void:
	hit_shake_time = maxf(0.0, hit_shake_time - delta)
	if hit_shake_time <= 0.0:
		hit_shake_strength = 0.0
		camera.position = camera_rest_position
		camera.rotation.z = camera_rest_roll
		return
	var elapsed: float = HIT_SHAKE_DURATION - hit_shake_time
	var envelope: float = pow(hit_shake_time / HIT_SHAKE_DURATION, 2.0)
	var amplitude: float = hit_shake_strength * envelope
	camera.position = camera_rest_position + Vector3(sin(elapsed * 83.0) * amplitude, cos(elapsed * 67.0) * amplitude, 0.0)
	camera.rotation.z = camera_rest_roll + sin(elapsed * 57.0) * amplitude * 0.4

