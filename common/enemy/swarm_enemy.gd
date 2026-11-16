class_name SwarmEnemy extends CharacterBody3D

@export var max_health: float = 45.0
@export var move_speed: float = 4.0
@export var acceleration: float = 14.0
@export var steering_interval: float = 0.22
@export var attack_range: float = 1.25
@export var animation_player: AnimationPlayer

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: Node3D = $undead

var spawner: Node3D
var visual_index: int = -1
var current_health: float
var _steering_timer: float = 0.0
var _desired_direction: Vector3 = Vector3.ZERO
var _use_navigation: bool = false
var _dead: bool = false
var activated: bool = false


func _ready() -> void:
	current_health = max_health
	_steering_timer = randf_range(0.0, steering_interval)
	floor_snap_length = 0.3
	animation_player.play("idle")

func activate() -> void:
	if _dead or activated:
		return
	activated = true
	_steering_timer = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not activated:
		if is_on_floor():
			set_physics_process(false)
			return
		velocity += get_gravity() * delta
		move_and_slide()
		if global_position.y < -20.0:
			_retire(false)
		return
	var player := Global.player
	if not is_instance_valid(player) or not player.is_alive:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		_steering_timer -= delta
		if _steering_timer <= 0.0:
			_steering_timer = steering_interval
			_update_steering(player)
		if _use_navigation:
			_update_navigation_direction()
		velocity.x = move_toward(velocity.x, _desired_direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, _desired_direction.z * move_speed, acceleration * delta)
		var offset: Vector3 = player.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() <= attack_range * attack_range and spawner:
			spawner.try_attack(player, global_position)
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
		
	if velocity.x != 0 or velocity.z != 0:
		animation_player.play("walk")
	else:
		animation_player.play("idle")
	move_and_slide()
	if _use_navigation:
		_stay_on_navigation_mesh()
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() > 0.01:
		var target_yaw := atan2(-horizontal_velocity.x, -horizontal_velocity.z)
		visual.rotation.y = lerp_angle(
			visual.rotation.y,
			target_yaw,
			minf(1.0, 8.0 * delta)
		)
	
	if global_position.y < -20.0:
		_retire(false)


func _update_steering(player: CharacterBody3D) -> void:
	var navigation_map := get_world_3d().navigation_map
	if not _use_navigation:
		_use_navigation = NavigationServer3D.map_get_iteration_id(navigation_map) > 0 and not NavigationServer3D.map_get_regions(navigation_map).is_empty()
	if _use_navigation:
		var nearest_enemy_point := NavigationServer3D.map_get_closest_point(navigation_map, global_position)
		var nearest_player_point := NavigationServer3D.map_get_closest_point(navigation_map, player.global_position)
		var horizontal_gap := Vector2(global_position.x, global_position.z).distance_to(Vector2(nearest_enemy_point.x, nearest_enemy_point.z))
		var target: Vector3 = nearest_enemy_point if horizontal_gap > 0.5 else nearest_player_point
		navigation_agent.target_position = target
		return
	var seek: Vector3 = player.global_position - global_position
	seek.y = 0.0
	var separation: Vector3 = spawner.get_separation(self) if spawner else Vector3.ZERO
	_desired_direction = (seek.normalized() + separation * 1.2).normalized()


func _update_navigation_direction() -> void:
	if navigation_agent.is_navigation_finished():
		_desired_direction = Vector3.ZERO
		return
	var next_point: Vector3 = navigation_agent.get_next_path_position()
	var seek: Vector3 = next_point - global_position
	seek.y = 0.0
	if seek.length_squared() < 0.01:
		_desired_direction = Vector3.ZERO
		return
	seek = seek.normalized()
	var separation: Vector3 = spawner.get_separation(self) if spawner else Vector3.ZERO
	var candidate: Vector3 = (seek + separation * 0.45).normalized()
	var probe: Vector3 = global_position + candidate * 0.75
	var nearest_probe := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, probe)
	var probe_gap := Vector2(probe.x, probe.z).distance_to(Vector2(nearest_probe.x, nearest_probe.z))
	_desired_direction = seek if probe_gap > 0.1 else candidate


func _stay_on_navigation_mesh() -> void:
	var nearest_point := NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position)
	if absf(nearest_point.y - global_position.y) > 1.5:
		return
	var gap := Vector2(global_position.x, global_position.z).distance_to(Vector2(nearest_point.x, nearest_point.z))
	if gap <= 0.1:
		return
	var clamped_position := global_position
	clamped_position.x = nearest_point.x
	clamped_position.z = nearest_point.z
	global_position = clamped_position
	velocity.x = 0.0
	velocity.z = 0.0


func get_damage(damage: float, _direction: Vector3, _is_enemy_damage: bool = false) -> void:
	if _dead or damage <= 0.0:
		return
	current_health -= damage
	if current_health <= 0.0:
		_retire(true)


func _retire(killed: bool) -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	if spawner:
		spawner.retire_enemy(self)
	if killed:
		Global.enemy_killed.emit()
	queue_free()
