extends CanvasLayer
var game: Node3D
var _label: Label
var _notice: Label
var _flash: ColorRect
var _notice_time := 0.0
const HELP := "WASD MOVE // SHIFT SPRINT // MOUSE AIM + FIRE // EXPLORE BOTH PATHS"
func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 24)
	add_child(_label)
	_notice = Label.new()
	_notice.position = Vector2(24, 58)
	_notice.add_theme_font_size_override("font_size", 18)
	_notice.text = HELP
	add_child(_notice)
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.2, 0.15, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
func _process(delta: float) -> void:
	if game and is_instance_valid(game.player):
		_label.text = "HULL %d%%  |  SHIPS %d  |  ROOMS %d" % [ceili(game.player.current_health), game.kills, game.get_node("RunBuilder").visited_route.size()]
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0: _notice.text = HELP
func damage_flash() -> void:
	_flash.color.a = 0.35
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.3)
func notify(message: String, duration: float = 2.0) -> void:
	_notice.text = message
	_notice_time = duration
