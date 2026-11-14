class_name Catalog
extends RefCounted
## Every content resource, listed by explicit path so a missing file fails loudly on first use.

const HOLD_TYPE_PATHS: Array[String] = [
	"res://data/holds/jug.tres",
	"res://data/holds/edge.tres",
	"res://data/holds/crimp.tres",
	"res://data/holds/sloper.tres",
	"res://data/holds/pinch.tres",
	"res://data/holds/pocket.tres",
	"res://data/holds/mono.tres",
	"res://data/holds/flake.tres",
	"res://data/holds/crack.tres",
	"res://data/holds/horn.tres",
	"res://data/holds/tufa.tres",
	"res://data/holds/ledge.tres",
	"res://data/holds/foot_chip.tres",
	"res://data/holds/smear.tres",
	"res://data/holds/ground.tres",
]

const CHARACTER_PATHS: Array[String] = [
	"res://data/characters/default.tres",
]

const ROCK_PATHS: Array[String] = [
	"res://data/rocks/granite.tres",
	"res://data/rocks/limestone.tres",
]

const WALL_SPEC_PATHS: Array[String] = [
	"res://data/walls/crag_1.tres",
]

static var _hold_types: Dictionary[StringName, HoldType] = {}
static var _characters: Dictionary[StringName, CharacterDef] = {}
static var _rocks: Dictionary[StringName, RockType] = {}
static var _wall_specs: Dictionary[StringName, WallSpec] = {}


static func hold_type(id: StringName) -> HoldType:
	if _hold_types.is_empty():
		for path: String in HOLD_TYPE_PATHS:
			var t := load(path) as HoldType
			assert(t != null, "Missing hold type: " + path)
			_hold_types[t.id] = t
	assert(_hold_types.has(id), "Unknown hold type: " + id)
	return _hold_types[id]


static func character(id: StringName) -> CharacterDef:
	if _characters.is_empty():
		for path: String in CHARACTER_PATHS:
			var c := load(path) as CharacterDef
			assert(c != null, "Missing character: " + path)
			_characters[c.id] = c
	assert(_characters.has(id), "Unknown character: " + id)
	return _characters[id]


static func has_rock(id: StringName) -> bool:
	rock(&"granite")
	return _rocks.has(id)


static func rock(id: StringName) -> RockType:
	if _rocks.is_empty():
		for path: String in ROCK_PATHS:
			var r := load(path) as RockType
			assert(r != null, "Missing rock type: " + path)
			_rocks[r.id] = r
	assert(_rocks.has(id), "Unknown rock type: " + id)
	return _rocks[id]


static func wall_spec(id: StringName) -> WallSpec:
	if _wall_specs.is_empty():
		for path: String in WALL_SPEC_PATHS:
			var s := load(path) as WallSpec
			assert(s != null, "Missing wall spec: " + path)
			_wall_specs[s.id] = s
	assert(_wall_specs.has(id), "Unknown wall spec: " + id)
	return _wall_specs[id]
