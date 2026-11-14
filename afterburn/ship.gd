extends StaticBody3D

const HULL_MATERIALS := {
	"striker": preload("res://afterburn/materials/cartoon_mint.tres"),
	"sniper": preload("res://afterburn/materials/cartoon_coral.tres"),
	"guardian": preload("res://afterburn/materials/cartoon_orange.tres"),
	"interceptor": preload("res://afterburn/materials/cartoon_purple.tres"),
	"boss": preload("res://afterburn/materials/cartoon_orange.tres"),
}

@export var game: Node
var kind: String = "striker"
var hp: float = 150.0
@export var max_hp: float = 150.0
var boss: bool = false
var age: float = 0.0
var shot_timer: float = 2.0
var telegraph: float = 0.0
var target_point := Vector3.ZERO
var anchor := Vector3.ZERO
var phase: int = 1
var dying: bool = false
var visual: MeshInstance3D
var beacon: MeshInstance3D
var health_label: Label3D
var tint := Color("#a4ffcb")
var radius: float = 1.7
var route_offset: float = -32.0

func _ready() -> void:
	add_to_group("afterburn_enemies")
	collision_layer = 2
	collision_mask = 0
	anchor = position
	route_offset = position.z - game.player.position.z
	shot_timer = randf_range(2.0, 3.6)
	var mesh_index: int = {"striker": 1, "sniper": 3, "guardian": 4, "interceptor": 7, "boss": 5}.get(kind, 1)
	tint = {"striker": Color("#a4ffcb"), "sniper": Color("#ff718e"), "guardian": Color("#ffaf74"), "interceptor": Color("#be9aff"), "boss": Color("#ffaf74")}.get(kind, Color.WHITE)
	var ship_mesh: Mesh = load("res://resources/spaceships/ship%d.obj" % mesh_index)
	visual = MeshInstance3D.new()
	visual.mesh = ship_mesh
	var bounds: AABB = ship_mesh.get_aabb()
	var width: float = 10.5 if boss else (4.0 if kind == "guardian" else 2.9)
	var factor: float = width / bounds.size.x
	visual.scale = Vector3.ONE * factor
	visual.position = -bounds.get_center() * factor
	visual.material_override = HULL_MATERIALS.get(kind, HULL_MATERIALS["striker"])
	add_child(visual)
	radius = 4.6 if boss else (2.0 if kind == "guardian" else 1.5)
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	collider.shape = sphere
	add_child(collider)
	beacon = MeshInstance3D.new()
	var core := SphereMesh.new()
	core.radius = 0.28 if boss else 0.14
	core.height = core.radius * 2.0
	beacon.mesh = core
	beacon.position = Vector3(0, -0.12, -0.5)
	beacon.material_override = game.material(tint, 3.5)
	add_child(beacon)
	for side in [-1.0, 1.0]:
		var engine := MeshInstance3D.new()
		var flame := BoxMesh.new()
		flame.size = Vector3(0.16, 0.14, 0.9) * (2.5 if boss else 1.0)
		engine.mesh = flame
		engine.position = Vector3(side * width * 0.28, 0, width * 0.25)
		engine.material_override = game.material(tint, 3.0)
		add_child(engine)
	health_label = Label3D.new()
	health_label.font_size = 32
	health_label.pixel_size = 0.008
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.position.y = radius + 0.7
	health_label.modulate = tint
	add_child(health_label)
	_update_label()

func _physics_process(delta: float) -> void:
	if dying or not game or game.state != "play":
		return
	age += delta
	if not is_instance_valid(game.player):
		return
	var player_position: Vector3 = game.player.global_position
	var amplitude: float = 9.0 if boss else (4.5 if kind == "interceptor" else 2.4)
	var movement_speed: float = 1.15 if kind == "interceptor" else 0.5
	var desired: Vector3 = anchor + Vector3(sin(age * movement_speed + anchor.x) * amplitude, sin(age * 1.2) * 0.7, cos(age * 0.5) * 2.0)
	desired.z = player_position.z + route_offset + cos(age * 0.5) * 2.0
	global_position = global_position.lerp(desired, minf(1.0, delta * 5.0))
	look_at(Vector3(player_position.x, global_position.y - 0.25, player_position.z))
	visual.rotation.z = sin(age * movement_speed) * 0.12
	if is_instance_valid(game.enemy_corridor):
		game.enemy_corridor.constrain_ship(self)
	if boss:
		var next_phase: int = 3 if hp < max_hp * 0.33 else (2 if hp < max_hp * 0.67 else 1)
		if next_phase != phase:
			phase = next_phase
			game.hud.notify("CIVIC ENFORCER // PHASE 0%d" % phase, 3.0)
			game.spawn_escort()
	if telegraph > 0.0:
		telegraph -= delta
		beacon.scale = Vector3.ONE * (2.0 + sin(age * 24.0) * 0.5)
		if telegraph <= 0.0:
			_fire()
			beacon.scale = Vector3.ONE
	else:
		shot_timer -= delta
		if shot_timer <= 0.0:
			telegraph = 1.1 if kind == "sniper" else 0.8
			target_point = player_position + Vector3(0, 1.1, 0)
			if boss:
				game.hud.notify("INCOMING SALVO // KEEP MOVING", 1.3)

func _fire() -> void:
	var salvo: int = (phase + 1) if boss else (3 if kind == "guardian" else 1)
	for index in range(salvo):
		var offset := Vector3((index - (salvo - 1) * 0.5) * 0.95, 0, 0)
		var origin: Vector3 = global_position + Vector3(0, -0.4, 0)
		var projectile_speed: float = 21.0 if kind == "sniper" else 15.0
		var runner_z: float = game.player.global_position.z
		var flight_time: float = absf(runner_z - origin.z) / (projectile_speed + absf(game.player.velocity.z))
		var aim: Vector3 = Vector3(target_point.x, target_point.y, runner_z + game.player.velocity.z * flight_time) + offset
		game.fire_bolt(origin, (aim - origin).normalized(), 21.0 if kind == "sniper" else 15.0, 24.0 if kind == "sniper" else 14.0, get_rid(), tint)
	shot_timer = (2.5 - phase * 0.35) if boss else randf_range(2.5, 4.0)

func get_damage(amount: float, _direction: Vector3, _enemy_damage: bool = false) -> void:
	if dying or not game or game.state != "play":
		return
	hp = maxf(0.0, hp - amount)
	game.hud.hit_feedback()
	game.spark(global_position, tint, 0.32)
	_update_label()
	if hp <= 0.0:
		dying = true
		collision_layer = 0
		game.ship_destroyed(self)
		queue_free()

func _update_label() -> void:
	if health_label:
		health_label.text = ("%s // %d" % [kind.to_upper(), ceili(hp)]) if not boss else "CIVIC ENFORCER"
