@tool
extends BTAction

@export var destination_var: StringName = &"carry_destination"
@export var min_distance: float = 12.0
@export var max_distance: float = 24.0
@export var max_attempts: int = 48

var nav: NavigationAgent3D


func _generate_name() -> String:
	return "Find distant carry destination"


func _setup() -> void:
	nav = agent.get_node_or_null("NavigationAgent3D") as NavigationAgent3D


func _tick(_delta: float) -> Status:
	if nav == null:
		return FAILURE
	var nav_map: RID = nav.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return FAILURE
	var origin: Vector3 = agent.global_position
	for attempt in range(max_attempts):
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(min_distance, max_distance)
		var sample: Vector3 = origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var point: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, sample)
		var horizontal_distance: float = Vector2(origin.x, origin.z).distance_to(Vector2(point.x, point.z))
		if horizontal_distance < min_distance or horizontal_distance > max_distance:
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(
			nav_map, origin, point, true, nav.navigation_layers
		)
		if path.size() < 2 or path[path.size() - 1].distance_to(point) > 0.75:
			continue
		blackboard.set_var(destination_var, point)
		return SUCCESS
	return FAILURE
