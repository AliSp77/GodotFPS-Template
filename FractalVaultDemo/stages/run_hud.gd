class_name StageRunHUD
extends CanvasLayer

signal choice(index: int)

@onready var status_label: Label = $Status
@onready var prompt_label: Label = $Prompt
@onready var prompt_backdrop: ColorRect = $PromptBackdrop
@onready var menu_panel: PanelContainer = $Menu
@onready var title_label: Label = $Menu/Rows/Title
@onready var option_buttons: Array[Button] = [$Menu/Rows/Option0, $Menu/Rows/Option1, $Menu/Rows/Option2, $Menu/Rows/Option3, $Menu/Rows/Option4]

func _ready() -> void:
	for index in option_buttons.size():
		option_buttons[index].pressed.connect(_on_option_pressed.bind(index))
	menu_panel.hide()

func _on_option_pressed(index: int) -> void:
	choice.emit(index)

func set_status(value: String) -> void:
	status_label.text = value

func set_prompt(value: String) -> void:
	prompt_label.text = value
	prompt_backdrop.visible = value != ""

func show_menu(title: String, options: Array[String], final_option: String, next_label: String = "") -> void:
	title_label.text = title
	for index in 3:
		option_buttons[index].visible = index < options.size()
		if index < options.size():
			option_buttons[index].text = options[index]
	option_buttons[3].visible = next_label != ""
	option_buttons[3].text = next_label
	option_buttons[4].text = final_option
	menu_panel.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_menu() -> void:
	menu_panel.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
