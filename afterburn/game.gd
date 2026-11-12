extends Node3D

const PLAYER_SCENE := preload("res://player/player.tscn")
const PLAYER_SCRIPT := preload("res://afterburn/player.gd")
const SHIP_SCRIPT := preload("res://afterburn/ship.gd")
const BOLT_SCRIPT := preload("res://afterburn/bolt.gd")
const HUD_SCRIPT := preload("res://afterburn/hud.gd")
const INPUT_SCRIPT := preload("res://afterburn/input.gd")
const OBSTACLE_SCRIPT := preload("res://afterburn/obstacle.gd")
const SAVE_PATH := "user://afterburn_profile_v1.json"
const ENCOUNTERS := ["FREIGHT ARRIVAL", "SIGNAL JAM", "CONTAINER SIEGE", "DEAD FREQUENCY", "REDLINE", "LAST TRANSMISSION"]
const QUOTAS := [5, 7, 8, 9, 10, 12]
const MODS := [
	{"id": "damage", "name": "HOT CHAMBER", "description": "+25% damage on every weapon. Hit the sky harder."},
	{"id": "armor", "name": "REACTIVE SHELL", "description": "+40 armor now. Reduce all incoming damage by 10%."},
	{"id": "health", "name": "SECOND HEART", "description": "+25 maximum health and a full repair."},
	{"id": "speed", "name": "GHOST DRIVE", "description": "+15% movement speed. Own the space between shots."},
	{"id": "reload", "name": "QUICK FEED", "description": "Reload 25% faster and refill every magazine."},
	{"id": "rate", "name": "OVERCLOCK", "description": "Fire 18% faster. More pressure, less breathing room."}
]

var state: String = "boot"
var player: CharacterBody3D
var hud: CanvasLayer
var boss_ship: Node3D
var encounter: int = 0
var spawned: int = 0
var spawn_timer: float = 1.0
var score: int = 0
var kills: int = 0
var run_credits: int = 0
var combo: float = 1.0
var combo_time: float = 0.0
var run_time: float = 0.0
var choices: Array = []
var build_names: PackedStringArray = []
var pickups: Array[Node3D] = []
var profile: Dictionary = {"credits": 0, "runs": 0, "best": 0, "wins": 0, "tier": 1, "ranks": [0, 0, 0, 0, 0]}
var materials: Dictionary = {}
var prop_meshes: Dictionary = {}
var base_damage: Dictionary = {}
var map: Node3D
var rng := RandomNumberGenerator.new()
var course_scene: PackedScene
var course_chunks: Dictionary = {}
var distance_run: float = 0.0
var scored_distance: int = 0
var lighting: Node3D

func _ready() -> void:
	rng.randomize()
	_load_profile()
	map = get_node_or_null("FreightDistrict")
	if not map:
		if ResourceLoader.exists("res://afterburn/district.tscn"):
			map = load("res://afterburn/district.tscn").instantiate()
			add_child(map)
		else:
			build_map()
	_init_course()
	_create_player()
	var input := Node.new()
	input.set_script(INPUT_SCRIPT)
	input.game = self
	add_child(input)
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	hud.game = self
	add_child(hud)
	state = "menu"
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.menu()

func _create_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.set_script(PLAYER_SCRIPT)
	player.game = self
	player.sensitivity = 0.0025
	player.position = Vector3(0, 0.1, 24)
	add_child(player)
	player.camera.make_current()
	player.camera.far = 170.0
	player.get_node("WeaponSubViewport").mouse_filter = Control.MOUSE_FILTER_IGNORE
	for weapon in player.weapons_manager.weapons_array:
		base_damage[weapon.name] = weapon.damage
		if not weapon.is_melee_weapon:
			weapon.firing_distance = 150.0
			weapon.burst_mode = weapon.name != "Pistol"
	for weapon in player.weapons_manager.weapons_array:
		weapon.deactivate()
	player.weapons_manager.current_weapon_index = 2
	player.weapons_manager.current_weapon = player.weapons_manager.weapons_array[2]
	player.weapons_manager.current_weapon.activate(false)

