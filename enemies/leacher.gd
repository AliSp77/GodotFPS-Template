
extends CharacterBody3D

enum State { PATROL, RUSH, RECOVER, GRAB }

@export_group("Movement")
@export var move_speed: float = 3.5
@export var gravity: float = 9.8
@export var rotation_speed: float = 5.0

@export_group("Vision")
@export var lose_sight_delay: float = 0.5
@export var player_aim_height: float = 1.0

@export_group("Grab")
@export var grab_distance: float = 1.6
@export var grab_cooldown: float = 6.0

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var ray: RayCast3D = $RayCast3D
@onready var bt_player: BTPlayer = $BTPlayer
@onready var state_label: Label3D = $StateLabel
@onready var body_visual: MeshInstance3D = $Visual/MeshInstance3D
@onready var rush_particles: GPUParticles3D = $Visual/GPUParticles3D
@onready var rush_sfx: AudioStreamPlayer3D = $RushSFX
@onready var recover_sfx: AudioStreamPlayer3D = $RecoverSFX

var moving: bool = false
var chasing: bool = false
var navigation_updated: bool = false
var state: State = State.PATROL
var patrol_speed: float
var body_material: StandardMaterial3D
var particle_material: ParticleProcessMaterial

var target_player: Player = null
var player_in_sensor: bool = false
var sight_loss_timer: float = 0.0
var held_player: Player
var grab_cooldown_left: float = 0.0


func _ready() -> void:
	patrol_speed = move_speed
	body_material = body_visual.get_surface_override_material(0).duplicate() as StandardMaterial3D
	body_visual.set_surface_override_material(0, body_material)
	particle_material = rush_particles.process_material.duplicate() as ParticleProcessMaterial
	rush_particles.process_material = particle_material
	_set_state(State.PATROL, patrol_speed)

	# Prevent the raycast from hitting Leacher itself.
	ray.add_exception(self)

	# Initialize the Behavior Tree state.
	if bt_player.blackboard != null:
		bt_player.blackboard.set_var(
			&"is_chasing", false
		)


# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------

func begin_move(destination: Vector3) -> void:
	navigation_updated = false
	nav.target_position = destination
	moving = true


func end_move() -> void:
	moving = false
	velocity.x = 0.0
	velocity.z = 0.0


# --------------------------------------------------
# PLAYER DETECTION
# --------------------------------------------------

func _on_vision_sensor_body_entered(body: Node3D) -> void:
	if body is Player:
		target_player = body
		player_in_sensor = true

		print("[Vision] Player entered detection area")


func _on_vision_sensor_body_exited(body: Node3D) -> void:
	if body == target_player:
		player_in_sensor = false

		# Do not clear target_player yet.
		# The chase task may still need this reference.
		print("[Vision] Player left detection area")


func can_see_player() -> bool:
	if not player_in_sensor:
		return false

	if not is_instance_valid(target_player):
		return false

	# Aim at the player's body instead of its feet.
	var target_pos: Vector3 = (
		target_player.global_position
		+ Vector3.UP * player_aim_height
	)

	# RayCast3D.target_position uses LOCAL coordinates.
	ray.target_position = ray.to_local(target_pos)

	# Update collision results immediately.
	ray.force_raycast_update()

	if not ray.is_colliding():
		return false

	# The first object hit must be the player.
	return ray.get_collider() == target_player


func update_vision(delta: float) -> bool:
	if is_instance_valid(held_player):
		return false
	var visible: bool = can_see_player()

	if visible:
		sight_loss_timer = 0.0
		set_chasing(true)
	else:
		sight_loss_timer += delta

		if chasing and sight_loss_timer >= lose_sight_delay:
			set_chasing(false)

			# Clear the player reference only when
			# they have also left the detection area.
			if not player_in_sensor:
				target_player = null

	return visible


func set_chasing(value: bool) -> void:
	# Avoid unnecessary Blackboard writes.
	if chasing == value:
		return

	chasing = value
	if not chasing:
		_set_state(State.PATROL, patrol_speed)

	if bt_player.blackboard != null:
		bt_player.blackboard.set_var(
			&"is_chasing",
			chasing
		)

	if chasing:
		print("[AI] Player detected -> CHASE")
	else:
		print("[AI] Player lost -> PATROL")


func set_chase_phase(phase: StringName, speed: float) -> void:
	if not chasing:
		return
	match phase:
		&"rush":
			_set_state(State.RUSH, speed)
		&"recover":
			_set_state(State.RECOVER, speed)


func can_grab_player() -> bool:
	if is_instance_valid(held_player):
		return true
	if not chasing or grab_cooldown_left > 0.0:
		return false
	if not is_instance_valid(target_player) or not target_player.is_alive or target_player.is_grabbed:
		return false
	var offset: Vector3 = target_player.global_position - global_position
	offset.y = 0.0
	return offset.length_squared() <= grab_distance * grab_distance


