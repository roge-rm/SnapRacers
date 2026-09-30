class_name Props
extends RefCounted

## Everything that stands around a track, built out of bricks. Each one is a
## function that adds its bricks to a SceneryKit at a spot on the ground, and
## says how much room it takes (its radius, in metres) so props don't end up
## inside each other.
##
## `facing` is how many quarter turns the front is turned from facing south
## (+Z), so buildings can face the track. Sizes are in metres. A stud is a
## quarter of a metre and a brick is 0.3 m high, the same as the karts, so a
## door is about a metre wide and a house about six.

const RED := Color("#c4281c")
const DARK_RED := Color("#7b2e2f")
const BLUE := Color("#0d69ab")
const DARK_BLUE := Color("#143044")
const AZURE := Color("#36aebf")
const YELLOW := Color("#f2cd37")
const ORANGE := Color("#da8540")
const GREEN := Color("#237841")
const BRIGHT_GREEN := Color("#4b9f4a")
const LIME := Color("#a4bd46")
const OLIVE := Color("#9b9a5a")
const SAND_GREEN := Color("#789082")
const WHITE := Color("#f2f3f2")
const LIGHT_GREY := Color("#a3a2a4")
const DARK_GREY := Color("#635f61")
const BLACK := Color("#1b2a34")
const TAN := Color("#d7c599")
const DARK_TAN := Color("#958a73")
const BROWN := Color("#694030")
const NOUGAT := Color("#cc8e69")
const TERRACOTTA := Color("#b5582c")
const PINK := Color("#e4adc8")
const WATER := Color("#3f86c2")
const LAVA := Color("#ff6a1a")
const GLASS := Color("#8fd3f4")

## How much room each prop takes, by name. Anything not listed takes 3 m.
const ROOM := {
	"broadleaf": 2.5, "pine": 2.5, "cypress": 1.2, "palm": 2.0, "olive": 2.5, "peach": 2.5, "lemon": 2.5,
	"snowy_pine": 2.5, "maple": 2.8, "birch": 2.0, "bush": 1.2, "rocks": 2.0, "reeds": 1.5, "snowman": 1.0,
	"hay": 1.2, "house": 5.0, "barn": 7.5, "silo": 3.0, "villa": 6.0, "trullo": 3.5, "cottage": 5.0,
	"cabin": 4.5, "factory": 12.0, "chimney": 2.5, "containers": 5.5, "tanks": 6.0, "crane": 5.0,
	"skyscraper": 9.0, "dune": 9.0, "tower": 4.0, "castle_wall": 8.0, "church": 7.0, "stilt_hut": 4.0,
	"windmill": 4.5, "wind_turbine": 4.0, "fence": 3.0, "tent": 3.5, "ruins": 5.0, "cactus": 1.2,
	"headframe": 9.0, "slag_heap": 14.0, "excavator": 22.0, "rocket": 14.0, "radar": 5.0,
	"volcano": 45.0, "mountain": 40.0, "castle": 26.0, "station": 14.0, "bridge": 16.0,
	"lake": 20.0, "pond": 9.0, "lava_pool": 7.0, "lighthouse": 4.0, "big_windmill": 6.0,
	"sakura": 2.5, "pagoda": 6.0, "ferris_wheel": 16.0, "old_banking": 48.0,
	"oast_house": 7.0, "standing_stones": 7.0, "control_tower": 5.0, "spectator_bank": 13.0,
}


## Builds the named prop. Unknown names build nothing.
static func add(kit: SceneryKit, prop: String, at: Vector3, rng: RandomNumberGenerator, facing := 0) -> void:
	var at_grid := Vector3(snappedf(at.x, 0.5), at.y, snappedf(at.z, 0.5))
	match prop:
		"broadleaf": broadleaf(kit, at_grid, rng, [GREEN, BRIGHT_GREEN][rng.randi() % 2])
		"peach": fruit_tree(kit, at_grid, rng, ORANGE)
		"lemon": fruit_tree(kit, at_grid, rng, YELLOW)
		"maple": broadleaf(kit, at_grid, rng, [RED, ORANGE, DARK_RED][rng.randi() % 3])
		"birch": birch(kit, at_grid, rng)
		"pine": pine(kit, at_grid, rng, false)
		"snowy_pine": pine(kit, at_grid, rng, true)
		"cypress": cypress(kit, at_grid, rng)
		"palm": palm(kit, at_grid, rng)
		"olive": olive(kit, at_grid, rng)
		"cactus": cactus(kit, at_grid, rng)
		"bush": kit.box(at_grid, Vector3(1.5, 1.2, 1.5), [GREEN, BRIGHT_GREEN, OLIVE][rng.randi() % 3], SceneryKit.BRICK, false)
		"rocks": rocks(kit, at_grid, rng)
		"reeds": reeds(kit, at_grid, rng)
		"snowman": snowman(kit, at_grid)
		"hay": kit.turned_cylinder(at_grid + Vector3.UP * 0.6, 0.6, 1.2, Basis(Vector3.BACK, PI * 0.5), TAN, SceneryKit.BRICK)
		"fence": fence(kit, at_grid, facing)
		"house": house(kit, at_grid, facing, [WHITE, TAN, YELLOW, NOUGAT][rng.randi() % 4], [RED, DARK_GREY, BLUE, BROWN][rng.randi() % 4])
		"cottage": house(kit, at_grid, facing, DARK_RED, DARK_GREY, true)
		"villa": villa(kit, at_grid, facing, rng)
		"barn": barn(kit, at_grid, facing)
		"silo": silo(kit, at_grid)
		"trullo": trullo(kit, at_grid)
		"cabin": cabin(kit, at_grid, facing)
		"factory": factory(kit, at_grid, facing)
		"chimney": chimney(kit, at_grid, rng)
		"containers": containers(kit, at_grid, rng)
		"tanks": tanks(kit, at_grid)
		"crane": crane(kit, at_grid, facing)
		"skyscraper": skyscraper(kit, at_grid, rng)
		"dune": dune(kit, at_grid, rng)
		"tower": tower(kit, at_grid, LIGHT_GREY)
		"castle_wall": castle_wall(kit, at_grid, facing)
		"church": church(kit, at_grid, facing)
		"stilt_hut": stilt_hut(kit, at_grid, facing)
		"windmill": windmill(kit, at_grid, facing, 1.0)
		"big_windmill": windmill(kit, at_grid, facing, 1.6)
		"wind_turbine": wind_turbine(kit, at_grid, facing)
		"tent": tent(kit, at_grid, facing, [RED, BLUE, YELLOW, WHITE][rng.randi() % 4])
		"ruins": ruins(kit, at_grid, rng)
		"headframe": headframe(kit, at_grid, facing)
		"slag_heap": stepped_heap(kit, at_grid, 12.0, 10, DARK_GREY, BLACK)
		"excavator": excavator(kit, at_grid, facing)
		"rocket": rocket(kit, at_grid, facing)
		"radar": radar(kit, at_grid, facing)
		"volcano": volcano(kit, at_grid)
		"mountain": mountain(kit, at_grid, rng)
		"castle": castle(kit, at_grid, facing)
		"station": station(kit, at_grid, facing)
		"bridge": stone_bridge(kit, at_grid, facing)
		"lake": water(kit, at_grid, 18.0, rng)
		"pond": water(kit, at_grid, 8.0, rng)
		"lava_pool": lava_pool(kit, at_grid, rng)
		"lighthouse": lighthouse(kit, at_grid)
		"sakura": broadleaf(kit, at_grid, rng, [PINK, Color("#f0c4d8")][rng.randi() % 2])
		"pagoda": pagoda(kit, at_grid)
		"ferris_wheel": ferris_wheel(kit, at_grid, facing)
		"old_banking": old_banking(kit, at_grid, facing)
		"oast_house": oast_house(kit, at_grid, facing)
		"standing_stones": standing_stones(kit, at_grid, rng)
		"control_tower": control_tower(kit, at_grid, facing)
		"spectator_bank": spectator_bank(kit, at_grid, facing, rng)