func start_run() -> void:
	get_tree().paused = false
	_clear_combat()
	_reset_course()
	if is_instance_valid(player):
		remove_child(player)
		player.free()
	base_damage.clear()
	_create_player()
	encounter = 0
	spawned = 0
	spawn_timer = 2.0
	score = 0
	kills = 0
	run_credits = 0
	combo = 1.0
	combo_time = 0.0
	run_time = 0.0
	distance_run = 0.0
	scored_distance = 0
	build_names.clear()
	profile.runs += 1
	player.vital_capacity = 100.0 + int(profile.ranks[0]) * 10.0
	player.current_health = player.vital_capacity
	player.armor = 50.0 + int(profile.ranks[3]) * 10.0
	player.mobility = 1.0 + int(profile.ranks[2]) * 0.04
	for weapon in player.weapons_manager.weapons_array:
		weapon.damage = float(base_damage[weapon.name]) * (1.0 + int(profile.ranks[1]) * 0.06)
	_refill()
	state = "play"
	_save_profile()
	hud.clear_overlay()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud.notify("AUTO-RUN // A / D STRAFE // SPACE JUMP // S SLIDE", 4.0)

func _process(delta: float) -> void:
	if state != "play":
		return
	run_time += delta
	distance_run = maxf(distance_run, 24.0 - player.position.z)
	var distance_points: int = floori(distance_run)
	if distance_points > scored_distance:
		score += (distance_points - scored_distance) * 2
		scored_distance = distance_points
	_stream_course()
	combo_time = maxf(0.0, combo_time - delta)
	if combo_time <= 0.0:
		combo = move_toward(combo, 1.0, delta * 0.6)
	spawn_timer -= delta
	if encounter < 6:
		if spawned < QUOTAS[encounter] and spawn_timer <= 0.0 and enemies_alive() < 4 + floori(encounter / 2.0):
			_spawn_enemy()
			spawned += 1
			spawn_timer = 1.8
		elif spawned >= QUOTAS[encounter] and enemies_alive() == 0:
			complete_encounter()
	for index in range(pickups.size() - 1, -1, -1):
		var pickup: Node3D = pickups[index]
		if not is_instance_valid(pickup):
			pickups.remove_at(index)
			continue
		pickup.rotation.y += delta
		pickup.position.y = 0.7 + sin(run_time * 2.5 + float(index)) * 0.12
		if pickup.global_position.distance_to(player.global_position + Vector3(0, 0.7, 0)) < 2.0:
			_collect(pickup)
			pickups.remove_at(index)
			pickup.queue_free()

func encounter_name() -> String:
	return ENCOUNTERS[clampi(encounter, 0, 5)]

func enemies_alive() -> int:
	var count: int = 0
	for enemy in get_tree().get_nodes_in_group("afterburn_enemies"):
		if is_instance_valid(enemy) and not enemy.dying:
			count += 1
	return count

func _spawn_enemy(kind_override: String = "") -> Node3D:
	var available := ["striker", "interceptor"]
	if encounter >= 1:
		available.append("sniper")
	if encounter >= 2:
		available.append("guardian")
	var kind: String = kind_override if kind_override != "" else available[rng.randi_range(0, available.size() - 1)]
	var ship := StaticBody3D.new()
	ship.set_script(SHIP_SCRIPT)
	ship.game = self
	ship.kind = kind
	ship.boss = kind == "boss"
	var health: float = {"striker": 145.0, "sniper": 130.0, "guardian": 320.0, "interceptor": 180.0, "boss": 2900.0}.get(kind, 150.0)
	ship.max_hp = health * (1.0 + (int(profile.tier) - 1) * 0.18)
	ship.hp = ship.max_hp
	var spawn_positions := [
		Vector3(-13, 5.5, -17), Vector3(13, 5.0, -23),
		Vector3(-11, 6.0, -12), Vector3(11, 5.5, -14),
		Vector3(-7, 7.0, -31), Vector3(7, 4.5, -9)]
	ship.position = (Vector3(0, 7, -22) if ship.boss else spawn_positions[spawned % spawn_positions.size()]) + Vector3(0, 0, player.position.z - 18.0)
	add_child(ship)
	return ship

