@tool
extends BTAction

@export var lift_height: float = 2.2


func _generate_name() -> String:
	return "Lift player"


func _tick(_delta: float) -> Status:
	if agent.has_method("grab_player") and agent.call("grab_player", lift_height):
		return SUCCESS
	return FAILURE
