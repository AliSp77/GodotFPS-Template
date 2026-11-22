class_name GrenadeCore
extends Node3D

signal finished(core: GrenadeCore)

enum Phase { GUIDED, BOUNCING, ARMED, EXPLODING, DONE }

@onready var flight_path: Path3D = $FlightPath
@onready var sweep: ShapeCast3D = $Sweep
@onready var core_visual: MeshInstance3D = $CoreVisual
@onready var warning_visual: MeshInstance3D = $WarningVisual
@onready var explosion_visual: MeshInstance3D = $ExplosionVisual
@onready var explosion_sound: AudioStreamPlayer3D = $ExplosionSound

var phase: Phase = Phase.GUIDED
var volley: Node3D
var start_position: Vector3
var target_position: Vector3
var forward: Vector3
var right: Vector3
var duration: float = 1.0
var arc_height: float = 2.0
var blast_radius: float = 2.5
var fuse_duration: float = 2.0
var max_air_time: float = 5.0
var elapsed: float = 0.0
var air_elapsed: float = 0.0
var fuse_left: float = 0.0
var explosion_left: float = 0.0
var bounce_velocity: Vector3 = Vector3.ZERO
var floor_bounces: int = 0
var direct_hit_player: Player


func launch(volley_node: Node3D, origin: Vector3, destination: Vector3, travel_time: float, height: float, radius: float, fuse: float, air_limit: float, ignored_rid: RID) -> void:
	volley = volley_node
	start_position = origin
	target_position = destination
	duration = maxf(0.1, travel_time)
	arc_height = maxf(0.0, height)
	blast_radius = maxf(0.1, radius)
	fuse_duration = maxf(0.1, fuse)
	max_air_time = maxf(duration, air_limit)
	forward = destination - origin
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else -global_basis.z
	right = forward.cross(Vector3.UP).normalized()
	global_position = origin
	warning_visual.scale = Vector3.ONE * blast_radius
	if ignored_rid.is_valid():
		sweep.add_exception_rid(ignored_rid)


func _physics_process(delta: float) -> void:
	match phase:
		Phase.GUIDED:
			air_elapsed += delta
			elapsed = minf(duration, elapsed + delta)
			var t := elapsed / duration
			var desired := start_position.lerp(target_position, t)
			desired.y += 4.0 * arc_height * t * (1.0 - t)
			var curve := flight_path.curve
			if curve != null and curve.point_count >= 2:
				# FlightPath X is sideways, Y is height, and Z is along the shot. Its first point is the muzzle offset.
				var offset := curve.sample_baked(t * curve.get_baked_length(), true) - curve.sample_baked(0.0)
				desired += right * offset.x + Vector3.UP * offset.y + forward * offset.z
			var guided_velocity := (desired - global_position) / maxf(delta, 0.001)
			_sweep_to(desired, guided_velocity)
			if phase == Phase.GUIDED and elapsed >= duration:
				phase = Phase.BOUNCING
				bounce_velocity = guided_velocity
		Phase.BOUNCING:
			air_elapsed += delta
			bounce_velocity += Vector3.DOWN * 9.8 * delta
			_sweep_to(global_position + bounce_velocity * delta, bounce_velocity)
		Phase.ARMED:
			fuse_left -= delta
			if fuse_left <= 0.0:
				_detonate()
		Phase.EXPLODING:
			explosion_left -= delta
			var progress := 1.0 - maxf(0.0, explosion_left) / 0.5
			explosion_visual.scale = Vector3.ONE * blast_radius * (0.15 + progress * 0.85)
			explosion_visual.transparency = progress
			if explosion_left <= 0.0:
				_finish()
	if (phase == Phase.GUIDED or phase == Phase.BOUNCING) and air_elapsed >= max_air_time:
		_finish()


func _sweep_to(destination: Vector3, incoming_velocity: Vector3) -> void:
	var motion := destination - global_position
	if motion.length_squared() < 0.000001:
		return
	sweep.target_position = sweep.global_basis.inverse() * motion
	sweep.force_shapecast_update()
	if not sweep.is_colliding():
		global_position = destination
		return
	var nearest := 0
	var nearest_distance := INF
	for index in sweep.get_collision_count():
		var distance := global_position.distance_squared_to(sweep.get_collision_point(index))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	var collider := sweep.get_collider(nearest)
	global_position += motion * maxf(0.0, sweep.get_closest_collision_safe_fraction() - 0.01)
	if collider is Player and (collider as Player).is_alive:
		direct_hit_player = collider as Player
		_detonate()
		return
	var normal := sweep.get_collision_normal(nearest)
	if normal.length_squared() < 0.01:
		normal = Vector3.UP
	bounce_velocity = incoming_velocity.bounce(normal) * 0.35
	if normal.dot(Vector3.UP) > 0.7:
		floor_bounces += 1
		bounce_velocity.x *= 0.55
		bounce_velocity.z *= 0.55
		if floor_bounces >= 2 or absf(bounce_velocity.y) < 1.0:
			_settle()
			return
	phase = Phase.BOUNCING


func _settle() -> void:
	phase = Phase.ARMED
	fuse_left = fuse_duration
	warning_visual.show()


func _detonate() -> void:
	if phase == Phase.EXPLODING or phase == Phase.DONE:
		return
	phase = Phase.EXPLODING
	warning_visual.hide()
	core_visual.hide()
	explosion_visual.show()
	explosion_visual.transparency = 0.0
	explosion_left = 0.5
	explosion_sound.play()
	if is_instance_valid(volley):
		volley.call("apply_explosion", global_position, blast_radius, direct_hit_player)


func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	finished.emit(self)
	queue_free()