func spawn_escort() -> void:
	if state == "play" and enemies_alive() < 5:
		_spawn_enemy("interceptor")
		spawned += 1

func fire_bolt(origin: Vector3, direction: Vector3, speed: float, damage: float, shooter: RID, tint: Color) -> void:
	var bolt := Node3D.new()
	bolt.set_script(BOLT_SCRIPT)
	bolt.game = self
	bolt.position = origin
	bolt.velocity = direction * speed
	bolt.damage = damage * (1.0 + (int(profile.tier) - 1) * 0.12)
	bolt.shooter = shooter
	bolt.tint = tint
	add_child(bolt)

func ship_destroyed(ship: Node3D) -> void:
	kills += 1
	combo = minf(5.0, combo + 0.25)
	combo_time = 6.0
	var value: int = 40 if ship.kind == "guardian" else 25
	var earned: int = roundi(value * (1.0 + int(profile.ranks[4]) * 0.08))
	if ship.boss:
		earned = 500
	score += roundi((250 if not ship.boss else 5000) * combo)
	profile.credits += earned
	run_credits += earned
	_save_profile()
	spark(ship.global_position, ship.tint, 2.5 if ship.boss else 1.5)
	Global.enemy_killed.emit()
	hud.notify("%s DOWN // +%d CR // ×%.1f" % [ship.kind.to_upper(), earned, combo], 1.3)
	if ship.boss:
		finish_run(true)
		return
	if rng.randf() < 0.65:
		var kind: String = ["health", "armor", "ammo"][kills % 3]
		add_pickup(kind, Vector3(clampf(ship.position.x, -7, 7), 0.7, ship.position.z))

func complete_encounter() -> void:
	if state != "play":
		return
	choices = MODS.duplicate(true)
	choices.shuffle()
	choices = choices.slice(0, 3)
	state = "reward"
	Global.aim_mode_changed.emit(false)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.rewards(choices)

func choose_upgrade(id: String) -> void:
	if state != "reward":
		return
	for mod in MODS:
		if mod.id == id:
			build_names.append(mod.name)
	match id:
		"damage":
			for weapon in player.weapons_manager.weapons_array:
				weapon.damage *= 1.25
		"armor":
			player.armor = minf(150.0, player.armor + 40.0)
			player.damage_resistance *= 0.9
		"health":
			player.vital_capacity += 25.0
			player.current_health = player.vital_capacity
		"speed":
			player.mobility *= 1.15
		"reload":
			for weapon in player.weapons_manager.weapons_array:
				weapon.reload_time *= 0.75
		"rate":
			for weapon in player.weapons_manager.weapons_array:
				weapon.cooldown *= 0.82
	player.current_health = minf(player.vital_capacity, player.current_health + 30.0)
	player.armor = minf(150.0, player.armor + 20.0)
	player.invulnerability = 2.0
	_refill()
	_clear_bolts()
	encounter += 1
	spawned = 0
	spawn_timer = 2.3
	hud.clear_overlay()
	state = "play"
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if encounter >= 6:
		boss_ship = _spawn_enemy("boss")
		hud.notify("FINAL INTERCEPT // CIVIC ENFORCER", 4.0)
	else:
		hud.notify("ENCOUNTER %02d // %s" % [encounter + 1, encounter_name()], 3.0)

func _refill() -> void:
	for key in Bullets.ammo_inventory:
		if Bullets.ammo_inventory[key].max != -1:
			Bullets.ammo_inventory[key].current = Bullets.ammo_inventory[key].max
	for weapon in player.weapons_manager.weapons_array:
		weapon.current_mag = weapon.mag_capacity
	Global.bullets_changed.emit()

func pause_run() -> void:
	if state != "play":
		return
	state = "pause"
	Global.aim_mode_changed.emit(false)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.paused()

func resume_run() -> void:
	if state != "pause":
		return
	state = "play"
	hud.clear_overlay()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func finish_run(won: bool) -> void:
	if state == "result":
		return
	state = "result"
	Global.aim_mode_changed.emit(false)
	profile.best = maxi(int(profile.best), score)
	if won:
		profile.wins += 1
		profile.tier = mini(10, int(profile.tier) + 1)
	_save_profile()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.result(won)

