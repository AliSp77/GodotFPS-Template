@tool
extends BTAction

@export var destination_var: StringName = &"carry_destination"
@export var carry_speed: float = 8.5
@export var arrival_distance: float = 1.8
@export var timeout: float = 10.0

var nav: NavigationAgent3D
var destination: Vector3
var started: bool = false
var completed: bool = false


func _generate_name() -> String:
	return "Rush to distant point with player"


func _setup() -> void:
	nav = agent.get_node_or_null("NavigationAgent3D") as NavigationAgent3D


func _enter() -> void:
	started = false
	completed = false
	if nav == null or not agent.has_method("start_carry"):
		return
	if not is_instance_valid(agent.held_player):
		return
	var value: Variant = blackboard.get_var(destination_var, null, false)
	if typeof(value) != TYPE_VECTOR3:
		return
	destination = value
	agent.call("start_carry", destination, carry_speed)
	started = true


func _tick(_delta: float) -> Status:
	if not started or not is_instance_valid(agent.held_player):
		return FAILURE
	if elapsed_time >= timeout:
		return FAILURE
	if agent.navigation_updated != true:
		return RUNNING
	var position: Vector3 = agent.global_position
	var distance: float = Vector2(position.x, position.z).distance_to(
		Vector2(destination.x, destination.z)
	)
	if distance <= arrival_distance or nav.is_target_reached():
		completed = true
		return SUCCESS
	if nav.is_navigation_finished():
		return FAILURE
	return RUNNING


func _exit() -> void:
	if agent.has_method("end_move"):
		agent.call("end_move")
	if not completed and agent.has_method("release_player"):
		agent.call("release_player")
