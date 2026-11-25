@tool
extends EditorInspectorPlugin

signal generate_requested(data: Resource)

const ChoiceProperty = preload("res://terrain/editor/generation_choice_property.gd")


func _can_handle(object: Object) -> bool:
	return object is Resource and object.has_method("GenerateFromSettings") and object.has_method("GetGenerationThemes")


func _parse_begin(object: Object) -> void:
	var generate := Button.new()
	generate.text = "Generate map from these settings"
	generate.tooltip_text = "Replace this resource's map using the settings below. This can be undone."
	generate.pressed.connect(func(): generate_requested.emit(object))
	add_custom_control(generate)


func _parse_property(object: Object, _type: int, name: String, _hint_type: int, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var keys: Array = []
	var labels: Array = []
	match name:
		"GenerationTheme":
			keys = ["Random", "*blend"]
			labels = ["Any theme", "Mixed regions"]
			keys.append_array(object.call("GetGenerationThemes"))
			labels.append_array(object.call("GetGenerationThemeNames"))
		"GenerationArchetype":
			keys = ["Random"]
			labels = ["Surprise me"]
			keys.append_array(object.call("GetGenerationArchetypes"))
			labels.append_array(object.call("GetGenerationArchetypeNames"))
		"GenerationFrame":
			keys = ["Random"]
			labels = ["Natural"]
			for key in object.call("GetGenerationFrames"):
				keys.append(key)
				labels.append(str(key).replace("_", " ").capitalize())
		"GenerationMotif":
			keys = ["Random", "*none"]
			labels = ["Let the map decide", "Pure landform"]
			keys.append_array(object.call("GetGenerationMotifs"))
			labels.append_array(object.call("GetGenerationMotifNames"))
		_:
			return false
	var editor := ChoiceProperty.new()
	editor.setup(keys, labels)
	add_property_editor(name, editor)
	return true
