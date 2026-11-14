class_name WaterStreaks
extends RefCounted
## Paints where water runs down a wall, for the dark streaks in the rock shader. Water starts where
## it collects (the cliff top, ledges and jugs, the blocks over knee-bars, rails, the bottoms of
## cracks, the lips of roofs), runs down with a little wander, fades as it goes, and stops at an
## overhang, where it drips off instead. Purely visual, and seeded from the wall seed.

## Texels per meter. The narrowest streaks are a few centimeters wide.
const PX_PER_M: float = 25.0
## Radians past vertical beyond which water drips off the rock instead of running down it.
const DRIP_ANGLE: float = 0.12
## Meters between places water may start along the cliff top, along rails and across roof lips.
const TOP_SPACING: float = 0.3
const RAIL_SPACING: float = 0.45
const LIP_SPACING: float = 0.4
## Meters a streak can wander sideways from where it started.
const WANDER: float = 0.25
## Seeps with no feature behind them, per square meter of wall at full streak strength.
const SEEPS_PER_M2: float = 0.025


class Source:
	var at: Vector2
	## 0..1: how dark the streak is where it starts.
	var strength: float
	## Meters across where it starts. Streaks widen as they fall.
	var width: float
	## Meters it runs before it has faded out.
	var length: float
	## Meters it clings to an overhang, fading, before it drips off.
	var cling: float = 0.2

	func _init(p: Vector2, dark: float, across: float, run: float) -> void:
		at = p
		strength = dark
		width = across
		length = run


## An 8-bit map over `area` (wall-space meters): 0 is dry rock, 1 the darkest streak.
static func bake(wall: Wall, area: Rect2) -> ImageTexture:
	var w := ceili(area.size.x * PX_PER_M)
	var h := ceili(area.size.y * PX_PER_M)
	var wet := PackedFloat32Array()
	wet.resize(w * h)
	var rng := RandomNumberGenerator.new()
	rng.seed = wall.gen_seed * 17 + 3
	var wander := FastNoiseLite.new()
	wander.seed = wall.gen_seed + 9
	wander.frequency = 0.35
	for source: Source in _sources(wall, rng, RockRelief.look_of(wall).streaks):
		_run(wet, w, h, area, wall, source, wander)
	var bytes := PackedByteArray()
	bytes.resize(w * h)
	for i: int in w * h:
		bytes[i] = int(clampf(wet[i], 0.0, 1.0) * 255.0)
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_L8, bytes))


