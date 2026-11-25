extends SceneTree
## Run with Godot .NET: --headless --path . --script res://terrain/tests/terrain_smoke.gd

var _level: Node3D
var _terrain: Node3D
var _player: CharacterBody3D
var _enemy: CharacterBody3D
var _frame := 0
var _started := 0
var _sent_noise := false


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	var script := load("res://terrain/core/CartoonTerrainData.cs")
	if script == null or not script.can_instantiate():
		_fail("C# terrain resource unavailable; build the .NET project first")
		return
	var a = script.new()
	var b = script.new()
	var recipe := {"archetype": "terraced_valley", "waterBias": 0.0}
	a.GenerateWithOptions(24, 24, "terrain-smoke", recipe)
	b.GenerateWithOptions(24, 24, "terrain-smoke", recipe)
	if a.ArtifactJson != b.ArtifactJson:
		_fail("same seed generated different documents")
		return
	for z in range(a.GetHeight()):
		for x in range(a.GetWidth()):
			if a.GetTile(x, z) == 2:
				_fail("zero water bias generated a water tile")
				return
	var document: Dictionary = JSON.parse_string(a.ArtifactJson)
	var usage: Array = []
	usage.resize(a.GetWidth() * a.GetHeight())
	usage.fill(0)
	usage[5 * a.GetWidth() + 5] = 2
	document["artifact"]["floorUsage"] = usage
	a.ArtifactJson = JSON.stringify(document)
	var saved: String = a.ArtifactJson
	a.ApplyEdit(5, 5, {"tool": "paint", "material": 2, "height": 0, "brush_size": 1})
	if a.GetTile(5, 5) != 2:
		_fail("terrain painting failed")
		return
	var edited: Dictionary = JSON.parse_string(a.ArtifactJson)
	if edited["artifact"]["floorUsage"][5 * a.GetWidth() + 5] != 2:
		_fail("floorUsage did not survive a map edit")
		return
	a.ArtifactJson = saved
	if a.ArtifactJson != saved or a.GetCellSize() != 2.5:
		_fail("document restoration or cell scale failed")
		return
	_level = load("res://terrain/demo/terrain_demo.tscn").instantiate()
	root.add_child(_level)
	_terrain = _level.get_node("Terrain")
	_player = _level.get_node("PlayerStart/Player")
	_enemy = _level.get_node("EnemyStart/Enemy")


func _physics_process(_delta: float) -> bool:
	if not is_instance_valid(_level):
		return false
	_frame += 1
	if _frame == 90:
		if not _player.is_on_floor() or not _enemy.is_on_floor():
			_fail("player or enemy did not land on demo terrain")
			return false
		var map := _level.get_world_3d().navigation_map
		var path := NavigationServer3D.map_get_path(map, _enemy.global_position, _player.global_position, true)
		if path.is_empty() or path[path.size() - 1].distance_to(_player.global_position) > 1.5:
			_fail("no complete navigation path between demo actors")
			return false
		root.get_node("Global").emit_signal("noise_emitted", _player.global_position, 100.0, _player)
		_sent_noise = true
	if _frame >= 1100 and _sent_noise:
		if _enemy.global_position.x > -5.0:
			var detail := ""
			for index in _enemy.get_slide_collision_count():
				var hit := _enemy.get_slide_collision(index)
				detail += " collider=%s normal=%s" % [hit.get_collider().get_path(), hit.get_normal()]
			_fail("enemy did not cross the bridge: position=%s, player=%s%s" % [_enemy.global_position, _player.global_position, detail])
			return false
		print("CARTOON_TERRAIN_SMOKE_OK")
		quit(0)
	if Time.get_ticks_msec() - _started > 45000:
		_fail("timed out")
	return false


func _fail(message: String) -> void:
	push_error("Cartoon terrain smoke: " + message)
	quit(1)
