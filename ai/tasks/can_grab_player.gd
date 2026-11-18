@tool
extends BTCondition


func _generate_name() -> String:
	return "Player is within grab range"


func _tick(_delta: float) -> Status:
	if agent.has_method("can_grab_player") and agent.call("can_grab_player"):
		return SUCCESS
	return FAILURE
