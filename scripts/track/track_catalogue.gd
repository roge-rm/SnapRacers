class_name TrackCatalogue
extends RefCounted

## Rows hold up to two [label, spec] tiles. Mirrored pieces share a row.
const CATEGORIES := [
	["Straights", "straights", [
		[["8 m straight\nQuarter tile", {"type": "quarter_straight"}], ["16 m straight\nHalf tile", {"type": "half_straight"}]],
		[["32 m straight", {"type": "straight", "length": 1}], ["64 m straight", {"type": "straight", "length": 2}]],
		[["96 m straight", {"type": "straight", "length": 3}], ["128 m straight", {"type": "straight", "length": 4}]],
	]],
	["Bends", "bends", [
		[["15° tight left", {"type": "arc", "turn": "left", "size": 1, "angle": 15}], ["15° tight right", {"type": "arc", "turn": "right", "size": 1, "angle": 15}]],
		[["15° normal left", {"type": "arc", "turn": "left", "size": 2, "angle": 15}], ["15° normal right", {"type": "arc", "turn": "right", "size": 2, "angle": 15}]],
		[["15° wide left", {"type": "arc", "turn": "left", "size": 3, "angle": 15}], ["15° wide right", {"type": "arc", "turn": "right", "size": 3, "angle": 15}]],
		[["15° extra wide left", {"type": "arc", "turn": "left", "size": 4, "angle": 15}], ["15° extra wide right", {"type": "arc", "turn": "right", "size": 4, "angle": 15}]],
		[["30° tight left", {"type": "arc", "turn": "left", "size": 1, "angle": 30}], ["30° tight right", {"type": "arc", "turn": "right", "size": 1, "angle": 30}]],
		[["30° normal left", {"type": "arc", "turn": "left", "size": 2, "angle": 30}], ["30° normal right", {"type": "arc", "turn": "right", "size": 2, "angle": 30}]],
		[["30° wide left", {"type": "arc", "turn": "left", "size": 3, "angle": 30}], ["30° wide right", {"type": "arc", "turn": "right", "size": 3, "angle": 30}]],
		[["30° extra wide left", {"type": "arc", "turn": "left", "size": 4, "angle": 30}], ["30° extra wide right", {"type": "arc", "turn": "right", "size": 4, "angle": 30}]],
		[["45° tight left", {"type": "arc", "turn": "left", "size": 1, "angle": 45}], ["45° tight right", {"type": "arc", "turn": "right", "size": 1, "angle": 45}]],
		[["45° normal left", {"type": "arc", "turn": "left", "size": 2, "angle": 45}], ["45° normal right", {"type": "arc", "turn": "right", "size": 2, "angle": 45}]],
		[["45° wide left", {"type": "arc", "turn": "left", "size": 3, "angle": 45}], ["45° wide right", {"type": "arc", "turn": "right", "size": 3, "angle": 45}]],
		[["45° extra wide left", {"type": "arc", "turn": "left", "size": 4, "angle": 45}], ["45° extra wide right", {"type": "arc", "turn": "right", "size": 4, "angle": 45}]],
		[["60° tight left", {"type": "arc", "turn": "left", "size": 1, "angle": 60}], ["60° tight right", {"type": "arc", "turn": "right", "size": 1, "angle": 60}]],
		[["60° normal left", {"type": "arc", "turn": "left", "size": 2, "angle": 60}], ["60° normal right", {"type": "arc", "turn": "right", "size": 2, "angle": 60}]],
		[["60° wide left", {"type": "arc", "turn": "left", "size": 3, "angle": 60}], ["60° wide right", {"type": "arc", "turn": "right", "size": 3, "angle": 60}]],
		[["60° extra wide left", {"type": "arc", "turn": "left", "size": 4, "angle": 60}], ["60° extra wide right", {"type": "arc", "turn": "right", "size": 4, "angle": 60}]],
		[["75° tight left", {"type": "arc", "turn": "left", "size": 1, "angle": 75}], ["75° tight right", {"type": "arc", "turn": "right", "size": 1, "angle": 75}]],
		[["75° normal left", {"type": "arc", "turn": "left", "size": 2, "angle": 75}], ["75° normal right", {"type": "arc", "turn": "right", "size": 2, "angle": 75}]],
		[["75° wide left", {"type": "arc", "turn": "left", "size": 3, "angle": 75}], ["75° wide right", {"type": "arc", "turn": "right", "size": 3, "angle": 75}]],
		[["75° extra wide left", {"type": "arc", "turn": "left", "size": 4, "angle": 75}], ["75° extra wide right", {"type": "arc", "turn": "right", "size": 4, "angle": 75}]],
		[["90° tight left", {"type": "curve", "turn": "left", "size": 1}], ["90° tight right", {"type": "curve", "turn": "right", "size": 1}]],
		[["90° normal left", {"type": "curve", "turn": "left", "size": 2}], ["90° normal right", {"type": "curve", "turn": "right", "size": 2}]],
		[["90° wide left", {"type": "curve", "turn": "left", "size": 3}], ["90° wide right", {"type": "curve", "turn": "right", "size": 3}]],
		[["90° extra wide left", {"type": "curve", "turn": "left", "size": 4}], ["90° extra wide right", {"type": "curve", "turn": "right", "size": 4}]],
	]],
	["Offsets", "slants", [
		[["Left offset\n64 × 32 m", {"type": "slant", "turn": "left", "length": 2, "across": 1}], ["Right offset\n64 × 32 m", {"type": "slant", "turn": "right", "length": 2, "across": 1}]],
		[["Left offset\n96 × 32 m", {"type": "slant", "turn": "left", "length": 3, "across": 1}], ["Right offset\n96 × 32 m", {"type": "slant", "turn": "right", "length": 3, "across": 1}]],
		[["Left offset\n96 × 64 m", {"type": "slant", "turn": "left", "length": 3, "across": 2}], ["Right offset\n96 × 64 m", {"type": "slant", "turn": "right", "length": 3, "across": 2}]],
		[["Left offset\n128 × 32 m", {"type": "slant", "turn": "left", "length": 4, "across": 1}], ["Right offset\n128 × 32 m", {"type": "slant", "turn": "right", "length": 4, "across": 1}]],
		[["Left offset\n128 × 64 m", {"type": "slant", "turn": "left", "length": 4, "across": 2}], ["Right offset\n128 × 64 m", {"type": "slant", "turn": "right", "length": 4, "across": 2}]],
		[["Left offset\n128 × 96 m", {"type": "slant", "turn": "left", "length": 4, "across": 3}], ["Right offset\n128 × 96 m", {"type": "slant", "turn": "right", "length": 4, "across": 3}]],
		[["Left +3 m\n96 × 32 m", {"type": "slant", "turn": "left", "length": 3, "across": 1, "rise": 1}], ["Right +3 m\n96 × 32 m", {"type": "slant", "turn": "right", "length": 3, "across": 1, "rise": 1}]],
		[["Left −3 m\n96 × 32 m", {"type": "slant", "turn": "left", "length": 3, "across": 1, "rise": -1}], ["Right −3 m\n96 × 32 m", {"type": "slant", "turn": "right", "length": 3, "across": 1, "rise": -1}]],
	]],
	["Hills", "hills", [
		[["Up 3 m\n32 m long", {"type": "ramp", "length": 1, "rise": 1}], ["Down 3 m\n32 m long", {"type": "ramp", "length": 1, "rise": -1}]],
		[["Up 3 m\n64 m long", {"type": "ramp", "length": 2, "rise": 1}], ["Down 3 m\n64 m long", {"type": "ramp", "length": 2, "rise": -1}]],
		[["Up 3 m\n96 m long", {"type": "ramp", "length": 3, "rise": 1}], ["Down 3 m\n96 m long", {"type": "ramp", "length": 3, "rise": -1}]],
		[["Up 6 m\n64 m long", {"type": "ramp", "length": 2, "rise": 2}], ["Down 6 m\n64 m long", {"type": "ramp", "length": 2, "rise": -2}]],
		[["Up 6 m\n96 m long", {"type": "ramp", "length": 3, "rise": 2}], ["Down 6 m\n96 m long", {"type": "ramp", "length": 3, "rise": -2}]],
		[["45° up 3 m\nNormal left", {"type": "arc", "angle": 45, "turn": "left", "size": 2, "rise": 1}], ["45° up 3 m\nNormal right", {"type": "arc", "angle": 45, "turn": "right", "size": 2, "rise": 1}]],
		[["45° down 3 m\nNormal left", {"type": "arc", "angle": 45, "turn": "left", "size": 2, "rise": -1}], ["45° down 3 m\nNormal right", {"type": "arc", "angle": 45, "turn": "right", "size": 2, "rise": -1}]],
		[["45° up 3 m\nWide left", {"type": "arc", "angle": 45, "turn": "left", "size": 3, "rise": 1}], ["45° up 3 m\nWide right", {"type": "arc", "angle": 45, "turn": "right", "size": 3, "rise": 1}]],
		[["45° down 3 m\nWide left", {"type": "arc", "angle": 45, "turn": "left", "size": 3, "rise": -1}], ["45° down 3 m\nWide right", {"type": "arc", "angle": 45, "turn": "right", "size": 3, "rise": -1}]],
		[["90° up 3 m\nNormal left", {"type": "curve", "turn": "left", "size": 2, "rise": 1}], ["90° up 3 m\nNormal right", {"type": "curve", "turn": "right", "size": 2, "rise": 1}]],
		[["90° down 3 m\nNormal left", {"type": "curve", "turn": "left", "size": 2, "rise": -1}], ["90° down 3 m\nNormal right", {"type": "curve", "turn": "right", "size": 2, "rise": -1}]],
		[["90° up 3 m\nWide left", {"type": "curve", "turn": "left", "size": 3, "rise": 1}], ["90° up 3 m\nWide right", {"type": "curve", "turn": "right", "size": 3, "rise": 1}]],
		[["90° down 3 m\nWide left", {"type": "curve", "turn": "left", "size": 3, "rise": -1}], ["90° down 3 m\nWide right", {"type": "curve", "turn": "right", "size": 3, "rise": -1}]],
		[["Hump 1.5 m\n96 m long", {"type": "crest", "length": 3, "height": 1.5}], ["Hump 3 m\n96 m long", {"type": "crest", "length": 3, "height": 3.0}]],
	]],
	["Banked", "banked", [
		[["45° bank 22°\nNormal left", {"type": "arc", "angle": 45, "turn": "left", "size": 2, "bank": 22}], ["45° bank 22°\nNormal right", {"type": "arc", "angle": 45, "turn": "right", "size": 2, "bank": 22}]],
		[["45° bank 22°\nWide left", {"type": "arc", "angle": 45, "turn": "left", "size": 3, "bank": 22}], ["45° bank 22°\nWide right", {"type": "arc", "angle": 45, "turn": "right", "size": 3, "bank": 22}]],
		[["90° bank 22°\nWide left", {"type": "curve", "turn": "left", "size": 3, "bank": 22}], ["90° bank 22°\nWide right", {"type": "curve", "turn": "right", "size": 3, "bank": 22}]],
		[["Wall ride left\n90° · bank 80°", {"type": "curve", "turn": "left", "size": 3, "bank": 80}], ["Wall ride right\n90° · bank 80°", {"type": "curve", "turn": "right", "size": 3, "bank": 80}]],
	]],
	["Specials", "stunts", [
		[["Jump", {"type": "jump"}], ["Level crossing", {"type": "crossing"}]],
		[["Loop left\n29 m high", {"type": "loop", "side": "left"}], ["Loop right\n29 m high", {"type": "loop", "side": "right"}]],
		[["Corkscrew L\n18.5 m high", {"type": "corkscrew", "side": "left"}], ["Corkscrew R\n18.5 m high", {"type": "corkscrew", "side": "right"}]],
		[["Shortcut left\n90° normal", {"type": "curve", "turn": "left", "size": 2, "cut": true}], ["Shortcut right\n90° normal", {"type": "curve", "turn": "right", "size": 2, "cut": true}]],
	]],
	# Each piece here also needs its key at the end of _SPEC_ORDER.
	["Splits", "splits", [
		# Rough and jump splits are named by where the dirt or the jump is;
		# a rough split's side is the way its tarmac swings out.
		[["Split straight\n64 × 32 m", {"type": "split", "length": 2}], ["Split straight\n96 × 32 m", {"type": "split", "length": 3}]],
		[["Wide split\n128 × 64 m", {"type": "split", "length": 4, "island": 38.0}]],
		[["Left split\n90° wide", {"type": "split_bend", "turn": "left", "size": 3}], ["Right split\n90° wide", {"type": "split_bend", "turn": "right", "size": 3}]],
		[["Left split\n90° extra wide", {"type": "split_bend", "turn": "left", "size": 4}], ["Right split\n90° extra wide", {"type": "split_bend", "turn": "right", "size": 4}]],
		[["Dirt right\n96 × 32 m", {"type": "rough_split", "side": "left"}], ["Dirt left\n96 × 32 m", {"type": "rough_split", "side": "right"}]],
		[["Jump left\n128 × 32 m", {"type": "jump_split", "side": "left"}], ["Jump right\n128 × 32 m", {"type": "jump_split", "side": "right"}]],
	]],
]

