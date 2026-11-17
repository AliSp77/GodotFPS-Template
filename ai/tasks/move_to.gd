@tool
extends BTAction

@export var destination_var: StringName = &"patrol_destination"
@export var timeout: float = 30.0

var nav: NavigationAgent3D
var move_started: bool = false
var debug_timer: float = 0.0

func _generate_name() -> String:
	return "Move To %s" % destination_var

func _setup() -> void:
	nav = agent.get_node_or_null(
        "NavigationAgent3D"
	) as NavigationAgent3D

func _enter() -> void:
	debug_timer = 0.0
	move_started = false

	if nav == null:
		return

	if not agent.has_method("begin_move"):
		return

	# Read destination from the Blackboard.
	var value: Variant = blackboard.get_var(
		destination_var, null, false
	)

	if typeof(value) != TYPE_VECTOR3:
		return

	var target: Vector3 = value

	# Start moving toward the target.
	agent.call("begin_move", target)
	move_started = true

func _tick(delta: float) -> Status:
	if not move_started:
		push_error("[MoveTo] Movement never started")
		return FAILURE

	debug_timer += delta

	if debug_timer >= 1.0:
		debug_timer = 0.0

		print(
			"[MoveTo] updated=", agent.get("navigation_updated"),
			" moving=", agent.get("moving"),
			" position=", agent.global_position,
			" target=", nav.target_position,
			" distance=", agent.global_position.distance_to(
				nav.target_position
			),
			" reached=", nav.is_target_reached(),
			" finished=", nav.is_navigation_finished()
		)

	if elapsed_time >= timeout:
		push_warning("[MoveTo] Timeout")
		return FAILURE

	if agent.get("navigation_updated") != true:
		return RUNNING

	if nav.is_target_reached():
		print("SUCCESS")
		return SUCCESS

	if nav.is_navigation_finished():
		print("FAILURE")
		return SUCCESS

	return RUNNING

func _exit() -> void:
	if move_started and agent.has_method("end_move"):
		agent.call("end_move")
