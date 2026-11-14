extends Area3D

## Invisible flight limits. The saved BoxShape3D controls the corridor width.
@export var follow_target: Node3D
@export var near_distance: float = 12.0
@export var far_distance: float = 30.0
@export var edge_margin: float = 0.15
@export var follow_offset: float = 30.0

func _ready() -> void:
	sync_to_player()

func _physics_process(_delta: float) -> void:
	sync_to_player()

func sync_to_player() -> void:
	if is_instance_valid(follow_target):
		global_position.z = follow_target.global_position.z - follow_offset

func horizontal_limits() -> Vector2:
	var bounds: CollisionShape3D = $Bounds
	var half_width: float = (bounds.shape as BoxShape3D).size.x * absf(bounds.global_basis.get_scale().x) * 0.5
	return Vector2(bounds.global_position.x - half_width, bounds.global_position.x + half_width)

func spawn_position(index: int, boss: bool = false) -> Vector3:
	sync_to_player()
	if boss:
		return $BossSpawn.global_position
	var points := $SpawnPoints.get_children()
	return points[posmod(index, points.size())].global_position

func constrain_ship(ship: Node3D, keep_ahead: bool = true) -> void:
	var limits := horizontal_limits()
	# Include the rotated visible hull and its spherical hitbox, so wings stay in.
	var extent: float = ship.radius
	if is_instance_valid(ship.visual) and ship.visual.mesh:
		var bounds: AABB = ship.visual.global_transform * ship.visual.get_aabb()
		extent = maxf(extent, maxf(absf(bounds.position.x - ship.global_position.x), absf(bounds.end.x - ship.global_position.x)))
	var center: float = (limits.x + limits.y) * 0.5
	var allowed: float = maxf(0.0, (limits.y - limits.x) * 0.5 - extent - edge_margin)
	ship.global_position.x = clampf(ship.global_position.x, center - allowed, center + allowed)
	if keep_ahead and is_instance_valid(follow_target):
		var near_gap: float = maxf(1.0, near_distance)
		var far_gap: float = maxf(near_gap, far_distance)
		ship.global_position.z = clampf(ship.global_position.z, follow_target.global_position.z - far_gap, follow_target.global_position.z - near_gap)
