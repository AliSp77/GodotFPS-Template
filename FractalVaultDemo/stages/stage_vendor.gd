class_name StageVendor
extends Area3D

@onready var label: Label3D = $Label3D
var active := false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	set_active(false)

func set_active(value: bool) -> void:
	active = value
	visible = value
	monitorable = value