func upgrade_cost(index: int) -> int:
	return 100 + int(profile.ranks[index]) * 90

func buy_upgrade(index: int) -> void:
	var cost: int = upgrade_cost(index)
	if profile.credits < cost or int(profile.ranks[index]) >= 10:
		return
	profile.credits -= cost
	profile.ranks[index] += 1
	_save_profile()
	hud.workshop()

func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return
	for key in ["credits", "runs", "best", "wins"]:
		profile[key] = clampi(int(data.get(key, 0)), 0, 999999999)
	profile.tier = clampi(int(data.get("tier", 1)), 1, 10)
	var ranks: Variant = data.get("ranks", [])
	if ranks is Array and ranks.size() == 5:
		for index in range(5):
			profile.ranks[index] = clampi(int(ranks[index]), 0, 10)

func _save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile))

func _clear_bolts() -> void:
	for bolt in get_tree().get_nodes_in_group("afterburn_bolts"):
		remove_child(bolt)
		bolt.queue_free()

func _clear_combat() -> void:
	boss_ship = null
	for enemy in get_tree().get_nodes_in_group("afterburn_enemies"):
		enemy.queue_free()
	_clear_bolts()
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	pickups.clear()
	for effect in get_tree().get_nodes_in_group("afterburn_effects"):
		effect.queue_free()

func add_pickup(kind: String, pos: Vector3, parent_node: Node3D = null) -> void:
	var pickup := Node3D.new()
	pickup.set_meta("kind", kind)
	pickup.position = pos
	var tint: Color = {"health": Color("#a4ffcb"), "armor": Color("#b4a4ff"), "ammo": Color("#ffaf74")}[kind]
	var model := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.45, 0.45)
	model.mesh = box
	model.material_override = material(tint, 1.5)
	pickup.add_child(model)
	var text := Label3D.new()
	text.text = {"health": "+ REPAIR", "armor": "+ ARMOR", "ammo": "+ AMMO"}[kind]
	text.position.y = 0.65
	text.font_size = 28
	text.pixel_size = 0.007
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.modulate = tint
	pickup.add_child(text)
	if parent_node:
		parent_node.add_child(pickup)
	else:
		add_child(pickup)
	pickups.append(pickup)

func _collect(pickup: Node3D) -> void:
	var kind: String = pickup.get_meta("kind")
	match kind:
		"health": player.current_health = minf(player.vital_capacity, player.current_health + 30.0)
		"armor": player.armor = minf(150.0, player.armor + 30.0)
		"ammo":
			for key in Bullets.ammo_inventory:
				Bullets._add_ammo(key, 80)
	hud.notify("%s SUPPLIED" % kind.to_upper(), 1.5)
	spark(pickup.global_position, Color("#a4ffcb"), 0.6)

func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key: String = str(color) + str(emission)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	materials[key] = mat
	return mat

func spark(pos: Vector3, tint: Color, radius: float) -> void:
	var effect := Node3D.new()
	effect.position = pos
	effect.add_to_group("afterburn_effects")
	add_child(effect)
	for index in range(6):
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * (0.1 + radius * 0.12)
		mesh.mesh = box
		mesh.material_override = material(tint, 2.5)
		effect.add_child(mesh)
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), rng.randf_range(-1, 1)).normalized()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(mesh, "position", direction * radius, 0.4)
		tween.tween_property(mesh, "scale", Vector3.ZERO, 0.5)
	var cleanup := create_tween()
	cleanup.tween_interval(0.6)
	cleanup.tween_callback(effect.queue_free)

