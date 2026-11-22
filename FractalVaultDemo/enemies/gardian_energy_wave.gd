extends Node3D

var max_radius: float = 6.0
var travel_time: float = 1.0
var damage: float = 10.0
var source_rid: RID

var _elapsed: float = 0.0
var _previous_radius: float = 0.0
var _hit_player: bool = false
var _ring: MeshInstance3D


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.13, 0.78, 1.0, 0.7)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.65, 1.0)
	material.emission_energy_multiplier = 2.5
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = material
	add_child(_ring)
	_ring.scale = Vector3(0.05, 1.0, 0.05)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var radius := max_radius * minf(1.0, _elapsed / maxf(0.01, travel_time))
	_ring.scale = Vector3(maxf(0.05, radius), 1.0, maxf(0.05, radius))
	if damage > 0.0 and not _hit_player:
		_try_hit_player(radius)
	_previous_radius = radius
	if _elapsed >= travel_time:
		queue_free()


func _try_hit_player(radius: float) -> void:
	var player := Global.player as Player
	if not is_instance_valid(player) or not player.is_alive:
		return
	var offset := player.global_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	if absf(offset.y) > 1.6 or distance > radius + 0.3 or distance < _previous_radius - 0.3:
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, player.global_position + Vector3.UP, 1, [source_rid])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != player:
		return
	_hit_player = true
	offset.y = 0.0
	player.get_damage(damage, offset.normalized(), true)
