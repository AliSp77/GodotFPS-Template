extends Node

var game: Node

func _input(event: InputEvent) -> void:
	if not game or game.state != "play":
		return
	if event.is_action_pressed("aim_mode"):
		Global.aim_mode_changed.emit(true)
	elif event.is_action_released("aim_mode"):
		Global.aim_mode_changed.emit(false)

func _process(_delta: float) -> void:
	if not game or game.state != "play":
		return
	if Input.is_action_just_pressed("fire"):
		Global.fire_input.emit()
	if Input.is_action_just_pressed("reload"):
		Global.reload_input.emit()
	if Input.is_action_just_pressed("weapon_change_next"):
		Global.weapon_switch_next.emit()
	if Input.is_action_just_pressed("weapon_change_prev"):
		Global.weapon_switch_prev.emit()