static func _sources(wall: Wall, rng: RandomNumberGenerator, amount: float) -> Array[Source]:
	var out: Array[Source] = []
	if amount <= 0.0:
		return out
	# Rain running off the cliff top.
	var top := wall.face_span(0.0)
	var x := top.x + rng.randf() * TOP_SPACING
	while x < top.y:
		if rng.randf() < 0.15 + 0.5 * amount:
			var run := rng.randf_range(2.0, 10.0) if rng.randf() < 0.7 else rng.randf_range(10.0, 30.0)
			out.append(Source.new(Vector2(x, rng.randf_range(0.0, 0.25)), rng.randf_range(0.35, 1.0), rng.randf_range(0.04, 0.22), run))
		x += TOP_SPACING * rng.randf_range(0.6, 1.4)
	# Water that pools in holds and spills over their lips.
	for hold: Hold in wall.holds:
		var chance := 0.0
		match hold.type.shape:
			HoldType.Shape.LEDGE:
				chance = 0.9
			HoldType.Shape.JUG:
				chance = 0.35
			HoldType.Shape.POCKET:
				chance = 0.2
			HoldType.Shape.EDGE:
				chance = 0.05
		if chance == 0.0 or rng.randf() >= chance * (0.5 + amount):
			continue
		var r := hold.type.radius
		var spill := hold.position + Vector2(rng.randf_range(-0.6, 0.6) * r, r * 0.4)
		out.append(Source.new(spill, rng.randf_range(0.3, 0.75), r * rng.randf_range(0.4, 0.9), rng.randf_range(0.8, 4.0)))
	for feature: RockFeature in wall.features:
		match feature.kind:
			RockFeature.Kind.NOTCH:
				var under := feature.points[0] + Vector2(rng.randf_range(-0.1, 0.1), 0.0)
				out.append(Source.new(under, rng.randf_range(0.5, 0.9), rng.randf_range(0.08, 0.18), rng.randf_range(1.5, 5.0)))
			RockFeature.Kind.CRACK:
				var bottom := feature.points[0]
				for p: Vector2 in feature.points:
					if p.y > bottom.y:
						bottom = p
				out.append(Source.new(bottom, rng.randf_range(0.5, 1.0), rng.randf_range(0.06, 0.14), rng.randf_range(2.0, 7.0)))
			RockFeature.Kind.RAIL:
				for i: int in range(1, feature.points.size()):
					var p0 := feature.points[i - 1]
					var p1 := feature.points[i]
					var length := p0.distance_to(p1)
					var along := rng.randf() * RAIL_SPACING
					while along < length:
						if rng.randf() < 0.35 + 0.3 * amount:
							var below := p0.lerp(p1, along / length) + Vector2(0.0, feature.width * 0.6)
							out.append(Source.new(below, rng.randf_range(0.25, 0.65), rng.randf_range(0.04, 0.12), rng.randf_range(0.8, 3.5)))
						along += RAIL_SPACING * rng.randf_range(0.6, 1.4)
	# Drips landing below the lips of overhangs.
	var col := rng.randf() * LIP_SPACING
	while col < wall.size.x:
		var y := 0.1
		var was_steep := false
		while y < wall.size.y:
			var p := Vector2(col, y)
			var steep := wall.angle_at(p) > DRIP_ANGLE
			if was_steep and not steep and wall.contains(p) and rng.randf() < 0.3 + 0.4 * amount:
				var landing := p + Vector2(0.0, rng.randf_range(0.0, 0.35))
				out.append(Source.new(landing, rng.randf_range(0.4, 0.85), rng.randf_range(0.06, 0.2), rng.randf_range(1.5, 5.0)))
			was_steep = steep
			y += 0.1
		col += LIP_SPACING * rng.randf_range(0.6, 1.4)
	# A few seeps with no feature behind them.
	for i: int in roundi(wall.size.x * wall.size.y * SEEPS_PER_M2 * amount):
		var y := rng.randf_range(0.5, wall.size.y - 1.0)
		var span := wall.face_span(y)
		out.append(Source.new(Vector2(rng.randf_range(span.x, span.y), y), rng.randf_range(0.2, 0.5), rng.randf_range(0.05, 0.25), rng.randf_range(1.0, 5.0)))
	for source: Source in out:
		source.cling = rng.randf_range(0.05, 0.45)
	return out


## Follows one streak down the wall, one texel row at a time.
static func _run(wet: PackedFloat32Array, w: int, h: int, area: Rect2, wall: Wall, source: Source, wander: FastNoiseLite) -> void:
	var first := maxi(0, floori((source.at.y - area.position.y) * PX_PER_M))
	var lane := source.at.x * 7.13 + source.at.y * 3.7
	var drift_from := wander.get_noise_2d(lane, source.at.y)
	var cling_rows := maxf(1.0, source.cling * PX_PER_M)
	var dripping := 0
	for row: int in range(first, mini(h, first + ceili(source.length * PX_PER_M))):
		var y := area.position.y + (row + 0.5) / PX_PER_M
		var x := source.at.x + (wander.get_noise_2d(lane, y) - drift_from) * WANDER
		var at := Vector2(x, y)
		if y > wall.size.y or not wall.contains(at):
			return
		if dripping > 0 or wall.angle_at(at) > DRIP_ANGLE:
			dripping += 1
			if dripping > cling_rows:
				return
		var t := float(row - first) / (source.length * PX_PER_M)
		var strength := source.strength * smoothstep(0.0, 1.5, row - first) * pow(1.0 - t, 1.3) * (1.0 - dripping / cling_rows)
		_paint_row(wet, w, row, area, x, source.width * (1.0 + t * 0.8), strength)


## Darkens one row of the map around `x` with a soft-edged band `width` meters across. Streaks that
## cross darken each other.
static func _paint_row(wet: PackedFloat32Array, w: int, row: int, area: Rect2, x: float, width: float, strength: float) -> void:
	var reach := width * 1.5
	var x0 := maxi(0, floori((x - reach - area.position.x) * PX_PER_M))
	var x1 := mini(w - 1, ceili((x + reach - area.position.x) * PX_PER_M))
	for px: int in range(x0, x1 + 1):
		var k := (area.position.x + (px + 0.5) / PX_PER_M - x) / (width * 0.5)
		var v := strength * exp(-k * k)
		var i := row * w + px
		wet[i] = 1.0 - (1.0 - wet[i]) * (1.0 - v)
