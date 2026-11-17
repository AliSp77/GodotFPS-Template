
@tool
extends BTAction

@export var patrol_radius: float = 50.0
@export var min_distance: float = 3.0
@export var max_attempts: int = 20
@export var destination_var: StringName = &"patrol_destination"

var nav: NavigationAgent3D


func _generate_name() -> String:
	return "Find Random Patrol Point (%.1f)" % patrol_radius


func _setup() -> void:
	nav = agent.get_node_or_null(
        "NavigationAgent3D"
	) as NavigationAgent3D


func _tick(_delta: float) -> Status:
	if nav == null:
		return FAILURE

	var nav_map: RID = nav.get_navigation_map()

	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return FAILURE

	var origin: Vector3 = agent.global_position

	for i in range(max_attempts):
		# Generate a random point within a circle.
		var angle: float = randf_range(0.0, TAU)
		var radius: float = sqrt(randf()) * patrol_radius

		var sample: Vector3 = origin + Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

		# Project sample onto the NavMesh.
		var point: Vector3 = NavigationServer3D.map_get_closest_point(
			nav_map,
			sample
		)

		var distance: float = origin.distance_to(point)

		if distance < min_distance or distance > patrol_radius:
			continue

		# Validate a complete navigation path.
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			nav_map,
			origin,
			point,
			true,
			nav.navigation_layers
		)

		if path.size() < 2:
			continue

		var final_point: Vector3 = path[path.size() - 1]

		if final_point.distance_to(point) > 0.75:
			continue

		# Store destination for the next task.
		blackboard.set_var(destination_var, point)

		return SUCCESS

	return FAILURE
