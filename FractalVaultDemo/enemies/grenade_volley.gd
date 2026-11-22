class_name GrenadeVolley
extends RangedEnemyProjectile

@export_group("Grenade Flight")
@export var arc_height: float = 2.0
@export var minimum_flight_time: float = 0.8
@export var maximum_flight_time: float = 1.5
@export var max_air_time: float = 5.0
@export_group("Grenade Blast")
@export var blast_radius: float = 2.5
@export var ground_fuse: float = 2.0

var target_position: Vector3
var _active_cores: int = 0
var _damaged_players: Dictionary = {}


func _ready() -> void:
	var origin := global_position
	var horizontal_distance := Vector2(origin.x, origin.z).distance_to(Vector2(target_position.x, target_position.z))
	var travel_time := clampf(horizontal_distance / maxf(0.1, speed), minimum_flight_time, maximum_flight_time)
	for child in get_children():
		if child is GrenadeCore:
			var core := child as GrenadeCore
			_active_cores += 1
			core.finished.connect(_on_core_finished)
			core.launch(self, origin, target_position, travel_time, arc_height, blast_radius, ground_fuse, max_air_time, shooter_rid)
	if _active_cores == 0:
		push_warning("Grenade volley has no authored GrenadeCore children.")
		queue_free()


func _physics_process(_delta: float) -> void:
	# Each authored core moves independently. A fired volley survives its shooter.
	pass


func apply_explosion(origin: Vector3, radius: float, direct_player: Player = null) -> void:
	for body in get_tree().get_nodes_in_group("player"):
		if not body is Player:
			continue
		var player := body as Player
		if not player.is_alive or _damaged_players.has(player.get_instance_id()):
			continue
		var chest := player.global_position + Vector3.UP
		if origin.distance_to(chest) > radius:
			continue
		if player != direct_player:
			var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.15, chest, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.get("collider") != player:
				continue
		_damaged_players[player.get_instance_id()] = true
		var push := chest - origin
		player.get_damage(damage, push.normalized() if push.length_squared() > 0.01 else Vector3.UP, true)


func _on_core_finished(_core: GrenadeCore) -> void:
	_active_cores -= 1
	if _active_cores <= 0:
		queue_free()
