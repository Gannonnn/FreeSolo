class_name RockRelief
extends RefCounted
## Bakes a wall into textures for the rock shader. A fine heightmap per chunk has every hold and
## feature carved into the rock, plus chalk and rubber marks. One coarse map for the whole wall has
## the big lumps, the face outline, the wall angle and the shade under roofs, and WaterStreaks
## paints where water runs down it.
## Cosmetic randomness is seeded from the wall seed, so a wall always looks the same.

## Fine heightmap texels per meter. Matching View.PX_PER_M gives one texel per pixel.
const FINE_PX_PER_M: float = 100.0
## Texels per meter of the crease detail. Its finest creases are several centimeters across, so
## half the fine resolution is enough and bakes four times faster.
const DETAIL_PX_PER_M: float = 50.0
## Coarse map texels per meter.
const COARSE_PX_PER_M: float = 12.5
## Meters of wall per fine chunk. Keeps each texture well under the 4096 px WebGL limit.
const CHUNK_HEIGHT: float = 8.0
## Meters of extra relief around each chunk, so normals and shadows match across seams.
const MARGIN: float = 0.32
## Meters of coarse map beyond the wall on every side.
const COARSE_MARGIN: float = 1.0
## Toward the sun: x right, y down the wall, z out of the wall. The shader uses the same vector.
const SUN := Vector3(-0.5, -0.68, 0.53)
## Meters from the face's outline over which the rock rounds away, like an arête.
const EDGE_ROUNDING: float = 0.7
## Meters the rock falls back over EDGE_ROUNDING. Bigger = the face edges look more rounded.
const EDGE_DROP: float = 0.5
## Roof shade is worked out on columns this many meters apart, in steps this many meters tall.
const SHADE_COLUMN: float = 1.0
const SHADE_STEP: float = 0.1
## Meters of relief in the face's big shapes, at lumpiness 1: rounded bulges, sharper crests, and
## (at jointing 1) the grooves between blocks. Purely visual.
const LUMP_DEPTH: float = 0.34
const RIDGE_DEPTH: float = 0.09
const JOINT_DEPTH: float = 0.1


class Chunk:
	## Meters, wall space: the area this chunk draws.
	var rect: Rect2
	## Meters, wall space: the area its texture covers (rect plus margins).
	var tex_rect: Rect2
	## RG half floats: R = height in meters, G = chalk (positive) or rubber (negative).
	var texture: ImageTexture
	## 8-bit creases and facets over the same area: 0.5 is flat, 0 and 1 are -/+ crease_depth.
	var detail: ImageTexture


## A fine heightmap being carved. Heights add as "highest wins" for bumps and "lowest wins" for
## holes, so pockets cut into lumps and lumps don't fill cracks.
class Sculpt:
	var w: int
	var h: int
	## Meters, wall space, at the corner of texel (0, 0).
	var origin: Vector2
	## Interleaved per texel: height in meters, then the mark.
	var data := PackedFloat32Array()

	func _init(width: int, height: int, corner: Vector2) -> void:
		w = width
		h = height
		origin = corner
		data.resize(w * h * 2)

	## Texels covering `area` (meters), clipped to the sculpt.
	func texels(area: Rect2) -> Rect2i:
		var x0 := maxi(0, floori((area.position.x - origin.x) * FINE_PX_PER_M))
		var y0 := maxi(0, floori((area.position.y - origin.y) * FINE_PX_PER_M))
		var x1 := mini(w, ceili((area.end.x - origin.x) * FINE_PX_PER_M))
		var y1 := mini(h, ceili((area.end.y - origin.y) * FINE_PX_PER_M))
		return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))

	## Meters, wall space, at the center of texel (x, y).
	func at(x: int, y: int) -> Vector2:
		return origin + (Vector2(x, y) + Vector2(0.5, 0.5)) / FINE_PX_PER_M

	func put(x: int, y: int, height: float, mark: float) -> void:
		var k := (y * w + x) * 2
		if height > data[k] and height > 0.0:
			data[k] = height
		elif height < data[k] and height < 0.0:
			data[k] = height
		if mark > data[k + 1]:
			data[k + 1] = mark
		elif mark < 0.0 and data[k + 1] <= 0.0 and mark < data[k + 1]:
			data[k + 1] = mark

	func to_texture() -> ImageTexture:
		var image := Image.create_from_data(w, h, false, Image.FORMAT_RGF, data.to_byte_array())
		image.convert(Image.FORMAT_RGH)
		image.generate_mipmaps()
		return ImageTexture.create_from_image(image)


