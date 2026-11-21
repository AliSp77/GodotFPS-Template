class_name FractalEnemyBase
extends CharacterBody3D

enum Awareness { IDLE, INVESTIGATE, ENGAGED, SEARCH, DEAD }

signal awareness_changed(previous, current)
signal damaged(amount: float, health: float)
signal died
signal animation_requested(name: StringName)

@export_group("Vitals")
@export var max_health: float = 100.0
@export var move_speed: float = 3.0
@export var acceleration: float = 12.0

@export_group("Senses")
@export var vision_range: float = 10.0
@export_range(1.0, 180.0) var vision_angle_degrees: float = 90.0
@export var hearing_sensitivity: float = 1.0
@export var search_duration: float = 4.0
@export var investigation_travel_timeout: float = 30.0

@export_group("Dodge")
@export var dodge_distance: float = 1.5
@export var dodge_duration: float = 0.3
@export var dodge_cooldown: float = 2.0

@export_group("Debug")
@export var show_state_indicator: bool = true

@onready var state_indicator: Label3D = $StateIndicator
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var vision_sensor: Area3D = $VisionSensor
@onready var sight_ray: RayCast3D = $SightRay
@onready var visuals: Node3D = $Visuals
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var head_hurt_point: CollisionObject3D = $HurtPoints/Head

var current_health: float
var awareness: Awareness = Awareness.IDLE
var target_player: Player
var last_known_position: Vector3
var has_last_known_position: bool = false

var _vision_timer: float = 0.0
var _memory_left: float = 0.0
var _investigation_travel_left: float = 0.0
var _investigation_moving: bool = false
var _dodge_cooldown_left: float = 0.0
var _dodge_left: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var _animation_lock_left: float = 0.0
var _death_started: bool = false


func _ready() -> void:
	current_health = max_health
	floor_snap_length = 0.3
	vision_sensor.set("length", vision_range)
	vision_sensor.set("angle", vision_angle_degrees)
	sight_ray.add_exception(self)
	Global.noise_emitted.connect(_on_noise_emitted)
	play_enemy_animation(&"idle")
	_update_state_indicator()


func _physics_process(delta: float) -> void:
	_update_state_indicator()
	if awareness == Awareness.DEAD:
		return

	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	_animation_lock_left = maxf(0.0, _animation_lock_left - delta)
	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = 0.12
		var seen_player := _find_visible_player()
		if seen_player != null:
			target_player = seen_player
			last_known_position = seen_player.global_position
			has_last_known_position = true
			_set_awareness(Awareness.ENGAGED)
		elif awareness == Awareness.ENGAGED:
			target_player = null
			_memory_left = search_duration
			_investigation_travel_left = investigation_travel_timeout
			_set_awareness(Awareness.SEARCH)

	if awareness == Awareness.INVESTIGATE or awareness == Awareness.SEARCH:
		var offset := last_known_position - global_position
		var arrived := Vector2(offset.x, offset.z).length() <= navigation_agent.target_desired_distance
		# Spend the search time at the destination, or while genuinely blocked.
		# Travelling through a hallway must not consume the entire investigation.
		if arrived or not _investigation_moving:
			_memory_left -= delta
		_investigation_travel_left -= delta
		if _memory_left <= 0.0 or _investigation_travel_left <= 0.0:
			has_last_known_position = false
			_set_awareness(Awareness.IDLE)

	var desired_direction := Vector3.ZERO
	if _dodge_left > 0.0:
		_dodge_left = maxf(0.0, _dodge_left - delta)
		desired_direction = _dodge_direction
		velocity.x = desired_direction.x * dodge_distance / maxf(dodge_duration, 0.01)
		velocity.z = desired_direction.z * dodge_distance / maxf(dodge_duration, 0.01)
	elif awareness == Awareness.ENGAGED and is_instance_valid(target_player):
		desired_direction = _direction_to(target_player.global_position)
	elif has_last_known_position and (awareness == Awareness.INVESTIGATE or awareness == Awareness.SEARCH):
		desired_direction = _direction_to(last_known_position)

	if _dodge_left <= 0.0:
		velocity.x = move_toward(velocity.x, desired_direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, desired_direction.z * move_speed, acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	var previous_position := global_position
	move_and_slide()
	var motion := global_position - previous_position
	_investigation_moving = desired_direction.length_squared() > 0.001 and Vector2(motion.x, motion.z).length() > 0.05 * delta

	var facing_direction := desired_direction
	if awareness == Awareness.ENGAGED and is_instance_valid(target_player):
		facing_direction = target_player.global_position - global_position
		facing_direction.y = 0.0
	if facing_direction.length_squared() > 0.001 and _dodge_left <= 0.0:
		var target_yaw := atan2(-facing_direction.x, -facing_direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, 8.0 * delta))
	_sync_animation()


func _find_visible_player() -> Player:
	for body in vision_sensor.get_overlapping_bodies():
		if body is Player and body.is_alive:
			var player := body as Player
			sight_ray.target_position = sight_ray.to_local(player.global_position + Vector3.UP)
			sight_ray.force_raycast_update()
			if sight_ray.is_colliding() and sight_ray.get_collider() == player:
				return player
	return null


