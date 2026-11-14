extends Node3D

@export var speed: float = 90.0
@export var collision_mask: int = 7
@export var max_distance: float = 150.0
var game: Node
var damage: float = 65.0
var shooter: RID
var direction := Vector3.FORWARD
var distance_travelled: float = 0.0
var impacted: bool = false

func _ready() -> void:
	add_to_group("afterburn_player_rounds")
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)

func _physics_process(delta: float) -> void:
	if impacted or not game or game.state != "play":
		return
	var step: float = minf(speed * delta, max_distance - distance_travelled)
	var destination: Vector3 = global_position + direction * step
	# A swept segment detects only this frame's travel; it deals no instant damage.
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, collision_mask, [shooter])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		impacted = true
		if hit.collider.has_method("get_damage"):
			hit.collider.get_damage(damage, direction, false)
		game.spark(hit.position, Color("#a4ffcb"), 0.25)
		queue_free()
		return
	global_position = destination
	distance_travelled += step
	if distance_travelled >= max_distance:
		queue_free()