## Stable preset order used by the closing solvers.
const _SPEC_ORDER := [
	"type=straight|length=1",
	"type=straight|length=2",
	"type=straight|length=3",
	"type=straight|length=4",
	"type=half_straight",
	"type=curve|turn=left|size=1",
	"type=curve|turn=right|size=1",
	"type=curve|turn=left|size=2",
	"type=curve|turn=right|size=2",
	"type=curve|turn=left|size=3",
	"type=curve|turn=right|size=3",
	"type=curve|turn=left|size=4",
	"type=curve|turn=right|size=4",
	"type=curve|turn=left|size=2|cut=true",
	"type=curve|turn=right|size=2|cut=true",
	"type=curve|turn=left|size=3|bank=22",
	"type=curve|turn=right|size=3|bank=22",
	"type=slant|length=2|turn=left|across=1",
	"type=slant|length=2|turn=right|across=1",
	"type=slant|length=3|turn=left|across=1",
	"type=slant|length=3|turn=right|across=1",
	"type=slant|length=4|turn=left|across=1",
	"type=slant|length=4|turn=right|across=1",
	"type=slant|length=4|turn=left|across=2",
	"type=slant|length=4|turn=right|across=2",
	"type=slant|length=3|turn=left|across=2",
	"type=slant|length=3|turn=right|across=2",
	"type=slant|length=4|turn=left|across=3",
	"type=slant|length=4|turn=right|across=3",
	"type=slant|length=3|turn=left|across=1|rise=1",
	"type=slant|length=3|turn=right|across=1|rise=1",
	"type=slant|length=3|turn=left|across=1|rise=-1",
	"type=slant|length=3|turn=right|across=1|rise=-1",
	"type=ramp|length=2|rise=1",
	"type=ramp|length=2|rise=-1",
	"type=ramp|length=3|rise=1",
	"type=ramp|length=3|rise=-1",
	"type=ramp|length=2|rise=2",
	"type=ramp|length=2|rise=-2",
	"type=ramp|length=3|rise=2",
	"type=ramp|length=3|rise=-2",
	"type=ramp|length=1|rise=1",
	"type=ramp|length=1|rise=-1",
	"type=curve|turn=left|size=2|rise=1",
	"type=curve|turn=right|size=2|rise=1",
	"type=curve|turn=left|size=2|rise=-1",
	"type=curve|turn=right|size=2|rise=-1",
	"type=curve|turn=left|size=3|rise=1",
	"type=curve|turn=right|size=3|rise=1",
	"type=curve|turn=left|size=3|rise=-1",
	"type=curve|turn=right|size=3|rise=-1",
	"type=crest|length=3|height=1.5",
	"type=crest|length=3|height=3",
	"type=jump",
	"type=crossing",
	"type=loop|side=left",
	"type=loop|side=right",
	"type=corkscrew|side=left",
	"type=corkscrew|side=right",
	"type=curve|turn=left|size=3|bank=80",
	"type=curve|turn=right|size=3|bank=80",
	"type=arc|angle=30|turn=left|size=1",
	"type=arc|angle=30|turn=right|size=1",
	"type=arc|angle=30|turn=left|size=2",
	"type=arc|angle=30|turn=right|size=2",
	"type=arc|angle=30|turn=left|size=3",
	"type=arc|angle=30|turn=right|size=3",
	"type=arc|angle=30|turn=left|size=4",
	"type=arc|angle=30|turn=right|size=4",
	"type=arc|angle=45|turn=left|size=1",
	"type=arc|angle=45|turn=right|size=1",
	"type=arc|angle=45|turn=left|size=2",
	"type=arc|angle=45|turn=right|size=2",
	"type=arc|angle=45|turn=left|size=3",
	"type=arc|angle=45|turn=right|size=3",
	"type=arc|angle=45|turn=left|size=4",
	"type=arc|angle=45|turn=right|size=4",
	"type=arc|angle=60|turn=left|size=1",
	"type=arc|angle=60|turn=right|size=1",
	"type=arc|angle=60|turn=left|size=2",
	"type=arc|angle=60|turn=right|size=2",
	"type=arc|angle=60|turn=left|size=3",
	"type=arc|angle=60|turn=right|size=3",
	"type=arc|angle=60|turn=left|size=4",
	"type=arc|angle=60|turn=right|size=4",
	"type=arc|angle=45|turn=left|size=2|bank=22",
	"type=arc|angle=45|turn=right|size=2|bank=22",
	"type=arc|angle=45|turn=left|size=3|bank=22",
	"type=arc|angle=45|turn=right|size=3|bank=22",
	"type=arc|angle=45|turn=left|size=2|rise=1",
	"type=arc|angle=45|turn=right|size=2|rise=1",
	"type=arc|angle=45|turn=left|size=2|rise=-1",
	"type=arc|angle=45|turn=right|size=2|rise=-1",
	"type=arc|angle=45|turn=left|size=3|rise=1",
	"type=arc|angle=45|turn=right|size=3|rise=1",
	"type=arc|angle=45|turn=left|size=3|rise=-1",
	"type=arc|angle=45|turn=right|size=3|rise=-1",
	"type=quarter_straight",
	"type=split|length=2",
	"type=split|length=3",
	"type=split|length=4|island=38",
	"type=split_bend|turn=left|size=3",
	"type=split_bend|turn=right|size=3",
	"type=split_bend|turn=left|size=4",
	"type=split_bend|turn=right|size=4",
	"type=rough_split|side=left",
	"type=rough_split|side=right",
	"type=jump_split|side=left",
	"type=jump_split|side=right",
	"type=arc|angle=15|turn=left|size=1",
	"type=arc|angle=15|turn=right|size=1",
	"type=arc|angle=15|turn=left|size=2",
	"type=arc|angle=15|turn=right|size=2",
	"type=arc|angle=15|turn=left|size=3",
	"type=arc|angle=15|turn=right|size=3",
	"type=arc|angle=15|turn=left|size=4",
	"type=arc|angle=15|turn=right|size=4",
	"type=arc|angle=75|turn=left|size=1",
	"type=arc|angle=75|turn=right|size=1",
	"type=arc|angle=75|turn=left|size=2",
	"type=arc|angle=75|turn=right|size=2",
	"type=arc|angle=75|turn=left|size=3",
	"type=arc|angle=75|turn=right|size=3",
	"type=arc|angle=75|turn=left|size=4",
	"type=arc|angle=75|turn=right|size=4",
]

