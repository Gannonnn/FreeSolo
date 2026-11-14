class_name RockType
extends Resource
## A kind of rock: how it looks, and which features and holds the wall generator gives it.

@export var id: StringName
@export var display_name: String

@export_group("Look")
## Main rock color.
@export var base_color: Color = Color(0.6, 0.58, 0.55)
## Dark mineral flecks and the dark side of bedding bands.
@export var dark_color: Color = Color(0.25, 0.24, 0.24)
## Light mineral flecks.
@export var light_color: Color = Color(0.85, 0.83, 0.8)
## Lichen or oxide patches.
@export var accent_color: Color = Color(0.6, 0.64, 0.45)
## Water streaks running down the face.
@export var streak_color: Color = Color(0.2, 0.19, 0.18)
## How speckled the rock is (granite high, limestone low).
@export_range(0.0, 1.0, 0.01) var grain: float = 0.5
## Bedding: how much the shade differs between the beds the rock is laid down in. Purely visual.
@export_range(0.0, 1.0, 0.01) var strata: float = 0.0
## Strength of dark water streaks.
@export_range(0.0, 1.0, 0.01) var streaks: float = 0.3
## How much of the rock lichen or oxide covers.
@export_range(0.0, 1.0, 0.01) var lichen: float = 0.3
## Big bulges and dishes in the face. Purely visual.
@export_range(0.0, 2.0, 0.01) var lumpiness: float = 1.0
## Grooves along joints that split the face into big blocks. Purely visual.
@export_range(0.0, 1.0, 0.01) var jointing: float = 0.5
## Vertical runnels, like water-worn limestone. Purely visual.
@export_range(0.0, 1.0, 0.01) var fluting: float = 0.0
## Meters of relief in the sharp creases and facets that cover the face. More = rougher, more
## broken-looking rock, but holds stand out less. Purely visual.
@export_range(0.0, 0.08, 0.001) var crease_depth: float = 0.03
## Meters across a typical facet between creases. Purely visual.
@export var crease_size: float = 0.7

@export_group("Features per 25 m of wall")
## Crack lines with finger jams along them.
@export var cracks: Vector2i = Vector2i(2, 4)
## Flakes: detached plates with a sidepull edge.
@export var flakes: Vector2i = Vector2i(1, 3)
## Horizontal rails of edges (bedding seams or dikes).
@export var rails: Vector2i = Vector2i(1, 2)
## Clusters of pockets.
@export var pocket_clusters: Vector2i = Vector2i(0, 0)
## Tufa columns: vertical lines of pinches.
@export var tufa_lines: Vector2i = Vector2i(0, 0)

@export_group("Scattered holds")
## Hold type ids the generator scatters across the face. Weights match by index.
@export var hold_ids: Array[StringName] = []
@export var hold_weights: PackedFloat32Array = PackedFloat32Array()
## Hold types used along rails, with weights.
@export var rail_ids: Array[StringName] = [&"edge", &"crimp"]
@export var rail_weights: PackedFloat32Array = PackedFloat32Array([0.6, 0.4])