func build_map() -> Node3D:
	map = Node3D.new()
	map.name = "FreightDistrict"
	add_child(map)
	var environment := WorldEnvironment.new()
	environment.name = "NightAtmosphere"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#142336")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#94afc9")
	env.ambient_light_energy = 0.65
	env.fog_enabled = true
	env.fog_light_color = Color("#193547")
	env.fog_density = 0.006
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	map.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.layers = 3
	moon.rotation_degrees = Vector3(-48, -28, 0)
	moon.light_color = Color("#b4d2e8")
	moon.light_energy = 1.3
	moon.shadow_enabled = true
	map.add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.layers = 3
	fill.rotation_degrees = Vector3(-25, 145, 0)
	fill.light_color = Color("#a4ffcb")
	fill.light_energy = 0.4
	map.add_child(fill)
	_box("DistrictFoundation", Vector3(72, 0.6, 100), Vector3(0, -0.3, -7), Color("#27343e"), true)
	_box("MainRoad", Vector3(18, 0.025, 100), Vector3(0, 0.02, -7), Color("#111c27"))
	for side in [-1, 1]:
		_box("FreightApron", Vector3(24, 0.12, 100), Vector3(side * 21, 0.06, -7), Color("#34434c"), true)
		_box("RunwayEdge", Vector3(0.075, 0.03, 100), Vector3(side * 8.8, 0.06, -7), Color("#a4ffcb"), false, 1.7)
		_box("BoundaryWall", Vector3(2, 5, 100), Vector3(side * 36, 2.3, -7), Color("#23323c"), true)
		for index in range(10):
			_box("RoadMarker", Vector3(0.13, 0.03, 2), Vector3(side * 1.4, 0.05, 35 - index * 9), Color("#d3d9bd"))
	_box("HangarCrown", Vector3(27, 0.18, 0.7), Vector3(0, 9, -55.5), Color("#ffaf74"), false, 2.0)
	for side in [-1, 1]:
		_box("HangarNeon", Vector3(0.16, 9, 0.7), Vector3(side * 13.5, 4.5, -55.5), Color("#ffaf74"), false, 2.0)
	_sign("CIVIC // FREIGHT AUTHORITY", Vector3(0, 11, -55), 0, Color("#a4ffcb"), 0.023)
	_sign("07 / AFTERBURN", Vector3(0, 6, -55.2), 0, Color("#ffaf74"), 0.028)
	var props: Node3D = load("res://resources/props/fps_demo_props.glb").instantiate()
	for node in props.get_children():
		if node is MeshInstance3D:
			prop_meshes[str(node.name)] = node.mesh
	props.free()
	for side in [-1, 1]:
		for index in range(3):
			var z: float = 21.0 - index * 26.0
			_prop("cargo", Vector3(side * 23, 0.14, z), Vector3(0.8, 0.8, 0.8), PI * 0.5, Color("#34505a") if side < 0 else Color("#71534a"))
			_sign("GAMMA / %02d" % (index + 1), Vector3(side * 21, 3.2, z + 5), 0, Color("#a4ffcb") if side < 0 else Color("#ffaf74"), 0.009)
			_prop("crate", Vector3(side * 12.5, 0.15, z + 3), Vector3.ONE, side * 0.15)
			_prop("crate", Vector3(side * 14, 0.15, z + 1.6), Vector3.ONE, 0)
			_prop("crate", Vector3(side * 13.4, 1.4, z + 2), Vector3.ONE * 0.85, 0.1)
			_prop("barrel", Vector3(side * 11.5, 0.15, z - 4), Vector3.ONE, 0)
			_prop("barrel", Vector3(side * 12.8, 0.15, z - 4.5), Vector3.ONE, 0.2)
		_prop("wreck", Vector3(side * 6.4, 0.1, -9 if side < 0 else 12), Vector3.ONE * 1.1, side * 0.5)
		for index in range(4):
			_prop("block", Vector3(side * 6.7, 0.22, 25 - index * 17), Vector3(0.85, 0.55, 0.45), 0.0)
		for index in range(5):
			var z: float = 32 - index * 20
			_box("LampPost", Vector3(0.16, 6, 0.16), Vector3(side * 31, 3, z), Color("#283640"))
			_box("LampHead", Vector3(2, 0.13, 0.4), Vector3(side * 30.2, 6.1, z), Color("#a4ffcb") if index % 2 == 0 else Color("#ffaf74"), false, 2.5)
			var light := OmniLight3D.new()
			light.position = Vector3(side * 28, 5, z)
			light.light_color = Color("#a4ffcb") if index % 2 == 0 else Color("#ffaf74")
			light.light_energy = 2.2
			light.omni_range = 12.0
			map.add_child(light)
	var skyline := RandomNumberGenerator.new()
	skyline.seed = 9127
	for side in [-1, 1]:
		for index in range(7):
			var height: float = skyline.randf_range(13, 47)
			var z: float = 65 - index * 20
			var x: float = side * skyline.randf_range(43, 59)
			var width: float = skyline.randf_range(8, 15)
			_box("SkylineTower", Vector3(width, height, 10), Vector3(x, height / 2.0 - 1, z), Color("#172738"))
			var neon: Color = Color("#a4ffcb") if index % 3 else Color("#b6a0ff")
			_box("TowerCrown", Vector3(width, 0.18, 10.1), Vector3(x, height - 1, z), neon, false, 1.7)
			for row in range(3, int(height) - 2, 4):
				_box("TowerWindow", Vector3(0.08, 0.65, 6.8), Vector3(x - side * (width / 2.0 + 0.02), row, z), Color("#3b7887"), false, 0.5)
	_sign("LOW GAMMA", Vector3(-35, 12, -16), PI * 0.5, Color("#a4ffcb"), 0.032)
	_sign("KEEP THE SIGNAL ALIVE", Vector3(35, 10, -28), -PI * 0.5, Color("#ffaf74"), 0.018)
	for index in range(3):
		_box("OverheadGantry", Vector3(68, 0.45, 0.6), Vector3(0, 13 + index, 28 - index * 36), Color("#314752"))
		for side in [-1, 1]:
			_box("GantryUpright", Vector3(0.6, 14, 0.6), Vector3(side * 33, 7, 28 - index * 36), Color("#314752"))
		_box("GantryLight", Vector3(9, 0.12, 0.8), Vector3(0, 12.7 + index, 28 - index * 36), Color("#a4ffcb"), false, 1.4)
	return map

