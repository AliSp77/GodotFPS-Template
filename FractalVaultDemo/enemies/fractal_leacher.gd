class_name FractalLeacher
extends FractalEnemyBase

enum ChasePhase { RUSH, RECOVER }

signal player_grabbed(player: Player)
signal player_released(player: Player)

@export_group("Leacher Chase")
@export var rush_speed: float = 8.5
@export var rush_duration: float = 1.2
@export var recover_speed: float = 1.2
@export var recover_duration: float = 1.0

@export_group("Leacher Grab")
@export var grab_distance: float = 1.6
@export var grab_lift_height: float = 2.2
@export var grab_cooldown: float = 6.0
@export var carry_speed: float = 8.5
@export var carry_duration: float = 10.0
@export var carry_min_distance: float = 12.0
@export var carry_max_distance: float = 24.0
@export var carry_arrival_distance: float = 1.2

var held_player: Player
var chase_phase: ChasePhase = ChasePhase.RUSH
var grab_cooldown_left: float = 0.0
var carry_destination: Vector3
var _phase_left: float = 0.0
var _carry_left: float = 0.0
var _carry_stuck_left: float = 0.0
var _grab_attempt_left: float = 0.0


func _physics_process(delta: float) -> void:
	grab_cooldown_left = maxf(0.0, grab_cooldown_left - delta)
	_grab_attempt_left = maxf(0.0, _grab_attempt_left - delta)
	if is_instance_valid(held_player):
		if not held_player.is_alive or not held_player.is_grabbed or held_player.grabber != self:
			release_player()
		else:
			_carry_physics(delta)
			return
	if awareness == Awareness.DEAD:
		super._physics_process(delta)
		return
	var regular_speed := move_speed
	if awareness == Awareness.ENGAGED:
		_phase_left -= delta
		if _phase_left <= 0.0:
			chase_phase = ChasePhase.RECOVER if chase_phase == ChasePhase.RUSH else ChasePhase.RUSH
			_phase_left = recover_duration if chase_phase == ChasePhase.RECOVER else rush_duration
		move_speed = rush_speed if chase_phase == ChasePhase.RUSH else recover_speed
	else:
		chase_phase = ChasePhase.RUSH
		_phase_left = rush_duration
	# Perception, investigation, pursuit, damage, and normal animations stay in the base.
	super._physics_process(delta)
	move_speed = regular_speed
	if _grab_attempt_left <= 0.0 and can_grab_player():
		_grab_attempt_left = 0.5
		grab_player()
	_update_state_indicator()


func can_grab_player() -> bool:
	if awareness != Awareness.ENGAGED or grab_cooldown_left > 0.0 or not is_on_floor():
		return false
	if is_instance_valid(held_player) or not is_instance_valid(target_player):
		return false
	if not target_player.is_alive or target_player.is_grabbed:
		return false
	var offset := target_player.global_position - global_position
	if absf(offset.y) > 1.25:
		return false
	offset.y = 0.0
	return offset.length_squared() <= grab_distance * grab_distance and _find_visible_player() == target_player


func grab_player(lift_height: float = -1.0) -> bool:
	if not can_grab_player():
		return false
	var destination := _find_carry_destination()
	if destination == Vector3.INF:
		return false
	var height := grab_lift_height if lift_height < 0.0 else lift_height
	if not target_player.begin_leacher_grab(self, height):
		return false
	held_player = target_player
	carry_destination = destination
	_carry_left = carry_duration
	_carry_stuck_left = 0.0
	_dodge_left = 0.0
	velocity = Vector3.ZERO
	play_enemy_animation(&"attack")
	player_grabbed.emit(held_player)
	_update_state_indicator()
	return true


