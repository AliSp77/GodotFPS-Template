@tool
extends BTAction

@export var chasing_var: StringName = &"is_chasing"
@export var phase: StringName = &"rush"
@export var phase_speed: float = 8.5

@export var stopping_distance: float = 1.5

@export var repath_interval: float = 0.3
@export var repath_distance: float = 0.5

var nav: NavigationAgent3D
var target: Node3D

var movement_started: bool = false
var task_ready: bool = false

var repath_timer: float = 0.0
var last_target_position: Vector3


func _generate_name() -> String:
	return "Chase Player: %s" % phase.capitalize()


func _setup() -> void:
	nav = agent.get_node_or_null(
        "NavigationAgent3D"
	) as NavigationAgent3D


func _enter() -> void:
	movement_started = false
	task_ready = false
	repath_timer = 0.0

	if nav == null:
		return

	if not agent.has_method("begin_move"):
		return

	if not agent.has_method("end_move"):
		return
	if not agent.has_method("set_chase_phase"):
		return

	target = agent.target_player

	if not is_instance_valid(target):
		return

	agent.call("set_chase_phase", phase, phase_speed)
	task_ready = true

	print("[Chase] Started")


func _tick(delta: float) -> Status:
	if not task_ready:
		return FAILURE

	# The vision sensor controls when chasing ends.
	var is_chasing: bool = blackboard.get_var(
		chasing_var, false
	)

	if not is_chasing:
		return SUCCESS

	if not is_instance_valid(target):
		agent.call("set_chasing", false)
		return FAILURE

	var target_position: Vector3 = target.global_position
	var current_position: Vector3 = agent.global_position

	# Ground-based horizontal distance.
	var horizontal_distance: float = Vector2(
		current_position.x,
		current_position.z
	).distance_to(
		Vector2(
			target_position.x,
			target_position.z
		)
	)

	# Stay near the player without pushing into them.
	if horizontal_distance <= stopping_distance:
		if movement_started:
			agent.call("end_move")
			movement_started = false

		return RUNNING

	repath_timer += delta

	# Request a path when movement starts or
	# when the player has moved significantly.
	var should_repath: bool = not movement_started

	if repath_timer >= repath_interval:
		if last_target_position.distance_to(target_position) >= repath_distance:
			should_repath = true

		if movement_started and nav.is_navigation_finished():
			should_repath = true

	if should_repath:
		agent.call("begin_move", target_position)

		movement_started = true
		last_target_position = target_position
		repath_timer = 0.0

	return RUNNING


func _exit() -> void:
	if not task_ready:
		return

	if not is_instance_valid(agent.held_player):
		agent.call("end_move")

	movement_started = false
	task_ready = false

	print("[Chase] Ended")
