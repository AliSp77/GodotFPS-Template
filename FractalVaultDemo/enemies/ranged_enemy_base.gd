class_name RangedEnemyBase
extends FractalEnemyBase

signal shot_fired(projectile: RangedEnemyProjectile)

@export_group("Ranged Movement")
@export var minimum_distance: float = 6.0
@export var maximum_distance: float = 10.0
@export var reposition_distance: float = 3.0
@export var reposition_interval: float = 0.6

@export_group("Ranged Attack")
@export var projectile_scene: PackedScene
@export var firing_range: float = 14.0
@export var windup_duration: float = 0.65
@export var firing_cooldown: float = 1.8
@export var projectile_speed: float = 18.0
@export var projectile_distance: float = 30.0
@export var projectile_damage: float = 8.0

@onready var muzzle: Marker3D = $Muzzle
@onready var aim_indicator: MeshInstance3D = $Muzzle/AimIndicator

var _windup_left: float = 0.0
var _cooldown_left: float = 0.5
var _reposition_left: float = 0.0
var _reposition_target: Vector3 = Vector3.INF
var _strafe_sign: float = 1.0


func _ready() -> void:
	_strafe_sign = -1.0 if randf() < 0.5 else 1.0
	super._ready()
	aim_indicator.hide()


func _physics_process(delta: float) -> void:
	if awareness == Awareness.DEAD:
		_cancel_windup()
		return
	_reposition_left = maxf(0.0, _reposition_left - delta)
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	super._physics_process(delta)
	if awareness != Awareness.ENGAGED or not is_instance_valid(target_player) or not target_player.is_alive or _dodge_left > 0.0:
		_cancel_windup()
		return
	if _windup_left > 0.0:
		if not _can_fire():
			_cancel_windup()
			return
		_windup_left -= delta
		if _windup_left <= 0.0:
			_windup_left = 0.0
			aim_indicator.hide()
			_fire_projectile(_aim_direction())
			_cooldown_left = maxf(0.05, firing_cooldown)
			play_enemy_animation(&"attack")
			_animation_lock_left = 0.3
		return
	if _cooldown_left <= 0.0 and _can_fire():
		_begin_windup()


func _engagement_direction() -> Vector3:
	if _windup_left > 0.0 or not is_instance_valid(target_player):
		return Vector3.ZERO
	var offset := global_position - target_player.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.01:
		return Vector3.ZERO
	if distance > maximum_distance:
		return _direction_to(target_player.global_position)
	var away := offset / distance
	if _reposition_left <= 0.0 or _reposition_target == Vector3.INF:
		var travel := maxf(1.0, reposition_distance)
		if distance < minimum_distance:
			_reposition_target = _pick_reposition(away, travel)
		else:
			var tangent := Vector3(-away.z, 0.0, away.x) * _strafe_sign
			_reposition_target = _pick_reposition(tangent, travel)
			if _reposition_target == Vector3.INF:
				_strafe_sign = -_strafe_sign
				_reposition_target = _pick_reposition(-tangent, travel)
		_reposition_left = maxf(0.1, reposition_interval)
	if _reposition_target == Vector3.INF:
		return Vector3.ZERO
	return _direction_to(_reposition_target)


func _pick_reposition(direction: Vector3, travel: float) -> Vector3:
	var map := navigation_agent.get_navigation_map()
	var has_navigation := map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty()
	for angle in [0.0, PI / 6.0, -PI / 6.0, PI / 3.0, -PI / 3.0]:
		var heading := direction.rotated(Vector3.UP, angle)
		var candidate := global_position + heading * travel
		if test_move(global_transform, heading * travel):
			continue
		if has_navigation:
			candidate = NavigationServer3D.map_get_closest_point(map, candidate)
			if Vector2(candidate.x, candidate.z).distance_to(Vector2(global_position.x, global_position.z)) < travel * 0.6:
				continue
			var path := NavigationServer3D.map_get_path(map, global_position, candidate, true, navigation_agent.navigation_layers)
			if path.size() < 2 or path[path.size() - 1].distance_to(candidate) > 0.75:
				continue
		else:
			var floor_query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 1.5, candidate + Vector3.DOWN * 2.5, 1, [get_rid()])
			var floor_hit := get_world_3d().direct_space_state.intersect_ray(floor_query)
			if floor_hit.is_empty() or floor_hit.normal.dot(Vector3.UP) < cos(floor_max_angle):
				continue
			candidate = floor_hit.position
		return candidate
	return Vector3.INF


func _can_fire() -> bool:
	if projectile_scene == null or not is_on_floor() or not is_instance_valid(target_player) or not target_player.is_alive:
		return false
	if muzzle.global_position.distance_to(target_player.global_position + Vector3.UP) > firing_range:
		return false
	if _find_visible_player() != target_player:
		return false
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position, target_player.global_position + Vector3.UP, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target_player


func _aim_direction() -> Vector3:
	return (target_player.global_position + Vector3.UP - muzzle.global_position).normalized()


func _begin_windup() -> void:
	_windup_left = maxf(0.05, windup_duration)
	aim_indicator.show()
	play_enemy_animation(&"attack_windup")
	_animation_lock_left = _windup_left


func _cancel_windup() -> void:
	_windup_left = 0.0
	if is_instance_valid(aim_indicator):
		aim_indicator.hide()


func _fire_projectile(aim_direction: Vector3) -> void:
	var projectile := projectile_scene.instantiate() as RangedEnemyProjectile
	if projectile == null:
		return
	projectile.direction = aim_direction
	projectile.shooter = self
	projectile.shooter_rid = get_rid()
	projectile.speed = projectile_speed
	projectile.max_distance = projectile_distance
	projectile.damage = projectile_damage
	get_parent().add_child(projectile)
	projectile.global_position = muzzle.global_position
	shot_fired.emit(projectile)


func get_damage(amount: float, direction: Vector3, is_enemy_damage: bool = false) -> void:
	_cancel_windup()
	super.get_damage(amount, direction, is_enemy_damage)
