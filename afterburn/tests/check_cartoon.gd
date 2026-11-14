extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node3D = load("res://afterburn/shaders/cartoon_preview.tscn").instantiate()
	root.add_child(scene)
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var arguments := OS.get_cmdline_user_args()
	var output_path: String = arguments[0] if not arguments.is_empty() else "user://cartoon_shader_preview.png"
	var result := screenshot.save_png(output_path)
	print("CARTOON_SHADER_RENDER: ", "PASS" if result == OK else "FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
