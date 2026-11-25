@tool
extends ScrollContainer

signal action_requested(action: String, arguments: Dictionary)
signal preview_changed

var paint_enabled := false
var target
var status: Label
var message: Label
var tool: OptionButton
var material_choice: OptionButton
var shape: OptionButton
var nature: OptionButton
var structure: OptionButton
var theme_key: LineEdit
var brush_size: SpinBox
var height: SpinBox
var strength: SpinBox
var soft: CheckBox
var file_dialog: FileDialog
var file_action := ""
var look_pickers: Dictionary = {}

func _init() -> void:
	custom_minimum_size.x = 260


func _ready() -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	var title := Label.new()
	title.text = "Cartoon Terrain"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(message)
	_button(box, "Create terrain data", "new_data")
	_section(box, "Generate")
	var generate_help := Label.new()
	generate_help.text = "Edit generation settings in the Data resource in the Inspector, then generate."
	generate_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(generate_help)
	_button(box, "Generate from data settings", "generate")
	_section(box, "Paint in the 3D viewport")
	var toggle := CheckButton.new()
	toggle.text = "Enable painting"
	toggle.tooltip_text = "Turn off to select and move scene objects."
	toggle.toggled.connect(func(value: bool): paint_enabled = value; preview_changed.emit())
	box.add_child(toggle)
	tool = _choice(box, "Tool", ["Paint", "Fill", "Raise", "Lower", "Flatten", "Smooth", "Nature", "Erase nature", "Build", "Theme", "Select", "Paste"])
	material_choice = _choice(box, "Material", ["Ground", "Rock", "Water", "Chasm", "Bridge"])
	height = _number(box, "Height (levels)", -8, 25, 0, 1)
	brush_size = _number(box, "Brush diameter", 1, 64, 1, 1)
	shape = _choice(box, "Brush shape", ["Circle", "Square", "Diamond"])
	tool.item_selected.connect(func(_index: int): preview_changed.emit())
	shape.item_selected.connect(func(_index: int): preview_changed.emit())
	brush_size.value_changed.connect(func(_value: float): preview_changed.emit())
	soft = CheckBox.new()
	soft.text = "Soft edges"
	box.add_child(soft)
	strength = _number(box, "Strength", 0.01, 1.0, 1.0, 0.01)
	nature = _choice(box, "Nature", ["Tree", "Thicket", "Stump"])
	structure = _choice(box, "Structure", ["Cleft", "Underpass"])
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = "Theme key"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	theme_key = LineEdit.new()
	theme_key.text = "highland_pass"
	theme_key.custom_minimum_size.x = 130
	row.add_child(theme_key)
	_section(box, "Selection")
	_button(box, "Copy selection", "copy")
	_button(box, "Cut selection", "cut")
	_button(box, "Clear selection", "clear")
	_section(box, "Look")
	_color_picker(box, "Ground tint", "ground_tint")
	_color_picker(box, "Water tint", "water_tint")
	_color_picker(box, "Foliage tint", "foliage_tint")
	_section(box, "Files")
	_button(box, "Save data resource…", "save_data")
	_button(box, "Import Studio JSON…", "import")
	_button(box, "Export Studio JSON…", "export")
	_section(box, "Derived data")
	_button(box, "Rebuild visuals", "rebuild_visuals")
	_button(box, "Rebuild collision", "rebuild_collision")
	_button(box, "Bake navigation", "bake_navigation")
	_button(box, "Validate spawn markers", "validate_spawns")
	file_dialog = FileDialog.new()
	add_child(file_dialog)
	file_dialog.file_selected.connect(_file_selected)
	var refresh_timer := Timer.new()
	refresh_timer.wait_time = 0.5
	refresh_timer.timeout.connect(refresh_status)
	add_child(refresh_timer)
	refresh_timer.start()
	refresh_status()


