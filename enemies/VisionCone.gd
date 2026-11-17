
@tool
extends Area3D
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

@export_group("Wedge Dimensions")

@export_range(0.1, 100.0, 0.1) var length: float = 8.0:
	set(value):
		length = value
		_generate_shape()

@export_range(1.0, 180.0, 1.0) var angle: float = 45.0:
	set(value):
		angle = value
		_generate_shape()

@export_range(0.01, 20.0, 0.01) var center_height: float = 0.5:
	set(value):
		center_height = value
		_generate_shape()

@export_range(0.01, 20.0, 0.01) var outer_height: float = 2.5:
	set(value):
		outer_height = value
		_generate_shape()

@export_group("Geometry")

@export_range(4, 128, 1) var segments: int = 32:
	set(value):
		segments = value
		_generate_shape()


func _ready() -> void:
	_generate_shape()


func _generate_shape() -> void:
	if not is_inside_tree():
		return

	var points := PackedVector3Array()

	var half_h := center_height * 0.5
	var half_H := outer_height * 0.5
	var half_angle := deg_to_rad(angle * 0.5)

	# Narrow end: two points separated vertically by h.
	points.append(Vector3(0.0, half_h, 0.0))
	points.append(Vector3(0.0, -half_h, 0.0))

	# Wide end: upper and lower circular arcs.
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var theta := lerpf(-half_angle, half_angle, t)

		var x := sin(theta) * length
		var z := -cos(theta) * length

		# Upper edge of the curved end.
		points.append(Vector3(x, half_H, z))

		# Lower edge of the curved end.
		points.append(Vector3(x, -half_H, z))

	# Generate convex collision geometry.
	var convex := ConvexPolygonShape3D.new()
	convex.points = points

	collision_shape_3d.shape = convex
