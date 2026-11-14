class_name Wall
extends RefCounted
## Everything gameplay needs about one wall or arena. Read-only during a climb.

## Meters per spatial bucket used by holds_near().
const BUCKET_SIZE: float = 1.0
## Meters per row of the face outline.
const FACE_CELL: float = 0.25

## Generation seed; 0 for hand-built walls.
var gen_seed: int = 0
## Meters. Origin top-left, y down; the ground is at y = size.y.
var size: Vector2
## Both hands on holds above this line finishes the wall.
var top_out_y: float
var holds: Array[Hold] = []
var rests: Array[RestSpot] = []
## [left hand, right hand] holds the climb starts on.
var start_holds: Array[Hold] = []
## Wall angle per grid cell, radians past vertical: negative is slab, 0 vertical, positive overhang.
var angle_grid: PackedFloat32Array
## Meters per angle grid cell.
var angle_cell: float = 1.0
var angle_cols: int = 1
var angle_rows: int = 1
## The rock it's made of. Null for hand-built walls.
var rock: RockType
## Per FACE_CELL row from the top: where the climbable face starts and ends, in meters.
## Empty means the face is the whole width.
var face_left: PackedFloat32Array
var face_right: PackedFloat32Array
## Cracks, flakes, rails, tufas and notches for the renderer to carve. Their holds are in `holds`.
var features: Array[RockFeature] = []
## Hands' holds, in order, on the line the generator's test climber took to the top. Proves the
## wall can be climbed; tests and the debug overlay use it. Empty for hand-built walls.
var guide: Array[Hold] = []
## Footholds the test climber stood on.
var guide_feet: Array[Hold] = []

var _buckets: Dictionary[Vector2i, Array] = {}


func _init(size_m: Vector2, top_out: float) -> void:
	size = size_m
	top_out_y = top_out
	set_uniform_angle(0.0)


func ground_y() -> float:
	return size.y


func set_uniform_angle(angle: float) -> void:
	set_angle_grid(maxf(size.x, size.y), 1, PackedFloat32Array([angle]))


## `values` is row-major, top row first.
func set_angle_grid(cell: float, cols: int, values: PackedFloat32Array) -> void:
	angle_cell = cell
	angle_cols = cols
	@warning_ignore("integer_division")
	angle_rows = values.size() / cols
	angle_grid = values


func angle_at(p: Vector2) -> float:
	var col := clampi(floori(p.x / angle_cell), 0, angle_cols - 1)
	var row := clampi(floori(p.y / angle_cell), 0, angle_rows - 1)
	return angle_grid[row * angle_cols + col]


## Meters: x = where the face starts at height `y`, y = where it ends.
func face_span(y: float) -> Vector2:
	if face_left.is_empty():
		return Vector2(0.0, size.x)
	var row := clampi(floori(y / FACE_CELL), 0, face_left.size() - 1)
	return Vector2(face_left[row], face_right[row])


## Whether `p` is on the face, at least `margin` meters in from its sides and top.
func contains(p: Vector2, margin: float = 0.0) -> bool:
	if p.y < margin or p.y > size.y:
		return false
	var span := face_span(p.y)
	return p.x >= span.x + margin and p.x <= span.y - margin


func add_hold(type: HoldType, at: Vector2, rotation: float = 0.0) -> Hold:
	var hold := Hold.new()
	hold.id = holds.size()
	hold.type = type
	hold.position = at
	hold.rotation = rotation
	holds.append(hold)
	var key := _bucket_of(at)
	if not _buckets.has(key):
		_buckets[key] = []
	_buckets[key].append(hold)
	return hold


func add_rest(spot: RestSpot) -> void:
	rests.append(spot)


## Every hold within `radius` meters of `p`.
func holds_near(p: Vector2, radius: float) -> Array[Hold]:
	var found: Array[Hold] = []
	var lo := _bucket_of(p - Vector2(radius, radius))
	var hi := _bucket_of(p + Vector2(radius, radius))
	var radius_sq := radius * radius
	for bx: int in range(lo.x, hi.x + 1):
		for by: int in range(lo.y, hi.y + 1):
			var bucket: Array = _buckets.get(Vector2i(bx, by), [])
			for hold: Hold in bucket:
				if hold.position.distance_squared_to(p) <= radius_sq:
					found.append(hold)
	return found


## The hold under `p`, allowing `slack` meters beyond its radius. The nearest one wins.
## With `hands_only`, footholds are ignored.
func hold_at(p: Vector2, slack: float, hands_only: bool = false) -> Hold:
	var best: Hold = null
	var best_dist := INF
	for hold: Hold in holds_near(p, 0.7):
		if hands_only and not hold.is_handhold():
			continue
		var d := hold.position.distance_to(p)
		if d <= hold.type.radius + slack and d < best_dist:
			best = hold
			best_dist = d
	return best


func _bucket_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / BUCKET_SIZE), floori(p.y / BUCKET_SIZE))