func set_terrain(value: Node3D) -> void:
	target = value
	if is_inside_tree():
		for property in look_pickers:
			var picker: ColorPickerButton = look_pickers[property]
			picker.disabled = not is_instance_valid(target)
			if is_instance_valid(target):
				picker.color = target.get(property)
		refresh_status()


func set_message(text: String) -> void:
	message.text = text


func is_paint_enabled() -> bool:
	return paint_enabled


func refresh_status() -> void:
	if not is_instance_valid(target):
		status.text = "Select a CartoonTerrain node to edit its map."
		return
	for property in look_pickers:
		var picker: ColorPickerButton = look_pickers[property]
		if not picker.get_popup().visible:
			picker.color = target.get(property)
	if target.get("data") == null:
		status.text = "No data assigned. Create data or assign a saved resource in the Inspector."
		return
	var collision_state := "STALE" if target.get("collision_stale") else "ready"
	var navigation_state := "STALE" if target.get("nav_stale") else "ready"
	var details := str(target.get("status"))
	var renderer: Node = target.get_node_or_null("TerrainPreview")
	if renderer != null:
		details = str(renderer.get("Status"))
	status.text = "%s × %s cells\nCollision: %s · Navigation: %s\n%s" % [target.data.call("GetWidth"), target.data.call("GetHeight"), collision_state, navigation_state, details]


func edit_options() -> Dictionary:
	var tools := ["paint", "fill", "raise", "lower", "flatten", "smooth", "decorate", "decoration_erase", "structure", "theme", "select", "paste"]
	var materials := [1, 0, 2, 4, 3]
	return {
		"tool": tools[tool.selected], "material": materials[material_choice.selected], "height": int(height.value),
		"brush_size": int(brush_size.value), "shape": ["circle", "square", "diamond"][shape.selected],
		"soft": soft.button_pressed, "strength": strength.value, "nature": ["tree", "thicket", "stump"][nature.selected],
		"structure": ["cleft", "underpass"][structure.selected], "theme": theme_key.text.strip_edges()
	}


func selected_tool() -> String:
	return str(edit_options()["tool"])


func _section(box: VBoxContainer, text: String) -> void:
	box.add_child(HSeparator.new())
	var label := Label.new()
	label.text = text
	box.add_child(label)


func _button(box: VBoxContainer, text: String, action: String) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(_button_pressed.bind(action))
	box.add_child(button)


func _button_pressed(action: String) -> void:
	if action in ["import", "export", "save_data"]:
		file_action = action
		file_dialog.clear_filters()
		file_dialog.access = FileDialog.ACCESS_RESOURCES if action == "save_data" else FileDialog.ACCESS_FILESYSTEM
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "import" else FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.add_filter("*.tres, *.res ; Godot resource" if action == "save_data" else "*.json ; Studio terrain JSON")
		file_dialog.popup_centered_ratio(0.7)
		return
	action_requested.emit(action, {})


func _file_selected(path: String) -> void:
	action_requested.emit(file_action, {"path": path})


func _color_picker(box: VBoxContainer, caption: String, property: String) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size.x = 100
	picker.edit_alpha = false
	picker.disabled = true
	row.add_child(picker)
	look_pickers[property] = picker
	picker.get_popup().about_to_popup.connect(func(): action_requested.emit("look_begin", {"property": property}))
	picker.color_changed.connect(func(color: Color): action_requested.emit("look_change", {"property": property, "color": color}))
	picker.get_popup().popup_hide.connect(func(): action_requested.emit("look_end", {"property": property}))


func _choice(box: VBoxContainer, caption: String, entries: Array) -> OptionButton:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var choice := OptionButton.new()
	choice.custom_minimum_size.x = 120
	for entry: String in entries:
		choice.add_item(entry)
	row.add_child(choice)
	return choice


func _number(box: VBoxContainer, caption: String, minimum: float, maximum: float, initial: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = initial
	spin.custom_minimum_size.x = 100
	row.add_child(spin)
	return spin