func _find_carry_destination() -> Vector3:
	var map := navigation_agent.get_navigation_map()
	var use_navigation := map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty()
	var minimum := maxf(1.0, carry_min_distance)
	var maximum := maxf(minimum, carry_max_distance)
	for attempt in range(32):
		var angle := randf_range(0.0, TAU)
		var sample := global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(minimum, maximum)
		if use_navigation:
			sample = NavigationServer3D.map_get_closest_point(map, sample)
			var distance := Vector2(sample.x, sample.z).distance_to(Vector2(global_position.x, global_position.z))
			if distance < minimum or distance > maximum:
				continue
			var path := NavigationServer3D.map_get_path(map, global_position, sample, true, navigation_agent.navigation_layers)
			if path.size() < 2 or path[path.size() - 1].distance_to(sample) > 0.75:
				continue
		else:
			if test_move(global_transform, sample - global_position):
				continue
			var ground := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
				sample + Vector3.UP * 2.0, sample + Vector3.DOWN * 3.0, collision_mask, [get_rid()]))
			if ground.is_empty() or ground.normal.dot(Vector3.UP) < cos(floor_max_angle):
				continue
			sample = ground.position
		return sample
	return Vector3.INF


func _carry_physics(delta: float) -> void:
	_carry_left -= delta
	var distance := Vector2(global_position.x, global_position.z).distance_to(Vector2(carry_destination.x, carry_destination.z))
	if _carry_left <= 0.0 or distance <= carry_arrival_distance:
		release_player()
		return
	var direction := _direction_to(carry_destination)
	velocity.x = direction.x * carry_speed
	velocity.z = direction.z * carry_speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	var next_position := global_position + velocity * delta
	var carry_position := next_position + Vector3.UP * held_player.grab_height
	var ground := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		next_position + Vector3.UP * 0.5, next_position + Vector3.DOWN * 2.0, collision_mask, [get_rid(), held_player.get_rid()]))
	if ground.is_empty() or not held_player.can_move_to_grab_position(carry_position, self):
		release_player()
		return
	var before := global_position
	move_and_slide()
	if not held_player.sync_grab_position():
		release_player()
		return
	var travelled := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_carry_stuck_left = _carry_stuck_left + delta if travelled < 0.05 * delta else 0.0
	if _carry_stuck_left >= 0.5:
		release_player()
		return
	if direction.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 8.0 * delta))
	_sync_animation()
	_update_state_indicator()


func release_player() -> void:
	var released := held_player
	held_player = null
	velocity = Vector3.ZERO
	grab_cooldown_left = grab_cooldown
	chase_phase = ChasePhase.RECOVER
	_phase_left = recover_duration
	if is_instance_valid(released) and released.is_grabbed and released.grabber == self:
		var release_position := released.find_safe_leacher_release(global_position, -global_basis.z)
		released.end_leacher_grab(release_position)
		player_released.emit(released)
	_update_state_indicator()


func notify_threat(origin: Vector3, time_to_impact: float) -> bool:
	if is_instance_valid(held_player):
		return false
	return super.notify_threat(origin, time_to_impact)


func _update_state_indicator() -> void:
	super._update_state_indicator()
	if not show_state_indicator:
		return
	if is_instance_valid(held_player):
		state_indicator.text = "FRACTAL LEACHER\nCARRY %.1fs" % maxf(0.0, _carry_left)
		state_indicator.modulate = Color(0.2, 0.9, 1.0)
	elif awareness == Awareness.ENGAGED:
		state_indicator.text = "FRACTAL LEACHER\n" + ("RUSH" if chase_phase == ChasePhase.RUSH else "RECOVER")
		state_indicator.modulate = Color(1.0, 0.25, 0.3) if chase_phase == ChasePhase.RUSH else Color(1.0, 0.7, 0.2)
	else:
		state_indicator.text = "FRACTAL LEACHER\n" + state_indicator.text


func _die() -> void:
	if _death_started:
		return
	if is_instance_valid(held_player):
		release_player()
	super._die()


func _exit_tree() -> void:
	# Scene teardown can remove the physics world before a grounded drop can be queried.
	var released := held_player
	held_player = null
	if is_instance_valid(released) and released.is_grabbed and released.grabber == self:
		released.end_leacher_grab()
		player_released.emit(released)