const BEND_ANGLES := [15, 30, 45, 60, 75, 90]
const BEND_SIZES := [1, 2, 3, 4]


## Plain drawer bend. Quarter circles keep their legacy spec.
static func bend(angle: int, size: int, turn: String) -> Dictionary:
	assert(angle in BEND_ANGLES and size in BEND_SIZES and turn in ["left", "right"])
	var spec := {"type": "curve" if angle == 90 else "arc", "turn": turn, "size": size}
	if angle != 90:
		spec["angle"] = angle
	return spec


## All presets in their stable solver order, independent of the drawer.
static func specs() -> Array:
	var by_key := {}
	for category in CATEGORIES:
		for row in category[2]:
			for tile in row:
				by_key[_spec_key(tile[1])] = tile[1]
	var out := []
	for key in _SPEC_ORDER:
		out.append(by_key[key].duplicate(true))
	return out


static func _spec_key(spec: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in ["type", "length", "angle", "turn", "size", "across", "rise", "height", "bank", "cut", "side", "island", "metres", "shift", "end", "heading", "handles"]:
		if spec.has(key):
			var value := _number(spec[key]) if spec[key] is float else str(spec[key]).to_lower()
			parts.append("%s=%s" % [key, value])
	return "|".join(parts)


## Flat road and descending ramps offered by the drawer, in stable order.
static func closer_choices() -> Array:
	var out := []
	for spec in specs():
		var kind: String = spec.type
		# Splits are never picked: a closing road is plain road.
		if TrackPiece.SPLIT_TYPES.has(kind):
			continue
		if kind in ["straight", "half_straight", "quarter_straight"] or (kind in ["curve", "arc", "slant"] and not spec.has("rise") and not spec.has("bank") and not spec.has("cut")) or (kind == "ramp" and spec.rise < 0):
			out.append(spec)
	return out


## Surface and walls do not change the drawer's part identity.
static func piece_name(spec: Dictionary) -> String:
	if spec.get("type") == "corkscrew":
		return "Corkscrew %s" % spec.get("side", "right")
	var key := _spec_key(spec)
	for category in CATEGORIES:
		for row in category[2]:
			for tile in row:
				if _spec_key(tile[1]) == key:
					return tile[0].replace("\n", " · ")
	var kind: String = spec.get("type", "straight")
	var piece := TrackPiece.from_spec(spec)
	var turn := "left" if piece.turn < 0 or piece.across < 0 else "right"
	match kind:
		"adjustable_straight":
			return "Adjustable straight"
		"adjustable_offset":
			return "Adjustable offset"
		"adjustable_split":
			return "Adjustable split"
		"split":
			return "Split straight"
		"split_bend":
			return "%s split" % turn.capitalize()
		"rough_split":
			return "Dirt left" if spec.get("side", "right") == "right" else "Dirt right"
		"jump_split":
			return "Jump %s" % spec.get("side", "right")
		"connector":
			return "Join"
		"curve", "arc":
			var style := "bend"
			if piece.cut:
				style = "shortcut"
			elif absf(piece.bank) >= TrackPiece.STICKY_BANK:
				style = "wall ride"
			elif piece.bank != 0:
				style = "banked bend"
			elif piece.rise != 0:
				style = "climb" if piece.rise > 0 else "drop"
			return "%s° %s %s" % [piece.angle, style, turn]
		"ramp":
			return "Ramp up" if piece.rise > 0 else "Ramp down"
		"slant":
			return "%s offset" % turn.capitalize()
		"crest":
			return "Hump"
		"quarter_straight":
			return "Quarter straight"
		"half_straight":
			return "Half straight"
		"loop", "corkscrew":
			return "%s %s" % [kind.capitalize(), spec.get("side", "right")]
		_:
			return kind.replace("_", " ").capitalize()


## Metres along the ground, centre radius and height for the selected part.
static func dimensions(spec: Dictionary) -> String:
	var kind: String = spec.get("type", "straight")
	var piece := TrackPiece.from_spec(spec)
	var length := piece.tiles * TrackPiece.TILE
	var rise := piece.rise
	var parts := PackedStringArray()
	match kind:
		"adjustable_straight":
			parts.append("%s m long" % _metres(piece.metres))
		"adjustable_offset":
			parts.append("%s m along · %s m sideways" % [_metres(piece.metres), _metres(piece.shift)])
		"split", "adjustable_split":
			parts.append("%s m long · island %s m" % [_metres(piece.run_length()), _metres(piece.island)])
		"split_bend":
			parts.append("90° · radius %s m" % _metres(piece.radius))
		"rough_split":
			parts.append("96 m long · one branch on dirt")
		"jump_split":
			parts.append("128 m long · jump on one branch")
		"connector":
			parts.append("%s m long" % _metres(piece.path_length()))
		"curve", "arc":
			parts.append("%s° · radius %s m" % [piece.angle, _metres(piece.radius)])
			if piece.bank != 0:
				parts.append("bank %s°" % _metres(rad_to_deg(piece.bank)))
		"slant":
			parts.append("%s m along · %s m across" % [_metres(length), _metres(absi(piece.across) * TrackPiece.TILE)])
		"quarter_straight":
			parts.append("8 m long")
		"half_straight":
			parts.append("16 m long")
		"jump":
			parts.append("96 m along · 1.5 m high")
		"loop", "corkscrew":
			parts.append("96 m along · 32 m across")
			parts.append("%s m high" % ("29" if kind == "loop" else "18.5"))
		"crest":
			parts.append("%s m long · %s m high" % [_metres(length), _metres(piece.crest_height)])
		"crossing":
			parts.append("32 m long")
		_:
			parts.append("%s m long" % _metres(length))
	if rise != 0:
		parts.append("%s %s m" % ["up" if rise > 0 else "down", _metres(absf(rise))])
	return " · ".join(parts)


static func _metres(value: float) -> String:
	return _number(snappedf(value, 0.1))


static func _number(value: float) -> String:
	return str(int(value)) if value == roundf(value) else String.num(value, 4)