var chunks: Array[Chunk] = []
## RGBA half floats: R = height in meters, G = inside the face (0..1), B = wall angle in radians,
## A = shade from rock above (0 lit, 1 shaded).
var coarse: ImageTexture
var coarse_rect: Rect2
var coarse_size: Vector2i
## 8-bit water streaks over coarse_rect: 0 dry, 1 darkest.
var wet: ImageTexture


static func bake(wall: Wall) -> RockRelief:
	var relief := RockRelief.new()
	relief._bake_coarse(wall)
	relief.wet = WaterStreaks.bake(wall, relief.coarse_rect)
	var marks := _mark_amounts(wall)
	var y := 0.0
	while y < wall.size.y:
		var rect := Rect2(0.0, y, wall.size.x, minf(CHUNK_HEIGHT, wall.size.y - y))
		relief.chunks.append(_bake_chunk(wall, rect, marks))
		y += CHUNK_HEIGHT
	return relief


static func look_of(wall: Wall) -> RockType:
	return wall.rock if wall.rock != null else Catalog.rock(&"granite")


# --- Coarse map -------------------------------------------------------------------

func _bake_coarse(wall: Wall) -> void:
	coarse_rect = Rect2(-COARSE_MARGIN, -COARSE_MARGIN, wall.size.x + COARSE_MARGIN * 2.0, wall.size.y + COARSE_MARGIN * 2.0)
	var w := ceili(coarse_rect.size.x * COARSE_PX_PER_M)
	var h := ceili(coarse_rect.size.y * COARSE_PX_PER_M)
	coarse_size = Vector2i(w, h)
	var look := look_of(wall)
	var lumps := FastNoiseLite.new()
	lumps.seed = wall.gen_seed
	lumps.frequency = 0.25
	lumps.fractal_octaves = 2
	lumps.domain_warp_enabled = true
	lumps.domain_warp_amplitude = 1.0
	lumps.domain_warp_frequency = 0.2
	var ridges := FastNoiseLite.new()
	ridges.seed = wall.gen_seed + 1
	ridges.frequency = 0.4
	ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridges.fractal_octaves = 2
	ridges.domain_warp_enabled = true
	ridges.domain_warp_amplitude = 0.6
	ridges.domain_warp_frequency = 0.3
	# Joints: grooves along the edges of irregular cells, splitting the face into blocks.
	var joints := FastNoiseLite.new()
	joints.seed = wall.gen_seed + 4
	joints.noise_type = FastNoiseLite.TYPE_CELLULAR
	joints.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	joints.frequency = 0.35
	joints.fractal_type = FastNoiseLite.FRACTAL_NONE
	joints.domain_warp_enabled = true
	joints.domain_warp_amplitude = 0.6
	joints.domain_warp_frequency = 0.5
	var jag := FastNoiseLite.new()
	jag.seed = wall.gen_seed + 2
	jag.frequency = 2.5
	var flutes := FastNoiseLite.new()
	flutes.seed = wall.gen_seed + 3
	flutes.frequency = 1.0
	var shade := _roof_shade(wall)
	var data := PackedFloat32Array()
	data.resize(w * h * 4)
	var i := 0
	for py: int in h:
		var y := coarse_rect.position.y + (py + 0.5) / COARSE_PX_PER_M
		for px: int in w:
			var x := coarse_rect.position.x + (px + 0.5) / COARSE_PX_PER_M
			var p := Vector2(x, y)
			var edge := _edge_distance(wall, p) + jag.get_noise_2dv(p) * 0.12
			var height := look.lumpiness * (lumps.get_noise_2dv(p) * LUMP_DEPTH + ridges.get_noise_2dv(p) * RIDGE_DEPTH)
			height -= look.jointing * JOINT_DEPTH * (1.0 - smoothstep(0.0, 0.15, joints.get_noise_2dv(p) + 1.0))
			if look.fluting > 0.0:
				var wobble := flutes.get_noise_2d(x * 0.6, y * 0.08) * 5.0
				height += look.fluting * 0.03 * sin(x * TAU / 0.5 + wobble)
			if edge < EDGE_ROUNDING:
				var t := 1.0 - maxf(edge, 0.0) / EDGE_ROUNDING
				height -= EDGE_DROP * t * t
			data[i] = height
			data[i + 1] = clampf(0.5 + edge / 0.1, 0.0, 1.0)
			data[i + 2] = wall.angle_at(p)
			data[i + 3] = _shade_at(shade, x, y)
			i += 4
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGBAF, data.to_byte_array())
	image.convert(Image.FORMAT_RGBAH)
	coarse = ImageTexture.create_from_image(image)


