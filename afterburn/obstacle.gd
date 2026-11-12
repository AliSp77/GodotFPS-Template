extends StaticBody3D

var game: Node
var destruct_root: Node3D
var hp: float = 100.0
var spent: bool = false
var kind: String = "barricade"

func strike_player() -> void:
	if spent or not game or game.state != "play":
		return
	game.player.get_damage(20.0, Vector3.ZERO, true)
	game.player.invulnerability = maxf(game.player.invulnerability, 0.7)
	game.combo = 1.0
	game.hud.notify("IMPACT // STRAFE, JUMP, OR SLIDE", 1.5)
	_break()

func get_damage(amount: float, _direction: Vector3, _enemy_damage: bool = false) -> void:
	if spent or not game or game.state != "play":
		return
	hp -= amount
	game.hud.hit_feedback()
	if hp <= 0.0:
		game.score += 35
		_break()

func _break() -> void:
	if spent:
		return
	spent = true
	game.spark(global_position + Vector3(0, 0.8, 0), Color("#ffaf74"), 1.3)
	set_deferred("collision_layer", 0)
	if is_instance_valid(destruct_root):
		destruct_root.queue_free()
	else:
		queue_free()
