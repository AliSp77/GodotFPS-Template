class_name StageLever
extends Area3D

@export_range(0, 1, 1) var branch: int = 0
@onready var label: Label3D = $Label3D
var active := false
var stage_title := ""
var fuel := 1.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	_refresh()

func set_offer(title: String) -> void:
	stage_title = title
	_refresh()

func set_fuel(value: float) -> void:
	fuel = clampf(value, 0.0, 1.0)
	_refresh()

func set_active(value: bool) -> void:
	active = value
	_refresh()

func _refresh() -> void:
	if label == null:
		return
	label.text = "%s\n%s  %d%%" % ["LEFT" if branch == 0 else "RIGHT", stage_title if stage_title != "" else "LOCKED", roundi(fuel * 100.0)]
	label.modulate = Color(0.3, 1.0, 0.8) if active else Color(0.6, 0.6, 0.6)
