extends Node3D
const BOLT_SCRIPT := preload("res://afterburn/bolt.gd")
var state := "play"
var kills := 0
var combo := 1.0
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	hud.game = self
	player.weapons_manager.switch_weapon(1)
	player.get_node("WeaponsManager/RayCastOrigin/WeaponRayCast").collision_mask = 7
	Global.player_dead.connect(_on_player_dead)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func start_run() -> void: get_tree().reload_current_scene()
func finish_run(won: bool) -> void:
	if state != "play": return
	state = "finished"
	hud.notify("GOAL REACHED // %d SHIPS DESTROYED" % kills if won else "RUN ENDED // %d SHIPS DESTROYED" % kills, 1000.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
func _on_player_dead() -> void: finish_run(false)
func ship_destroyed(_ship: Node3D) -> void:
	kills += 1
	hud.notify("SHIP DOWN // %d" % kills, 1.5)
	Global.enemy_killed.emit()
func fire_bolt(origin: Vector3, direction: Vector3, speed: float, damage: float, shooter: RID, tint: Color) -> void:
	var bolt := Node3D.new()
	bolt.set_script(BOLT_SCRIPT)
	bolt.game = self
	bolt.position = origin
	bolt.velocity = direction * speed
	bolt.damage = damage
	bolt.shooter = shooter
	bolt.tint = tint
	add_child(bolt)
func spark(at: Vector3, tint: Color, scale_amount: float) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12 * scale_amount
	mesh.height = 0.24 * scale_amount
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	visual.material_override = material
	add_child(visual)
	visual.global_position = at
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(visual.queue_free)
