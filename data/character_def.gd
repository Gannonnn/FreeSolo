class_name CharacterDef
extends Resource
## A starting character. Reach comes from height and ape index and never changes during a run.

@export var id: StringName
@export var display_name: String
## Meters. Scales every limb and the torso.
@export_range(1.5, 2.0, 0.01) var height: float = 1.75
## Arm span ÷ height. Above 1 = longer arms = more reach.
@export_range(0.95, 1.1, 0.01) var ape_index: float = 1.0
@export var starting_stats: Stats
## Protection pieces at the start of each wall (Milestone 3).
@export var starting_gear: int = 0
## Holds in the rack at the start of a run (Milestone 4).
@export var starting_rack: Array[HoldType] = []