## Meters from `p` to the nearest edge of the face (sides or top), negative outside.
static func _edge_distance(wall: Wall, p: Vector2) -> float:
	var span := _smooth_span(wall, p.y)
	return minf(minf(p.x - span.x, span.y - p.x), p.y)


## Like Wall.face_span, but blended between rows so the outline is smooth.
static func _smooth_span(wall: Wall, y: float) -> Vector2:
	if wall.face_left.is_empty():
		return Vector2(0.0, wall.size.x)
	var f := clampf(y / Wall.FACE_CELL - 0.5, 0.0, wall.face_left.size() - 1.0)
	var row := mini(floori(f), wall.face_left.size() - 2)
	if row < 0:
		return Vector2(wall.face_left[0], wall.face_right[0])
	var t := f - row
	return Vector2(lerpf(wall.face_left[row], wall.face_left[row + 1], t), lerpf(wall.face_right[row], wall.face_right[row + 1], t))


## Per column (every SHADE_COLUMN meters), shade every SHADE_STEP down the wall from rock above
## sticking out further than the sun can clear. Only big roofs throw it.
static func _roof_shade(wall: Wall) -> Array[PackedFloat32Array]:
	var rise := SUN.z / -SUN.y
	var steps := ceili(wall.size.y / SHADE_STEP) + 1
	var lookback := ceili(4.0 / SHADE_STEP)
	var columns: Array[PackedFloat32Array] = []
	var x := 0.0
	while x <= wall.size.x + SHADE_COLUMN:
		var out := PackedFloat32Array()
		out.resize(steps)
		for k: int in range(steps - 2, -1, -1):
			out[k] = out[k + 1] + tan(wall.angle_at(Vector2(x, (k + 0.5) * SHADE_STEP))) * SHADE_STEP
		var shade := PackedFloat32Array()
		shade.resize(steps)
		for k: int in steps:
			var s := 0.0
			for j: int in range(maxi(0, k - lookback), k):
				s = maxf(s, (out[j] - out[k] - (k - j) * SHADE_STEP * rise) * 4.0)
			shade[k] = clampf(s, 0.0, 1.0)
		columns.append(shade)
		x += SHADE_COLUMN
	return columns


static func _shade_at(columns: Array[PackedFloat32Array], x: float, y: float) -> float:
	var fx := clampf(x / SHADE_COLUMN, 0.0, columns.size() - 1.0)
	var col := mini(floori(fx), columns.size() - 2)
	var steps := columns[0].size()
	var k := clampi(floori(y / SHADE_STEP), 0, steps - 1)
	return lerpf(columns[col][k], columns[col + 1][k], fx - col)


# --- Fine chunks ------------------------------------------------------------------

## Chalk on handholds (positive) and rubber on footholds (negative). Ordinary wear only;
## chalk that marks the proven line comes later. Hard-to-spot holds get none.
static func _mark_amounts(wall: Wall) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = wall.gen_seed * 31 + 7
	var amounts := PackedFloat32Array()
	amounts.resize(wall.holds.size())
	for hold: Hold in wall.holds:
		if hold.hard_to_spot:
			continue
		if hold.is_handhold():
			amounts[hold.id] = rng.randf_range(0.1, 0.45) if rng.randf() < 0.65 else 0.0
		elif hold.is_foothold():
			amounts[hold.id] = -rng.randf_range(0.0, 0.25)
	return amounts


