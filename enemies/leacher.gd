
extends CharacterBody3D

@export var move_speed: float = 3.5
@export var gravity: float = 9.8

@onready var nav: NavigationAgent3D = $NavigationAgent3D

var moving: bool = false
var navigation_updated: bool = false


func begin_move(destination: Vector3) -> void:
	navigation_updated = false
	nav.target_position = destination
	moving = true


func end_move() -> void:
	moving = false
	velocity.x = 0.0
	velocity.z = 0.0


func _physics_process(delta: float) -> void:
	if moving:
		var next_point: Vector3 = global_position

		# Always perform the first path update after
		# a new movement request.
		if not navigation_updated or not nav.is_navigation_finished():
			next_point = nav.get_next_path_position()
			navigation_updated = true

		if not nav.is_navigation_finished():
			var direction: Vector3 = next_point - global_position
			direction.y = 0.0
			direction = direction.normalized()

			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Apply gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()
