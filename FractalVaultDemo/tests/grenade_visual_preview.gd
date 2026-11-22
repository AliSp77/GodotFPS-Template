extends Node3D

func _ready() -> void:
	var volley := load("res://FractalVaultDemo/enemies/grenade_volley_square.tscn").instantiate() as GrenadeVolley
	volley.position = Vector3(0, 1.4, 0)
	volley.target_position = Vector3(0, 0.5, -8)
	volley.speed = 6.0
	add_child(volley)