static func _bake_chunk(wall: Wall, rect: Rect2, marks: PackedFloat32Array) -> Chunk:
	var chunk := Chunk.new()
	chunk.rect = rect
	chunk.tex_rect = rect.grow(MARGIN)
	var sculpt := Sculpt.new(roundi(chunk.tex_rect.size.x * FINE_PX_PER_M), roundi(chunk.tex_rect.size.y * FINE_PX_PER_M), chunk.tex_rect.position)
	for feature: RockFeature in wall.features:
		if feature.bounds(0.4).intersects(chunk.tex_rect):
			_carve(sculpt, feature, wall.gen_seed)
	for hold: Hold in wall.holds:
		if hold.type.shape == HoldType.Shape.SMEAR:
			continue
		var reach := hold.type.radius * 2.4 + 0.05
		if Rect2(hold.position - Vector2(reach, reach), Vector2(reach, reach) * 2.0).intersects(chunk.tex_rect):
			_stamp(sculpt, hold, marks[hold.id])
	chunk.texture = sculpt.to_texture()
	chunk.detail = _detail_texture(wall, chunk.tex_rect)
	return chunk


## Sharp creases and facets over the whole face, from ridged noise. Made by the noise library in
## one call (no per-texel script), and continuous across chunks because the noise is offset to
## each chunk's place on the wall.
static func _detail_texture(wall: Wall, area: Rect2) -> ImageTexture:
	var look := look_of(wall)
	var noise := FastNoiseLite.new()
	noise.seed = wall.gen_seed + 5
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.3
	noise.fractal_gain = 0.45
	noise.frequency = 1.0 / (look.crease_size * DETAIL_PX_PER_M)
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = look.crease_size * DETAIL_PX_PER_M * 0.35
	noise.domain_warp_frequency = noise.frequency * 0.5
	noise.offset = Vector3(area.position.x * DETAIL_PX_PER_M, area.position.y * DETAIL_PX_PER_M, 0.0)
	var image := noise.get_image(roundi(area.size.x * DETAIL_PX_PER_M), roundi(area.size.y * DETAIL_PX_PER_M), false, false, false)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## A repeatable 0..1 value per integer, for per-hold variation.
