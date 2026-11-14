@tool
extends "res://common/managers/weapons_manager.gd"

## The weapon held when the scene opens and when a new run starts.
@export_node_path("Node3D") var starting_weapon: NodePath = NodePath("AssualtRifle"):
	set(value):
		starting_weapon = value
		if Engine.is_editor_hint() and is_inside_tree():
			_preview_starting_weapon()

func _ready() -> void:
	if Engine.is_editor_hint():
		_preview_starting_weapon()
		return
	super._ready()
	equip_starting_weapon()

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		super._process(delta)

func _preview_starting_weapon() -> void:
	# Preview only existing nodes; weapon gameplay scripts do not run in the editor.
	var selected := get_node_or_null(starting_weapon)
	for child in get_children():
		var pose := child.get_node_or_null("StandardAimPosition") as Node3D
		if not pose:
			continue
		child.visible = child == selected
		var arms := child.get_node_or_null("fps_demo_arms") as Node3D
		if arms:
			arms.transform = pose.transform
		for helper_name in ["TestTarget", "TestCamera"]:
			var helper := child.get_node_or_null(helper_name) as Node3D
			if helper:
				helper.visible = false

func equip_starting_weapon() -> void:
	if switch_tween:
		switch_tween.kill()
	current_aim_mode = false
	is_switching = false
	var selected := get_node_or_null(starting_weapon) as Node3D
	var index := weapons_array.find(selected)
	if index < 0:
		push_warning("Starting Weapon must point to a weapon in Weapons Array; using the first weapon.")
		index = 0
	for weapon in weapons_array:
		weapon.deactivate()
	current_weapon_index = index
	current_weapon = weapons_array[index]
	current_weapon.activate(false)
