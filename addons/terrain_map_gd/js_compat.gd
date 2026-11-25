extends RefCounted
## ECMAScript number and string operations needed by the Studio's generator.
## The seed itself must remain a String; do not stringify floats to form seeds.

const UINT32_MODULUS := 4294967296
const UINT32_MASK := 0xffffffff
const INT32_SIGN := 0x80000000


static func to_uint32(value: Variant) -> int:
	# Integer inputs can be masked without passing through a floating point value.
	if typeof(value) == TYPE_INT:
		return int(value) & UINT32_MASK
	var number: float = float(value)
	if not is_finite(number) or number == 0.0:
		return 0
	# int(float) truncates towards zero. Reduce first to avoid int64 overflow.
	var remainder: int = int(fmod(number, float(UINT32_MODULUS)))
	return remainder & UINT32_MASK


static func to_int32(value: Variant) -> int:
	var unsigned := to_uint32(value)
	return unsigned - UINT32_MODULUS if unsigned >= INT32_SIGN else unsigned


static func imul(a: Variant, b: Variant) -> int:
	# Each operand is signed 32-bit, so the intermediate fits in signed int64.
	return to_int32(to_int32(a) * to_int32(b))


static func unsigned_shift_right(value: Variant, shift: int) -> int:
	return to_uint32(value) >> (shift & 31)


static func js_round(value: float) -> float:
	# ECMA Math.round chooses the integer towards +infinity on a half tie.
	if not is_finite(value) or value == 0.0:
		return value
	var result := ceil(value)
	if result - 0.5 > value:
		result -= 1.0
	return result


static func uint8(value: Variant) -> int:
	return to_uint32(value) & 0xff


static func int8(value: Variant) -> int:
	var unsigned := uint8(value)
	return unsigned - 256 if unsigned >= 128 else unsigned


static func uint16(value: Variant) -> int:
	return to_uint32(value) & 0xffff


static func int16(value: Variant) -> int:
	var unsigned := uint16(value)
	return unsigned - 65536 if unsigned >= 32768 else unsigned


static func utf16_units(value: String) -> PackedInt32Array:
	# Godot indexes Unicode code points; JS charCodeAt indexes UTF-16 code units.
	var units := PackedInt32Array()
	for index in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint <= 0xffff:
			units.append(codepoint)
		else:
			codepoint -= 0x10000
			units.append(0xd800 | (codepoint >> 10))
			units.append(0xdc00 | (codepoint & 0x3ff))
	return units
