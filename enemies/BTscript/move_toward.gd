
@tool
extends BTAction

@export var patrol_radius: float = 50.0
@export var min_distance: float = 3.0
@export var max_attempts: int = 20
@export var timeout: float = 30.0
@export var patrol_destination_var: StringName = &"patrol_destination"

var nav: NavigationAgent3D
var destination: Vector3
var move_started: bool = false
var tick_count: int = 0


func _generate_name() -> String:
	return "Random Patrol (%.1f)" % patrol_radius


func _setup() -> void:
	nav = agent.get_node_or_null("NavigationAgent3D") as NavigationAgent3D


func _enter() -> void:
	move_started = false
	tick_count = 0

	if nav == null or not agent.has_method("begin_move"):
		return

	var nav_map: RID = nav.get_navigation_map()

	# Navigation data must be synchronized.
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return

	var origin: Vector3 = agent.patrol_center

	for i in range(max_attempts):
		# Sample a random point inside a circle.
		var angle: float = randf_range(0.0, TAU)
		var radius: float = sqrt(randf()) * patrol_radius

		var sample: Vector3 = origin + Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

		# Project onto the navigation mesh.
		var point: Vector3 = NavigationServer3D.map_get_closest_point(
			nav_map, sample
		)

		var distance: float = origin.distance_to(point)

		if distance < min_distance or distance > patrol_radius:
			continue

		# Verify that a complete route exists.
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			nav_map,
			origin,
			point,
			true,
			nav.navigation_layers
		)

		if path.size() < 2:
			continue

		if path[path.size() - 1].distance_to(point) > 0.75:
			continue

		destination = point
		blackboard.set_var(patrol_destination_var, destination)

		agent.call("begin_move", destination)
		move_started = true
		return


func _tick(_delta: float) -> Status:
	if not move_started:
		return FAILURE

	tick_count += 1

	# Allow the NavigationAgent to update its path.
	if tick_count == 1:
		return RUNNING

	if nav.is_target_reached():
		return SUCCESS

	if nav.is_navigation_finished():
		return FAILURE

	if elapsed_time >= timeout:
		return FAILURE

	return RUNNING


func _exit() -> void:
	if agent != null and agent.has_method("end_move"):
		agent.call("end_move")