func _direction_to(destination: Vector3) -> Vector3:
	var target := destination
	var stopping_distance := navigation_agent.target_desired_distance
	var map := navigation_agent.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
		var nearest := NavigationServer3D.map_get_closest_point(map, global_position)
		var gap := Vector2(global_position.x, global_position.z).distance_to(Vector2(nearest.x, nearest.z))
		if gap <= 1.0:
			# Align raised navigation points with the character's physical feet.
			navigation_agent.path_height_offset = nearest.y - global_position.y
			var navigation_target := NavigationServer3D.map_get_closest_point(map, destination)
			if navigation_agent.target_position.distance_squared_to(navigation_target) > 0.01 or navigation_agent.get_current_navigation_path().is_empty():
				navigation_agent.target_position = navigation_target
			# Refresh the path before asking whether navigation has finished.
			target = navigation_agent.get_next_path_position()
			if navigation_agent.is_navigation_finished():
				return Vector3.ZERO
			# Let the agent advance intermediate waypoints before stopping.
			stopping_distance = 0.01
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() <= stopping_distance:
		return Vector3.ZERO
	return direction.normalized()


func _on_noise_emitted(noise_position: Vector3, radius: float, source: Node3D) -> void:
	if awareness == Awareness.DEAD or not source is Player:
		return
	if not is_instance_valid(source) or not (source as Player).is_alive:
		return
	if global_position.distance_to(noise_position) > radius * maxf(0.0, hearing_sensitivity):
		return
	last_known_position = noise_position
	has_last_known_position = true
	if awareness != Awareness.ENGAGED:
		target_player = null
		_memory_left = search_duration
		_investigation_travel_left = investigation_travel_timeout
		_set_awareness(Awareness.INVESTIGATE)


func get_damage(amount: float, direction: Vector3, _is_enemy_damage: bool = false) -> void:
	if awareness == Awareness.DEAD or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	damaged.emit(amount, current_health)
	if current_health <= 0.0:
		_die()
		return
	if awareness != Awareness.ENGAGED:
		var from_direction := -direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO
		last_known_position = global_position + from_direction * 2.0
		has_last_known_position = true
		_memory_left = search_duration
		_investigation_travel_left = investigation_travel_timeout
		_set_awareness(Awareness.INVESTIGATE)
	play_enemy_animation(&"hurt")
	_animation_lock_left = 0.25


func notify_threat(origin: Vector3, time_to_impact: float) -> bool:
	if awareness == Awareness.DEAD or _dodge_cooldown_left > 0.0 or not is_on_floor():
		return false
	if time_to_impact < 0.12 or time_to_impact > 1.5:
		return false
	var toward_threat := origin - sight_ray.global_position
	if toward_threat.length_squared() < 0.01 or toward_threat.length() > vision_range:
		return false
	if (-global_basis.z).dot(toward_threat.normalized()) < cos(deg_to_rad(vision_angle_degrees * 0.5)):
		return false
	sight_ray.target_position = sight_ray.to_local(origin)
	sight_ray.force_raycast_update()
	if sight_ray.is_colliding() and not sight_ray.get_collider() is Player:
		return false
	var horizontal := origin - global_position
	horizontal.y = 0.0
	if horizontal.length_squared() < 0.01:
		return false
	var side := Vector3.UP.cross(horizontal.normalized())
	for candidate in [side, -side]:
		if _can_dodge(candidate):
			_dodge_direction = candidate
			_dodge_left = dodge_duration
			_dodge_cooldown_left = dodge_cooldown
			play_enemy_animation(&"dodge")
			_animation_lock_left = dodge_duration
			return true
	return false


func _can_dodge(direction: Vector3) -> bool:
	var displacement := direction * dodge_distance
	if test_move(global_transform, displacement):
		return false
	var landing := global_position + displacement
	var floor_query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP, landing + Vector3.DOWN * 2.0, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty()


func play_enemy_animation(clip_name: StringName) -> void:
	animation_requested.emit(clip_name)
	if animation_player.has_animation(clip_name):
		animation_player.play(clip_name)


func _sync_animation() -> void:
	if awareness == Awareness.DEAD or _animation_lock_left > 0.0:
		return
	var motion := Vector2(velocity.x, velocity.z).length()
	var desired := &"move" if motion > 0.15 else &"idle"
	if animation_player.current_animation != String(desired):
		play_enemy_animation(desired)


func _set_awareness(next: Awareness) -> void:
	if awareness == next:
		return
	var previous := awareness
	awareness = next
	_update_state_indicator()
	awareness_changed.emit(previous, next)
	if next == Awareness.ENGAGED:
		play_enemy_animation(&"alert")
		_animation_lock_left = 0.35


func _update_state_indicator() -> void:
	state_indicator.visible = show_state_indicator
	if not show_state_indicator:
		return
	var state_text: String = "IDLE"
	var state_color := Color(0.65, 0.85, 1.0)
	match awareness:
		Awareness.INVESTIGATE:
			state_text = "INVESTIGATE\n%.1fs" % maxf(0.0, _memory_left)
			if _investigation_moving:
				state_text = "INVESTIGATE\nMOVING"
			state_color = Color(1.0, 0.82, 0.2)
		Awareness.ENGAGED:
			state_text = "ENGAGED"
			state_color = Color(1.0, 0.25, 0.2)
		Awareness.SEARCH:
			state_text = "SEARCH\n%.1fs" % maxf(0.0, _memory_left)
			if _investigation_moving:
				state_text = "SEARCH\nMOVING"
			state_color = Color(1.0, 0.55, 0.15)
		Awareness.DEAD:
			state_text = "DEAD"
			state_color = Color(0.6, 0.6, 0.65)
	if state_indicator.text != state_text:
		state_indicator.text = state_text
	state_indicator.modulate = state_color


func _die() -> void:
	if _death_started:
		return
	_death_started = true
	_set_awareness(Awareness.DEAD)
	target_player = null
	velocity = Vector3.ZERO
	collision_layer = 0
	head_hurt_point.collision_layer = 0
	play_enemy_animation(&"death")
	died.emit()
	Global.enemy_killed.emit()
	await get_tree().create_timer(1.0).timeout
	queue_free()
