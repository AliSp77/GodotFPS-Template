@tool
extends BTAction


func _generate_name() -> String:
	return "Release player"


func _tick(_delta: float) -> Status:
	if not agent.has_method("release_player"):
		return FAILURE
	agent.call("release_player")
	return SUCCESS