## Turns an offset from a prop's middle by its facing.
static func _turn(v: Vector3, facing: int) -> Vector3:
	match posmod(facing, 4):
		1:
			return Vector3(v.z, v.y, -v.x)
		2:
			return Vector3(-v.x, v.y, -v.z)
		3:
			return Vector3(-v.z, v.y, v.x)
	return v


## A size turned the same way (width and depth swap on odd turns).
static func _turn_size(size: Vector3, facing: int) -> Vector3:
	return Vector3(size.z, size.y, size.x) if posmod(facing, 2) == 1 else size


static func _box(kit: SceneryKit, at: Vector3, offset: Vector3, size: Vector3, facing: int, colour: Color, surface := SceneryKit.BRICK, solid := true) -> void:
	kit.box(at + _turn(offset, facing), _turn_size(size, facing), colour, surface, solid)


## A pitched roof over a box `width` across and `depth` deep, its ridge
## running across, sitting on `top`.
static func _roof(kit: SceneryKit, top: Vector3, width: float, depth: float, pitch: float, facing: int, colour: Color) -> void:
	var half := depth * 0.5 + 0.3
	var slope := half / cos(pitch)
	var rise := half * tan(pitch)
	for side in [-1.0, 1.0]:
		var tilt := Basis(Vector3.RIGHT, side * pitch)
		var centre := Vector3(0.0, rise * 0.5, side * half * 0.5)
		var basis := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5) * tilt
		kit.turned_box(top + _turn(centre, facing), Vector3(width + 0.6, 0.25, slope), basis, colour, SceneryKit.SMOOTH)
	# Fill the gable ends with stepped bricks.
	var steps := 4
	for k in steps:
		var w := depth * (1.0 - float(k) / steps)
		for end in [-1.0, 1.0]:
			_box(kit, top, Vector3(end * (width * 0.5 - 0.15), rise * k / steps, 0.0), Vector3(0.3, rise / steps, w), facing, colour.darkened(0.25), SceneryKit.SMOOTH, false)


# Trees and plants.

static func broadleaf(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, leaves: Color) -> void:
	var trunk := 1.2 + rng.randf() * 0.9
	kit.box(at, Vector3(0.5, trunk, 0.5), BROWN, SceneryKit.BRICK, true)
	var size := 2.5 + rng.randf() * 1.0
	kit.box(at + Vector3.UP * trunk, Vector3(size * 0.8, 0.9, size * 0.8), leaves.darkened(0.1), SceneryKit.BRICK, false)
	kit.box(at + Vector3.UP * (trunk + 0.9), Vector3(size, 1.2, size), leaves, SceneryKit.BRICK, false)
	kit.box(at + Vector3.UP * (trunk + 2.1), Vector3(size * 0.6, 0.9, size * 0.6), leaves.lightened(0.1), SceneryKit.BRICK, false)


static func fruit_tree(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, fruit: Color) -> void:
	broadleaf(kit, at, rng, BRIGHT_GREEN)
	for k in 5:
		var a := rng.randf() * TAU
		var r := 1.1 + rng.randf() * 0.3
		kit.box(at + Vector3(cos(a) * r, 2.2 + rng.randf() * 1.4, sin(a) * r), Vector3(0.3, 0.3, 0.3), fruit, SceneryKit.SMOOTH, false)


