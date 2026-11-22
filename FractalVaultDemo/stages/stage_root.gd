class_name StageRoot
extends Node3D

signal player_entered(player: Player)

@onready var entry: Marker3D = $Entry
@onready var exits: Array[Marker3D] = [$ExitLeft, $ExitRight]
@onready var entry_door: StageDoor = $EntryDoor
@onready var doors: Array[StageDoor] = [$Doors/Left, $Doors/Right]
@onready var levers: Array[StageLever] = [$Levers/Left, $Levers/Right]
@onready var vendor: StageVendor = $Vendor
@onready var spawn_markers: Node3D = $EnemySpawns
@onready var enemies: Node3D = $Enemies
@onready var navigation: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	$EntryArea.body_entered.connect(_on_entry_body_entered)
	vendor.set_active(false)
	for lever in levers:
		lever.set_active(false)

func _on_entry_body_entered(body: Node3D) -> void:
	if body is Player and body.is_alive:
		player_entered.emit(body)

func set_offers(left: String, right: String) -> void:
	levers[0].set_offer(left)
	levers[1].set_offer(right)
	for lever in levers:
		lever.set_fuel(1.0)

func set_shop_active(value: bool) -> void:
	vendor.set_active(value)
	for lever in levers:
		lever.set_active(value)

func spawn_position(rng: RandomNumberGenerator, player_position: Vector3) -> Vector3:
	var markers := spawn_markers.get_children()
	if markers.is_empty():
		return global_position
	if rng.randf() < 0.7:
		return (markers[rng.randi_range(0, markers.size() - 1)] as Marker3D).global_position
	var map := navigation.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		for attempt in 12:
			var point := to_global(Vector3(rng.randf_range(-14.0, 14.0), 0.0, rng.randf_range(-12.0, 8.0)))
			var closest := NavigationServer3D.map_get_closest_point(map, point)
			if closest.distance_to(player_position) > 8.0 and closest.distance_to(point) < 2.0:
				return closest + Vector3.UP * 0.1
	return (markers[rng.randi_range(0, markers.size() - 1)] as Marker3D).global_position