func _box(node_name: String, dimensions: Vector3, pos: Vector3, color: Color, collision: bool = false, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.set_meta("role", node_name)
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = material(color, emission)
	node.position = pos
	map.add_child(node)
	if collision:
		var body := StaticBody3D.new()
		body.collision_layer = 5
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = dimensions
		shape.shape = box
		body.add_child(shape)
		node.add_child(body)
	return node

func _prop(kind: String, pos: Vector3, dimensions: Vector3, yaw: float, tint: Color = Color.TRANSPARENT) -> void:
	var node := MeshInstance3D.new()
	node.name = kind.capitalize()
	node.mesh = prop_meshes[kind]
	node.position = pos
	node.scale = dimensions
	node.rotation.y = yaw
	if tint.a > 0.0:
		node.material_override = material(tint)
	map.add_child(node)
	node.add_to_group("supplied_props", true)
	var body := StaticBody3D.new()
	body.collision_layer = 5
	if kind in ["cargo", "barrel", "wreck"]:
		body.add_to_group("metal", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bounds: AABB = node.mesh.get_aabb()
	box.size = bounds.size
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	node.add_child(body)

func _sign(text: String, pos: Vector3, yaw: float, tint: Color, pixel_size: float) -> void:
	var district_sign := Label3D.new()
	district_sign.name = "DistrictSign"
	district_sign.text = text
	district_sign.font = preload("res://resources/fonts/ShareTech-Regular.ttf")
	district_sign.font_size = 64
	district_sign.pixel_size = pixel_size
	district_sign.modulate = tint
	district_sign.position = pos
	district_sign.rotation.y = yaw
	map.add_child(district_sign)


func _init_course() -> void:
	course_scene = load("res://afterburn/district.tscn")
	lighting = Node3D.new()
	lighting.name = "CourseLighting"
	add_child(lighting)
	for child in map.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			map.remove_child(child)
			lighting.add_child(child)
	course_chunks[0] = map
	_cache_course_props()
	_prepare_chunk(map, 0)
	for index in [-1, 1, 2]:
		_spawn_chunk(index)

func _cache_course_props() -> void:
	if not prop_meshes.is_empty():
		return
	var source: Node3D = load("res://resources/props/fps_demo_props.glb").instantiate()
	for child in source.get_children():
		if child is MeshInstance3D:
			prop_meshes[str(child.name)] = child.mesh
	source.free()

func _reset_course() -> void:
	for chunk in course_chunks.values():
		if is_instance_valid(chunk):
			remove_child(chunk)
			chunk.free()
	course_chunks.clear()
	for index in [-1, 0, 1, 2]:
		_spawn_chunk(index)

func _spawn_chunk(index: int) -> void:
	var chunk: Node3D = course_scene.instantiate()
	chunk.name = "Route_%d" % index
	chunk.position.z = -index * 100.0
	for child in chunk.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			child.free()
	add_child(chunk)
	course_chunks[index] = chunk
	if index == 0:
		map = chunk
	_prepare_chunk(chunk, index)

func _prepare_chunk(chunk: Node3D, index: int) -> void:
	for child in chunk.get_children():
		if child is MeshInstance3D and child.is_in_group("supplied_props") and absf(child.position.x) < 10.0:
			for body in child.get_children():
				if body is StaticBody3D:
					body.set_script(OBSTACLE_SCRIPT)
					body.game = self
					body.destruct_root = child
					body.add_to_group("runner_obstacles")
	for row in range(3):
		var open_lane: int = posmod(index + row + 1, 3)
		var z: float = 8.0 - row * 26.0
		if posmod(index + row, 4) == 2:
			var beam: Node3D = _runner_prop(chunk, "block", Vector3(0, 1.25, z), Vector3(6.15, 0.24, 0.3))
			beam.kind = "low beam"
			var clearance_sign := Label3D.new()
			clearance_sign.text = "LOW CLEARANCE // SLIDE"
			clearance_sign.font_size = 44
			clearance_sign.pixel_size = 0.009
			clearance_sign.position.y = 1.2
			clearance_sign.modulate = Color("#ffaf74")
			beam.add_child(clearance_sign)
		else:
			for lane in range(3):
				if lane != open_lane:
					var kind: String = "crate" if posmod(row + lane + index, 2) == 0 else "block"
					_runner_prop(chunk, kind, Vector3((lane - 1) * 6.0, 0.14, z), Vector3.ONE if kind == "crate" else Vector3(0.85, 0.48, 0.45))
		if index >= 0:
			add_pickup(["ammo", "health", "armor"][posmod(row + index, 3)], Vector3((open_lane - 1) * 6.0, 0.7, z - 9), chunk)

func _runner_prop(chunk: Node3D, kind: String, pos: Vector3, mesh_scale: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.set_script(OBSTACLE_SCRIPT)
	body.game = self
	body.destruct_root = body
	body.kind = kind
	body.position = pos
	body.collision_layer = 5
	body.collision_mask = 0
	body.add_to_group("runner_obstacles")
	var mesh := MeshInstance3D.new()
	mesh.mesh = prop_meshes[kind]
	var bounds: AABB = mesh.mesh.get_aabb()
	mesh.scale = mesh_scale
	mesh.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * mesh_scale
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size * mesh_scale
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	body.add_child(shape)
	chunk.add_child(body)
	return body

func _stream_course() -> void:
	var current: int = floori((43.0 - player.position.z) / 100.0)
	for index in range(current - 1, current + 3):
		if not course_chunks.has(index):
			_spawn_chunk(index)
	for index in course_chunks.keys():
		if int(index) < current - 1 or int(index) > current + 2:
			var chunk: Node3D = course_chunks[index]
			course_chunks.erase(index)
			chunk.queue_free()
	for obstacle in get_tree().get_nodes_in_group("runner_obstacles"):
		if obstacle.kind == "low beam" and not obstacle.spent and not obstacle.has_meta("warned"):
			var gap: float = player.position.z - obstacle.global_position.z
			if gap > 0.0 and gap < 15.0:
				obstacle.set_meta("warned", true)
				hud.notify("LOW CLEARANCE // HOLD S OR CTRL TO SLIDE", 2.0)
