extends CanvasLayer

const INK := Color("#10141b")
const PAPER := Color("#f1eddf")
const MINT := Color("#a4ffcb")
const ORANGE := Color("#ffaf74")
const MUTED := Color("#98a7ad")
var game: Node
var root: Control
var overlay: Control
var score_label: Label
var distance_label: Label
var status_label: Label
var objective_label: Label
var health_label: Label
var armor_label: Label
var ammo_label: Label
var weapon_label: Label
var combo_label: Label
var dash_label: Label
var hp_bar: ProgressBar
var armor_bar: ProgressBar
var dash_bar: ProgressBar
var boss_bar: ProgressBar
var boss_label: Label
var toast_label: Label
var flash: ColorRect
var crosshair: Label
var hitmark: Label
var segments: Array[ColorRect] = []
var toast_time: float = 0.0
var hit_time: float = 0.0
var font: Font = preload("res://resources/fonts/ShareTech-Regular.ttf")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top_back := rect(root, Color(0.035, 0.055, 0.08, 0.7))
	top_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_back.offset_bottom = 98
	label(root, "LOW GAMMA", Vector2(28, 22), Vector2(240, 28), 23)
	label(root, "AFTERBURN / ENDLESS RUN", Vector2(28, 53), Vector2(260, 22), 12, MINT)
	distance_label = label(root, "000000 M / AUTO-RUN", Vector2(28, 76), Vector2(260, 18), 10, MUTED)
	status_label = label(root, "", Vector2(-220, 23), Vector2(440, 22), 13, MINT)
	status_label.anchor_left = 0.5
	status_label.anchor_right = 0.5
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in range(6):
		var segment := rect(root, Color("#ffffff24"))
		segment.position = Vector2(-144 + index * 49, 56)
		segment.size = Vector2(43, 3)
		segment.anchor_left = 0.5
		segment.anchor_right = 0.5
		segments.append(segment)
	objective_label = label(root, "", Vector2(-220, 67), Vector2(440, 22), 11, MUTED)
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label = label(root, "", Vector2(-270, 22), Vector2(240, 55), 22)
	score_label.anchor_left = 1.0
	score_label.anchor_right = 1.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var footer := rect(root, Color(0.035, 0.055, 0.08, 0.78))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -138
	health_label = bottom_label("VITAL SYSTEM", Vector2(28, -118), Vector2(225, 23), 13)
	hp_bar = bottom_bar(Vector2(28, -88), Vector2(225, 5), MINT)
	armor_label = bottom_label("ARMOR", Vector2(28, -72), Vector2(225, 23), 12, MUTED)
	armor_bar = bottom_bar(Vector2(28, -45), Vector2(225, 4), Color("#b3a4ff"))
	combo_label = bottom_label("", Vector2(-150, -120), Vector2(300, 26), 18, ORANGE)
	combo_label.anchor_left = 0.5
	combo_label.anchor_right = 0.5
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_label = bottom_label("", Vector2(-150, -88), Vector2(300, 22), 11, MUTED)
	dash_label.anchor_left = 0.5
	dash_label.anchor_right = 0.5
	dash_bar = bottom_bar(Vector2(-150, -54), Vector2(300, 4), Color("#a7caff"))
	dash_bar.anchor_left = 0.5
	dash_bar.anchor_right = 0.5
	weapon_label = bottom_label("", Vector2(-300, -121), Vector2(270, 26), 15, MINT)
	weapon_label.anchor_left = 1.0
	weapon_label.anchor_right = 1.0
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label = bottom_label("", Vector2(-300, -92), Vector2(270, 45), 35)
	ammo_label.anchor_left = 1.0
	ammo_label.anchor_right = 1.0
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var help := bottom_label("A / D STRAFE   SPACE JUMP   S / CTRL SLIDE   SHIFT / Q DASH   RMB AIM   R RELOAD   WHEEL SWITCH   ESC PAUSE", Vector2(28, -26), Vector2(1220, 19), 10, MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -26
	help.offset_bottom = -7
	crosshair = label(root, "+", Vector2(-16, -21), Vector2(32, 42), 28, MINT)
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmark = label(root, "×", Vector2(-24, -27), Vector2(48, 54), 44, ORANGE)
	hitmark.anchor_left = 0.5
	hitmark.anchor_right = 0.5
	hitmark.anchor_top = 0.5
	hitmark.anchor_bottom = 0.5
	hitmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmark.hide()
	toast_label = label(root, "", Vector2(-360, 133), Vector2(720, 38), 20, ORANGE)
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label = label(root, "", Vector2(-240, 103), Vector2(480, 22), 12, ORANGE)
	boss_label.anchor_left = 0.5
	boss_label.anchor_right = 0.5
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = bar(root, Vector2(-240, 128), Vector2(480, 5), ORANGE)
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.hide()
	flash = rect(root, Color(1, 0.2, 0.3, 0))
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color = PAPER) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

