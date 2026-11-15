@tool
extends Node3D
class_name ArenaSegment

const SIZE := 24.0
const AREA := SIZE * SIZE
const DOOR_WIDTH := 4.0
enum RoomType { STRAIGHT, FORK, DEAD_END, GOAL }
@export var room_type: RoomType = RoomType.STRAIGHT
@export_range(0.01, 10.0, 0.01) var selection_weight := 1.0

func authored_enemy_count() -> int: return _child_count("AuthoredEnemies")
func authored_obstacle_count() -> int: return _child_count("AuthoredObstacles")
func enemy_slots() -> Array[Marker3D]: return _markers("EnemySpawns")
func obstacle_slots() -> Array[Marker3D]: return _markers("ObstacleSpawns")
func exit_directions() -> PackedInt32Array:
	match room_type:
		RoomType.STRAIGHT: return PackedInt32Array([0])
		RoomType.FORK: return PackedInt32Array([0, 1])
	return PackedInt32Array()

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var entry := get_node_or_null("Entry") as Marker3D
	if entry == null or not entry.position.is_equal_approx(Vector3(0, 0, 12)):
		errors.append("Entry must be a Marker3D at (0, 0, 12).")
	if room_type in [RoomType.STRAIGHT, RoomType.FORK]:
		var exit_marker := get_node_or_null("Exit") as Marker3D
		if exit_marker == null or not exit_marker.position.is_equal_approx(Vector3(0, 0, -12)):
			errors.append("Exit must be a Marker3D at (0, 0, -12).")
	if room_type == RoomType.FORK:
		var side := get_node_or_null("ExitEastMarker") as Marker3D
		if side == null or not side.position.is_equal_approx(Vector3(12, 0, 0)):
			errors.append("Fork ExitEastMarker must be a Marker3D at (12, 0, 0).")
		var collision := get_node_or_null("EastWall/Collision") as CollisionShape3D
		if collision == null or not collision.disabled:
			errors.append("Fork EastWall collision must be disabled.")
		for path in ["EastExitNorth", "EastExitSouth"]:
			if not get_node_or_null(path) is StaticBody3D:
				errors.append("Fork needs %s doorway wall." % path)
	if room_type in [RoomType.DEAD_END, RoomType.GOAL] and not get_node_or_null("ExitBlock") is StaticBody3D:
		errors.append("Terminal room needs an ExitBlock wall.")
	for path in ["AuthoredEnemies", "AuthoredObstacles", "EnemySpawns", "ObstacleSpawns"]:
		if not get_node_or_null(path) is Node3D:
			errors.append("Missing Node3D container: %s." % path)
	for marker in enemy_slots() + obstacle_slots():
		_validate_placement(marker.position, str(marker.name), errors)
	for path in ["AuthoredEnemies", "AuthoredObstacles"]:
		var container := get_node_or_null(path)
		if container != null:
			for child in container.get_children():
				if child is Node3D:
					_validate_placement((child as Node3D).position, str(child.name), errors)
	return errors

func _validate_placement(point: Vector3, label: String, errors: PackedStringArray) -> void:
	if absf(point.x) > 11.0 or absf(point.z) > 11.0:
		errors.append("%s lies outside the usable arena." % label)
	if absf(point.x) < 3.0 and point.z > 9.0:
		errors.append("%s blocks Entry." % label)
	if room_type in [RoomType.STRAIGHT, RoomType.FORK] and absf(point.x) < 3.0 and point.z < -9.0:
		errors.append("%s blocks Exit." % label)
	if room_type == RoomType.FORK and absf(point.z) < 3.0 and point.x > 9.0:
		errors.append("%s blocks ExitEast." % label)

func _get_configuration_warnings() -> PackedStringArray: return validation_errors()
func _child_count(path: String) -> int:
	var container := get_node_or_null(path)
	return container.get_child_count() if container != null else 0
func _markers(path: String) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	var container := get_node_or_null(path)
	if container != null:
		for child in container.get_children():
			if child is Marker3D: result.append(child)
	return result
