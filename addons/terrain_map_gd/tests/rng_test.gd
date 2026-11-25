extends SceneTree

const RNG = preload("res://addons/terrain_map_gd/studio_rng.gd")


func _initialize() -> void:
	# Golden values from the Studio's JavaScript-compatible FNV-1a / mulberry32 implementation.
	var vectors := [
		["", 2166136261, [2625274932, 2119670693, 3324411561, 1770755366, 3488654967]],
		["my-world", 1212557670, [21840293, 2513022312, 4096152088, 1027597966, 788188370]],
		["seed-1", 3597787782, [3490405299, 2254090093, 2418907795, 4223514349, 1913837662]],
		["تهران", 3194740584, [2234178161, 1707781504, 486735576, 1086467980, 2991681266]],
		["😀", 3409036472, [3949134190, 2278450477, 1786177236, 281350428, 4170881302]],
	]
	for vector in vectors:
		var seed_text: String = vector[0]
		if RNG.hash_seed(seed_text) != vector[1]:
			_fail("hash mismatch for %s" % seed_text)
			return
		var rng = RNG.new(seed_text)
		for expected in vector[2]:
			var actual: int = rng.next_u32()
			if actual != expected:
				_fail("sequence mismatch for %s: got %s, expected %s" % [seed_text, actual, expected])
				return
	print("TERRAIN_STUDIO_RNG_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
