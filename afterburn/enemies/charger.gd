extends "res://afterburn/ship.gd"

@export_group("Charge Attack")
@export_range(0.5, 5.0, 0.1) var warning_duration: float = 1.6
@export_range(30.0, 140.0, 1.0) var spawn_distance: float = 60.0
@export_range(40.0, 250.0, 1.0) var charge_speed: float = 125.0
@export var ram_damage: float = 80.0
@export var pass_distance: float = 24.0

@onready var warning_path: Node3D = $WarningPath
@onready var status_label: Label3D = $AttackStatus
@onready var hit_shape: CollisionShape3D = $CollisionShape3D
var attack_state: String = "waiting"
var warning_remaining: float = 0.0
var locked_x: float = 0.0
var hit_player: bool = false
var previous_player_center := Vector3.ZERO

func _ready() -> void:
	# The saved prefab supplies every visual, collider, and warning node.
	kind = "charger"
	tint = Color("#ff3658")
	hp = max_hp
	visual = $Hull
	beacon = $WarningBeacon
	health_label = $HealthLabel
	radius = (hit_shape.shape as SphereShape3D).radius
	collision_layer = 2
	collision_mask = 0
	add_to_group("afterburn_enemies")
	add_to_group("afterburn_chargers")
	_update_label()
	if game and is_instance_valid(game.player):
		_begin_warning()

func _begin_warning() -> void:
	if is_instance_valid(game.enemy_corridor):
		game.enemy_corridor.constrain_ship(self, false)
	locked_x = global_position.x
	warning_remaining = warning_duration
	attack_state = "warning"
	previous_player_center = game.player.get_node("CollisionShape3D").global_position
	var near_z: float = game.player.global_position.z + pass_distance
	var length: float = maxf(1.0, near_z - global_position.z)
	var capsule: CapsuleShape3D = game.player.get_node("CollisionShape3D").shape
	warning_path.global_position = Vector3(locked_x, 0.09, global_position.z + length * 0.5)
	warning_path.scale = Vector3((radius + capsule.radius) * 2.0, 1.0, length)
	warning_path.visible = true
	status_label.text = "CHARGE PATH LOCKED // STRAFE CLEAR"
	if game.state == "play" and game.hud:
		game.hud.notify("CHARGER // LEAVE THE RED PATH OR SHOOT IT DOWN", warning_duration + 0.4)

func _physics_process(delta: float) -> void:
	if dying or not game or game.state != "play" or not is_instance_valid(game.player):
		return
	if attack_state == "waiting":
		_begin_warning()
	age += delta
	var move_delta: float = delta
	if attack_state == "warning":
		var warning_step: float = minf(warning_remaining, delta)
		warning_remaining = maxf(0.0, warning_remaining - warning_step)
		move_delta -= warning_step
		beacon.scale = Vector3.ONE * (1.2 + 0.35 * sin(age * 22.0))
		status_label.text = "CHARGER // %.1f" % warning_remaining
		if warning_remaining > 0.0:
			previous_player_center = game.player.get_node("CollisionShape3D").global_position
			return
		attack_state = "charging"
		status_label.text = "INCOMING"
		beacon.scale = Vector3.ONE * 1.8
	if attack_state == "charging" and move_delta > 0.0:
		var start: Vector3 = global_position
		var destination: Vector3 = start + Vector3.BACK * charge_speed * move_delta
		destination.x = locked_x
		_sweep_player(start, destination)
		global_position = destination
		if global_position.z > game.player.global_position.z + pass_distance:
			attack_state = "passed"
			warning_path.visible = false
			# Escaping the charge gives no kill reward, but never stalls the encounter.
			dying = true
			collision_layer = 0
			queue_free()
	previous_player_center = game.player.get_node("CollisionShape3D").global_position

func _sweep_player(start: Vector3, destination: Vector3) -> void:
	if hit_player or not game.player.is_alive:
		return
	var player_shape: CollisionShape3D = game.player.get_node("CollisionShape3D")
	var capsule: CapsuleShape3D = player_shape.shape
	var half_segment: float = maxf(0.0, capsule.height * 0.5 - capsule.radius)
	# Relative motion includes the auto-running player. Sweep the whole frame so
	# a fast charge cannot skip through the player between physics ticks.
	var points: PackedVector3Array = Geometry3D.get_closest_points_between_segments(
		start - previous_player_center, destination - player_shape.global_position,
		Vector3.DOWN * half_segment, Vector3.UP * half_segment)
	if points[0].distance_squared_to(points[1]) <= pow(radius + capsule.radius, 2.0):
		hit_player = true
		var scaled_damage: float = ram_damage * (1.0 + (int(game.profile.tier) - 1) * 0.12)
		game.player.get_damage(scaled_damage, Vector3.BACK, true)

func get_damage(amount: float, direction: Vector3, enemy_damage: bool = false) -> void:
	# No invulnerable warning or charge phase: the ship is always shootable.
	super.get_damage(amount, direction, enemy_damage)
	if dying:
		attack_state = "destroyed"
		warning_path.visible = false
