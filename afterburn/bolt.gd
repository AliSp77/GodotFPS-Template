extends Node3D

var game: Node
var velocity := Vector3.ZERO
var damage: float = 12.0
var lifetime: float = 5.0
var shooter: RID
var tint := Color("#ff805e")

func _ready() -> void:
	add_to_group("afterburn_bolts")
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	visual.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 3.0
	visual.material_override = material
	add_child(visual)
	var tail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.055, 0.055, 0.8)
	tail.mesh = box
	tail.position.z = 0.32
	tail.material_override = material
	add_child(tail)
	if velocity.length() > 0:
		look_at(global_position + velocity.normalized())

func _physics_process(delta: float) -> void:
	if not game or game.state != "play":
		return
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var destination: Vector3 = global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 1, [shooter])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("get_damage"):
			hit.collider.get_damage(damage, velocity.normalized(), true)
		game.spark(hit.position, tint, 0.28)
		queue_free()
	else:
		global_position = destination
