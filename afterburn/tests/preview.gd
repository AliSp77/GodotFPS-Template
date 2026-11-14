extends "res://afterburn/game.gd"

@export var scenario: String = "boss"

func _load_profile() -> void:
	pass

func _save_profile() -> void:
	pass

func _ready() -> void:
	super._ready()
	start_run()
	if scenario == "reward":
		complete_encounter()
	elif scenario == "charger":
		spawn_timer = 99999.0
		_spawn_enemy("charger")
	else:
		encounter = 6
		boss_ship = _spawn_enemy("boss")
		hud.notify("FINAL INTERCEPT // CIVIC ENFORCER", 3.0)