func rect(parent: Node, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(14)
	return box

func bar(parent: Node, pos: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.position = pos
	node.size = dimensions
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_style := style(Color("#ffffff20"))
	background_style.set_content_margin_all(0)
	background_style.set_border_width_all(0)
	var fill_style := style(color)
	fill_style.set_content_margin_all(0)
	fill_style.set_border_width_all(0)
	node.add_theme_stylebox_override("background", background_style)
	node.add_theme_stylebox_override("fill", fill_style)
	parent.add_child(node)
	node.size = dimensions
	return node

func bottom_label(text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color = PAPER) -> Label:
	var node := label(root, text, pos, dimensions, font_size, color)
	node.anchor_top = 1.0
	node.anchor_bottom = 1.0
	return node

func bottom_bar(pos: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var node := bar(root, pos, dimensions, color)
	node.anchor_top = 1.0
	node.anchor_bottom = 1.0
	return node

func button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, callback: Callable, primary: bool = true) -> Button:
	var node := Button.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_stylebox_override("normal", style(MINT if primary else Color("#17252b"), MINT if primary else Color("#4a6067")))
	node.add_theme_stylebox_override("hover", style(Color("#d3ffe3") if primary else Color("#29433d"), MINT))
	node.add_theme_stylebox_override("pressed", style(ORANGE, ORANGE))
	node.add_theme_color_override("font_color", INK if primary else PAPER)
	node.add_theme_color_override("font_hover_color", INK if primary else PAPER)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func new_overlay() -> Control:
	if is_instance_valid(overlay):
		overlay.free()
	for child in root.get_children():
		if child is CanvasItem:
			child.hide()
	overlay = Control.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := rect(overlay, Color(0.025, 0.045, 0.065, 0.93))
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stripe := rect(overlay, MINT)
	stripe.position = Vector2(56, 60)
	stripe.size = Vector2(38, 3)
	return overlay

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	for child in root.get_children():
		if child is CanvasItem:
			child.show()

func menu() -> void:
	var panel := new_overlay()
	label(panel, "AN ENDLESS FIRST PERSON ROGUELITE", Vector2(109, 49), Vector2(900, 25), 14, MINT)
	label(panel, "LOW GAMMA", Vector2(56, 105), Vector2(1140, 112), 100)
	label(panel, "AFTERBURN.", Vector2(56, 205), Vector2(1140, 112), 100, ORANGE)
	label(panel, "THE SKY BELONGS TO THEM. TAKE IT BACK.", Vector2(61, 343), Vector2(1000, 30), 22, MINT)
	label(panel, "Run an endless freight route. Strafe, jump, slide, and shoot.\nSurvive six encounters, then bring down the Civic Enforcer.", Vector2(61, 389), Vector2(1050, 70), 20, MUTED)
	label(panel, "%d CREDITS BANKED     %d RUNS     THREAT TIER %02d" % [game.profile.credits, game.profile.runs, game.profile.tier], Vector2(61, 483), Vector2(1050, 30), 17, ORANGE)
	button(panel, "START RUN  /  ENTER", Vector2(61, 538), Vector2(270, 57), game.start_run)
	button(panel, "PERMANENT UPGRADES", Vector2(348, 538), Vector2(270, 57), workshop, false)
	label(panel, "KEEP RUNNING. CREDITS SURVIVE DEATH.\n6 ENCOUNTERS  /  4 SHIP CLASSES  /  1 GUNSHIP  /  AN ENDLESS CITY", Vector2(61, 623), Vector2(1120, 50), 13, MUTED)

func workshop() -> void:
	var panel := new_overlay()
	label(panel, "PERSISTENT SYSTEMS / SAVED ON THIS DEVICE", Vector2(109, 49), Vector2(1050, 25), 14, MINT)
	label(panel, "COME BACK STRONGER.", Vector2(56, 109), Vector2(1150, 80), 60)
	label(panel, "%d CREDITS AVAILABLE" % game.profile.credits, Vector2(60, 201), Vector2(1000, 30), 21, ORANGE)
	var names := ["HULL", "BALLISTICS", "MOBILITY", "ARMOR", "SALVAGE"]
	var descriptions := ["+10 maximum health", "+6% weapon damage", "+4% move speed", "+10 starting armor", "+8% credits per kill"]
	for index in range(5):
		var rank: int = int(game.profile.ranks[index])
		var cost: int = game.upgrade_cost(index)
		var card := Panel.new()
		card.position = Vector2(60 + index * 231, 270)
		card.size = Vector2(215, 245)
		card.add_theme_stylebox_override("panel", style(Color("#14242a"), Color("#42605b")))
		panel.add_child(card)
		label(card, names[index], Vector2(18, 20), Vector2(190, 25), 18, MINT)
		label(card, "%02d / 10" % rank, Vector2(18, 69), Vector2(190, 48), 34)
		label(card, descriptions[index], Vector2(18, 126), Vector2(190, 40), 14, MUTED)
		var buy := button(card, "MAXED" if rank >= 10 else "%d CR / BUY" % cost, Vector2(16, 186), Vector2(183, 43), func(): game.buy_upgrade(index), true)
		buy.disabled = rank >= 10 or game.profile.credits < cost
	button(panel, "START RUN", Vector2(60, 555), Vector2(270, 56), game.start_run)
	button(panel, "BACK", Vector2(348, 555), Vector2(200, 56), menu, false)
	label(panel, "Upgrades persist across runs. Defeat the Enforcer to increase the threat tier.", Vector2(60, 640), Vector2(1150, 30), 15, MUTED)

func rewards(choices: Array) -> void:
	var panel := new_overlay()
	label(panel, "ENCOUNTER %02d CLEARED / ACTION PAUSED" % (game.encounter + 1), Vector2(109, 49), Vector2(1100, 25), 14, MINT)
	label(panel, "REWRITE YOUR BUILD.", Vector2(56, 105), Vector2(1180, 90), 67)
	label(panel, "Choose one upgrade. Repairs, armor, and ammunition arrive before the next encounter.", Vector2(60, 208), Vector2(1150, 38), 18, MUTED)
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		var card := Panel.new()
		card.position = Vector2(60 + index * 391, 286)
		card.size = Vector2(369, 250)
		card.add_theme_stylebox_override("panel", style(Color("#142b2a"), Color("#42605b")))
		panel.add_child(card)
		label(card, "FIELD MOD / 0%d" % (index + 1), Vector2(22, 21), Vector2(320, 24), 14, MINT)
		label(card, choice.name, Vector2(22, 77), Vector2(330, 45), 31)
		var desc := label(card, choice.description, Vector2(22, 131), Vector2(325, 50), 17, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size = Vector2(325, 50)
		button(card, "INSTALL / %d" % (index + 1), Vector2(22, 192), Vector2(325, 43), func(): game.choose_upgrade(choice.id))
	label(panel, "CURRENT BUILD / " + ("STOCK SYSTEMS" if game.build_names.is_empty() else " + ".join(game.build_names)), Vector2(60, 585), Vector2(1150, 56), 16, ORANGE)

func paused() -> void:
	var panel := new_overlay()
	label(panel, "RUN SUSPENDED", Vector2(109, 49), Vector2(1000, 25), 14, MINT)
	label(panel, "TAKE A BREATH.", Vector2(56, 145), Vector2(1160, 100), 80)
	label(panel, "Your run is paused. Credits earned so far are already banked.", Vector2(60, 300), Vector2(1100, 45), 21, MUTED)
	button(panel, "RESUME RUN", Vector2(60, 419), Vector2(280, 58), game.resume_run)
	button(panel, "END RUN / KEEP CREDITS", Vector2(360, 419), Vector2(330, 58), func(): game.finish_run(false), false)

func result(won: bool) -> void:
	var panel := new_overlay()
	label(panel, "CIVIC ENFORCER DESTROYED" if won else "SIGNAL LOST / RUN TERMINATED", Vector2(109, 49), Vector2(1050, 25), 14, MINT)
	label(panel, "SKY RECLAIMED." if won else "BUILD. BREAK. RETURN.", Vector2(56, 127), Vector2(1170, 100), 71, ORANGE if won else PAPER)
	label(panel, "A higher threat tier is now available." if won else "Your salvage is safe. Upgrade your systems and run it again.", Vector2(60, 276), Vector2(1100, 45), 21, MUTED)
	label(panel, "%06d SCORE       %d KILLS       %d CREDITS EARNED" % [game.score, game.kills, game.run_credits], Vector2(60, 375), Vector2(1120, 60), 28, MINT)
	label(panel, "DISTANCE / %06d METERS" % floori(game.distance_run), Vector2(60, 440), Vector2(1100, 32), 21, ORANGE)
	button(panel, "RUN AGAIN", Vector2(60, 500), Vector2(270, 58), game.start_run)
	button(panel, "UPGRADES", Vector2(350, 500), Vector2(240, 58), workshop, false)
	button(panel, "MAIN MENU", Vector2(610, 500), Vector2(240, 58), menu, false)
	label(panel, "BANK / %d CR     BEST / %06d" % [game.profile.credits, game.profile.best], Vector2(60, 610), Vector2(1000, 30), 17, ORANGE)

func notify(text: String, duration: float = 2.0) -> void:
	toast_label.text = text
	toast_time = duration

func hit_feedback() -> void:
	hit_time = 0.12

func damage_flash() -> void:
	flash.color = Color(1.0, 0.16, 0.25, 0.23)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		if game.state == "play":
			game.pause_run()
		elif game.state == "pause":
			game.resume_run()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and game.state in ["menu", "result"]:
			game.start_run()
		elif game.state == "reward" and event.keycode in [KEY_1, KEY_2, KEY_3]:
			var index: int = event.keycode - KEY_1
			if index < game.choices.size():
				game.choose_upgrade(game.choices[index].id)

func _process(delta: float) -> void:
	if not game or not is_instance_valid(game.player):
		return
	var playing: bool = game.state == "play"
	if is_instance_valid(overlay):
		flash.color.a = 0.0
	crosshair.visible = playing and not game.player.is_aiming
	hit_time = maxf(0.0, hit_time - delta)
	hitmark.visible = playing and hit_time > 0.0
	flash.color.a = maxf(0.0, flash.color.a - delta * 0.7)
	if playing:
		toast_time = maxf(0.0, toast_time - delta)
	toast_label.visible = playing and toast_time > 0.0
	var player: Node = game.player
	hp_bar.max_value = player.vital_capacity
	hp_bar.value = player.current_health
	armor_bar.max_value = maxf(100.0, player.armor)
	armor_bar.value = player.armor
	health_label.text = "VITAL SYSTEM                     %03d" % ceili(player.current_health)
	armor_label.text = "ARMOR                               %03d" % ceili(player.armor)
	dash_bar.max_value = 3.0
	dash_bar.value = 3.0 - player.dash_cooldown
	dash_label.text = "AUTO-RUN %02d KM/H    SHIFT / %s" % [roundi(absf(player.velocity.z) * 3.6), "DASH READY" if player.dash_cooldown <= 0.0 else "%.1fs" % player.dash_cooldown]
	combo_label.text = "×%.1f / MOMENTUM" % game.combo
	distance_label.text = "%06d M / %02d KM/H" % [floori(game.distance_run), roundi(absf(player.velocity.z) * 3.6)]
	score_label.text = "%06d\n%d CREDITS BANKED" % [game.score, game.profile.credits]
	status_label.text = "THREAT TIER %02d / %s" % [game.profile.tier, "FINAL INTERCEPT" if game.encounter >= 6 else "ENCOUNTER %02d" % (game.encounter + 1)]
	objective_label.text = "DESTROY THE CIVIC ENFORCER" if game.encounter >= 6 else "%s / %d HOSTILES" % [game.encounter_name(), game.enemies_alive()]
	for index in range(6):
		segments[index].color = MINT if index < game.encounter else (ORANGE if index == game.encounter else Color("#ffffff24"))
	var weapon: Node = player.weapons_manager.current_weapon
	if is_instance_valid(weapon):
		weapon_label.text = weapon.name.to_upper() + (" / RELOADING" if weapon.is_reloading else "")
		ammo_label.text = "MELEE" if weapon.is_melee_weapon else "%02d / %03d" % [weapon.current_mag, maxi(0, weapon.get_current_ammo())]
	boss_bar.visible = playing and is_instance_valid(game.boss_ship)
	boss_label.visible = boss_bar.visible
	if boss_bar.visible:
		boss_bar.max_value = game.boss_ship.max_hp
		boss_bar.value = game.boss_ship.hp
		boss_label.text = "CIVIC ENFORCER // PHASE 0%d" % game.boss_ship.phase
