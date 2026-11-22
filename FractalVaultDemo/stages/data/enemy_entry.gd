class_name EnemyEntry
extends Resource

@export var enemy_scene: PackedScene
@export_range(1, 20, 1) var count: int = 1
@export var interval: float = 1.5
@export var health_multiplier: float = 1.0
