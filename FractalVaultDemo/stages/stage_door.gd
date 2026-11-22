class_name StageDoor
extends Node3D

signal closed

@onready var collision_shape: CollisionShape3D = $Blocker/CollisionShape3D
@onready var panel: MeshInstance3D = $Panel

var is_open := false
var _tween: Tween

func _ready() -> void:
	panel.position.y = 1.5
	collision_shape.disabled = false

func set_open(value: bool) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	is_open = value
	collision_shape.set_deferred(&"disabled", value)
	_tween = create_tween()
	_tween.tween_property(panel, "position:y", 4.5 if value else 1.5, 0.6)
	if not value:
		_tween.tween_callback(func() -> void: closed.emit())