static func birch(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := 3.0 + rng.randf()
	kit.cylinder(at, 0.22, trunk, WHITE, SceneryKit.BRICK, true)
	for k in 3:
		kit.box(at + Vector3(0.0, 0.6 + k * 0.9, 0.0), Vector3(0.46, 0.1, 0.46), BLACK, SceneryKit.SMOOTH, false)
	kit.box(at + Vector3.UP * (trunk - 0.6), Vector3(2.2, 1.8, 2.2), LIME, SceneryKit.BRICK, false)


static func pine(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, snowy: bool) -> void:
	var trunk := 0.9
	kit.cylinder(at, 0.3, trunk, BROWN, SceneryKit.BRICK, true)
	var size := 2.6 + rng.randf() * 0.8
	var y := trunk
	for k in 3:
		var r := size * (1.0 - k * 0.25) * 0.5
		var h := 1.8 - k * 0.2
		kit.cone(at + Vector3.UP * y, r, h, GREEN.darkened(0.1 * k))
		if snowy:
			kit.cone(at + Vector3.UP * (y + h * 0.55), r * 0.5, h * 0.45, WHITE)
		y += h * 0.6


static func cypress(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	kit.cylinder(at, 0.2, 0.6, BROWN, SceneryKit.BRICK, true)
	var h := 5.0 + rng.randf() * 2.0
	kit.cylinder(at + Vector3.UP * 0.6, 0.7, h * 0.6, GREEN.darkened(0.25))
	kit.cone(at + Vector3.UP * (0.6 + h * 0.6), 0.7, h * 0.4, GREEN.darkened(0.25))


static func palm(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := 4.5 + rng.randf() * 2.0
	var lean := Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
	for k in 6:
		var f := float(k) / 6.0
		kit.cylinder(at + lean * f * f + Vector3.UP * h * f, 0.22 - f * 0.05, h / 6.0, DARK_TAN, SceneryKit.BRICK, k == 0)
	var top := at + lean + Vector3.UP * h
	for k in 6:
		var a := k * TAU / 6.0 + rng.randf() * 0.3
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.35)
		kit.turned_box(top + Vector3(sin(a), -0.3, cos(a)) * 1.2, Vector3(0.7, 0.08, 2.6), basis, BRIGHT_GREEN)
	for k in 3:
		kit.box(top + Vector3(0.25 * (k - 1), -0.5, 0.2), Vector3(0.3, 0.3, 0.3), BROWN, SceneryKit.SMOOTH, false)


static func olive(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	kit.box(at, Vector3(0.6, 0.9, 0.6), BROWN, SceneryKit.BRICK, true)
	kit.box(at + Vector3(0.2, 0.9, 0.1), Vector3(0.5, 0.6, 0.5), BROWN)
	var size := 3.0 + rng.randf()
	kit.box(at + Vector3(0.2, 1.5, 0.1), Vector3(size, 0.9, size * 0.9), SAND_GREEN, SceneryKit.BRICK, false)
	kit.box(at + Vector3(0.2, 2.4, 0.1), Vector3(size * 0.6, 0.6, size * 0.6), SAND_GREEN.lightened(0.1), SceneryKit.BRICK, false)


static func cactus(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := 2.0 + rng.randf() * 1.5
	kit.cylinder(at, 0.35, h, GREEN, SceneryKit.BRICK, true)
	kit.cylinder(at + Vector3(0.55, h * 0.4, 0.0), 0.2, 0.9, GREEN)
	kit.box(at + Vector3(0.3, h * 0.4, 0.0), Vector3(0.5, 0.3, 0.3), GREEN, SceneryKit.BRICK, false)


static func rocks(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var s := Vector3(1.0 + rng.randf(), 0.6 + rng.randf() * 0.9, 1.0 + rng.randf())
		kit.box(at + Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)), s, [DARK_GREY, LIGHT_GREY][k % 2])


static func reeds(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 7:
		var h := 1.2 + rng.randf() * 1.0
		kit.box(at + Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)), Vector3(0.12, h, 0.12), [OLIVE, DARK_TAN, GREEN][k % 3], SceneryKit.SMOOTH, false)


static func snowman(kit: SceneryKit, at: Vector3) -> void:
	kit.cylinder(at, 0.7, 0.9, WHITE, SceneryKit.SMOOTH, true)
	kit.cylinder(at + Vector3.UP * 0.9, 0.5, 0.7, WHITE, SceneryKit.SMOOTH)
	kit.cylinder(at + Vector3.UP * 1.6, 0.35, 0.55, WHITE, SceneryKit.SMOOTH)
	kit.box(at + Vector3(0.0, 1.85, 0.36), Vector3(0.1, 0.1, 0.3), ORANGE, SceneryKit.SMOOTH, false)
	kit.cylinder(at + Vector3.UP * 2.15, 0.4, 0.08, BLACK, SceneryKit.SMOOTH)
	kit.cylinder(at + Vector3.UP * 2.2, 0.28, 0.45, BLACK, SceneryKit.SMOOTH)


static func fence(kit: SceneryKit, at: Vector3, facing: int) -> void:
	for k in 4:
		_box(kit, at, Vector3(-3.0 + k * 2.0, 0.0, 0.0), Vector3(0.2, 1.2, 0.2), facing, WHITE)
	for y in [0.45, 0.9]:
		_box(kit, at, Vector3(0.0, y, 0.0), Vector3(6.2, 0.15, 0.1), facing, WHITE, SceneryKit.SMOOTH, false)


static func water(kit: SceneryKit, at: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	# A rough round pond made of overlapping flat tiles, with a sandy edge.
	for k in 5:
		var a := k * TAU / 5.0 + rng.randf() * 0.5
		var off := Vector3(cos(a), 0.0, sin(a)) * radius * 0.35
		var s := radius * (1.0 + rng.randf() * 0.3)
		kit.box(at + off + Vector3.UP * 0.02, Vector3(s * 1.15, 0.06, s * 1.15), TAN, SceneryKit.SMOOTH, false)
		kit.box(at + off + Vector3.UP * 0.03, Vector3(s, 0.06, s), WATER, SceneryKit.WATER, false)


static func lava_pool(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var off := Vector3(rng.randf_range(-2, 2), 0.0, rng.randf_range(-2, 2))
		kit.box(at + off + Vector3.UP * 0.02, Vector3(6.0, 0.1, 6.0), BLACK, SceneryKit.BRICK, false)
		kit.box(at + off + Vector3.UP * 0.04, Vector3(4.5, 0.1, 4.5), LAVA, SceneryKit.GLOW, false)


# Buildings.

## A house with walls, a door, windows and a pitched roof. A cottage gets
## white corners, like a Swedish one.
static func house(kit: SceneryKit, at: Vector3, facing: int, wall: Color, roof: Color, cottage := false) -> void:
	var w := 6.0
	var d := 5.0
	var h := 3.3
	_box(kit, at, Vector3.ZERO, Vector3(w, h, d), facing, wall)
	_box(kit, at, Vector3(0.0, 0.0, d * 0.5), Vector3(1.0, 2.1, 0.1), facing, BROWN, SceneryKit.SMOOTH, false)
	for x in [-1.8, 1.8]:
		_box(kit, at, Vector3(x, 1.2, d * 0.5), Vector3(1.0, 1.1, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(x, 1.2, -d * 0.5), Vector3(1.0, 1.1, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
	if cottage:
		for x in [-w * 0.5, w * 0.5]:
			for z in [-d * 0.5, d * 0.5]:
				_box(kit, at, Vector3(x, 0.0, z), Vector3(0.35, h, 0.35), facing, WHITE, SceneryKit.SMOOTH, false)
	_roof(kit, at + Vector3.UP * h, w, d, deg_to_rad(38.0), facing, roof)
	_box(kit, at, Vector3(1.5, h, -0.8), Vector3(0.6, 2.2, 0.6), facing, DARK_RED)


static func villa(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var wall: Color = [Color("#f4e3c1"), Color("#f2c9a0"), WHITE][rng.randi() % 3]
	_box(kit, at, Vector3.ZERO, Vector3(8.0, 3.6, 6.0), facing, wall)
	_box(kit, at, Vector3(2.0, 3.6, 0.0), Vector3(4.0, 3.0, 6.0), facing, wall)
	for x in [-3.0, -1.0, 1.0, 3.0]:
		for y in [0.9, 4.5]:
			if y > 4.0 and x < 0.0:
				continue
			_box(kit, at, Vector3(x, y, 3.0), Vector3(0.8, 1.4, 0.1), facing, DARK_BLUE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(-2.0, 3.6, 0.0), Vector3(4.4, 0.3, 6.4), facing, TERRACOTTA, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(2.0, 6.6, 0.0), Vector3(4.4, 0.3, 6.4), facing, TERRACOTTA, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(-2.0, 3.9, 3.0), Vector3(4.0, 0.9, 0.2), facing, WHITE, SceneryKit.BRICK, false)


static func barn(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var w := 10.0
	var d := 7.0
	var h := 4.5
	_box(kit, at, Vector3.ZERO, Vector3(w, h, d), facing, RED)
	_box(kit, at, Vector3(0.0, 0.0, d * 0.5), Vector3(3.2, 3.4, 0.1), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.3, d * 0.5 + 0.02), Vector3(2.8, 0.2, 0.1), facing, RED, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 4.0, d * 0.5), Vector3(1.2, 1.0, 0.1), facing, WHITE, SceneryKit.SMOOTH, false)
	_roof(kit, at + Vector3.UP * h, w, d, deg_to_rad(42.0), facing, DARK_GREY)


static func silo(kit: SceneryKit, at: Vector3) -> void:
	kit.cylinder(at, 1.8, 9.0, LIGHT_GREY, SceneryKit.BRICK, true)
	kit.cone(at + Vector3.UP * 9.0, 1.9, 1.5, BLUE)
	for y in [2.0, 4.5, 7.0]:
		kit.cylinder(at + Vector3.UP * y, 1.85, 0.2, DARK_GREY, SceneryKit.SMOOTH)


static func trullo(kit: SceneryKit, at: Vector3) -> void:
	kit.cylinder(at, 2.6, 2.4, WHITE, SceneryKit.BRICK, true)
	var y := 2.4
	for k in 6:
		var r := 2.8 - k * 0.42
		kit.cylinder(at + Vector3.UP * y, r, 0.45, LIGHT_GREY if k % 2 == 0 else DARK_GREY)
		y += 0.45
	kit.cylinder(at + Vector3.UP * y, 0.25, 0.5, WHITE, SceneryKit.SMOOTH)
	kit.box(at + Vector3(0.0, 0.0, 2.55), Vector3(1.0, 1.8, 0.2), BROWN, SceneryKit.SMOOTH, false)


static func cabin(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(6.0, 2.7, 5.0), facing, BROWN)
	for x in [-3.0, 3.0]:
		for z in [-2.5, 2.5]:
			_box(kit, at, Vector3(x, 0.0, z), Vector3(0.5, 2.7, 0.5), facing, BROWN.darkened(0.3), SceneryKit.BRICK, false)
	_box(kit, at, Vector3(0.0, 0.0, 2.5), Vector3(1.0, 2.0, 0.1), facing, DARK_RED, SceneryKit.SMOOTH, false)
	_roof(kit, at + Vector3.UP * 2.7, 6.0, 5.0, deg_to_rad(40.0), facing, GREEN.darkened(0.2))
	_box(kit, at, Vector3(-1.8, 2.7, -0.5), Vector3(0.7, 2.4, 0.7), facing, LIGHT_GREY)


static func factory(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var w := 22.0
	var d := 12.0
	var h := 6.0
	_box(kit, at, Vector3.ZERO, Vector3(w, h, d), facing, LIGHT_GREY)
	_box(kit, at, Vector3(0.0, 0.0, d * 0.5), Vector3(w, 1.2, 0.1), facing, BLUE, SceneryKit.SMOOTH, false)
	for x in [-6.0, 0.0, 6.0]:
		_box(kit, at, Vector3(x, 0.0, d * 0.5 + 0.02), Vector3(4.0, 4.2, 0.1), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	# A sawtooth roof, one slope and one upright face after another.
	for k in 5:
		var x := -w * 0.5 + 2.2 + k * 4.4
		var basis := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5) * Basis(Vector3.BACK, deg_to_rad(28.0))
		kit.turned_box(at + _turn(Vector3(x, h + 1.0, 0.0), facing), Vector3(4.8, 0.25, d), basis, DARK_GREY)
		_box(kit, at, Vector3(x + 2.1, h, 0.0), Vector3(0.2, 2.2, d), facing, GLASS, SceneryKit.SMOOTH, false)
	chimney(kit, at + _turn(Vector3(w * 0.5 - 2.0, 0.0, -d * 0.5 - 2.5), facing), null)


static func chimney(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := 18.0 if rng == null else 14.0 + rng.randf() * 8.0
	kit.cylinder(at, 1.3, h, DARK_RED, SceneryKit.BRICK, true)
	for k in 3:
		kit.cylinder(at + Vector3.UP * (h - 1.2 - k * 2.4), 1.35, 1.2, RED if k % 2 == 0 else WHITE, SceneryKit.SMOOTH)


static func containers(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var colours := [RED, BLUE, ORANGE, GREEN, DARK_BLUE, YELLOW]
	for x in [-1.3, 1.3]:
		for y in 1 + rng.randi() % 3:
			kit.box(at + Vector3(x, y * 2.6, 0.0), Vector3(2.5, 2.6, 6.0), colours[rng.randi() % colours.size()], SceneryKit.BRICK, y == 0)


static func tanks(kit: SceneryKit, at: Vector3) -> void:
	for x in [-3.0, 3.0]:
		kit.cylinder(at + Vector3(x, 0.0, 0.0), 2.6, 7.0, WHITE, SceneryKit.BRICK, true)
		kit.cone(at + Vector3(x, 7.0, 0.0), 2.7, 1.2, LIGHT_GREY)
		kit.cylinder(at + Vector3(x, 3.0, 0.0), 2.65, 0.4, RED, SceneryKit.SMOOTH)


static func crane(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(3.0, 1.0, 3.0), facing, DARK_GREY)
	for k in 7:
		_box(kit, at, Vector3(0.0, 1.0 + k * 3.0, 0.0), Vector3(1.2, 3.0, 1.2), facing, YELLOW, SceneryKit.BRICK, k == 0)
	_box(kit, at, Vector3(4.0, 22.0, 0.0), Vector3(16.0, 1.0, 1.0), facing, YELLOW)
	_box(kit, at, Vector3(-4.5, 21.0, 0.0), Vector3(3.0, 1.5, 2.0), facing, DARK_GREY)
	_box(kit, at, Vector3(10.0, 12.0, 0.0), Vector3(0.1, 10.0, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)


static func skyscraper(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var colour: Color = [Color("#5b7fa3"), Color("#7fa6c9"), LIGHT_GREY, Color("#4e6b8a")][rng.randi() % 4]
	var w := 8.0 + rng.randf() * 4.0
	var y := 0.0
	var levels := 2 + rng.randi() % 3
	for k in levels:
		var h := 12.0 + rng.randf() * 14.0
		kit.box(at + Vector3.UP * y, Vector3(w, h, w), colour, SceneryKit.WINDOWS, k == 0)
		y += h
		w *= 0.75
	kit.cylinder(at + Vector3.UP * y, 0.3, 8.0 + rng.randf() * 6.0, LIGHT_GREY, SceneryKit.SMOOTH)


static func dune(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	stepped_heap(kit, at, 8.0 + rng.randf() * 4.0, 4 + rng.randi() % 3, TAN, DARK_TAN)


## A mound made of layers, each smaller than the one below, like a heap or a
## dune or a hill built from plates.
static func stepped_heap(kit: SceneryKit, at: Vector3, radius: float, layers: int, colour: Color, top: Color) -> void:
	for k in layers:
		var f := 1.0 - float(k) / layers
		var r := radius * f
		kit.box(at + Vector3.UP * k * 0.9, Vector3(r * 2.0, 0.9, r * 1.7), colour.lerp(top, float(k) / layers), SceneryKit.BRICK, k == 0)


static func tower(kit: SceneryKit, at: Vector3, stone: Color) -> void:
	kit.cylinder(at, 3.0, 12.0, stone, SceneryKit.BRICK, true)
	for k in 10:
		var a := k * TAU / 10.0
		kit.box(at + Vector3(cos(a) * 2.8, 12.0, sin(a) * 2.8), Vector3(0.9, 0.9, 0.9), stone)
	kit.cone(at + Vector3.UP * 12.9, 2.2, 4.5, RED)
	for y in [5.0, 8.5]:
		kit.box(at + Vector3(0.0, y, 3.0), Vector3(0.6, 1.2, 0.2), BLACK, SceneryKit.SMOOTH, false)


static func castle_wall(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(14.0, 6.0, 2.4), facing, LIGHT_GREY)
	for k in 7:
		_box(kit, at, Vector3(-6.0 + k * 2.0, 6.0, 0.0), Vector3(1.0, 0.9, 2.4), facing, LIGHT_GREY)


static func church(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(6.0, 5.0, 10.0), facing, WHITE)
	_roof(kit, at + Vector3.UP * 5.0, 10.0, 6.0, deg_to_rad(45.0), (facing + 1) % 4, RED)
	_box(kit, at, Vector3(0.0, 0.0, 6.5), Vector3(3.0, 11.0, 3.0), facing, WHITE)
	kit.cone(at + _turn(Vector3(0.0, 11.0, 6.5), facing), 2.2, 7.0, DARK_GREY)
	_box(kit, at, Vector3(0.0, 7.5, 8.0), Vector3(1.0, 1.5, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)


static func stilt_hut(kit: SceneryKit, at: Vector3, facing: int) -> void:
	water(kit, at, 5.0, RandomNumberGenerator.new())
	for x in [-1.8, 1.8]:
		for z in [-1.5, 1.5]:
			_box(kit, at, Vector3(x, 0.0, z), Vector3(0.3, 1.8, 0.3), facing, BROWN)
	_box(kit, at, Vector3(0.0, 1.8, 0.0), Vector3(4.4, 0.3, 3.8), facing, BROWN)
	_box(kit, at, Vector3(0.0, 2.1, 0.0), Vector3(3.6, 2.1, 3.0), facing, TAN)
	_roof(kit, at + Vector3.UP * 4.2, 3.6, 3.0, deg_to_rad(40.0), facing, DARK_TAN)


static func windmill(kit: SceneryKit, at: Vector3, facing: int, scale: float) -> void:
	kit.cylinder(at, 2.3 * scale, 6.5 * scale, WHITE, SceneryKit.BRICK, true)
	kit.cone(at + Vector3.UP * 6.5 * scale, 2.5 * scale, 2.0 * scale, BLACK)
	kit.box(at + _turn(Vector3(0.0, 0.0, 2.3 * scale), facing), _turn_size(Vector3(1.0, 1.9, 0.2), facing), BROWN, SceneryKit.SMOOTH, false)
	var hub := at + Vector3.UP * 6.3 * scale + _turn(Vector3(0.0, 0.0, 2.6 * scale), facing)
	var face := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5)
	for k in 4:
		var blade := face * Basis(Vector3.BACK, k * PI * 0.5 + 0.4)
		kit.turned_box(hub + blade * Vector3(0.0, 2.6 * scale, 0.0), Vector3(1.0 * scale, 5.2 * scale, 0.1), blade, WHITE)
		kit.turned_box(hub + blade * Vector3(0.0, 2.6 * scale, 0.05), Vector3(0.15, 5.2 * scale, 0.12), blade, BROWN)


static func wind_turbine(kit: SceneryKit, at: Vector3, facing: int) -> void:
	kit.cylinder(at, 0.7, 26.0, WHITE, SceneryKit.SMOOTH, true)
	var face := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5)
	kit.turned_box(at + Vector3.UP * 26.5, Vector3(1.4, 1.4, 3.5), face, WHITE)
	var hub := at + Vector3.UP * 26.5 + face * Vector3(0.0, 0.0, 1.9)
	for k in 3:
		var blade := face * Basis(Vector3.BACK, k * TAU / 3.0)
		kit.turned_box(hub + blade * Vector3(0.0, 5.5, 0.0), Vector3(0.9, 11.0, 0.2), blade, WHITE)


static func tent(kit: SceneryKit, at: Vector3, facing: int, colour: Color) -> void:
	for x in [-2.0, 2.0]:
		for z in [-2.0, 2.0]:
			_box(kit, at, Vector3(x, 0.0, z), Vector3(0.15, 2.4, 0.15), facing, LIGHT_GREY, SceneryKit.SMOOTH)
	_roof(kit, at + Vector3.UP * 2.4, 4.4, 4.4, deg_to_rad(30.0), facing, colour)
	_box(kit, at, Vector3(0.0, 0.0, 0.0), Vector3(2.0, 0.8, 1.0), facing, LIGHT_GREY, SceneryKit.SMOOTH, false)


static func ruins(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	kit.box(at, Vector3(9.0, 0.6, 6.0), TAN)
	for k in 6:
		var h := 1.5 + rng.randf() * 4.0 if rng.randf() < 0.7 else 5.5
		kit.cylinder(at + Vector3(-3.6 + (k % 3) * 3.6, 0.6, -2.0 + floorf(k / 3.0) * 4.0), 0.5, h, WHITE, SceneryKit.BRICK, true)
	kit.box(at + Vector3(0.0, 6.1, 2.0), Vector3(8.0, 0.8, 1.2), WHITE)


# Landmarks.

static func headframe(kit: SceneryKit, at: Vector3, facing: int) -> void:
	# The tall steel frame over a mine shaft, with its winding wheel on top.
	for x in [-2.5, 2.5]:
		for z in [-2.0, 2.0]:
			_box(kit, at, Vector3(x * (1.0 - 0.0), 0.0, z), Vector3(0.5, 18.0, 0.5), facing, RED)
		for y in [4.0, 9.0, 14.0]:
			_box(kit, at, Vector3(x, y, 0.0), Vector3(0.3, 0.3, 4.5), facing, RED, SceneryKit.SMOOTH, false)
	for y in [4.0, 9.0, 14.0]:
		_box(kit, at, Vector3(0.0, y, 2.0), Vector3(5.5, 0.3, 0.3), facing, RED, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 18.0, 0.0), Vector3(6.0, 0.6, 5.0), facing, DARK_RED)
	var side := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)
	kit.turned_cylinder(at + Vector3.UP * 20.6, 2.6, 0.4, side, DARK_GREY)
	kit.turned_cylinder(at + Vector3.UP * 20.6, 0.4, 1.2, side, BLACK)
	_box(kit, at, Vector3(0.0, 0.0, -6.5), Vector3(8.0, 5.0, 5.0), facing, DARK_RED)
	_roof(kit, at + _turn(Vector3(0.0, 5.0, -6.5), facing), 8.0, 5.0, deg_to_rad(35.0), facing, DARK_GREY)


static func excavator(kit: SceneryKit, at: Vector3, facing: int) -> void:
	# A bucket wheel excavator, the giant digger from open pit mines.
	for x in [-5.0, 5.0]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(3.0, 2.0, 12.0), facing, DARK_GREY)
	_box(kit, at, Vector3(0.0, 2.0, 0.0), Vector3(12.0, 6.0, 9.0), facing, WHITE)
	_box(kit, at, Vector3(0.0, 8.0, -1.0), Vector3(6.0, 3.0, 5.0), facing, WHITE, SceneryKit.WINDOWS)
	var face := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5)
	var boom := face * Basis(Vector3.RIGHT, deg_to_rad(20.0))
	kit.turned_box(at + face * Vector3(0.0, 11.0, 11.0), Vector3(2.5, 2.5, 22.0), boom, YELLOW, SceneryKit.BRICK)
	kit.turned_box(at + face * Vector3(0.0, 17.0, -4.0), Vector3(1.5, 1.5, 16.0), face * Basis(Vector3.RIGHT, deg_to_rad(-25.0)), YELLOW, SceneryKit.BRICK)
	var wheel_at := at + face * Vector3(0.0, 7.5, 21.0)
	var side := face * Basis(Vector3.BACK, PI * 0.5)
	kit.turned_cylinder(wheel_at, 6.0, 1.5, side, YELLOW)
	for k in 10:
		var a := k * TAU / 10.0
		kit.turned_box(wheel_at + face * Vector3(0.0, sin(a) * 6.2, cos(a) * 6.2), Vector3(2.0, 1.2, 1.4), face * Basis(Vector3.RIGHT, -a), DARK_GREY, SceneryKit.SMOOTH)


static func rocket(kit: SceneryKit, at: Vector3, facing: int) -> void:
	kit.box(at, Vector3(14.0, 1.2, 14.0), LIGHT_GREY)
	var base := at + Vector3.UP * 1.2
	kit.cylinder(base + Vector3.UP * 1.0, 2.2, 24.0, WHITE, SceneryKit.SMOOTH, true)
	kit.cylinder(base + Vector3.UP * 10.0, 2.25, 0.8, BLACK, SceneryKit.SMOOTH)
	kit.cylinder(base + Vector3.UP * 18.0, 2.25, 0.5, RED, SceneryKit.SMOOTH)
	kit.cone(base + Vector3.UP * 25.0, 2.2, 5.0, WHITE, SceneryKit.SMOOTH)
	for k in 4:
		var a := k * PI * 0.5
		var out := Vector3(cos(a), 0.0, sin(a))
		kit.cylinder(base + out * 2.9, 0.9, 12.0, WHITE, SceneryKit.SMOOTH)
		kit.cone(base + out * 2.9 + Vector3.UP * 12.0, 0.9, 2.0, WHITE, SceneryKit.SMOOTH)
		kit.turned_box(base + out * 3.6 + Vector3.UP * 1.6, Vector3(0.2, 3.0, 2.0), Basis(Vector3.UP, -a), RED)
		kit.cone(base + out * 2.9 - Vector3.UP * 0.2, 0.7, 1.2, DARK_GREY)
	# The launch tower beside it, with an arm across.
	var tower_at := at + _turn(Vector3(-6.0, 1.2, 0.0), facing)
	for y in range(0, 30, 3):
		kit.box(tower_at + Vector3.UP * y, Vector3(3.0, 3.0, 3.0), RED if y % 6 == 0 else DARK_RED, SceneryKit.BRICK, y == 0)
	kit.box(tower_at + _turn(Vector3(2.6, 20.0, 0.0), facing), _turn_size(Vector3(3.0, 0.8, 1.2), facing), DARK_GREY, SceneryKit.SMOOTH, false)


static func radar(kit: SceneryKit, at: Vector3, facing: int) -> void:
	kit.box(at, Vector3(2.4, 3.0, 2.4), LIGHT_GREY)
	var face := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(55.0))
	kit.turned_cylinder(at + Vector3.UP * 4.5, 3.6, 0.4, face, WHITE)
	kit.turned_cylinder(at + Vector3.UP * 4.5 + face * Vector3(0.0, 1.2, 0.0), 0.2, 2.4, face, DARK_GREY)


static func volcano(kit: SceneryKit, at: Vector3) -> void:
	var y := 0.0
	for k in 9:
		var r := 38.0 - k * 3.8
		kit.cylinder(at + Vector3.UP * y, r, 3.0, DARK_GREY.darkened(0.1 * (k % 2)), SceneryKit.BRICK, k == 0)
		y += 3.0
	kit.cylinder(at + Vector3.UP * (y - 0.4), 5.0, 0.6, LAVA, SceneryKit.GLOW)
	# Lava running down two sides.
	for side in [Vector3(1, 0, 0.3), Vector3(-0.4, 0, 1)]:
		var dir: Vector3 = side.normalized()
		for k in 8:
			var r := 6.0 + k * 3.8
			kit.box(at + dir * r + Vector3.UP * (y - 3.0 - k * 3.0 + 0.1), Vector3(2.4, 3.1, 2.4), LAVA, SceneryKit.GLOW, false)


static func mountain(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var layers := 10 + rng.randi() % 4
	for k in layers:
		var f := 1.0 - float(k) / layers
		var r := 36.0 * f + 3.0
		var colour: Color = WHITE if k >= layers - 3 else [DARK_GREY, LIGHT_GREY.darkened(0.2)][k % 2]
		kit.box(at + Vector3(rng.randf_range(-1, 1), k * 3.0, rng.randf_range(-1, 1)), Vector3(r * 2.0, 3.0, r * 1.8), colour, SceneryKit.BRICK, k == 0)


static func castle(kit: SceneryKit, at: Vector3, facing: int) -> void:
	for corner in [Vector3(-12, 0, -10), Vector3(12, 0, -10), Vector3(-12, 0, 10), Vector3(12, 0, 10)]:
		tower(kit, at + corner, LIGHT_GREY)
	for side in [[Vector3(0, 0, -10), 0], [Vector3(0, 0, 10), 0], [Vector3(-12, 0, 0), 1], [Vector3(12, 0, 0), 1]]:
		castle_wall(kit, at + side[0], side[1])
	# The keep in the middle, with flags.
	kit.box(at, Vector3(10.0, 16.0, 9.0), DARK_GREY)
	for k in 5:
		kit.box(at + Vector3(-4.0 + k * 2.0, 16.0, 4.0), Vector3(1.0, 0.9, 1.0), DARK_GREY)
		kit.box(at + Vector3(-4.0 + k * 2.0, 16.0, -4.0), Vector3(1.0, 0.9, 1.0), DARK_GREY)
	kit.cylinder(at + Vector3.UP * 16.0, 0.12, 6.0, BROWN, SceneryKit.SMOOTH)
	kit.box(at + Vector3(1.0, 20.5, 0.0), Vector3(2.0, 1.2, 0.1), BLUE, SceneryKit.SMOOTH, false)
	kit.box(at + _turn(Vector3(0.0, 0.0, 10.5), facing), _turn_size(Vector3(3.0, 4.0, 0.3), facing), BROWN, SceneryKit.SMOOTH, false)


static func station(kit: SceneryKit, at: Vector3, facing: int) -> void:
	# A little railway station with a steam train waiting at the platform.
	_box(kit, at, Vector3(0.0, 0.0, -3.0), Vector3(26.0, 0.9, 4.0), facing, LIGHT_GREY)
	_box(kit, at, Vector3(0.0, 0.9, -4.0), Vector3(9.0, 3.6, 3.0), facing, TAN)
	_roof(kit, at + _turn(Vector3(0.0, 4.5, -4.0), facing), 9.0, 3.0, deg_to_rad(35.0), facing, DARK_RED)
	# The rails.
	for z in [0.7, 2.3]:
		_box(kit, at, Vector3(0.0, 0.0, z), Vector3(30.0, 0.2, 0.2), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	var face := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)
	var track := at + _turn(Vector3(0.0, 0.0, 1.5), facing)
	# The engine: a black boiler, a cab and a chimney.
	kit.turned_cylinder(track + _turn(Vector3(7.0, 2.0, 0.0), facing), 1.1, 6.0, face, BLACK)
	kit.box(track + _turn(Vector3(3.2, 0.3, 0.0), facing), _turn_size(Vector3(2.6, 3.6, 2.6), facing), BLACK)
	kit.box(track + _turn(Vector3(3.2, 3.9, 0.0), facing), _turn_size(Vector3(3.0, 0.3, 3.0), facing), RED, SceneryKit.SMOOTH, false)
	kit.cylinder(track + _turn(Vector3(9.0, 3.0, 0.0), facing), 0.35, 1.4, BLACK)
	kit.box(track + _turn(Vector3(6.5, 0.2, 0.0), facing), _turn_size(Vector3(8.0, 0.8, 2.2), facing), RED, SceneryKit.SMOOTH, false)
	# Two coaches.
	for k in 2:
		var x := -2.5 - k * 7.0
		kit.box(track + _turn(Vector3(x, 0.4, 0.0), facing), _turn_size(Vector3(6.4, 3.0, 2.6), facing), [GREEN, DARK_RED][k], SceneryKit.WINDOWS)
		kit.box(track + _turn(Vector3(x, 3.4, 0.0), facing), _turn_size(Vector3(6.6, 0.3, 2.8), facing), DARK_GREY, SceneryKit.SMOOTH, false)


static func stone_bridge(kit: SceneryKit, at: Vector3, facing: int) -> void:
	# An old stone bridge with three arches, over a river.
	_box(kit, at, Vector3.ZERO, Vector3(40.0, 0.06, 12.0), facing, WATER, SceneryKit.WATER, false)
	for k in 4:
		_box(kit, at, Vector3(-13.5 + k * 9.0, 0.0, 0.0), Vector3(2.0, 5.0, 4.0), facing, TAN)
	for k in 3:
		var x := -9.0 + k * 9.0
		_box(kit, at, Vector3(x, 4.0, 0.0), Vector3(7.0, 1.0, 4.0), facing, TAN, SceneryKit.BRICK, false)
		_box(kit, at, Vector3(x, 3.4, 0.0), Vector3(5.0, 0.6, 4.0), facing, TAN, SceneryKit.BRICK, false)
	_box(kit, at, Vector3(0.0, 5.0, 0.0), Vector3(30.0, 0.6, 4.0), facing, DARK_TAN, SceneryKit.BRICK, false)
	for z in [-1.8, 1.8]:
		_box(kit, at, Vector3(0.0, 5.6, z), Vector3(30.0, 0.9, 0.4), facing, TAN, SceneryKit.BRICK, false)


static func lighthouse(kit: SceneryKit, at: Vector3) -> void:
	for k in 6:
		kit.cylinder(at + Vector3.UP * k * 2.4, 2.0 - k * 0.12, 2.4, RED if k % 2 == 0 else WHITE, SceneryKit.BRICK, k == 0)
	kit.cylinder(at + Vector3.UP * 14.4, 1.2, 1.6, YELLOW, SceneryKit.GLOW)
	kit.cone(at + Vector3.UP * 16.0, 1.5, 1.8, DARK_GREY)


## A pagoda, red with wide dark roofs, a little smaller at each storey.
static func pagoda(kit: SceneryKit, at: Vector3) -> void:
	var y := 0.0
	for k in 4:
		var w := 7.0 - k * 1.3
		kit.box(at + Vector3.UP * y, Vector3(w - 1.6, 2.2, w - 1.6), RED, SceneryKit.BRICK, k == 0)
		kit.box(at + Vector3.UP * (y + 2.2), Vector3(w + 1.2, 0.3, w + 1.2), DARK_GREY, SceneryKit.SMOOTH, false)
		kit.box(at + Vector3.UP * (y + 2.5), Vector3(w - 0.6, 0.3, w - 0.6), DARK_GREY, SceneryKit.SMOOTH, false)
		y += 2.8
	kit.cylinder(at + Vector3.UP * y, 0.15, 3.0, YELLOW, SceneryKit.SMOOTH)


## A big Ferris wheel on an A frame, with cars in all sorts of colours
## around the rim. It stands side on to the way it faces.
static func ferris_wheel(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var radius := 14.0
	var hub := at + Vector3.UP * (radius + 2.0)
	var across := _turn(Vector3.RIGHT, facing)
	var axle := _turn(Vector3.BACK, facing)
	for side in [-1.0, 1.0]:
		for lean in [-1.0, 1.0]:
			var foot: Vector3 = at + axle * side * 2.5 + across * lean * 6.0
			var leg: Vector3 = hub + axle * side * 2.5 - foot
			kit.turned_box(foot + leg * 0.5, Vector3(0.5, leg.length(), 0.5), Basis(Quaternion(Vector3.UP, leg.normalized())), WHITE)
	kit.turned_cylinder(hub, 0.8, 6.0, Basis(Quaternion(Vector3.UP, axle)), LIGHT_GREY)
	var colours := [RED, YELLOW, BLUE, GREEN, ORANGE, AZURE, PINK, WHITE]
	var cars := 16
	for k in cars:
		var a := TAU * k / cars
		var out := across * cos(a) + Vector3.UP * sin(a)
		var tangent := across * -sin(a) + Vector3.UP * cos(a)
		# The rim, one straight piece to the next car, and a spoke to it.
		var chord := 2.0 * radius * sin(PI / cars)
		kit.turned_box(hub + out * radius * cos(PI / cars) + tangent * chord * 0.5, Vector3(0.4, chord, 0.4), Basis(Quaternion(Vector3.UP, tangent.normalized())), WHITE)
		kit.turned_box(hub + out * radius * 0.5, Vector3(0.2, radius, 0.2), Basis(Quaternion(Vector3.UP, out.normalized())), LIGHT_GREY)
		kit.box(hub + out * radius - Vector3.UP * 2.2, Vector3(1.6, 1.6, 1.6), colours[k % colours.size()], SceneryKit.SMOOTH, false)


## A stretch of steep old concrete banking, a quarter of a big circle, like
## the old oval that still stands in the park at Monza.
static func old_banking(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var radius := 42.0
	var pieces := 18
	for k in pieces:
		var a := PI * 0.5 * (k + 0.5) / pieces
		var out := _turn(Vector3(cos(a), 0.0, sin(a)), facing)
		var along := _turn(Vector3(-sin(a), 0.0, cos(a)), facing)
		var tilt := Basis(along, deg_to_rad(55.0))
		var face := Basis(along.cross(Vector3.UP).normalized(), Vector3.UP, along)
		kit.turned_box(at + out * radius + Vector3.UP * 3.5, Vector3(0.8, 10.0, radius * PI * 0.5 / pieces + 0.2), tilt * face, LIGHT_GREY if k % 2 == 0 else Color("#bcbcbc"))
		kit.box(at + out * (radius + 4.5), Vector3(1.2, 7.8, 1.2), DARK_GREY, SceneryKit.BRICK, false)


## A Kent oast house: a round brick kiln with a pointed roof and a white cowl
## on top, beside a white barn.
static func oast_house(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var kiln := at + _turn(Vector3(-3.0, 0.0, 0.0), facing)
	kit.cylinder(kiln, 2.4, 5.4, TERRACOTTA, SceneryKit.BRICK, true)
	kit.cone(kiln + Vector3.UP * 5.4, 2.7, 4.8, DARK_GREY)
	kit.cylinder(kiln + Vector3.UP * 9.6, 0.5, 1.2, WHITE, SceneryKit.SMOOTH)
	_box(kit, kiln, Vector3(0.0, 10.4, 0.5), Vector3(1.0, 1.0, 1.2), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(2.4, 0.0, 0.0), Vector3(6.0, 3.6, 4.4), facing, WHITE)
	_box(kit, at, Vector3(2.4, 0.9, 2.2), Vector3(1.6, 1.4, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
	_roof(kit, at + _turn(Vector3(2.4, 3.6, 0.0), facing), 6.0, 4.4, deg_to_rad(40.0), facing, DARK_GREY)


## A row of old standing stones, like the ones all over Brittany, each one
## a different height and leaning a little.
static func standing_stones(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 5:
		var h := 2.6 + rng.randf() * 2.8
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.BACK, rng.randf_range(-0.1, 0.1))
		var spot := at + Vector3((k - 2) * 2.6, h * 0.5 - 0.2, rng.randf_range(-0.6, 0.6))
		kit.turned_box(spot, Vector3(1.1, h, 0.8), lean, [LIGHT_GREY, DARK_GREY, Color("#8a8a86")][rng.randi() % 3], SceneryKit.BRICK)
	kit.box(at + Vector3(0.0, 0.0, 0.0), Vector3(12.0, 0.3, 2.0), OLIVE, SceneryKit.BRICK, false)


## An airport control tower, a tall grey shaft with a glass room on top.
static func control_tower(kit: SceneryKit, at: Vector3, facing: int) -> void:
	kit.box(at, Vector3(3.0, 13.0, 3.0), LIGHT_GREY)
	kit.box(at + Vector3.UP * 13.0, Vector3(5.2, 0.4, 5.2), DARK_GREY, SceneryKit.SMOOTH, false)
	kit.box(at + Vector3.UP * 13.4, Vector3(4.8, 2.4, 4.8), GLASS, SceneryKit.WINDOWS, false)
	kit.box(at + Vector3.UP * 15.8, Vector3(5.4, 0.4, 5.4), WHITE, SceneryKit.SMOOTH, false)
	kit.cylinder(at + _turn(Vector3(1.4, 16.2, 1.4), facing), 0.12, 3.0, RED, SceneryKit.SMOOTH)
	kit.cylinder(at + _turn(Vector3(1.4, 19.2, 1.4), facing), 0.3, 0.4, RED, SceneryKit.GLOW)


## A grassy bank covered in people watching, the way rallycross crowds stand
## on the hillsides. It steps up away from the track.
static func spectator_bank(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var across := 22.0
	var steps := 4
	for k in steps:
		_box(kit, at, Vector3(0.0, 0.0, -k * 1.8), Vector3(across - k * 1.2, 0.9 + k * 0.9, 1.8), facing, BRIGHT_GREEN if k % 2 == 0 else GREEN)
		# A row of people along the top of each step.
		var x := -across * 0.5 + 1.0
		while x < across * 0.5 - 1.0 - k * 0.6:
			if rng.randf() < 0.75:
				var coat: Color = [RED, BLUE, YELLOW, WHITE, ORANGE, GREEN, DARK_BLUE, AZURE][rng.randi() % 8]
				_box(kit, at, Vector3(x, 0.9 + k * 0.9, -k * 1.8 + rng.randf_range(-0.3, 0.3)), Vector3(0.5, 0.9, 0.4), facing, coat, SceneryKit.SMOOTH, false)
				_box(kit, at, Vector3(x, 1.8 + k * 0.9, -k * 1.8), Vector3(0.36, 0.36, 0.36), facing, YELLOW, SceneryKit.SMOOTH, false)
			x += rng.randf_range(0.8, 1.4)


# Things along the side of the track.

## A stack of old tires in a barrier, three tires high and soft to hit.
static func barrier_stack(kit: SceneryKit, at: Vector3, top: Color) -> void:
	for k in 3:
		kit.cylinder(at + Vector3.UP * k * 0.28, 0.38, 0.28, top if k == 2 else BLACK, SceneryKit.SMOOTH)
	kit.soft_box(Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.42), Vector3(0.7, 0.84, 0.7))


static func tire_stack(kit: SceneryKit, at: Vector3, top: Color) -> void:
	for k in 4:
		kit.cylinder(at + Vector3.UP * k * 0.28, 0.38, 0.28, top if k == 3 else BLACK, SceneryKit.SMOOTH, k == 0)


static func grandstand(kit: SceneryKit, at: Vector3, length: float, facing: int, rng: RandomNumberGenerator) -> void:
	var rows := 5
	for r in rows:
		_box(kit, at, Vector3(0.0, 0.0, -r * 1.1), Vector3(length, 0.9 + r * 0.9, 1.1), facing, LIGHT_GREY if r % 2 == 0 else Color("#bcbcbc"))
		# The crowd, as heads and shirts in all sorts of colours.
		var shirts := [RED, BLUE, YELLOW, GREEN, WHITE, ORANGE, PINK, AZURE]
		var x := -length * 0.5 + 0.6
		while x < length * 0.5 - 0.4:
			if rng.randf() < 0.75:
				var seat := Vector3(x, 0.9 + r * 0.9, -r * 1.1)
				_box(kit, at, seat, Vector3(0.5, 0.5, 0.35), facing, shirts[rng.randi() % shirts.size()], SceneryKit.SMOOTH, false)
				_box(kit, at, seat + Vector3.UP * 0.5, Vector3(0.3, 0.3, 0.3), facing, YELLOW, SceneryKit.SMOOTH, false)
			x += 0.8
	# A roof on posts, in a team colour.
	for x in [-length * 0.5, 0.0, length * 0.5]:
		_box(kit, at, Vector3(x, 0.0, -rows * 1.1 - 0.3), Vector3(0.4, 8.0, 0.4), facing, WHITE)
	_box(kit, at, Vector3(0.0, 8.0, -rows * 0.55), Vector3(length + 1.0, 0.4, rows * 1.1 + 1.6), facing, RED, SceneryKit.SMOOTH, false)


static func pit_building(kit: SceneryKit, at: Vector3, length: float, facing: int) -> void:
	var depth := 7.0
	_box(kit, at, Vector3(0.0, 0.0, -depth * 0.5), Vector3(length, 4.2, depth), facing, WHITE)
	var colours := [RED, BLUE, YELLOW, GREEN, ORANGE, DARK_BLUE]
	var doors := int(length / 5.0)
	for k in doors:
		var x := -length * 0.5 + 2.5 + k * 5.0
		_box(kit, at, Vector3(x, 0.0, 0.02), Vector3(4.0, 3.2, 0.1), facing, DARK_GREY, SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(x, 3.4, 0.02), Vector3(4.0, 0.6, 0.1), facing, colours[k % colours.size()], SceneryKit.SMOOTH, false)
	# The race control tower on one end, all windows.
	_box(kit, at, Vector3(length * 0.5 - 3.0, 4.2, -depth * 0.5), Vector3(6.0, 5.0, depth), facing, LIGHT_GREY, SceneryKit.WINDOWS)
	_box(kit, at, Vector3(length * 0.5 - 3.0, 9.2, -depth * 0.5), Vector3(6.6, 0.4, depth + 0.6), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 4.2, 0.2), Vector3(length, 0.9, 0.3), facing, BLUE, SceneryKit.SMOOTH, false)


static func billboard(kit: SceneryKit, at: Vector3, facing: int, colour: Color) -> void:
	for x in [-2.5, 2.5]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(0.3, 2.0, 0.3), facing, LIGHT_GREY)
	_box(kit, at, Vector3(0.0, 2.0, 0.0), Vector3(6.4, 2.4, 0.3), facing, colour, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(-0.8, 2.6, 0.18), Vector3(3.6, 0.5, 0.05), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.4, 3.4, 0.18), Vector3(4.6, 0.35, 0.05), facing, WHITE, SceneryKit.SMOOTH, false)


static func flag(kit: SceneryKit, at: Vector3, colour: Color) -> void:
	kit.cylinder(at, 0.08, 6.0, WHITE, SceneryKit.SMOOTH, true)
	kit.box(at + Vector3(0.8, 4.8, 0.0), Vector3(1.6, 1.0, 0.06), colour, SceneryKit.SMOOTH, false)


static func marshal_post(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(1.6, 2.4, 1.6), facing, WHITE)
	_box(kit, at, Vector3(0.0, 2.4, 0.0), Vector3(2.0, 0.3, 2.0), facing, ORANGE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 1.2, 0.81), Vector3(1.0, 0.7, 0.05), facing, GLASS, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.9, 2.7, 0.0), Vector3(0.06, 1.4, 0.06), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(1.3, 3.5, 0.0), Vector3(0.8, 0.5, 0.04), facing, YELLOW, SceneryKit.SMOOTH, false)
