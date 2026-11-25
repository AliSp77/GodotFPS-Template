extends SceneTree

const Js := preload("res://addons/terrain_map_gd/js_compat.gd")


func _init() -> void:
	assert(Js.to_uint32(-1) == 4294967295)
	assert(Js.to_int32(4294967295) == -1)
	assert(Js.to_uint32(4294967297.9) == 1)
	assert(Js.to_uint32(-1.9) == 4294967295)
	assert(Js.to_uint32(INF) == 0)
	assert(Js.to_uint32(NAN) == 0)
	assert(Js.imul(0xffffffff, 5) == -5)
	assert(Js.imul(0x7fffffff, 2) == -2)
	assert(Js.unsigned_shift_right(-1, 1) == 2147483647)
	assert(Js.unsigned_shift_right(-1, 33) == 2147483647)
	assert(Js.js_round(-1.5) == -1.0)
	assert(Js.js_round(1.5) == 2.0)
	assert(Js.js_round(-1.6) == -2.0)
	assert(Js.uint8(-1) == 255 and Js.int8(255) == -1)
	assert(Js.uint16(-1) == 65535 and Js.int16(65535) == -1)
	assert(Js.utf16_units("A😀é") == PackedInt32Array([65, 0xd83d, 0xde00, 233]))
	print("JS compatibility tests passed")
	quit()
