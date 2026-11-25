@tool
extends EditorProperty

var choice := OptionButton.new()
var values: Array = []


func setup(keys: Array, names: Array) -> void:
	values = keys
	add_child(choice)
	add_focusable(choice)
	for index in keys.size():
		choice.add_item(str(names[index]) if index < names.size() else str(keys[index]))
	choice.item_selected.connect(_selected)


func _update_property() -> void:
	var current := str(get_edited_object().get(get_edited_property()))
	var index := values.find(current)
	if index >= 0:
		choice.select(index)
	else:
		choice.select(-1)


func _selected(index: int) -> void:
	emit_changed(get_edited_property(), values[index])
