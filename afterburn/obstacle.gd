extends CollisionObject3D

@export var game: Node
@export_enum("solid barrier", "breakable barrier", "low beam", "laser fence", "low laser", "high laser") var kind: String = "solid barrier"
@export var hp: float = 130.0
@export var contact_damage: float = 20.0
@export var destruct_root: Node3D
var spent: bool = false

func _ready() -> void:
	add_to_group("runner_obstacles")
	if not game:
		var ancestor := get_parent()
		while ancestor:
			if ancestor.has_method("start_run"):
				game = ancestor
				break
			ancestor = ancestor.get_parent()

func _physics_process(_delta: float) -> void:
	# Lasers hurt on overlap without blocking movement, jumping, or sliding.
	var area: Node = self
	if area is Area3D and game and game.state == "play":
		for body in area.get_overlapping_bodies():
			if body == game.player:
				strike_player()

func strike_player() -> void:
	if spent or not game or game.state != "play":
		return
	var protected: bool = game.player.invulnerability > 0.0
	if not protected:
		game.player.get_damage(contact_damage, Vector3.ZERO, true)
		game.player.invulnerability = maxf(game.player.invulnerability, 0.7)
		game.combo = 1.0
		game.hud.notify("IMPACT // STRAFE, JUMP, OR SLIDE", 1.5)
	# This is the only type that can be destroyed, even by a protected dash.
	if kind == "breakable barrier":
		_break()

func get_damage(amount: float, _direction: Vector3, enemy_damage: bool = false) -> void:
	if spent or not game or game.state != "play" or kind != "breakable barrier" or enemy_damage:
		return
	hp -= maxf(0.0, amount)
	game.hud.hit_feedback()
	if hp <= 0.0:
		game.score += 35
		_break()

func _break() -> void:
	if spent or kind != "breakable barrier":
		return
	spent = true
	game.spark(global_position + Vector3(0, 0.8, 0), Color("#a4ffcb"), 1.3)
	set_deferred("collision_layer", 0)
	if is_instance_valid(destruct_root):
		destruct_root.queue_free()
	else:
		queue_free()
