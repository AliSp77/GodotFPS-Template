class_name RunEffect
extends Resource

func can_apply(_player: Player) -> bool:
	return true

func apply(_run: Node, _player: Player) -> void:
	push_error("RunEffect.apply must be implemented by a concrete effect.")
