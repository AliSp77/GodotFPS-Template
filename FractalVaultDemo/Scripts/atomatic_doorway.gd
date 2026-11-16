@tool
extends Node3D

@export var debug: bool
@export var opening_sequence: bool
@export var animation_player: AnimationPlayer

@onready var timer: Timer = $Timer

var _door_state: bool = false # True: Open, False: Close
var _open_timer: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
		_open_timer = true
		timer.start()

func try_2_close():
	if not _door_state:
		animation_player.play("Open")
		_door_state = true
		
func _on_front_presure_plate_body_entered(body: Node3D) -> void:
	animation_player.play()
	pass # Replace with function body.

func _on_back_presure_plate_body_entered(body: Node3D) -> void:
	pass # Replace with function body.

func _on_timer_timeout():
	_open_timer = false
