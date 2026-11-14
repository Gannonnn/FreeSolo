class_name WallSpec
extends Resource
## One level's wall: its size, rock, steepness and how featured it is. WallGen turns a spec and a
## seed into a Wall.

@export var id: StringName
@export var display_name: String
## Meters from the ground to the top.
@export var height: float = 25.0
## Meters. The climbable face is narrower; the rest shows the landscape behind the cliff.
@export var width: float = 14.0
@export var rock: RockType
## Narrowest and widest the climbable face gets, in meters.
@export var face_width: Vector2 = Vector2(9.0, 12.5)

@export_group("Steepness")
## Meters per band of roughly constant angle.
@export var band_length: Vector2 = Vector2(2.5, 5.5)
## Chance each band is a slab, and that it's an overhang. The rest are near vertical.
@export_range(0.0, 1.0, 0.01) var slab_chance: float = 0.25
@export_range(0.0, 1.0, 0.01) var overhang_chance: float = 0.3
## Degrees past vertical for each kind of band. Negative is slab.
@export var slab_degrees: Vector2 = Vector2(-22.0, -8.0)
@export var vertical_degrees: Vector2 = Vector2(-5.0, 6.0)
@export var overhang_degrees: Vector2 = Vector2(12.0, 28.0)

@export_group("Holds")
## Scattered handholds per square meter of face, on average. Lower = more blank rock, more
## repairs by the generator, and a harder wall to read.
@export var hold_density: float = 4.0
## Scattered foot chips per square meter. Lower = feet more often off, so more drain.
@export var foot_density: float = 6.0
## Smears per square meter on slabs.
@export var smear_density: float = 4.0
## Natural knee-bar spots, before the generator adds any the climb needs.
@export var kneebars: Vector2i = Vector2i(1, 2)
## Natural ledges. Kept for older specs / future object-rests; walls use 0 for now.
@export var ledges: Vector2i = Vector2i(0, 0)