static func _hash01(n: int) -> float:
	var v := sin(float(n) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


static func _stamp(sculpt: Sculpt, hold: Hold, mark: float) -> void:
	var r := hold.type.radius * (0.9 + 0.2 * _hash01(hold.id))
	match hold.type.shape:
		HoldType.Shape.EDGE:
			_lip(sculpt, hold, mark, r * 1.5, r * 0.9, maxf(r * 0.22, 0.008), clampf(r * 0.25, 0.008, 0.025), 0.0, 0.0)
		HoldType.Shape.CHIP:
			_lip(sculpt, hold, mark, r * 1.1, r * 0.8, r * 0.35, 0.007, 0.0, 0.0)
		HoldType.Shape.JUG:
			_lip(sculpt, hold, mark, r * 1.15, r * 1.6, r * 0.15, 0.022, 0.06, r * 0.6)
		HoldType.Shape.LEDGE:
			_lip(sculpt, hold, mark, r * 1.05, r * 1.6, r * 0.2, 0.07, 0.0, 0.0)
		HoldType.Shape.FLAKE:
			_lip(sculpt, hold, mark, r * 1.3, r * 1.8, 0.008, 0.035, 0.03, 0.014)
		HoldType.Shape.SLOPER:
			_dome(sculpt, hold, mark, r, 0.055, false)
		HoldType.Shape.HORN:
			_dome(sculpt, hold, mark, r, 0.055, true)
		HoldType.Shape.POCKET:
			_pocket(sculpt, hold, mark, r)
		HoldType.Shape.PINCH:
			_rib(sculpt, hold, mark, r * 0.45, r * 1.4, 0.04)
		HoldType.Shape.TUFA:
			_rib(sculpt, hold, mark, r * 0.55, r * 1.7, 0.055)
		HoldType.Shape.CRACK:
			_rib(sculpt, hold, mark, r * 0.35, r * 0.9, -0.045)


## An edge-like hold: rock ramps up to a lip, then drops away behind it (the part you grip faces
## the hold's facing). With `cavity` > 0 it drops into a hole behind the lip (jugs, flake gaps).
## `half` is half the length along the lip, `below` the ramp length, `top` the depth of the drop.
static func _lip(sculpt: Sculpt, hold: Hold, mark: float, half: float, below: float, top: float, lip: float, cavity: float, cavity_len: float) -> void:
	var f := hold.facing()
	var a := Vector2(-f.y, f.x)
	var reach := maxf(half, maxf(below, top + cavity_len)) + 0.01
	var box := sculpt.texels(Rect2(hold.position - Vector2(reach, reach), Vector2(reach, reach) * 2.0))
	# The lip bends gently and irregularly: about one bend along any hold, whatever its size.
	var phase_a := _hash01(hold.id + 17) * TAU
	var phase_b := _hash01(hold.id + 29) * TAU
	var bend := clampf(half * 0.12, 0.002, 0.012)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var d := sculpt.at(x, y) - hold.position
			var u := d.dot(a)
			var au := absf(u)
			if au > half:
				continue
			var along := u / half
			var v := d.dot(f) - (sin(along * 2.2 + phase_a) * 0.65 + sin(along * 5.3 + phase_b) * 0.35) * bend
			var height := 0.0
			if v < 0.0:
				height = lip * smoothstep(-below, -below * 0.25, v)
			elif v < top:
				var k := v / top
				height = lerpf(lip, -cavity, smoothstep(0.0, 1.0, k)) if cavity > 0.0 else lip * (1.0 - smoothstep(0.0, 1.0, k))
			elif cavity > 0.0 and v < top + cavity_len:
				height = -cavity * (1.0 - smoothstep(0.4, 1.0, (v - top) / cavity_len))
			else:
				continue
			var taper := 1.0 - smoothstep(half * 0.55, half, au)
			var m := 0.0
			if mark != 0.0 and v > -below * 0.3 and v < top + cavity_len * 0.8:
				m = mark * (1.0 - smoothstep(half * 0.4, half * 0.95, au))
			sculpt.put(x, y, height * taper, m)


## A rounded hold. Slopers are broad domes, flatter on the side they face. Horns are knobs with
## steep sides and a flat top.
static func _dome(sculpt: Sculpt, hold: Hold, mark: float, r: float, peak: float, knob: bool) -> void:
	var f := hold.facing()
	var a := Vector2(-f.y, f.x)
	var reach := r * 1.3
	var box := sculpt.texels(Rect2(hold.position - Vector2(reach, reach), Vector2(reach, reach) * 2.0))
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var d := sculpt.at(x, y) - hold.position
			var u := d.dot(a)
			var v := d.dot(f)
			var height := 0.0
			var rr := 0.0
			if knob:
				rr = (u * u + v * v) / (r * r)
				if rr >= 1.0:
					continue
				height = peak * (1.0 - smoothstep(0.3, 1.0, sqrt(rr)))
			else:
				var sv := r * (1.1 if v > -r * 0.2 else 0.75)
				var dv := v + r * 0.2
				rr = (u * u) / (r * r * 1.3) + (dv * dv) / (sv * sv)
				if rr >= 1.0:
					continue
				height = peak * (1.0 - rr) * (1.0 - rr)
			var m := 0.0
			if mark != 0.0 and v > -r * 0.15:
				m = mark * (1.0 - smoothstep(0.3, 0.9, rr))
			sculpt.put(x, y, height, m)


## A hole: deepest in the middle, with a small raised rim. The gripping lip is on its facing side.
static func _pocket(sculpt: Sculpt, hold: Hold, mark: float, r: float) -> void:
	var f := hold.facing()
	var a := Vector2(-f.y, f.x)
	var rx := r * 0.95
	var ry := r * 0.8
	var depth := 0.03 + r * 0.1
	var reach := r * 1.4
	var box := sculpt.texels(Rect2(hold.position - Vector2(reach, reach), Vector2(reach, reach) * 2.0))
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var d := sculpt.at(x, y) - hold.position
			var u := d.dot(a) / rx
			var v := (d.dot(f) - ry * 0.1) / ry
			var rr := u * u + v * v
			if rr >= 1.8:
				continue
			var height := 0.0
			if rr < 1.0:
				height = -depth * sqrt(1.0 - rr)
			else:
				height = 0.004 * (1.0 - (rr - 1.0) / 0.8)
			var m := 0.0
			if mark != 0.0 and rr < 1.3 and v < 0.2:
				m = mark * (1.0 - smoothstep(0.6, 1.3, rr))
			sculpt.put(x, y, height, m)


## A rib along the hold's facing: pinches and tufas stand proud; a crack jam (negative height) is
## a pod where the crack widens.
static func _rib(sculpt: Sculpt, hold: Hold, mark: float, half_width: float, half_length: float, peak: float) -> void:
	var f := hold.facing()
	var a := Vector2(-f.y, f.x)
	var reach := maxf(half_width, half_length) + 0.01
	var box := sculpt.texels(Rect2(hold.position - Vector2(reach, reach), Vector2(reach, reach) * 2.0))
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var d := sculpt.at(x, y) - hold.position
			var s := d.dot(a) / half_width
			var t := absf(d.dot(f)) / half_length
			if absf(s) >= 1.0 or t >= 1.0:
				continue
			var height := 0.0
			if peak > 0.0:
				height = peak * sqrt(1.0 - s * s) * (1.0 - smoothstep(0.55, 1.0, t))
			else:
				height = peak * (1.0 - s * s) * (1.0 - t * t)
			var m := 0.0
			if mark != 0.0:
				m = mark * (1.0 - smoothstep(0.5, 1.0, t)) * (0.4 + 0.6 * absf(s))
			sculpt.put(x, y, height, m)


# --- Features -----------------------------------------------------------------------

static func _carve(sculpt: Sculpt, feature: RockFeature, seed_value: int) -> void:
	var total := 0.0
	for i: int in range(1, feature.points.size()):
		total += feature.points[i - 1].distance_to(feature.points[i])
	var walked := 0.0
	match feature.kind:
		RockFeature.Kind.NOTCH:
			_notch(sculpt, feature.points[0], feature.width)
			return
	for i: int in range(1, feature.points.size()):
		var p0 := feature.points[i - 1]
		var p1 := feature.points[i]
		match feature.kind:
			RockFeature.Kind.CRACK:
				_crack_segment(sculpt, p0, p1, feature.width, walked, seed_value)
			RockFeature.Kind.FLAKE:
				_flake_segment(sculpt, p0, p1, feature.width, feature.side, walked, total)
			RockFeature.Kind.RAIL:
				_rail_segment(sculpt, p0, p1, feature.width, walked, total)
			RockFeature.Kind.TUFA:
				_tufa_segment(sculpt, p0, p1, feature.width, walked, total)
		walked += p0.distance_to(p1)


## Nearest point on segment p0-p1 to p, as [distance along from p0 (meters), distance away].
static func _segment_coords(p: Vector2, p0: Vector2, p1: Vector2) -> Vector2:
	var ab := p1 - p0
	var length := ab.length()
	var t := clampf((p - p0).dot(ab) / (length * length), 0.0, 1.0)
	return Vector2(t * length, p.distance_to(p0 + ab * t))


static func _segment_box(sculpt: Sculpt, p0: Vector2, p1: Vector2, grow: float) -> Rect2i:
	return sculpt.texels(Rect2(p0, Vector2.ZERO).expand(p1).grow(grow))


## A slot with steep walls, a little wider in places.
static func _crack_segment(sculpt: Sculpt, p0: Vector2, p1: Vector2, width: float, walked: float, seed_value: int) -> void:
	var box := _segment_box(sculpt, p0, p1, width + 0.03)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var c := _segment_coords(sculpt.at(x, y), p0, p1)
			var along := walked + c.x
			var half := width * 0.5 * (0.75 + 0.5 * absf(sin(along * 7.3 + seed_value)) + 0.2 * sin(along * 23.0))
			if c.y < half:
				var k := c.y / half
				sculpt.put(x, y, -0.055 * (1.0 - k * k * k * k * k * k), 0.0)
			elif c.y < half + 0.012:
				sculpt.put(x, y, 0.002, 0.0)


## A detached plate on one side of the line, with a dark gap along its free edge.
static func _flake_segment(sculpt: Sculpt, p0: Vector2, p1: Vector2, width: float, side: float, walked: float, total: float) -> void:
	var dir := (p1 - p0).normalized()
	var normal := Vector2(-dir.y, dir.x) * side
	var length := p0.distance_to(p1)
	var box := _segment_box(sculpt, p0, p1, width + 0.03)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var d := sculpt.at(x, y) - p0
			var along := d.dot(dir)
			if along < -0.01 or along > length + 0.01:
				continue
			var across := d.dot(normal)
			var s := walked + along
			var taper := smoothstep(0.0, 0.15, s) * smoothstep(0.0, 0.15, total - s)
			if across >= 0.0 and across < width:
				sculpt.put(x, y, 0.04 * taper * (1.0 - smoothstep(width * 0.45, width, across)), 0.0)
			elif across < 0.0 and across > -0.012:
				sculpt.put(x, y, -0.03 * taper, 0.0)


## A long edge: the rock below the line stands proud and drops away at the line.
static func _rail_segment(sculpt: Sculpt, p0: Vector2, p1: Vector2, band: float, walked: float, total: float) -> void:
	var dir := (p1 - p0).normalized()
	var down := Vector2(-dir.y, dir.x)
	if down.y < 0.0:
		down = -down
	var length := p0.distance_to(p1)
	var top := 0.012
	var box := _segment_box(sculpt, p0, p1, band + 0.02)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var d := sculpt.at(x, y) - p0
			var along := d.dot(dir)
			if along < -0.01 or along > length + 0.01:
				continue
			var across := d.dot(down)
			var s := walked + along
			var taper := smoothstep(0.0, 0.2, s) * smoothstep(0.0, 0.2, total - s)
			if across >= 0.0 and across < band:
				sculpt.put(x, y, 0.016 * taper * smoothstep(band, band * 0.2, across), 0.0)
			elif across < 0.0 and across > -top:
				sculpt.put(x, y, 0.016 * taper * (1.0 - smoothstep(0.0, 1.0, -across / top)), 0.0)


## A rounded column standing out from the wall.
static func _tufa_segment(sculpt: Sculpt, p0: Vector2, p1: Vector2, width: float, walked: float, total: float) -> void:
	var box := _segment_box(sculpt, p0, p1, width * 1.4)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var c := _segment_coords(sculpt.at(x, y), p0, p1)
			var s := walked + c.x
			var half := width * (0.85 + 0.3 * sin(s * 5.0) + 0.1 * sin(s * 31.0))
			if c.y >= half:
				continue
			var taper := smoothstep(0.0, 0.3, s) * smoothstep(0.0, 0.3, total - s)
			var k := c.y / half
			sculpt.put(x, y, 0.065 * taper * sqrt(1.0 - k * k) * (1.0 + 0.08 * sin(s * 40.0)), 0.0)


## A small roof above a knee-bar spot: a block whose flat underside is where the knee jams.
static func _notch(sculpt: Sculpt, knee: Vector2, width: float) -> void:
	var half := width * 0.5
	var box := sculpt.texels(Rect2(knee + Vector2(-half - 0.05, -0.34), Vector2(width + 0.1, 0.36)))
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var p := sculpt.at(x, y)
			var side := 1.0 - smoothstep(half - 0.06, half + 0.04, absf(p.x - knee.x))
			var vertical := smoothstep(knee.y - 0.33, knee.y - 0.12, p.y) * (1.0 - smoothstep(knee.y - 0.012, knee.y, p.y))
			if side > 0.0 and vertical > 0.0:
				sculpt.put(x, y, 0.11 * side * vertical, 0.0)
