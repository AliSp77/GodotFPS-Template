class_name RussianDollEnemy
extends FractalEnemyBase

const MAX_SPLITS: int = 4
const BASE_RADIUS: float = 0.72
const BASE_HEIGHT: float = 2.1
const STAGE_COLORS = [
	Color(0.68, 0.08, 0.12),
	Color(0.92, 0.28, 0.08),
	Color(0.94, 0.66, 0.12),
	Color(0.18, 0.65, 0.43),
	Color(0.30, 0.31, 0.76),
]

@export_group("Russian Doll")
@export_range(0, 4, 1) var split_generation: int = 0
@export var base_health: float = 160.0
@export var base_damage: float = 24.0
@export var base_speed: float = 1.8
@export var attack_cooldown: float = 1.25

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var doll_visual: Node3D = $Visuals/DollVisual
@onready var body_mesh: MeshInstance3D = $Visuals/DollVisual/Body
@onready var cap_mesh: MeshInstance3D = $Visuals/DollVisual/Cap

var attack_damage: float
var _size: float
var _attack_timer: float = 0.4


func _ready() -> void:
	split_generation = clampi(split_generation, 0, MAX_SPLITS)
	_size = pow(0.78, split_generation)
	sound_pitch_scale *= pow(1.12, split_generation)
	max_health = base_health * pow(0.65, split_generation)
	move_speed = base_speed * pow(1.4, split_generation)
	attack_damage = base_damage * pow(0.65, split_generation)

	# Resize the physical body and head hurt point along with the model.
	var body_shape := collision_shape.shape.duplicate() as CapsuleShape3D
	body_shape.radius = BASE_RADIUS * _size
	body_shape.height = BASE_HEIGHT * _size
	collision_shape.shape = body_shape
	collision_shape.position.y = body_shape.height * 0.5
	var head_shape := head_hurt_point.get_node("CollisionShape3D") as CollisionShape3D
	var sphere := head_shape.shape.duplicate() as SphereShape3D
	sphere.radius = 0.53 * _size
	head_shape.shape = sphere
	head_hurt_point.position.y = 2.1 * _size
	doll_visual.scale = Vector3.ONE * _size
	vision_sensor.position.y = 1.8 * _size
	sight_ray.position.y = 1.8 * _size
	state_indicator.position.y = 3.0 * _size
	navigation_agent.radius = BASE_RADIUS * _size
	navigation_agent.target_desired_distance = 0.65 * _size

	var tint: Color = STAGE_COLORS[split_generation]
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = tint
	body_material.roughness = 0.8
	body_mesh.material_override = body_material
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = tint.darkened(0.25)
	cap_material.roughness = 0.8
	cap_mesh.material_override = cap_material
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if global_position.y < -20.0:
		queue_free()
		return
	if awareness != Awareness.ENGAGED or not is_instance_valid(target_player) or not target_player.is_alive:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _attack_timer > 0.0:
		return
	var offset := target_player.global_position - global_position
	if absf(offset.y) > 1.25 * _size:
		return
	offset.y = 0.0
	var reach := 1.4 * _size + 0.45
	if offset.length_squared() > reach * reach or _find_visible_player() != target_player:
		return
	_attack_timer = attack_cooldown
	play_enemy_animation(&"attack")
	_animation_lock_left = 0.3
	target_player.get_damage(attack_damage, offset.normalized(), true)


func _die() -> void:
	if _death_started:
		return
	super._die()
	call_deferred("_spawn_children")


func _spawn_children() -> void:
	if split_generation >= MAX_SPLITS or not get_parent() is Node3D:
		return
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
		child.vision_range = vision_range
		child.vision_angle_degrees = vision_angle_degrees
		child.hearing_sensitivity = hearing_sensitivity
		child.search_duration = search_duration
		child.investigation_travel_timeout = investigation_travel_timeout
		child.show_state_indicator = show_state_indicator
		host.add_child(child)
		child.global_position = origin + direction * offset * side
