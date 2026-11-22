extends Node3D

@onready var ray_cast_origin: Node3D = $RayCastOrigin
@onready var weapon_ray_cast: RayCast3D = $RayCastOrigin/WeaponRayCast
@onready var main_camera: Camera3D = %MainCamera

# Smooth follow settings
@export var follow_speed: float = 60.0 

# Weapon index for switching
# The editor-authored loadout contains knife then pistol; purchased scenes append here.
@export var weapons_array: Array[Node3D] = []
var current_weapon_index: int = 0
var current_weapon: Node3D

# Track aim mode state
var current_aim_mode: bool = false
var controls_locked: bool = false
var damage_multiplier: float = 1.0
var reload_multiplier: float = 1.0
var _base_stats: Dictionary = {}
var _acquired: Array[Node3D] = []

# Weapon switch state
var is_switching: bool = false
var switch_tween: Tween

func _ready() -> void:
	# Start with the pistol in the editor-authored loadout.
	for weapon in weapons_array:
		_base_stats[weapon] = Vector2(weapon.damage, weapon.reload_time)
	current_weapon_index = mini(1, weapons_array.size() - 1)
	_setup_current_weapon()
	
	# Connect to input signals
	Global.fire_input.connect(_on_fire_input)
	Global.reload_input.connect(_on_reload_input)
	Global.weapon_switch_next.connect(switch_to_next_weapon)
	Global.weapon_switch_prev.connect(switch_to_previous_weapon)
	Global.aim_mode_changed.connect(_on_aim_mode_changed)

func _setup_current_weapon() -> void:
	current_weapon = weapons_array[current_weapon_index]
	
	# Initialize all weapons
	for weapon in weapons_array:
		weapon.initialize(main_camera, weapon_ray_cast, ray_cast_origin)
		weapon.deactivate()
	
	# Activate current weapon (pistol) with current aim mode
	current_weapon.activate(current_aim_mode)

func _process(_delta: float) -> void:
	# Smoothly interpolate position and rotation to follow camera
	var target_transform = main_camera.global_transform
	
	# Lerp position
	global_position = global_position.lerp(target_transform.origin, follow_speed * _delta)
	
	# Slerp rotation (spherical linear interpolation for smooth rotation)
	var current_basis = global_transform.basis
	var target_basis = target_transform.basis
	global_transform.basis = current_basis.slerp(target_basis, follow_speed * _delta)
	
	# Continuous firing for automatic weapons (burst mode)
	# Pass false to indicate this is NOT the initial press
	if not controls_locked and Input.is_action_pressed("fire") and current_weapon.burst_mode:
		current_weapon.try_fire(false)

func _on_fire_input() -> void:
	if controls_locked:
		return
	# This is called on initial press, so pass true
	current_weapon.try_fire(true)

func _on_reload_input() -> void:
	if controls_locked:
		return
	if current_weapon.is_melee_weapon:
		return
	current_weapon.start_reload()

func _on_aim_mode_changed(aim_mode: bool) -> void:
	if controls_locked:
		return
	# Update tracked aim mode
	current_aim_mode = aim_mode
	
	# The weapon will handle its own animation through its connected signal
	# No need to do anything else here as each weapon is connected to the global signal

# Weapon switching functions
func switch_to_next_weapon() -> void:
	if controls_locked:
		return
	if current_weapon.is_reloading:
		return
	var next_index = (current_weapon_index + 1) % weapons_array.size()
	switch_weapon(next_index)

func switch_to_previous_weapon() -> void:
	if controls_locked:
		return
	if current_weapon.is_reloading:
		return
	var prev_index = (current_weapon_index - 1 + weapons_array.size()) % weapons_array.size()
	switch_weapon(prev_index)

func switch_weapon(index: int) -> void:
	if controls_locked:
		return
	if index < 0 or index >= weapons_array.size():
		return
	if index == current_weapon_index and not is_switching:
		return
	
	# Kill any in-progress tween to prevent stale callbacks running
	if switch_tween:
		switch_tween.kill()
	
	# Deactivate ALL weapons immediately — prevents double-visibility on rapid scroll
	for weapon in weapons_array:
		weapon.deactivate()
	
	# Update the reference now so rapid calls always operate on the correct weapon
	current_weapon_index = index
	current_weapon = weapons_array[current_weapon_index]
	is_switching = true
	
	switch_tween = create_tween()
	switch_tween.set_ease(Tween.EASE_IN_OUT)
	switch_tween.set_trans(Tween.TRANS_SINE)
	
	# Rotate down to -30 degrees (0.2s)
	switch_tween.tween_property(self, "rotation_degrees:x", -30.0, 0.2)
	
	# Activate the new weapon at the lowest point of the animation
	switch_tween.tween_callback(func():
		current_weapon.activate(current_aim_mode)
		Global.bullets_changed.emit()
	)
	
	# Rotate up to 10 degrees (0.2s)
	switch_tween.tween_property(self, "rotation_degrees:x", 10.0, 0.2)
	
	# Return to 0 degrees (0.1s)
	switch_tween.tween_property(self, "rotation_degrees:x", 0.0, 0.1)
	
	switch_tween.tween_callback(func():
		is_switching = false
	)


func has_weapon_scene(scene: PackedScene) -> bool:
	if scene == null:
		return false
	for weapon in weapons_array:
		if weapon.scene_file_path == scene.resource_path:
			return true
	return false

func equip_weapon(definition: WeaponDefinition) -> bool:
	if definition == null or definition.weapon_scene == null:
		return false
	for weapon in weapons_array:
		if weapon.scene_file_path == definition.weapon_scene.resource_path:
			return false
	var weapon := definition.weapon_scene.instantiate() as Node3D
	if weapon == null:
		return false
	add_child(weapon)
	weapon.damage *= damage_multiplier
	weapon.reload_time *= reload_multiplier
	weapon.initialize(main_camera, weapon_ray_cast, ray_cast_origin)
	weapon.deactivate()
	weapons_array.append(weapon)
	_acquired.append(weapon)
	switch_weapon(weapons_array.size() - 1)
	return true

func reset_run_loadout() -> void:
	if switch_tween:
		switch_tween.kill()
	for weapon in _acquired:
		weapons_array.erase(weapon)
		weapon.queue_free()
	_acquired.clear()
	for weapon in _base_stats:
		if is_instance_valid(weapon):
			weapon.damage = _base_stats[weapon].x
			weapon.reload_time = _base_stats[weapon].y
	damage_multiplier = 1.0
	reload_multiplier = 1.0
	current_weapon_index = mini(1, weapons_array.size() - 1)
	is_switching = false
	_setup_current_weapon()

func set_controls_locked(value: bool) -> void:
	controls_locked = value

# Helper functions to get weapon state
func get_current_mag() -> int:
	return current_weapon.get_current_mag()

func get_current_ammo() -> int:
	return current_weapon.get_current_ammo()

func get_max_ammo() -> int:
	return current_weapon.get_max_ammo()
