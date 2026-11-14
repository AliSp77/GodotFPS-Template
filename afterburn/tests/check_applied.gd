extends Node

class PreviewGame:
	extends "res://afterburn/game.gd"
	func _load_profile() -> void:
		pass
	func _save_profile() -> void:
		pass

var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	print("PASS " if condition else "FAIL ", description)
	if not condition:
		failures += 1

func _run() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var game: Node3D = load("res://afterburn/afterburn.tscn").instantiate()
	game.set_script(PreviewGame)
	get_tree().root.add_child(game)
	await get_tree().process_frame
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.weapons_manager.set_process(false)
	var slots := {"Pistol": "pistol", "AssualtRifle": "assualt", "AssualtBurstRifle": "assualt_burst", "LMG": "lmg"}
	for slot: String in slots:
		var prefix: String = "WeaponsManager/" + slot + "/fps_demo_arms/Armature/Skeleton3D/"
		var body: MeshInstance3D = game.player.get_node(prefix + "hand_R/" + slots[slot])
		var magazine: MeshInstance3D = game.player.get_node(prefix + "Holder_R/" + slots[slot] + "_ammo")
		var assigned: bool = body.material_override is ShaderMaterial and magazine.material_override == body.material_override
		if assigned:
			assigned = body.material_override.shader.resource_path == "res://afterburn/shaders/cartoon.gdshader" and body.material_override.get_shader_parameter("albedo_texture").resource_path == "res://resources/textures/fps_demo_texture.png" and body.material_override.next_pass != null
		check(assigned and not body.get_node("MeshInstance3D").visible and not magazine.get_node("MeshInstance3D").visible, slot + " and magazine use textured cel material with a single outline")
	for slot in ["Knife", "Pistol", "AssualtRifle", "AssualtBurstRifle", "LMG"]:
		var arms: MeshInstance3D = game.player.get_node("WeaponsManager/" + slot + "/fps_demo_arms/Armature/Skeleton3D/fps_arms_extended")
		var material := arms.material_override as ShaderMaterial
		check(material != null and material.shader.resource_path == "res://afterburn/shaders/cartoon.gdshader" and material.get_shader_parameter("albedo_texture").resource_path == "res://resources/textures/fps_demo_texture.png" and material.next_pass != null and not arms.get_node("MeshInstance3D").visible, slot + " hands and arms use original texture with cel shading and a single outline")
	var index: int = 0
	for kind in ["striker", "sniper", "guardian", "interceptor", "boss", "charger"]:
		var ship: Node3D = game._spawn_enemy(kind)
		ship.set_physics_process(false)
		check(ship.visual.material_override is ShaderMaterial and ship.visual.material_override.shader.resource_path == "res://afterburn/shaders/cartoon.gdshader" and ship.visual.material_override.next_pass != null, kind + " hull uses cel shader and outline")
		if index < 4:
			ship.global_position = Vector3(-5.4 + index * 3.6, 3.4, game.player.global_position.z - 18.0)
		elif kind == "boss":
			ship.global_position = Vector3(0, 6, game.player.global_position.z - 30.0)
		index += 1
	for audio in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		audio.stop()
	for frame in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var arguments := OS.get_cmdline_user_args()
	var output_path: String = arguments[0] if not arguments.is_empty() else "user://cartoon_gameplay_preview.png"
	check(get_tree().root.get_texture().get_image().save_png(output_path) == OK, "Gameplay shader preview saved")
	game._clear_combat()
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("CARTOON_APPLIED: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)

