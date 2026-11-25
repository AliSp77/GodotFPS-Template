@tool
class_name TerrainStudioRng
extends RefCounted
## A direct GDScript port of the Studio's xfnv-1a seed hash and mulberry32 RNG.
## This is one building block of the generator; it does not generate a map.

const JS = preload("res://addons/terrain_map_gd/js_compat.gd")
const MASK := 0xffffffff
const UINT32_SCALE := 4294967296.0

var _state: int = 1


func _init(seed_text: String = "") -> void:
	_state = hash_seed(seed_text)
	if _state == 0:
		_state = 1


static func hash_seed(seed_text: String) -> int:
	var h: int = 0x811c9dc5
	for unit: int in JS.utf16_units(seed_text):
		h = ((h ^ unit) * 0x01000193) & MASK
	return h


static func from_state(value: int):
	var rng = load("res://addons/terrain_map_gd/studio_rng.gd").new()
	rng._state = value & MASK
	if rng._state == 0:
		rng._state = 1
	return rng


func next_u32() -> int:
	_state = (_state + 0x6d2b79f5) & MASK
	var t: int = _state
	t = ((t ^ (t >> 15)) * (t | 1)) & MASK
	t = (t ^ ((t + (((t ^ (t >> 7)) * (t | 61)) & MASK)) & MASK)) & MASK
	return (t ^ (t >> 14)) & MASK


func next_float() -> float:
	return float(next_u32()) / UINT32_SCALE


## The original also permits fractional bounds, so this returns a float.
func next_int_inclusive(minimum: float, maximum: float) -> float:
	if maximum <= minimum:
		return minimum
	return minimum + fmod(float(next_u32()), maximum - minimum + 1.0)


func next_range(minimum: float, maximum: float) -> float:
	return minimum + next_float() * (maximum - minimum)


func next_bool(probability: float = 0.5) -> bool:
	return next_float() < probability


func pick(values: Array) -> Variant:
	assert(not values.is_empty(), "Rng.pick: empty array")
	return values[int(next_int_inclusive(0, values.size() - 1))]


func weighted(values: Array, weights: Array) -> Variant:
	assert(not values.is_empty(), "Rng.weighted: empty array")
	var total := 0.0
	for weight in weights:
		total += float(weight)
	var roll := next_float() * total
	for index in values.size():
		roll -= float(weights[index]) if index < weights.size() else 0.0
		if roll < 0:
			return values[index]
	return values.back()


func shuffled(values: Array) -> Array:
	var result := values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := int(next_int_inclusive(0, i))
		var item: Variant = result[i]
		result[i] = result[j]
		result[j] = item
	return result


func fork(salt: String):
	return from_state(next_u32() ^ hash_seed(salt))
