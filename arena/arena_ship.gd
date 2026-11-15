extends StaticBody3D
@export var player: Node3D
var game: Node3D
@export_range(1.0, 500.0, 1.0) var max_hp := 140.0
@export_range(0.0, 10.0, 0.1) var strafe_radius := 1.5
@export_range(0.5, 8.0, 0.1) var fire_interval := 3.0
var hp := 140.0
var dying := false
var _anchor := Vector3.ZERO
var _age := 0.0
var _fire_timer := 1.5

func _ready() -> void:
	add_to_group("afterburn_enemies")
	hp = max_hp
	_anchor = global_position
	_fire_timer += fmod(absf(_anchor.x + _anchor.z), 1.5)
	_update_label()

func _physics_process(delta: float) -> void:
	if dying or not is_instance_valid(player) or not player.is_alive or game == null or game.state != "play": return
	_age += delta
	global_position = _anchor + Vector3(sin(_age * 1.3 + _anchor.x) * strafe_radius, sin(_age * 2.0) * 0.4, 0.0)
	look_at(player.global_position + Vector3.UP)
	_fire_timer -= delta
	if _fire_timer <= 0.0 and global_position.distance_to(player.global_position) < 32.0:
		var origin := global_position + Vector3(0, -0.15, 0)
		var direction := (player.global_position + Vector3.UP - origin).normalized()
		game.fire_bolt(origin, direction, 18.0, 12.0, get_rid(), Color("#a4ffcb"))
		_fire_timer = fire_interval

func get_damage(amount: float, _direction: Vector3, _enemy_damage: bool = false) -> void:
	if dying: return
	hp = maxf(0.0, hp - amount)
	_update_label()
	if hp <= 0.0:
		dying = true
		collision_layer = 0
		if is_instance_valid(game): game.ship_destroyed(self)
		queue_free()

func _update_label() -> void:
	var label := get_node_or_null("HealthLabel") as Label3D
	if label: label.text = "STRIKER // %d" % ceili(hp)
