class_name RussianDollEnemy extends CharacterBody3D

const MAX_SPLITS: int = 4
const BASE_RADIUS: float = 0.72
const BASE_HEIGHT: float = 2.65
const STAGE_COLORS = [
	Color(0.68, 0.08, 0.12),
	Color(0.92, 0.28, 0.08),
	Color(0.94, 0.66, 0.12),
	Color(0.18, 0.65, 0.43),
	Color(0.30, 0.31, 0.76),
]

@export_range(0, 4, 1) var split_generation: int = 0
@export var base_health: float = 160.0
@export var base_damage: float = 24.0
@export var base_speed: float = 1.8
@export var attack_cooldown: float = 1.25
@export var acceleration: float = 12.0
@export var steering_interval: float = 0.18

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals
@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var cap_mesh: MeshInstance3D = $Visuals/Cap

var current_health: float
var max_health: float
var attack_damage: float
var move_speed: float

var _size: float
var _attack_timer: float = 0.4
var _steering_timer: float = 0.0
var _desired_direction: Vector3 = Vector3.ZERO
var _use_navigation: bool = false
var _dead: bool = false


func _ready() -> void:
	split_generation = clampi(split_generation, 0, MAX_SPLITS)
	_size = pow(0.78, split_generation)
	max_health = base_health * pow(0.65, split_generation)
	current_health = max_health
	attack_damage = base_damage * pow(0.65, split_generation)
	move_speed = base_speed * pow(1.4, split_generation)
	floor_snap_length = 0.3
	_steering_timer = randf_range(0.0, steering_interval)

	# Change the physics shape itself, not only the visible mesh.
	var shape: CapsuleShape3D = collision_shape.shape.duplicate() as CapsuleShape3D
	shape.radius = BASE_RADIUS * _size
	shape.height = BASE_HEIGHT * _size
	collision_shape.shape = shape
	collision_shape.position.y = shape.height * 0.5
	visuals.scale = Vector3.ONE * _size
	navigation_agent.radius = maxf(0.2, BASE_RADIUS * _size)

	var tint: Color = STAGE_COLORS[split_generation]
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = tint
	body_material.roughness = 0.8
	body_mesh.material_override = body_material
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = tint.darkened(0.25)
	cap_material.roughness = 0.8
	cap_mesh.material_override = cap_material


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	var player := Global.player as Player
	if not is_instance_valid(player) or not player.is_alive:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		_steering_timer -= delta
		if _steering_timer <= 0.0:
			_steering_timer = steering_interval
			_update_steering(player)
		velocity.x = move_toward(velocity.x, _desired_direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, _desired_direction.z * move_speed, acceleration * delta)
		var offset := player.global_position - global_position
		offset.y = 0.0
		var reach := 1.4 * _size + 0.45
		if offset.length_squared() <= reach * reach and _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			player.get_damage(attack_damage, offset.normalized(), true)
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if global_position.y < -20.0:
		_dead = true
		queue_free()


func _update_steering(player: Player) -> void:
	var navigation_map := get_world_3d().navigation_map
	if not _use_navigation:
		_use_navigation = NavigationServer3D.map_get_iteration_id(navigation_map) > 0 and not NavigationServer3D.map_get_regions(navigation_map).is_empty()
	var destination := player.global_position
	if _use_navigation:
		var nearest_point := NavigationServer3D.map_get_closest_point(navigation_map, global_position)
		var navigation_gap := Vector2(global_position.x, global_position.z).distance_to(Vector2(nearest_point.x, nearest_point.z))
		if navigation_gap <= 1.5:
			navigation_agent.target_position = NavigationServer3D.map_get_closest_point(navigation_map, destination)
			if not navigation_agent.is_navigation_finished():
				destination = navigation_agent.get_next_path_position()
	var seek := destination - global_position
	seek.y = 0.0
	_desired_direction = seek.normalized()
	var facing := player.global_position - global_position
	facing.y = 0.0
	if facing.length_squared() > 0.001:
		visuals.rotation.y = atan2(-facing.x, -facing.z)


func get_damage(damage: float, _direction: Vector3, _is_enemy_damage: bool = false) -> void:
	if _dead or damage <= 0.0:
		return
	current_health = maxf(0.0, current_health - damage)
	if current_health <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	hide()
	Global.enemy_killed.emit()
	call_deferred("_spawn_children_and_free")


func _spawn_children_and_free() -> void:
	if split_generation < MAX_SPLITS and get_parent() is Node3D:
		var doll_scene: PackedScene = load("res://FractalVaultDemo/enemies/russian_doll_enemy.tscn")
		var host := get_parent() as Node3D
		var origin := global_position
		var direction := Vector3.RIGHT.rotated(Vector3.UP, randf() * TAU)
		var next_size := _size * 0.78
		var offset := BASE_RADIUS * next_size * 1.25
		for side in [-1.0, 1.0]:
			var child := doll_scene.instantiate() as RussianDollEnemy
			child.split_generation = split_generation + 1
			child.base_health = base_health
			child.base_damage = base_damage
			child.base_speed = base_speed
			child.attack_cooldown = attack_cooldown
			child.acceleration = acceleration
			child.steering_interval = steering_interval
			host.add_child(child)
			child.global_position = origin + direction * offset * side
	queue_free()
