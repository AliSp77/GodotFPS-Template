class_name RangedEnemyProjectile
extends Node3D

@export var speed: float = 18.0
@export var max_distance: float = 30.0
@export var damage: float = 8.0
@export_flags_3d_physics var collision_mask: int = 1

var direction: Vector3 = Vector3.FORWARD
var shooter: FractalEnemyBase
var shooter_rid: RID
var distance_travelled: float = 0.0
var impacted: bool = false


func _ready() -> void:
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	if impacted:
		return
	if not is_instance_valid(shooter) or shooter.awareness == FractalEnemyBase.Awareness.DEAD:
		queue_free()
		return
	var remaining := maxf(0.0, max_distance - distance_travelled)
	if remaining <= 0.0:
		queue_free()
		return
	var step := minf(maxf(0.0, speed) * delta, remaining)
	var destination := global_position + direction * step
	var exclusions: Array[RID] = []
	if shooter_rid.is_valid():
		exclusions.append(shooter_rid)
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, collision_mask, exclusions)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		impacted = true
		if hit.collider is Player and (hit.collider as Player).is_alive:
			(hit.collider as Player).get_damage(damage, direction, true)
		queue_free()
		return
	global_position = destination
	distance_travelled += step
	if distance_travelled >= max_distance:
		queue_free()