func grab_player(lift_height: float) -> bool:
	if not can_grab_player() or is_instance_valid(held_player):
		return false
	if not target_player.begin_leacher_grab(self, lift_height):
		return false
	held_player = target_player
	end_move()
	_set_state(State.GRAB, move_speed)
	return true


func start_carry(destination: Vector3, speed: float) -> void:
	if is_instance_valid(held_player):
		move_speed = speed
		begin_move(destination)


func release_player() -> void:
	if not is_instance_valid(held_player):
		held_player = null
		return
	end_move()
	var release_position: Vector3 = global_position - global_basis.z * 1.6
	var nav_map: RID = nav.get_navigation_map()
	if nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0:
		release_position = NavigationServer3D.map_get_closest_point(nav_map, release_position)
	held_player.end_leacher_grab(release_position)
	held_player = null
	grab_cooldown_left = grab_cooldown
	set_chasing(false)


func _set_state(next_state: State, speed: float) -> void:
	state = next_state
	move_speed = speed
	match state:
		State.PATROL:
			rush_sfx.stop()
			recover_sfx.stop()
			state_label.modulate = Color(1.0, 0.55, 1.0)
			body_material.albedo_color = Color(1.0, 0.0, 1.0)
			particle_material.color = Color(1.0, 0.0, 1.0)
			print("[Leacher] PATROL")
		State.RUSH:
			recover_sfx.stop()
			state_label.modulate = Color(1.0, 0.3, 0.3)
			body_material.albedo_color = Color(1.0, 0.08, 0.12)
			particle_material.color = Color(1.0, 0.1, 0.1)
			rush_particles.restart()
			rush_sfx.play()
			print("[Leacher] RUSH")
		State.RECOVER:
			rush_sfx.stop()
			state_label.modulate = Color(1.0, 0.75, 0.25)
			body_material.albedo_color = Color(1.0, 0.55, 0.1)
			particle_material.color = Color(1.0, 0.55, 0.1)
			recover_sfx.play()
			print("[Leacher] RECOVER")
		State.GRAB:
			recover_sfx.stop()
			state_label.modulate = Color(0.35, 0.9, 1.0)
			body_material.albedo_color = Color(0.08, 0.65, 1.0)
			particle_material.color = Color(0.2, 0.85, 1.0)
			rush_particles.restart()
			rush_sfx.play()
			print("[Leacher] GRAB")
	rush_particles.emitting = state == State.RUSH or state == State.GRAB
	_update_state_label()


func _update_state_label() -> void:
	match state:
		State.PATROL:
			state_label.text = "LEACHER // PATROL"
		State.RUSH:
			state_label.text = "LEACHER // RUSH"
		State.RECOVER:
			state_label.text = "LEACHER // RECOVER"
		State.GRAB:
			state_label.text = "LEACHER // GRAB"


# --------------------------------------------------
# ROTATION
# --------------------------------------------------


func rotate_toward_player(delta: float) -> void:
	if not is_instance_valid(target_player):
		return

	var direction: Vector3 = (
		target_player.global_position - global_position
	)

	rotate_toward_direction(direction, delta)


# --------------------------------------------------
# PHYSICS
# --------------------------------------------------


func _physics_process(delta: float) -> void:
	# 1. Update player visibility.
	grab_cooldown_left = maxf(0.0, grab_cooldown_left - delta)
	var player_visible: bool = false
	if held_player != null:
		if not is_instance_valid(held_player) or not held_player.is_alive:
			release_player()
	else:
		player_visible = update_vision(delta)

	# 2. Rotate toward the player when chasing
	# and the player is visible.
	if chasing and player_visible:
		rotate_toward_player(delta)

	# 3. Navigation movement.
	if moving:
		var next_point: Vector3 = global_position

		if not navigation_updated or not nav.is_navigation_finished():
			next_point = nav.get_next_path_position()
			navigation_updated = true

		if not nav.is_navigation_finished():
			var direction: Vector3 = (
				next_point - global_position
			)

			direction.y = 0.0

			if direction.length_squared() > 0.0001:
				direction = direction.normalized()

				velocity.x = direction.x * move_speed
				velocity.z = direction.z * move_speed

				# Face the navigation direction while
				# patrolling or when the player is hidden.
				if not (chasing and player_visible):
					rotate_toward_direction(direction, delta)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# 4. Gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# 5. Apply movement.
	move_and_slide()
	if is_instance_valid(held_player):
		held_player.sync_grab_position()


func _exit_tree() -> void:
	if is_instance_valid(held_player):
		release_player()


func rotate_toward_direction(direction: Vector3, delta: float) -> void:
	direction.y = 0.0

	if direction.length_squared() <= 0.0001:
		return

	var target_angle: float = atan2(
		-direction.x,
		-direction.z
	)

	global_rotation.y = lerp_angle(
		global_rotation.y,
		target_angle,
		clampf(rotation_speed * delta, 0.0, 1.0)
	)
