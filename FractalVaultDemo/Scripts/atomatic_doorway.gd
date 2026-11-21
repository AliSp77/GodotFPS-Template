@tool
extends Node3D

@export var debug: bool
@export var opening_sequence: bool


@export var wait_time: float = 2.0

@onready var timer: Timer = $Timer
@onready var presure_plate: Area3D = $PresurePlate
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _door_state: bool = false # True: Open, False: Close

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	timer.wait_time = wait_time
	presure_plate.body_entered.connect(_on_presure_plate_body_entered)
	presure_plate.body_exited.connect(_on_presure_plate_body_exited)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if debug:
		if opening_sequence and not animation_player.is_playing():
			animation_player.play("Open")
			opening_sequence = false
			animation_player.queue("DebugWait")
			animation_player.queue("Close")
	pass

func try_2_open():
	if not _door_state:
		animation_player.play("Open")
		_door_state = true

func try_2_close():
	if _has_occupants():
		return
	if _door_state:
		animation_player.play("Close")
		_door_state = false
		
func _on_presure_plate_body_entered(body: Node3D) -> void:
	if not _can_use_door(body):
		return
	try_2_open()
	timer.stop()
	pass # Replace with function body.

func _on_presure_plate_body_exited(body: Node3D) -> void:
	if _can_use_door(body) and not _has_occupants():
		timer.start()
	pass # Replace with function body.

func _on_timer_timeout():
	try_2_close()


func _can_use_door(body: Node3D) -> bool:
	return body is CharacterBody3D or body.is_in_group(&"door_access")


func _has_occupants() -> bool:
	for body in presure_plate.get_overlapping_bodies():
		if _can_use_door(body):
			return true
	return false
