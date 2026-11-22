class_name Gardian
extends FractalEnemyBase

const ENERGY_WAVE_SCRIPT: Script = preload("res://FractalVaultDemo/enemies/gardian_energy_wave.gd")

enum Phase { ROAM, TITAN }

signal titan_started
signal shield_broken
signal titan_exploded

@export_group("Roaming Attack")
@export var attack_damage: float = 16.0
@export var attack_range: float = 1.7
@export var attack_cooldown: float = 1.3

@export_group("Titan")
@export var titan_cooldown: float = 6.0
@export var titan_charge_duration: float = 5.0
@export var shield_max_health: float = 300.0
@export var wave_interval: float = 1.1
@export var wave_radius: float = 6.0
@export var wave_travel_time: float = 1.0
@export var wave_damage: float = 10.0
@export var explosion_radius: float = 8.0
@export var explosion_damage: float = 65.0

@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/HeadMesh
@onready var weak_point_visuals: Node3D = $Visuals/WeakPoints
@onready var left_weak_point: CollisionObject3D = $HurtPoints/Left
@onready var right_weak_point: CollisionObject3D = $HurtPoints/Right
@onready var titan_shield: StaticBody3D = $TitanShield
@onready var shield_visual: MeshInstance3D = $TitanShield/Visual
@onready var charge_label: Label3D = $ChargeLabel
@onready var waves: Node3D = $Waves

var phase: Phase = Phase.ROAM
var shield_health: float = 0.0
var _attack_left: float = 0.4
var _titan_left: float = 0.0
var _charge_left: float = 0.0
var _wave_left: float = 0.0


func _ready() -> void:
	# World collision still works through collision_mask; weapon rays ignore this layer.
	collision_layer = 8
	_titan_left = titan_cooldown
	_set_weak_points_active(true)
	titan_shield.collision_layer = 0
	titan_shield.hide()
	charge_label.hide()
	super._ready()


func _physics_process(delta: float) -> void:
	if awareness == Awareness.DEAD:
		return
	if phase == Phase.TITAN:
		_titan_physics(delta)
		return
	super._physics_process(delta)
	if awareness == Awareness.DEAD:
		return
	_attack_left = maxf(0.0, _attack_left - delta)
	if awareness != Awareness.ENGAGED or not is_instance_valid(target_player) or not target_player.is_alive:
		return
	_titan_left -= delta
	if _titan_left <= 0.0:
		_enter_titan()
		return
	_try_attack()


func _try_attack() -> void:
	if _attack_left > 0.0 or not is_on_floor():
		return
	var offset := target_player.global_position - global_position
	if absf(offset.y) > 1.3:
		return
	offset.y = 0.0
	if offset.length_squared() > attack_range * attack_range or _find_visible_player() != target_player:
		return
	_attack_left = attack_cooldown
	play_enemy_animation(&"attack")
	_animation_lock_left = 0.3
	target_player.get_damage(attack_damage, offset.normalized(), true)


func _enter_titan() -> void:
	if phase == Phase.TITAN or awareness == Awareness.DEAD:
		return
	phase = Phase.TITAN
	_charge_left = maxf(0.1, titan_charge_duration)
	_wave_left = 0.25
	shield_health = maxf(1.0, shield_max_health)
	velocity.x = 0.0
	velocity.z = 0.0
	_dodge_left = 0.0
	_set_weak_points_active(false)
	titan_shield.collision_layer = 2
	titan_shield.show()
	charge_label.show()
	_update_charge_label()
	play_enemy_animation(&"alert")
	titan_started.emit()


func _titan_physics(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_charge_left -= delta
	_wave_left -= delta
	if _wave_left <= 0.0:
		_spawn_wave(wave_radius, wave_travel_time, wave_damage)
		_wave_left = maxf(0.15, wave_interval)
	shield_visual.scale = Vector3.ONE * (1.0 + 0.04 * sin((titan_charge_duration - _charge_left) * 8.0))
	_update_charge_label()
	if _charge_left <= 0.0:
		_explode()


func damage_shield(amount: float, _direction: Vector3) -> void:
	if phase != Phase.TITAN or awareness == Awareness.DEAD or amount <= 0.0:
		return
	shield_health = maxf(0.0, shield_health - amount)
	_update_charge_label()
	if shield_health <= 0.0:
		_break_shield()


func _break_shield() -> void:
	if phase != Phase.TITAN:
		return
	phase = Phase.ROAM
	_titan_left = maxf(0.1, titan_cooldown)
	_disable_shield()
	_set_weak_points_active(true)
	_clear_waves()
	play_enemy_animation(&"hurt")
	_animation_lock_left = 0.4
	shield_broken.emit()


func _explode() -> void:
	if phase != Phase.TITAN:
		return
	var player := Global.player as Player
	if is_instance_valid(player) and player.is_alive:
		var offset := player.global_position - global_position
		var distance := Vector2(offset.x, offset.z).length()
		if distance <= explosion_radius and absf(offset.y) <= 2.5 and _has_clear_path_to(player):
			offset.y = 0.0
			player.get_damage(explosion_damage, offset.normalized(), true)
	var host := get_parent() as Node3D
	if is_instance_valid(host):
		var blast := _make_wave(explosion_radius, 0.6, 0.0)
		host.add_child(blast)
		blast.global_position = global_position + Vector3.UP * 0.15
	titan_exploded.emit()
	_die()


func _spawn_wave(radius: float, duration: float, damage: float) -> void:
	var wave := _make_wave(radius, duration, damage)
	waves.add_child(wave)
	wave.global_position = global_position + Vector3.UP * 0.15


func _make_wave(radius: float, duration: float, damage: float) -> Node3D:
	var wave: Node3D = ENERGY_WAVE_SCRIPT.new()
	wave.set("max_radius", radius)
	wave.set("travel_time", duration)
	wave.set("damage", damage)
	wave.set("source_rid", get_rid())
	return wave


func _has_clear_path_to(player: Player) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, player.global_position + Vector3.UP, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player


func _update_charge_label() -> void:
	charge_label.text = "TITAN  SHIELD %d\nBLAST %.1fs" % [ceili(shield_health), maxf(0.0, _charge_left)]


func _disable_shield() -> void:
	titan_shield.collision_layer = 0
	titan_shield.hide()
	shield_visual.scale = Vector3.ONE
	charge_label.hide()


func _set_weak_points_active(active: bool) -> void:
	weak_point_visuals.visible = active
	head_hurt_point.collision_layer = 2 if active else 0
	left_weak_point.collision_layer = 2 if active else 0
	right_weak_point.collision_layer = 2 if active else 0
	body_mesh.visible = not active
	head_mesh.visible = not active


func _clear_waves() -> void:
	for wave in waves.get_children():
		wave.queue_free()


func get_damage(amount: float, direction: Vector3, is_enemy_damage: bool = false) -> void:
	if phase == Phase.TITAN:
		return
	super.get_damage(amount, direction, is_enemy_damage)


func notify_threat(origin: Vector3, time_to_impact: float) -> bool:
	if phase == Phase.TITAN:
		return false
	return super.notify_threat(origin, time_to_impact)


func _die() -> void:
	if _death_started:
		return
	phase = Phase.ROAM
	_disable_shield()
	left_weak_point.collision_layer = 0
	right_weak_point.collision_layer = 0
	_clear_waves()
	super._die()
