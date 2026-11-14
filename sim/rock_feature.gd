class_name RockFeature
extends RefCounted
## A crack, flake, rail, tufa column or knee-bar notch on a generated wall. Gameplay only uses the
## holds placed along it; the renderer carves the feature itself into the rock.

enum Kind { CRACK, FLAKE, RAIL, TUFA, NOTCH }

var kind: Kind
## Meters, wall space. A polyline; a notch has one point, the knee spot under it.
var points: PackedVector2Array
## Meters. Crack width, flake plate width, rail band, column width or notch width.
var width: float
## Flakes: +1 when the plate is to the right of the line (walking from the first point), -1 left.
var side: float = 1.0


static func make(feature_kind: Kind, line: PackedVector2Array, feature_width: float, feature_side: float = 1.0) -> RockFeature:
	var f := RockFeature.new()
	f.kind = feature_kind
	f.points = line
	f.width = feature_width
	f.side = feature_side
	return f


## Meters, wall space: the area the feature covers, grown by `margin`.
func bounds(margin: float) -> Rect2:
	var r := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		r = r.expand(p)
	return r.grow(margin + width)
