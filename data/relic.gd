class_name Relic
extends Resource
## A rule-breaking run modifier, picked 1 of 3 between walls (Milestone 5).
## Example: "Campus Kid" has rules [NO_FEET], stat_deltas.power = 3 and cap_deltas.power = 5.

## Rules the sim checks, each in exactly one place.
enum Rule {
	NO_FEET, ## Feet never place (FootPlanner).
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Added to stat levels when picked. Can be negative.
@export var stat_deltas: Stats
## Added to stat caps, so a level can go past the normal max.
@export var cap_deltas: Stats
@export var rules: Array[Rule] = []
