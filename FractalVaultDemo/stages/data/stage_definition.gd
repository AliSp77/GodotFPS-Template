class_name StageDefinition
extends Resource

enum Kind { REGULAR, MID_BOSS, FINAL_BOSS }

@export var id: StringName
@export var title: String
@export var kind: Kind = Kind.REGULAR
@export_file("*.tscn") var scene_path: String
@export var encounter: EncounterDefinition
@export_range(1, 5, 1) var threat: int = 1
@export var clear_credits: int = 50
@export var meta_reward: int = 0
