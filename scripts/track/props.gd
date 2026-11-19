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
## How tall a lamp post is, and how far its arm reaches.
const LAMP_HEIGHT := 10.0
const LAMP_REACH := 3.0
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
	"snowy_pine": 2.5, "maple": 2.8, "birch": 2.0, "bush": 1.2, "tree_clump": 5.0, "hedge_row": 4.8, "rocks": 2.0, "reeds": 1.5, "snowman": 1.0,
	"hay": 1.2, "house": 5.0, "barn": 7.5, "silo": 3.0, "villa": 6.0, "trullo": 3.5, "cottage": 5.0,
	"cabin": 4.5, "factory": 12.0, "chimney": 2.5, "containers": 5.5, "tanks": 6.0, "crane": 5.0,
	"skyscraper": 9.0, "dune": 9.0, "tower": 4.0, "castle_wall": 8.0, "church": 7.0, "stilt_hut": 4.0,
	"windmill": 4.5, "wind_turbine": 4.0, "fence": 3.0, "tent": 3.5, "ruins": 5.0, "cactus": 1.2,
	"headframe": 9.0, "slag_heap": 14.0, "excavator": 22.0, "rocket": 14.0, "radar": 5.0,
	"volcano": 45.0, "mountain": 40.0, "castle": 26.0, "station": 14.0, "bridge": 16.0,
	"lake": 20.0, "pond": 9.0, "lava_pool": 7.0, "lighthouse": 4.0, "big_windmill": 6.0,
	"sakura": 2.5, "pagoda": 6.0, "ferris_wheel": 16.0, "old_banking": 48.0,
	"oast_house": 7.0, "standing_stones": 7.0, "control_tower": 5.0, "spectator_bank": 13.0,
	"tire_pile": 3.0, "kart_row": 8.0, "viewing_deck": 12.0, "pallets": 2.5, "kart_office": 7.0,
	"carousel": 7.0, "drop_tower": 5.0, "red_roof": 40.0,
	"parasols": 2.8, "beach_hut": 2.2, "lifeguard_tower": 2.4, "windsurf": 1.6, "beach_hotel": 10.0,
	"sandcastle": 7.0, "harbour_fort": 12.0, "penguins": 1.6, "stone_pine": 3.0, "gum_tree": 2.6,
	"watchtower": 3.0, "lamp_post": 1.0, "grandstand": 14.0, "pit_building": 14.0, "billboard": 3.2, "marshal_post": 2.0,
	"flag": 1.0, "fans": 3.0, "tire_stack": 1.0, "barrier_stack": 1.0, "boats": 6.0,
	"chalet": 6.0, "snowy_chalet": 6.0, "alpine_church": 8.0, "cows": 2.8, "snowy_peak": 40.0,
	"cable_car": 45.0, "ski_jump": 33.0,
	"mesa": 38.0, "butte": 16.0, "saloon": 8.0, "water_tower": 3.5, "saguaro": 1.6, "mine_carts": 8.0,
	"windpump": 3.0, "red_rocks": 2.4,
	"jungle_tree": 3.0, "jungle_sapling": 1.6, "jungle_bush": 1.6, "fern": 1.2, "parrots": 1.6, "stepped_pyramid": 17.5, "stone_head": 4.6,
	"waterfall": 14.0, "rope_bridge": 18.0, "canopy_walk": 15.0, "karst": 13.0, "jungle_hut": 5.0,
	"city_block": 7.5, "townhouses": 7.0, "traffic_light": 1.2, "neon_sign": 2.6, "street_tree": 1.4, "armco": 3.4,
	"phone_box": 1.0, "double_decker": 5.6, "tuk_tuk": 2.0, "neon_tower": 9.0, "lantern_gate": 5.0,
	"tunnel_mouth": 13.0, "spire_tower": 10.5, "clock_tower": 5.0, "overpass": 17.0, "chedi": 7.5,
	"hot_air_balloon": 5.0, "airship": 14.0, "falls_isle": 16.0, "rainbow": 17.0, "weather_vane": 7.0,
	"windmill_isle": 9.0, "sky_lighthouse": 8.0, "sky_dock": 14.0, "sky_isle": 6.0, "cloud_puff": 6.0,
}
## Props that sit all or mostly under the road, so they only suit courses up
## in the sky.
const BELOW_ROAD := ["falls_isle", "rainbow", "weather_vane", "windmill_isle", "sky_lighthouse", "sky_dock", "sky_isle", "cloud_puff"]
## Props built well above or below where they stand. The editor picks these
## by the middle of what's built, instead of just above the ground.
const OFF_THE_GROUND := BELOW_ROAD + ["hot_air_balloon", "airship"]
## How far below where they stand these sky props reach, so islands keep out
## of them. Any other reaches 25 m down.
const DEPTH := {"falls_isle": 38.0}


## Props that reach over the road, so they may be put on it when none of
## their solid parts is near the road: the cable car and rope bridge put
## across the road, and the canopy walk at 1.5 times its size or more.
const SPANNING := ["canopy_walk", "cable_car", "rope_bridge"]
## Landmarks turn in steps of this many degrees, and come in these sizes.
const TURN_STEP := 15
## Their deep water is drawn as straight rectangles, so these only turn in quarters.
const QUARTER_ONLY := ["lake", "pond"]
const SCALES := [0.5, 0.75, 1.0, 1.5, 2.0]


## Whether the solid parts of a placed landmark, as turned and sized, come
## within `clear` metres of any of the road's `points` (x and z are used).
static func solid_near(mark: Dictionary, points: PackedVector3Array, clear: float) -> bool:
	var kit := SceneryKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var at := Vector3(float(mark.at[0]), 0.0, float(mark.at[1]))
	add_mark(kit, mark, at, rng)
	for solid in kit.solids:
		var where: Transform3D = solid[0]
		var half: Vector3 = solid[1] * 0.5
		var back := where.affine_inverse()
		for p: Vector3 in points:
			var local := back * Vector3(p.x, where.origin.y, p.z)
			var out := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.z) - half.z, 0.0))
			if out.length() < clear:
				return true
	return false


## The room a placed landmark takes, with its size setting.
static func room_of(mark: Dictionary) -> float:
	return float(ROOM.get(mark.get("prop", ""), 3.0)) * float(mark.get("scale", 1.0))


## How far a placed landmark is turned, in degrees. Old ones only have
## quarter turns in "facing".
static func angle_of(mark: Dictionary) -> int:
	if mark.get("prop", "") in QUARTER_ONLY:
		return posmod(roundi(float(mark.get("angle", int(mark.get("facing", 0)) * 90)) / 90.0), 4) * 90
	if mark.has("angle"):
		return posmod(int(mark.angle), 360)
	return posmod(int(mark.get("facing", 0)), 4) * 90


## Builds a placed landmark: turned by its angle and scaled by its size
## setting about where it stands. Quarter turns go through `facing` as usual
## and the rest is turned afterwards.
static func add_mark(kit: SceneryKit, mark: Dictionary, at: Vector3, rng: RandomNumberGenerator) -> void:
	var angle := angle_of(mark)
	var facing := posmod(roundi(angle / 90.0), 4)
	var extra := deg_to_rad(angle - roundi(angle / 90.0) * 90)
	var grown := float(mark.get("scale", 1.0))
	var prop := str(mark.get("prop", ""))
	if is_zero_approx(extra) and is_equal_approx(grown, 1.0):
		add(kit, prop, at, rng, facing)
		return
	var counts := [kit.boxes.size(), kit.cylinders.size(), kit.cones.size(), kit.balls.size(), kit.solids.size(), kit.soft.size(), kit.movers.size(), kit.fans.size()]
	add(kit, prop, at, rng, facing)
	var turn := Basis(Vector3.UP, extra)
	var pivot := Vector3(snappedf(at.x, 0.5), at.y, snappedf(at.z, 0.5))
	var whole := Transform3D(turn.scaled(Vector3.ONE * grown), pivot - turn.scaled(Vector3.ONE * grown) * pivot)
	var lists := [kit.boxes, kit.cylinders, kit.cones, kit.balls, kit.solids, kit.soft]
	var follows := prop == "tree_clump" and kit.ground.is_valid()
	for k in lists.size():
		for i in range(counts[k], lists[k].size()):
			var entry: Array = lists[k][i]
			var was: Vector3 = entry[0].origin
			if k >= 4:
				var where: Transform3D = entry[0]
				entry[0] = Transform3D(turn * where.basis, pivot + turn * (where.origin - pivot) * grown)
				entry[1] = entry[1] * grown
			else:
				entry[0] = whole * entry[0]
			if follows:
				# Trees stand on the ground at their new spot.
				var now: Vector3 = entry[0].origin
				entry[0].origin.y += kit.ground.call(now.x, now.z) - kit.ground.call(was.x, was.z)
	for i in range(counts[6], kit.movers.size()):
		kit.movers[i].pivot = whole * kit.movers[i].pivot
	for i in range(counts[7], kit.fans.size()):
		kit.fans[i][0] = whole * kit.fans[i][0]


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
		"bush": bush(kit, at_grid, rng)
		"rocks": rocks(kit, at_grid, rng)
		"reeds": reeds(kit, at_grid, rng)
		"snowman": snowman(kit, at_grid)
		"hay": hay(kit, at_grid)
		"tree_clump": tree_clump(kit, at_grid)
		"hedge_row": hedge_row(kit, at_grid, facing, rng)
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
		"tire_pile": tire_pile(kit, at_grid, rng)
		"kart_row": kart_row(kit, at_grid, facing, rng)
		"viewing_deck": viewing_deck(kit, at_grid, facing, rng)
		"pallets": pallets(kit, at_grid, rng)
		"kart_office": kart_office(kit, at_grid, facing)
		"carousel": carousel(kit, at_grid, rng)
		"drop_tower": drop_tower(kit, at_grid)
		"red_roof": red_roof(kit, at_grid)
		"parasols": parasols(kit, at_grid, rng)
		"beach_hut": beach_hut(kit, at_grid, facing, rng)
		"lifeguard_tower": lifeguard_tower(kit, at_grid, facing)
		"windsurf": windsurf(kit, at_grid, rng)
		"beach_hotel": beach_hotel(kit, at_grid, facing, rng)
		"sandcastle": sandcastle(kit, at_grid)
		"harbour_fort": harbour_fort(kit, at_grid, facing)
		"penguins": penguins(kit, at_grid, rng)
		"stone_pine": stone_pine(kit, at_grid, rng)
		"gum_tree": broadleaf(kit, at_grid, rng, [SAND_GREEN, OLIVE][rng.randi() % 2])
		"watchtower": tower(kit, at_grid, TAN)
		"chalet": chalet(kit, at_grid, facing, rng, false)
		"snowy_chalet": chalet(kit, at_grid, facing, rng, true)
		"alpine_church": alpine_church(kit, at_grid, facing)
		"cows": cows(kit, at_grid, rng)
		"snowy_peak": snowy_peak(kit, at_grid, rng, 1.0, true)
		"cable_car": cable_car(kit, at_grid, facing)
		"ski_jump": ski_jump(kit, at_grid, facing)
		"mesa": mesa(kit, at_grid, rng, 1.0, true)
		"butte": butte(kit, at_grid, rng, 1.0, true)
		"saloon": saloon(kit, at_grid, facing, rng)
		"water_tower": water_tower(kit, at_grid)
		"saguaro": saguaro(kit, at_grid, rng)
		"mine_carts": mine_carts(kit, at_grid, facing, rng)
		"windpump": windpump(kit, at_grid, facing)
		"red_rocks": red_rocks(kit, at_grid, rng)
		"jungle_tree": jungle_tree(kit, at_grid, rng)
		"jungle_sapling": jungle_sapling(kit, at_grid, rng)
		"jungle_bush": jungle_bush(kit, at_grid, rng)
		"fern": fern(kit, at_grid, rng)
		"parrots": parrots(kit, at_grid, facing, rng)
		"stepped_pyramid": stepped_pyramid(kit, at_grid, facing, rng)
		"stone_head": stone_head(kit, at_grid, facing, rng)
		"waterfall": waterfall(kit, at_grid, facing, rng)
		"rope_bridge": rope_bridge(kit, at_grid, facing, rng)
		"canopy_walk": canopy_walk(kit, at_grid, facing, rng)
		"karst": karst(kit, at_grid, rng, 1.0, true)
		"jungle_hut": jungle_hut(kit, at_grid, facing, rng)
		"city_block": city_block(kit, at_grid, facing, rng)
		"townhouses": townhouses(kit, at_grid, facing, rng)
		"traffic_light": traffic_light(kit, at_grid, facing)
		"neon_sign": neon_sign(kit, at_grid, facing, rng)
		"street_tree": street_tree(kit, at_grid, rng)
		"armco": armco(kit, at_grid, facing)
		"phone_box": phone_box(kit, at_grid, facing)
		"double_decker": double_decker(kit, at_grid, facing)
		"tuk_tuk": tuk_tuk(kit, at_grid, facing, rng)
		"neon_tower": neon_tower(kit, at_grid, facing, rng)
		"lantern_gate": lantern_gate(kit, at_grid, facing)
		"tunnel_mouth": tunnel_mouth(kit, at_grid, facing)
		"spire_tower": spire_tower(kit, at_grid, rng, 1.0, true)
		"clock_tower": clock_tower(kit, at_grid, facing)
		"overpass": overpass(kit, at_grid, facing)
		"chedi": chedi(kit, at_grid)
		"hot_air_balloon": hot_air_balloon(kit, at_grid, rng, rng.randf_range(6.0, 22.0))
		"airship": airship(kit, at_grid, facing, rng, rng.randf_range(14.0, 24.0))
		"falls_isle": falls_isle(kit, at_grid, rng)
		"rainbow": rainbow(kit, at_grid, facing, rng)
		"weather_vane": weather_vane(kit, at_grid, facing, rng)
		"windmill_isle": windmill_isle(kit, at_grid, facing, rng)
		"sky_lighthouse": sky_lighthouse(kit, at_grid, rng)
		"sky_dock": sky_dock(kit, at_grid, facing, rng)
		"sky_isle": sky_isle(kit, at_grid, rng)
		"cloud_puff": cloud_puff(kit, at_grid, rng)
		"grandstand": grandstand(kit, at_grid, 24.0, facing, rng)
		"pit_building": pit_building(kit, at_grid, 24.0, facing)
		"billboard": billboard(kit, at_grid, facing, [RED, BLUE, YELLOW, GREEN, WHITE][rng.randi() % 5])
		"marshal_post": marshal_post(kit, at_grid, facing)
		"flag": flag(kit, at_grid, [RED, YELLOW, BLUE, GREEN][rng.randi() % 4])
		"lamp_post": lamp_post(kit, at_grid, facing)
		"fans": fan_line(kit, at_grid, facing, rng)
		"tire_stack": tire_stack(kit, at_grid, [RED, WHITE, BLUE][rng.randi() % 3])
		"barrier_stack": barrier_stack(kit, at_grid, [RED, WHITE, BLUE][rng.randi() % 3])
		"boats":
			boat(kit, at_grid + _turn(Vector3(-2.2, 0.0, 0.0), facing), facing * PI * 0.5, rng)
			boat(kit, at_grid + _turn(Vector3(2.2, 0.0, 1.0), facing), facing * PI * 0.5 + 0.2, rng)


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
static func _roof(kit: SceneryKit, top: Vector3, width: float, depth: float, pitch: float, facing: int, colour: Color, gables := true) -> void:
	var half := depth * 0.5 + 0.3
	var slope := half / cos(pitch)
	var rise := half * tan(pitch)
	for side in [-1.0, 1.0]:
		var tilt := Basis(Vector3.RIGHT, side * pitch)
		var centre := Vector3(0.0, rise * 0.5, side * half * 0.5)
		# The same quarter turns as _turn(), so the slopes meet at the ridge.
		var basis := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5) * tilt
		kit.turned_box(top + _turn(centre, facing), Vector3(width + 0.6, 0.25, slope), basis, colour, SceneryKit.SMOOTH)
	if not gables:
		return
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


static func bush(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	kit.box(at, Vector3(1.5, 1.2, 1.5), [GREEN, BRIGHT_GREEN, OLIVE][rng.randi() % 3], SceneryKit.BRICK, false)


static func hay(kit: SceneryKit, at: Vector3) -> void:
	kit.turned_cylinder(at + Vector3.UP * 0.6, 0.6, 1.2, Basis(Vector3.BACK, PI * 0.5), TAN, SceneryKit.BRICK)


## The trees a clump can have, picked at random.
const CLUMP_TREES := ["broadleaf", "broadleaf", "birch", "pine", "maple"]


## Three to five mixed trees close together. Its own seed comes from where
## it stands, so a clump looks the same every time and for everyone online.
## When it's breakable each tree comes down on its own. The trees sit a
## little low so they don't float on a slope, and each stands on the ground
## under it when the kit knows the ground.
static func tree_clump(kit: SceneryKit, at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(roundf(at.x * 2.0)) * 73856093 ^ int(roundf(at.z * 2.0)) * 19349663
	var count := 3 + rng.randi() % 3
	var turn := rng.randf() * TAU
	for k in count:
		var a := turn + k * TAU / count + rng.randf_range(-0.4, 0.4)
		var r := 0.0 if k == 0 and count > 3 else rng.randf_range(1.8, 3.2)
		var spot := Vector3(snappedf(cos(a) * r, 0.5), -0.3, snappedf(sin(a) * r, 0.5)) + at
		if kit.ground.is_valid():
			spot.y = kit.ground.call(spot.x, spot.z) - 0.3
		var tree: String = CLUMP_TREES[rng.randi() % CLUMP_TREES.size()]
		if kit.breaking():
			kit.begin(tree, true)
		match tree:
			"birch": birch(kit, spot, rng)
			"pine": pine(kit, spot, rng, false)
			"maple": broadleaf(kit, spot, rng, [RED, ORANGE][rng.randi() % 2])
			_: broadleaf(kit, spot, rng, [GREEN, BRIGHT_GREEN][rng.randi() % 2])


## A straight line of six bushes, running across its facing. When it's
## breakable each bush comes down on its own.
static func hedge_row(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	for k in 6:
		if kit.breaking():
			kit.begin("bush", true)
		var spot := at + _turn(Vector3((k - 2.5) * 1.45, 0.0, 0.0), facing)
		var high := 1.2 + rng.randf() * 0.3
		kit.box(spot, Vector3(1.5, high, 1.5), [GREEN, GREEN, BRIGHT_GREEN][rng.randi() % 3], SceneryKit.BRICK, false)


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
	# The jib swings slowly to and fro.
	kit.begin_mover(Transform3D(Basis.IDENTITY, at + Vector3.UP * 22.0), { "swing": Vector3.UP, "angle": 0.4, "rate": 0.15 })
	_box(kit, at, Vector3(4.0, 22.0, 0.0), Vector3(16.0, 1.0, 1.0), facing, YELLOW)
	_box(kit, at, Vector3(-4.5, 21.0, 0.0), Vector3(3.0, 1.5, 2.0), facing, DARK_GREY)
	_box(kit, at, Vector3(10.0, 12.0, 0.0), Vector3(0.1, 10.0, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)
	kit.end_mover()


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
	# The sails turn slowly in the wind.
	kit.begin_mover(Transform3D(face, hub), { "spin": Vector3.BACK, "speed": 0.5 })
	for k in 4:
		var blade := face * Basis(Vector3.BACK, k * PI * 0.5 + 0.4)
		kit.turned_box(hub + blade * Vector3(0.0, 2.6 * scale, 0.0), Vector3(1.0 * scale, 5.2 * scale, 0.1), blade, WHITE)
		kit.turned_box(hub + blade * Vector3(0.0, 2.6 * scale, 0.05), Vector3(0.15, 5.2 * scale, 0.12), blade, BROWN)
	kit.end_mover()


static func wind_turbine(kit: SceneryKit, at: Vector3, facing: int) -> void:
	kit.cylinder(at, 0.7, 26.0, WHITE, SceneryKit.SMOOTH, true)
	var face := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5)
	kit.turned_box(at + Vector3.UP * 26.5, Vector3(1.4, 1.4, 3.5), face, WHITE)
	var hub := at + Vector3.UP * 26.5 + face * Vector3(0.0, 0.0, 1.9)
	kit.begin_mover(Transform3D(face, hub), { "spin": Vector3.BACK, "speed": 0.9 })
	for k in 3:
		var blade := face * Basis(Vector3.BACK, k * TAU / 3.0)
		kit.turned_box(hub + blade * Vector3(0.0, 5.5, 0.0), Vector3(0.9, 11.0, 0.2), blade, WHITE)
	kit.end_mover()


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
	# The dish sweeps round.
	kit.begin_mover(Transform3D(Basis.IDENTITY, at + Vector3.UP * 4.5), { "spin": Vector3.UP, "speed": 0.7 })
	kit.turned_cylinder(at + Vector3.UP * 4.5, 3.6, 0.4, face, WHITE)
	kit.turned_cylinder(at + Vector3.UP * 4.5 + face * Vector3(0.0, 1.2, 0.0), 0.2, 2.4, face, DARK_GREY)
	kit.end_mover()


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


## A floating island of rock with a grass top at `top`, about `radius`
## across. Its rock narrows in steps to a point underneath. Bigger ones can
## have trees, and a stream that pours off the edge. None of it is solid.
static func floating_island(kit: SceneryKit, top: Vector3, radius: float, rng: RandomNumberGenerator, trees: int, waterfall: bool) -> void:
	var grass: Color = [BRIGHT_GREEN, GREEN, LIME][rng.randi() % 3]
	var turf := clampf(radius * 0.1, 0.4, 0.8)
	var soil := clampf(radius * 0.12, 0.5, 1.2)
	kit.cylinder(top - Vector3.UP * turf, radius, turf, grass, SceneryKit.PLAIN)
	kit.cylinder(top - Vector3.UP * (turf + soil), radius * 0.97, soil, BROWN, SceneryKit.PLAIN)
	# Rock in steps, each a bit narrower and nudged to one side so it looks
	# lumpy, then a point.
	var y := top.y - turf - soil
	var middle := Vector3(top.x, 0.0, top.z)
	var r := radius * 0.9
	for k in 3:
		var h := radius * (0.32 - k * 0.04) + 0.3
		middle += Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * radius * 0.06
		kit.cylinder(Vector3(middle.x, y - h, middle.z), r, h, [DARK_TAN, LIGHT_GREY, DARK_GREY][k], SceneryKit.PLAIN)
		y -= h
		r *= 0.68
	var point := radius * 0.55 + 1.0
	kit.turned_cone(Vector3(middle.x, y - point * 0.5, middle.z), r * 1.3, point, Basis(Vector3.RIGHT, PI), DARK_GREY)
	# A couple of boulders sticking out of the sides.
	for k in 2:
		var a := rng.randf() * TAU
		var size := radius * rng.randf_range(0.25, 0.4)
		var out := Vector3(cos(a), 0.0, sin(a)) * radius * 0.7
		var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.3, 0.7))
		kit.turned_box(top + out - Vector3.UP * (turf + soil + size * 0.7), Vector3.ONE * size, tilt, LIGHT_GREY if k == 0 else DARK_TAN, SceneryKit.PLAIN)
	for k in trees:
		var a := rng.randf() * TAU
		var spot := top + Vector3(cos(a), 0.0, sin(a)) * radius * rng.randf_range(0.1, 0.6)
		if rng.randf() < 0.5:
			pine(kit, spot, rng, false)
		else:
			broadleaf(kit, spot, rng, [GREEN, BRIGHT_GREEN][rng.randi() % 2])
	if waterfall:
		# A wide stream across the top to the edge, then a sheet of water
		# down past the bottom, thinning out as it goes, with spray where it
		# comes over the edge.
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var facing := Basis(Vector3.UP, atan2(out.x, out.z))
		var wide := clampf(radius * 0.45, 2.5, 4.5)
		kit.turned_box(top + out * radius * 0.5 + Vector3.UP * 0.03, Vector3(wide * 0.8, 0.1, radius), facing, WATER, SceneryKit.WATER)
		var fall := radius * 1.6 + 6.0
		# Flattened round columns, so the water looks as wide from the side.
		kit.stretched("cylinders", top + out * (radius + wide * 0.2) - Vector3.UP * fall * 0.5, Vector3(wide, fall, wide * 0.45), facing, WATER.lightened(0.25), SceneryKit.WATER)
		kit.stretched("cylinders", top + out * (radius + wide * 0.25) - Vector3.UP * (fall + 4.0), Vector3(wide * 0.75, 8.0, wide * 0.3), facing, WATER.lightened(0.5), SceneryKit.WATER)
		var across := facing * Vector3.RIGHT
		for k in 3:
			var x := (k - 1) * wide * 0.35
			kit.ball(top + out * (radius + wide * 0.2) + across * x - Vector3.UP * 0.4, Vector3(wide * 0.6, 2.0, wide * 0.6), facing, WHITE)


## A puffy cloud of flat round white blobs, about `size` across, centred on
## `at`.
static func cloud(kit: SceneryKit, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var blobs := 3 + rng.randi() % 3
	for k in blobs:
		var r := size * rng.randf_range(0.25, 0.45)
		var off := Vector3(rng.randf_range(-0.5, 0.5) * size, 0.0, rng.randf_range(-0.3, 0.3) * size)
		var h := r * rng.randf_range(0.35, 0.5)
		kit.cylinder(at + off - Vector3.UP * h * 0.5, r, h, WHITE, SceneryKit.PLAIN)
		# A smaller puff on top, so it rounds off.
		kit.cylinder(at + off + Vector3.UP * h * 0.5, r * 0.65, h * 0.6, WHITE, SceneryKit.PLAIN)


static func lighthouse(kit: SceneryKit, at: Vector3) -> void:
	for k in 6:
		kit.cylinder(at + Vector3.UP * k * 2.4, 2.0 - k * 0.12, 2.4, RED if k % 2 == 0 else WHITE, SceneryKit.BRICK, k == 0)
	kit.cylinder(at + Vector3.UP * 14.4, 1.2, 1.6, YELLOW, SceneryKit.GLOW)
	kit.cone(at + Vector3.UP * 16.0, 1.5, 1.8, DARK_GREY)


## A lamp post beside the road: a tall grey pole with an arm reaching out
## over the runoff toward the road and a lamp on the end, which lights up when
## it's dark. Returns where the lamp is.
static func lamp_post(kit: SceneryKit, at: Vector3, facing: int) -> Vector3:
	kit.cylinder(at, 0.16, LAMP_HEIGHT, LIGHT_GREY, SceneryKit.SMOOTH, true)
	_box(kit, at, Vector3(0.0, LAMP_HEIGHT - 0.2, LAMP_REACH * 0.5), Vector3(0.18, 0.18, LAMP_REACH), facing, LIGHT_GREY, SceneryKit.SMOOTH, false)
	var head := at + _turn(Vector3(0.0, LAMP_HEIGHT - 0.45, LAMP_REACH), facing)
	_box(kit, head - Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3(0.8, 0.25, 1.3), facing, Color("#fff1d6"), SceneryKit.LAMP, false)
	return head


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
	# The wheel goes slowly round.
	kit.begin_mover(Transform3D(Basis.IDENTITY, hub), { "spin": axle, "speed": 0.12 })
	for k in cars:
		var a := TAU * k / cars
		var out := across * cos(a) + Vector3.UP * sin(a)
		var tangent := across * -sin(a) + Vector3.UP * cos(a)
		# The rim, one straight piece to the next car, and a spoke to it.
		var chord := 2.0 * radius * sin(PI / cars)
		kit.turned_box(hub + out * radius * cos(PI / cars) + tangent * chord * 0.5, Vector3(0.4, chord, 0.4), Basis(Quaternion(Vector3.UP, tangent.normalized())), WHITE)
		kit.turned_box(hub + out * radius * 0.5, Vector3(0.2, radius, 0.2), Basis(Quaternion(Vector3.UP, out.normalized())), LIGHT_GREY)
		kit.box(hub + out * radius - Vector3.UP * 2.2, Vector3(1.6, 1.6, 1.6), colours[k % colours.size()], SceneryKit.SMOOTH, false)
	kit.end_mover()


## A stretch of steep old concrete banking, a quarter of a big circle, like
## an old oval left standing in a park.
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
				fan(kit, at, Vector3(x, 0.9 + k * 0.9, -k * 1.8 + rng.randf_range(-0.3, 0.3)), facing, rng)
			x += rng.randf_range(0.8, 1.4)
	kit.new_crowd()


# Things inside an indoor kart hall.

## A heap of old tires, stacks of different heights leaning together.
static func tire_pile(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 5:
		var spot := at + Vector3(rng.randf_range(-1.6, 1.6), 0.0, rng.randf_range(-1.6, 1.6)).snapped(Vector3.ONE * 0.8)
		for level in rng.randi_range(1, 5):
			kit.cylinder(spot + Vector3.UP * level * 0.28, 0.38, 0.28, BLACK, SceneryKit.SMOOTH)


## A row of rental karts parked nose in, waiting for the next session.
static func kart_row(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var paint: Color = [RED, BLUE, YELLOW, GREEN, ORANGE][rng.randi() % 5]
	for k in 6:
		var spot := at + _turn(Vector3((k - 2.5) * 2.2, 0.0, 0.0), facing)
		_box(kit, spot, Vector3(0.0, 0.2, 0.0), Vector3(1.2, 0.2, 2.0), facing, DARK_GREY, SceneryKit.SMOOTH, false)
		_box(kit, spot, Vector3(0.0, 0.4, 0.8), Vector3(1.3, 0.35, 0.5), facing, paint, SceneryKit.SMOOTH, false)
		_box(kit, spot, Vector3(0.0, 0.4, -0.3), Vector3(0.6, 0.6, 0.6), facing, BLACK, SceneryKit.SMOOTH, false)
		for x in [-0.7, 0.7]:
			for z in [-0.7, 0.7]:
				_box(kit, spot, Vector3(x, 0.0, z), Vector3(0.3, 0.5, 0.5), facing, BLACK, SceneryKit.SMOOTH, false)


## A raised deck for watching from, on posts, with glass along the front and
## people leaning on it, and steps up at one end.
static func viewing_deck(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var length := 18.0
	for x in [-8.5, 0.0, 8.5]:
		for z in [-2.5, 2.5]:
			_box(kit, at, Vector3(x, 0.0, z), Vector3(0.6, 4.0, 0.6), facing, LIGHT_GREY)
	_box(kit, at, Vector3(0.0, 4.0, 0.0), Vector3(length, 0.4, 6.0), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 4.4, 2.9), Vector3(length, 1.1, 0.15), facing, GLASS, SceneryKit.SMOOTH, false)
	for k in 6:
		_box(kit, at, Vector3(length * 0.5 + 0.6, k * 0.66, -2.0 + k * 0.7), Vector3(1.2, 0.66, 0.7), facing, LIGHT_GREY, SceneryKit.BRICK, false)
	var x := -length * 0.5 + 1.0
	while x < length * 0.5 - 1.0:
		if rng.randf() < 0.7:
			fan(kit, at, Vector3(x, 4.4, 2.3), facing, rng)
		x += rng.randf_range(0.9, 1.6)
	kit.new_crowd()


## Pallets stacked up, the way they are at the back of a warehouse.
static func pallets(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for level in rng.randi_range(2, 6):
		kit.box(at + Vector3.UP * level * 0.3, Vector3(2.0, 0.1, 2.0), TAN, SceneryKit.SMOOTH, false)
		kit.box(at + Vector3.UP * (level * 0.3 + 0.1), Vector3(2.0, 0.2, 1.8), DARK_TAN, SceneryKit.SMOOTH, false)
	kit.box(at, Vector3(2.0, 0.3, 2.0), DARK_TAN, SceneryKit.SMOOTH, false)


## The office where you sign in and pick up a helmet, with big windows and a
## glowing sign on top.
static func kart_office(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(10.0, 3.3, 5.0), facing, WHITE)
	_box(kit, at, Vector3(0.0, 0.8, 2.5), Vector3(8.0, 1.8, 0.1), facing, GLASS, SceneryKit.WINDOWS, false)
	_box(kit, at, Vector3(0.0, 3.3, 0.0), Vector3(10.4, 0.3, 5.4), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 3.6, 2.2), Vector3(6.0, 1.2, 0.3), facing, YELLOW, SceneryKit.GLOW, false)


# Things at a theme park.

## A carousel: a round platform with horses on poles, under a striped roof.
static func carousel(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	kit.cylinder(at, 6.0, 0.6, WHITE, SceneryKit.BRICK, true)
	# Everything on top goes round.
	kit.begin_mover(Transform3D(Basis.IDENTITY, at), { "spin": Vector3.UP, "speed": 0.6 })
	kit.cylinder(at + Vector3.UP * 0.6, 1.2, 4.0, YELLOW, SceneryKit.SMOOTH)
	for k in 12:
		var a := TAU * k / 12.0
		var spot := at + Vector3(cos(a), 0.0, sin(a)) * 4.5
		kit.cylinder(spot + Vector3.UP * 0.6, 0.08, 4.0, YELLOW, SceneryKit.SMOOTH)
		kit.box(spot + Vector3.UP * (1.2 + 0.4 * (k % 2)), Vector3(0.5, 0.8, 1.4), [WHITE, BROWN, BLACK, TAN][rng.randi() % 4], SceneryKit.SMOOTH, false)
	for k in 8:
		kit.cylinder(at + Vector3.UP * (4.6 + k * 0.25), 6.4 - k * 0.8, 0.25, RED if k % 2 == 0 else WHITE, SceneryKit.SMOOTH)
	kit.cylinder(at + Vector3.UP * 6.6, 0.3, 1.0, YELLOW, SceneryKit.GLOW)
	kit.end_mover()


## A drop tower: a tall mast with a ring of seats that goes up and falls.
static func drop_tower(kit: SceneryKit, at: Vector3) -> void:
	kit.box(at, Vector3(4.0, 1.0, 4.0), DARK_GREY)
	kit.box(at + Vector3.UP, Vector3(2.0, 38.0, 2.0), LIGHT_GREY)
	# The seats ride up and down the tower.
	kit.begin_mover(Transform3D(Basis.IDENTITY, at + Vector3.UP * 20.0), { "bob": 14.0, "rate": 0.35 })
	kit.cylinder(at + Vector3.UP * 20.0, 3.2, 1.6, BLUE, SceneryKit.SMOOTH)
	kit.end_mover()
	kit.cylinder(at + Vector3.UP * 39.0, 1.6, 1.2, RED, SceneryKit.GLOW)


## The huge low red roof of the theme park in Abu Dhabi, sweeping down to the
## sand at its edges.
static func red_roof(kit: SceneryKit, at: Vector3) -> void:
	for k in 6:
		var r := 36.0 - k * 5.5
		kit.cylinder(at + Vector3.UP * k * 1.6, r, 1.6, RED if k < 5 else DARK_RED, SceneryKit.SMOOTH, k == 0)
	kit.cylinder(at + Vector3.UP * 9.6, 6.0, 2.0, YELLOW, SceneryKit.SMOOTH)


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
		# The crowd, brick figures in all sorts of colours, in bunches along it that
		# cheer as the karts go past them.
		var x := -length * 0.5 + 0.6
		while x < length * 0.5 - 0.4:
			if int((x + length * 0.5) / 8.0) != int((x - 0.8 + length * 0.5) / 8.0):
				kit.new_crowd()
			if rng.randf() < 0.75:
				fan(kit, at, Vector3(x, 0.9 + r * 0.9, -r * 1.1 + 0.15), facing, rng)
			x += 0.8
	# A roof on posts, in a team colour.
	for x in [-length * 0.5, 0.0, length * 0.5]:
		_box(kit, at, Vector3(x, 0.0, -rows * 1.1 - 0.3), Vector3(0.4, 8.0, 0.4), facing, WHITE)
	_box(kit, at, Vector3(0.0, 8.0, -rows * 0.55), Vector3(length + 1.0, 0.4, rows * 1.1 + 1.6), facing, RED, SceneryKit.SMOOTH, false)


static func pit_building(kit: SceneryKit, at: Vector3, length: float, facing: int, style := "") -> void:
	var depth := 7.0
	var western := style == "western"
	var jungle := style == "jungle"
	var wall := Color("#b07a4a") if western else (Color("#cdb88a") if jungle else WHITE)
	_box(kit, at, Vector3(0.0, 0.0, -depth * 0.5), Vector3(length, 4.2, depth), facing, wall)
	var colours := [RED, BLUE, YELLOW, GREEN, ORANGE, DARK_BLUE]
	var doors := int(length / 5.0)
	for k in doors:
		var x := -length * 0.5 + 2.5 + k * 5.0
		_box(kit, at, Vector3(x, 0.0, 0.02), Vector3(4.0, 3.2, 0.1), facing, DARK_GREY, SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(x, 3.4, 0.02), Vector3(4.0, 0.6, 0.1), facing, colours[k % colours.size()], SceneryKit.SMOOTH, false)
	var tower := Vector3(length * 0.5 - 3.0, 4.2, -depth * 0.5)
	if western:
		# Out west race control is a wooden building on the roof with a tall
		# false front and a sign, and a porch along the front of the roof.
		var wood := WOOD
		var back := 2.6
		var room := Vector3(tower.x, 4.2, -back - (depth - back) * 0.5)
		_box(kit, at, room, Vector3(6.0, 3.4, depth - back), facing, wood)
		_roof(kit, at + _turn(room + Vector3(0.0, 3.4, 0.0), facing), depth - back, 6.0, deg_to_rad(16.0), facing + 1, wood.darkened(0.35))
		# The false front, stepped at the top, with the sign on it.
		var front := Vector3(tower.x, 4.2, -back + 0.2)
		_box(kit, at, front, Vector3(6.6, 5.0, 0.4), facing, wood.lightened(0.08))
		_box(kit, at, front + Vector3(0.0, 5.0, 0.0), Vector3(3.4, 0.8, 0.4), facing, wood.lightened(0.08))
		_box(kit, at, front + Vector3(0.0, 5.8, 0.0), Vector3(3.8, 0.2, 0.5), facing, RED, SceneryKit.SMOOTH, false)
		_box(kit, at, front + Vector3(0.0, 3.4, 0.25), Vector3(5.0, 1.2, 0.1), facing, RED, SceneryKit.SMOOTH, false)
		_box(kit, at, front + Vector3(0.0, 3.5, 0.3), Vector3(4.6, 1.0, 0.1), facing, PALE_ROCK.lightened(0.3), SceneryKit.SMOOTH, false)
		for k in 5:
			_box(kit, at, front + Vector3(-1.6 + k * 0.8, 3.65, 0.36), Vector3(0.45, 0.6, 0.05), facing, BLACK, SceneryKit.SMOOTH, false)
		for x in [-1.8, 1.8]:
			_box(kit, at, front + Vector3(x, 0.9, 0.25), Vector3(1.4, 1.4, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
		_box(kit, at, front + Vector3(0.0, 0.0, 0.25), Vector3(1.2, 2.2, 0.1), facing, wood.darkened(0.3), SceneryKit.SMOOTH, false)
		# The porch: boards on the roof, posts along its edge and a roof.
		_box(kit, at, Vector3(tower.x, 4.2, -back * 0.5), Vector3(6.6, 0.15, back), facing, wood.darkened(0.2), SceneryKit.BRICK, false)
		for x in [-3.0, -1.0, 1.0, 3.0]:
			_box(kit, at, Vector3(tower.x + x, 4.35, -0.25), Vector3(0.25, 2.6, 0.25), facing, wood.darkened(0.2), SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(tower.x, 6.95, -back * 0.5 + 0.1), Vector3(6.8, 0.2, back + 0.4), facing, RED.darkened(0.2), SceneryKit.SMOOTH, false)
	elif jungle:
		# In the jungle race control is a bamboo hut on the roof with a steep
		# thatched roof and a deck round it.
		var walls := Color("#b89a62")
		_box(kit, at, tower + Vector3(0.0, 0.0, -0.5), Vector3(5.6, 3.0, depth - 1.0), facing, walls)
		for k in 7:
			_box(kit, at, tower + Vector3(-2.4 + k * 0.8, 0.0, depth * 0.5 - 0.98), Vector3(0.14, 3.0, 0.1), facing, walls.darkened(0.2), SceneryKit.SMOOTH, false)
		for x in [-1.5, 1.5]:
			_box(kit, at, tower + Vector3(x, 1.0, depth * 0.5 - 0.92), Vector3(1.4, 1.2, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
		_roof(kit, at + _turn(tower + Vector3(0.0, 3.0, -0.5), facing), 6.4, depth, deg_to_rad(38.0), facing + 1, THATCH, false)
		_box(kit, at, tower + Vector3(0.0, 3.0, -0.5), Vector3(6.0, 0.3, depth), facing, THATCH.darkened(0.15), SceneryKit.SMOOTH, false)
	elif style == "alpine":
		# In the Alps race control is a wooden chalet on the roof, with a
		# balcony of red flowers and its gable to the road.
		var wood := Color("#8a5a3a")
		_box(kit, at, tower, Vector3(6.0, 3.4, depth), facing, wood)
		for x in [-1.5, 1.5]:
			_box(kit, at, tower + Vector3(x, 1.0, depth * 0.5), Vector3(1.4, 1.4, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
		_box(kit, at, tower + Vector3(0.0, 0.9, depth * 0.5 + 0.12), Vector3(6.0, 0.35, 0.3), facing, RED, SceneryKit.BRICK, false)
		_roof(kit, at + _turn(tower + Vector3(0.0, 3.4, 0.0), facing), depth + 1.2, 6.6, deg_to_rad(28.0), facing + 1, wood.darkened(0.3))
	else:
		# The race control tower on one end, all windows.
		_box(kit, at, tower, Vector3(6.0, 5.0, depth), facing, LIGHT_GREY, SceneryKit.WINDOWS)
		_box(kit, at, tower + Vector3(0.0, 5.0, 0.0), Vector3(6.6, 0.4, depth + 0.6), facing, DARK_GREY, SceneryKit.SMOOTH, false)
		if style == "city":
			# In the city it has a glowing sign on the roof.
			_box(kit, at, tower + Vector3(0.0, 5.4, depth * 0.5 - 0.3), Vector3(5.0, 1.4, 0.3), facing, YELLOW, SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, 4.2, 0.2), Vector3(length, 0.9, 0.3), facing, WOOD.darkened(0.3) if western or jungle else BLUE, SceneryKit.SMOOTH, false)


static func billboard(kit: SceneryKit, at: Vector3, facing: int, colour: Color) -> void:
	for x in [-2.5, 2.5]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(0.3, 2.0, 0.3), facing, LIGHT_GREY)
	_box(kit, at, Vector3(0.0, 2.0, 0.0), Vector3(6.4, 2.4, 0.3), facing, colour, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(-0.8, 2.6, 0.18), Vector3(3.6, 0.5, 0.05), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.4, 3.4, 0.18), Vector3(4.6, 0.35, 0.05), facing, WHITE, SceneryKit.SMOOTH, false)


static func flag(kit: SceneryKit, at: Vector3, colour: Color) -> void:
	kit.cylinder(at, 0.08, 6.0, WHITE, SceneryKit.SMOOTH, true)
	# The flag flaps about the pole.
	kit.begin_mover(Transform3D(Basis.IDENTITY, at + Vector3.UP * 5.3), { "swing": Vector3.UP, "angle": 0.35, "rate": 2.2 })
	kit.box(at + Vector3(0.8, 4.8, 0.0), Vector3(1.6, 1.0, 0.06), colour, SceneryKit.SMOOTH, false)
	kit.end_mover()


## A little boat that rocks gently, pointing along `heading`.
static func boat(kit: SceneryKit, at: Vector3, heading: float, rng: RandomNumberGenerator) -> void:
	var turn := Basis(Vector3.UP, heading)
	kit.begin_mover(Transform3D(Basis.IDENTITY, at), { "swing": turn * Vector3.BACK, "angle": 0.06, "rate": 1.1 })
	var hull: Color = [WHITE, RED, BLUE, YELLOW][rng.randi() % 4]
	kit.turned_box(at + Vector3.UP * 0.4, Vector3(2.4, 1.0, 7.0), turn, hull, SceneryKit.SMOOTH)
	kit.turned_box(at + Vector3.UP * 0.95 + turn * Vector3(0.0, 0.0, 2.6), Vector3(1.6, 0.4, 2.0), turn, hull.lightened(0.2), SceneryKit.SMOOTH)
	if rng.randf() < 0.7:
		kit.turned_cylinder(at + Vector3.UP * 4.5, 0.08, 7.0, turn, WHITE)
		kit.turned_box(at + Vector3.UP * 4.0 + turn * Vector3(0.0, 0.0, -1.2), Vector3(0.05, 5.5, 2.6), turn, WHITE, SceneryKit.SMOOTH)
	else:
		kit.turned_box(at + Vector3.UP * 1.5 + turn * Vector3(0.0, 0.0, -1.0), Vector3(1.8, 1.2, 2.4), turn, WHITE, SceneryKit.SMOOTH)
	kit.end_mover()


static func marshal_post(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(1.6, 2.4, 1.6), facing, WHITE)
	_box(kit, at, Vector3(0.0, 2.4, 0.0), Vector3(2.0, 0.3, 2.0), facing, ORANGE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 1.2, 0.81), Vector3(1.0, 0.7, 0.05), facing, GLASS, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.9, 2.7, 0.0), Vector3(0.06, 1.4, 0.06), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(1.3, 3.5, 0.0), Vector3(0.8, 0.5, 0.04), facing, YELLOW, SceneryKit.SMOOTH, false)


# By the sea.

## Beach umbrellas with towels laid out under them.
static func parasols(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var colours := [RED, BLUE, YELLOW, ORANGE, AZURE, WHITE]
	for k in 3:
		var spot := at + Vector3(rng.randf_range(-1.8, 1.8), 0.0, rng.randf_range(-1.8, 1.8))
		kit.cylinder(spot, 0.06, 2.2, WHITE, SceneryKit.SMOOTH, k == 0)
		kit.cone(spot + Vector3.UP * 1.9, 1.2, 0.5, colours[rng.randi() % colours.size()], SceneryKit.SMOOTH)
		kit.box(spot + Vector3(0.6, 0.0, 0.4), Vector3(0.8, 0.04, 1.8), colours[rng.randi() % colours.size()], SceneryKit.SMOOTH, false)


## A little wooden hut in bright stripes, with a pitched roof.
static func beach_hut(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var colour: Color = [RED, BLUE, YELLOW, AZURE, PINK, BRIGHT_GREEN][rng.randi() % 6]
	_box(kit, at, Vector3.ZERO, Vector3(2.4, 2.4, 2.0), facing, WHITE)
	for k in 3:
		_box(kit, at, Vector3(-0.8 + k * 0.8, 0.0, 1.01), Vector3(0.4, 2.4, 0.05), facing, colour, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.0, 1.05), Vector3(0.8, 1.8, 0.05), facing, BROWN, SceneryKit.SMOOTH, false)
	_roof(kit, at + Vector3.UP * 2.4, 2.4, 2.0, deg_to_rad(35.0), facing, colour)


## A lifeguard's lookout on stilts, with a ladder and a flag.
static func lifeguard_tower(kit: SceneryKit, at: Vector3, facing: int) -> void:
	for x in [-0.9, 0.9]:
		for z in [-0.9, 0.9]:
			_box(kit, at, Vector3(x, 0.0, z), Vector3(0.2, 2.4, 0.2), facing, WHITE)
	_box(kit, at, Vector3(0.0, 2.4, 0.0), Vector3(2.4, 0.2, 2.4), facing, BROWN, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 2.6, -0.2), Vector3(1.8, 1.5, 1.6), facing, RED, SceneryKit.BRICK, false)
	_box(kit, at, Vector3(0.0, 3.1, 0.61), Vector3(1.4, 0.6, 0.05), facing, GLASS, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 4.1, -0.2), Vector3(2.2, 0.2, 2.0), facing, YELLOW, SceneryKit.SMOOTH, false)
	for k in 6:
		_box(kit, at, Vector3(0.0, 0.3 + k * 0.38, 1.4), Vector3(0.8, 0.08, 0.12), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(1.0, 4.3, -1.0), Vector3(0.06, 1.6, 0.06), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(1.4, 5.5, -1.0), Vector3(0.8, 0.5, 0.04), facing, RED, SceneryKit.SMOOTH, false)


## A windsurfing board and its sail, stood up on the sand.
static func windsurf(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var turn := Basis(Vector3.UP, rng.randf() * TAU)
	kit.turned_box(at + Vector3.UP * 0.05, Vector3(0.6, 0.1, 2.6), turn, WHITE)
	var sail: Color = [RED, YELLOW, AZURE, ORANGE, PINK][rng.randi() % 5]
	kit.turned_box(at + Vector3.UP * 1.6 + turn * Vector3(0.0, 0.0, 0.3), Vector3(0.05, 3.0, 1.6), turn * Basis(Vector3.RIGHT, 0.15), sail)
	kit.turned_cylinder(at + Vector3.UP * 1.6 + turn * Vector3(0.0, 0.0, -0.5), 0.04, 3.2, turn, LIGHT_GREY)
	kit.soft_box(Transform3D(turn, at + Vector3.UP * 1.0), Vector3(0.6, 2.0, 1.6))


## A tall white hotel with balconies all the way up and a terrace on top.
static func beach_hotel(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var floors := 6 + rng.randi() % 4
	var accent: Color = [AZURE, ORANGE, YELLOW, BLUE][rng.randi() % 4]
	var h := floors * 3.0
	_box(kit, at, Vector3.ZERO, Vector3(16.0, h, 9.0), facing, WHITE)
	for f in floors:
		_box(kit, at, Vector3(0.0, 2.6 + f * 3.0, 4.9), Vector3(16.4, 0.25, 1.2), facing, WHITE, SceneryKit.SMOOTH, false)
		for x in 5:
			_box(kit, at, Vector3(-6.4 + x * 3.2, 0.9 + f * 3.0, 4.52), Vector3(2.0, 1.6, 0.05), facing, GLASS, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, h, 0.0), Vector3(16.4, 0.4, 9.4), facing, accent, SceneryKit.SMOOTH, false)
	for x in [-5.0, 0.0, 5.0]:
		kit.cone(at + _turn(Vector3(x, h + 0.4, 0.0), facing) + Vector3.UP * 1.4, 1.0, 0.4, accent, SceneryKit.SMOOTH)
		kit.cylinder(at + _turn(Vector3(x, h + 0.4, 0.0), facing), 0.05, 1.5, WHITE, SceneryKit.SMOOTH)
	_box(kit, at, Vector3(0.0, 0.0, 5.2), Vector3(4.0, 3.0, 1.2), facing, accent, SceneryKit.SMOOTH, false)


## A huge sandcastle, made of bricks, with four round towers and a flag.
static func sandcastle(kit: SceneryKit, at: Vector3) -> void:
	kit.box(at, Vector3(11.0, 1.2, 11.0), TAN)
	kit.box(at + Vector3.UP * 1.2, Vector3(8.0, 3.0, 8.0), TAN)
	for x in [-4.0, 4.0]:
		for z in [-4.0, 4.0]:
			kit.cylinder(at + Vector3(x, 1.2, z), 1.4, 4.4, TAN.lightened(0.08), SceneryKit.BRICK, true)
			kit.cone(at + Vector3(x, 5.6, z), 1.6, 1.4, DARK_TAN, SceneryKit.BRICK)
	for k in 6:
		var x := -2.5 + k
		for z in [-4.0, 4.0]:
			kit.box(at + Vector3(x, 4.2, z), Vector3(0.5, 0.5, 0.5), TAN)
	kit.box(at + Vector3.UP * 4.2, Vector3(3.0, 2.6, 3.0), TAN.lightened(0.08))
	kit.cone(at + Vector3.UP * 6.8, 2.0, 1.6, DARK_TAN)
	kit.cylinder(at + Vector3.UP * 8.4, 0.05, 2.0, WHITE, SceneryKit.SMOOTH)
	kit.box(at + Vector3(0.5, 9.6, 0.0), Vector3(1.0, 0.6, 0.04), RED, SceneryKit.SMOOTH, false)
	kit.box(at + Vector3(0.0, 1.2, 4.05), Vector3(1.6, 2.0, 0.1), DARK_TAN, SceneryKit.SMOOTH, false)


## Thick sloping walls of honey coloured stone round a harbour, with a corner
## bastion, a watchtower and a dome behind.
static func harbour_fort(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var stone := Color("#d9b77e")
	for k in 3:
		var w := 22.0 - k * 1.2
		_box(kit, at, Vector3(0.0, k * 2.0, 0.0), Vector3(w, 2.0, 7.0 - k * 0.8), facing, stone.darkened(k * 0.05))
	for k in 8:
		_box(kit, at, Vector3(-9.5 + k * 2.7, 6.0, 2.2), Vector3(1.2, 0.8, 0.8), facing, stone)
	_box(kit, at, Vector3(10.0, 0.0, -4.0), Vector3(6.0, 7.5, 6.0), facing, stone.darkened(0.08))
	_box(kit, at, Vector3(10.0, 7.5, -4.0), Vector3(2.6, 3.0, 2.6), facing, stone)
	kit.cylinder(at + _turn(Vector3(-6.0, 6.0, -1.5), facing), 2.2, 2.0, stone.lightened(0.05))
	kit.cone(at + _turn(Vector3(-6.0, 8.0, -1.5), facing), 2.3, 2.6, DARK_RED)
	kit.cylinder(at + _turn(Vector3(-6.0, 10.6, -1.5), facing), 0.2, 1.0, stone)


## A few little penguins waddling up from the beach, a hand high.
static func penguins(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 4 + rng.randi() % 3:
		var spot := at + Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
		var face := Basis(Vector3.UP, rng.randf() * TAU)
		kit.cylinder(spot, 0.16, 0.42, Color("#2c3e5a"), SceneryKit.SMOOTH)
		kit.turned_box(spot + Vector3.UP * 0.2 + face * Vector3(0.0, 0.0, 0.12), Vector3(0.18, 0.3, 0.06), face, WHITE)
		kit.cylinder(spot + Vector3.UP * 0.42, 0.12, 0.14, Color("#2c3e5a"), SceneryKit.SMOOTH)
		kit.turned_box(spot + Vector3.UP * 0.48 + face * Vector3(0.0, 0.0, 0.14), Vector3(0.05, 0.04, 0.1), face, BLACK)


## An umbrella pine, with a tall bare trunk and a wide flat top.
static func stone_pine(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := 3.6 + rng.randf() * 1.4
	kit.box(at, Vector3(0.5, trunk, 0.5), BROWN, SceneryKit.BRICK, true)
	var size := 4.2 + rng.randf() * 1.4
	kit.box(at + Vector3.UP * trunk, Vector3(size, 0.8, size), GREEN.darkened(0.1), SceneryKit.BRICK, false)
	kit.box(at + Vector3.UP * (trunk + 0.8), Vector3(size * 0.7, 0.6, size * 0.7), GREEN, SceneryKit.BRICK, false)


# The Alps.

## A wooden chalet on a white stone ground floor, with a balcony of red
## flowers along the front and a wide roof with its gable to the front. A
## snowy one has snow on the roof.
static func chalet(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator, snowy: bool) -> void:
	var w := 7.0
	var d := 6.0
	var wood: Color = [Color("#8a5a3a"), Color("#9a6440"), Color("#7a4a2c")][rng.randi() % 3]
	var shutters: Color = [GREEN, RED, DARK_RED][rng.randi() % 3]
	_box(kit, at, Vector3.ZERO, Vector3(w, 2.4, d), facing, WHITE)
	_box(kit, at, Vector3(0.0, 2.4, 0.0), Vector3(w, 2.4, d), facing, wood)
	_box(kit, at, Vector3(0.0, 0.0, d * 0.5), Vector3(1.0, 1.9, 0.1), facing, wood.darkened(0.2), SceneryKit.SMOOTH, false)
	for x in [-2.2, 2.2]:
		_box(kit, at, Vector3(x, 0.8, d * 0.5), Vector3(0.9, 0.9, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
		for s in [-0.6, 0.6]:
			_box(kit, at, Vector3(x + s, 0.8, d * 0.5), Vector3(0.3, 0.9, 0.16), facing, shutters, SceneryKit.SMOOTH, false)
	for x in [-2.0, 0.0, 2.0]:
		_box(kit, at, Vector3(x, 3.2, d * 0.5), Vector3(1.0, 1.0, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
	# The balcony, with flower boxes along its rail.
	_box(kit, at, Vector3(0.0, 2.3, d * 0.5 + 0.6), Vector3(w, 0.2, 1.2), facing, wood.darkened(0.15), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 2.5, d * 0.5 + 1.14), Vector3(w, 0.8, 0.12), facing, wood.lightened(0.15), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 3.3, d * 0.5 + 1.05), Vector3(w - 0.4, 0.35, 0.35), facing, RED, SceneryKit.BRICK, false)
	# The roof's ridge runs front to back, and it reaches out over the balcony.
	var roof_colour := DARK_GREY if snowy else wood.darkened(0.3)
	_roof(kit, at + Vector3.UP * 4.8, d + 2.0, w + 0.6, deg_to_rad(26.0), facing + 1, roof_colour)
	if snowy:
		_roof(kit, at + Vector3.UP * 5.05, d + 1.8, w + 0.4, deg_to_rad(26.0), facing + 1, WHITE, false)
	_box(kit, at, Vector3(-2.0, 4.8, -1.0), Vector3(0.6, 2.4, 0.6), facing, WHITE)


## A white village church with a red roof, a tall tower with a clock on each
## side, and a long green spire.
static func alpine_church(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(6.0, 5.0, 10.0), facing, WHITE)
	_roof(kit, at + Vector3.UP * 5.0, 10.0, 6.0, deg_to_rad(40.0), facing + 1, RED)
	for z in [-3.0, 0.0, 3.0]:
		for x in [-3.0, 3.0]:
			_box(kit, at, Vector3(x, 1.6, z), Vector3(0.1, 2.2, 0.8), facing, DARK_BLUE, SceneryKit.SMOOTH, false)
	var tower := Vector3(0.0, 0.0, 6.4)
	_box(kit, at, tower, Vector3(3.2, 14.0, 3.2), facing, WHITE)
	_box(kit, at, tower + Vector3(0.0, 0.0, 1.6), Vector3(1.2, 2.2, 0.1), facing, BROWN, SceneryKit.SMOOTH, false)
	# The belfry, a band of dark openings, and the clocks under it.
	for side in 4:
		var out := _turn(Vector3(0.0, 0.0, 1.62), side)
		var flat := Basis(Quaternion(Vector3.UP, out.normalized()))
		_box(kit, at, tower + out + Vector3(0.0, 12.2, 0.0), _turn_size(Vector3(1.6, 1.4, 0.1), side), facing, BLACK, SceneryKit.SMOOTH, false)
		var clock := at + _turn(tower + out + Vector3(0.0, 10.4, 0.0), facing)
		var face := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5) * flat
		kit.turned_cylinder(clock, 0.75, 0.12, face, WHITE)
		# The hands, at ten past twelve.
		var front := clock + _turn(out.normalized(), facing) * 0.08
		var across := _turn(_turn(Vector3.RIGHT, side), facing)
		kit.box(front, _turn_size(Vector3(0.1, 0.55, 0.06), side + facing), BLACK, SceneryKit.SMOOTH, false)
		kit.box(front + across * 0.18 - Vector3.UP * 0.05, _turn_size(Vector3(0.36, 0.1, 0.06), side + facing), BLACK, SceneryKit.SMOOTH, false)
	_box(kit, at, tower + Vector3(0.0, 14.0, 0.0), Vector3(3.6, 0.4, 3.6), facing, WHITE)
	kit.cone(at + _turn(tower, facing) + Vector3.UP * 14.4, 2.0, 10.0, Color("#4f8f78"))
	kit.cylinder(at + _turn(tower, facing) + Vector3.UP * 24.2, 0.08, 1.2, YELLOW, SceneryKit.SMOOTH)
	kit.box(at + _turn(tower, facing) + Vector3.UP * 24.8, Vector3(0.6, 0.1, 0.1), YELLOW, SceneryKit.SMOOTH, false)


## Two or three toy cows grazing in a little ring, heads out, brown or white
## with patches, each with a bell on a red collar.
static func cows(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	# Their own random numbers, so the rest of the scenery doesn't hang on how
	# a cow is built.
	var own := RandomNumberGenerator.new()
	own.seed = rng.randi()
	var count := 2 + own.randi() % 2
	var turn := own.randf() * TAU
	for k in count:
		var a := turn + TAU * (k + own.randf_range(-0.12, 0.12)) / count
		var out := Vector3(cos(a), 0.0, sin(a))
		var face := Basis(Vector3.UP, atan2(out.x, out.z) + own.randf_range(-0.5, 0.5))
		_cow(kit, at + out * own.randf_range(1.3, 1.6), face, own)


## One cow facing +Z in `face`: a round body, a big head, stubby legs, little
## horns and a cowbell.
static func _cow(kit: SceneryKit, spot: Vector3, face: Basis, rng: RandomNumberGenerator) -> void:
	var patched := rng.randf() < 0.5
	var coat: Color = WHITE if patched else [Color("#8a5a3a"), NOUGAT, Color("#9b8a78")][rng.randi() % 3]
	var patch: Color = [BLACK, BROWN][rng.randi() % 2]
	var grazing := rng.randf() < 0.5
	var along := face * Basis(Vector3.RIGHT, PI * 0.5)
	# The hind legs stand wider apart than the front ones, with a thigh each.
	for z in [-0.42, 0.42]:
		var wide := 0.28 if z < 0.0 else 0.24
		for x in [-wide, wide]:
			kit.turned_box(spot + face * Vector3(x, 0.32, z), Vector3(0.22, 0.5, 0.22), face, coat.darkened(0.08))
			kit.turned_box(spot + face * Vector3(x, 0.06, z), Vector3(0.24, 0.12, 0.24), face, DARK_GREY)
	for x in [-0.3, 0.3]:
		kit.turned_box(spot + face * Vector3(x, 0.74, -0.44), Vector3(0.22, 0.5, 0.42), face, coat.darkened(0.04))
	# The body, a fat cylinder with narrower ones out the ends to round it off,
	# plain so it has no seams like a barrel, and hip bones up at the back.
	kit.turned_cylinder(spot + face * Vector3(0.0, 0.88, 0.0), 0.42, 1.2, along, coat, SceneryKit.PLAIN)
	kit.turned_cylinder(spot + face * Vector3(0.0, 0.88, 0.0), 0.34, 1.42, along, coat, SceneryKit.PLAIN)
	for x in [-0.24, 0.24]:
		kit.turned_box(spot + face * Vector3(x, 1.18, -0.5), Vector3(0.18, 0.08, 0.24), face, coat, SceneryKit.PLAIN)
	if patched:
		for side in [-1.0, 1.0]:
			kit.turned_box(spot + face * Vector3(side * 0.4, 0.92, rng.randf_range(-0.3, 0.2)), Vector3(0.08, 0.42, 0.5), face, patch)
		kit.turned_box(spot + face * Vector3(0.0, 1.29, rng.randf_range(-0.35, 0.1)), Vector3(0.36, 0.06, 0.4), face, patch)
	kit.turned_box(spot + face * Vector3(0.0, 0.46, -0.3), Vector3(0.32, 0.18, 0.3), face, PINK)
	# The long tail, a little off centre, with a pale tuft on a plain cow.
	var pale := Color("#efe4c4")
	kit.turned_box(spot + face * Vector3(0.08, 0.92, -0.75), Vector3(0.08, 0.66, 0.06), face, coat.darkened(0.25), SceneryKit.PLAIN)
	kit.turned_box(spot + face * Vector3(0.08, 0.52, -0.75), Vector3(0.15, 0.2, 0.12), face, pale if not patched else BLACK, SceneryKit.PLAIN)
	# The big head, down in the grass or up looking about.
	var head := Vector3(0.0, 0.6, 0.92) if grazing else Vector3(0.0, 1.2, 0.84)
	kit.turned_box(spot + face * head, Vector3(0.66, 0.6, 0.6), face, coat)
	if patched:
		kit.turned_box(spot + face * (head + Vector3(0.18, 0.12, 0.0)), Vector3(0.32, 0.38, 0.62), face, patch)
	kit.turned_box(spot + face * (head + Vector3(0.0, -0.17, 0.32)), Vector3(0.7, 0.3, 0.2), face, PINK)
	for x in [-0.12, 0.12]:
		kit.turned_box(spot + face * (head + Vector3(x, -0.14, 0.42)), Vector3(0.08, 0.08, 0.02), face, DARK_RED)
	for x in [-0.17, 0.17]:
		kit.turned_box(spot + face * (head + Vector3(x, 0.08, 0.31)), Vector3(0.12, 0.15, 0.03), face, BLACK)
		kit.turned_box(spot + face * (head + Vector3(x + 0.03, 0.12, 0.325)), Vector3(0.04, 0.04, 0.01), face, WHITE)
		# An ear out each side and a horn curling up.
		kit.turned_box(spot + face * (head + Vector3(signf(x) * 0.42, 0.14, -0.08)), Vector3(0.22, 0.08, 0.14), face, coat.darkened(0.1))
		var horn := face * Basis(Vector3.BACK, -signf(x) * 0.5)
		kit.turned_cone(spot + face * (head + Vector3(signf(x) * 0.26, 0.4, -0.06)), 0.07, 0.26, horn, Color("#efe4c4"), SceneryKit.SMOOTH)
	# The red collar and the bell under the neck.
	var neck := Vector3(0.0, head.y - 0.12, 0.6)
	kit.turned_box(spot + face * neck, Vector3(0.5, 0.36, 0.08), face * Basis(Vector3.RIGHT, -0.5), RED)
	kit.cone(spot + face * (neck + Vector3(0.0, -0.46, 0.1)), 0.15, 0.26, YELLOW, SceneryKit.SMOOTH)


## Rock colours for the mountains, from dark to light grey.
const ROCKS := [Color("#6e6b68"), Color("#7d7a76"), Color("#8d8984"), Color("#9a958f")]


## A craggy mountain: a big summit with smaller ones round it, each a block
## stood on its corner so it comes to a rough point, grey rock with a snow cap
## and snow down the gullies. `size` scales it up for the far peaks round an
## alpine course, which aren't solid.
static func snowy_peak(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, size: float, solid: bool) -> void:
	var own := RandomNumberGenerator.new()
	own.seed = rng.randi()
	var height := own.randf_range(38.0, 44.0) * size
	var snow_line := height * own.randf_range(0.66, 0.74)
	# How far out from the middle the others stand.
	var spread := height * 0.5
	_crag(kit, at, height, snow_line, 3, own)
	var peaks := 2 + own.randi() % 2
	var turn := own.randf() * TAU
	for k in peaks:
		var a := turn + TAU * (k + own.randf_range(-0.2, 0.2)) / peaks
		var out := Vector3(cos(a), 0.0, sin(a)) * spread * own.randf_range(0.75, 1.1)
		_crag(kit, at + out, height * own.randf_range(0.55, 0.8), snow_line, 1, own)
	# Low bare shoulders round the foot.
	for k in 2:
		var a := turn + PI / peaks + PI * k + own.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0.0, sin(a)) * spread * own.randf_range(0.9, 1.05)
		_crag(kit, at + out, height * own.randf_range(0.3, 0.4), INF, 0, own)
	if solid:
		kit.box(at, Vector3(spread * 0.8, 6.0, spread * 0.8), ROCKS[1], SceneryKit.SMOOTH, true)


## One summit `height` tall over `foot`: a block stood on its corner, sunk to
## its widest part, leaning a little and drawn out upwards so it's steep. Snow
## covers it above `snow_line` (or a small cap if it's lower), with `streaks`
## of snow down its faces. `steep` is how much it's drawn out, random if 0.
static func _crag(kit: SceneryKit, foot: Vector3, height: float, snow_line: float, streaks: int, rng: RandomNumberGenerator, steep := 0.0) -> void:
	if steep == 0.0:
		steep = rng.randf_range(1.5, 1.9)
	var tall := Basis.from_scale(Vector3(1.0, steep, 1.0))
	# Everything is worked out before it's drawn out upwards by `steep`.
	var h := height / steep
	var stretch := Vector3(rng.randf_range(0.85, 1.15), rng.randf_range(0.85, 1.15), rng.randf_range(0.85, 1.15))
	# Corner to corner it's twice the height, so the middle is at the foot.
	var dims := stretch.normalized() * h * 2.0
	var a := rng.randf() * TAU
	var lean := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(cos(a), 0.0, sin(a)), rng.randf_range(0.0, 0.14))
	var basis := lean * Basis(Quaternion(dims.normalized(), Vector3.UP))
	var up := lean * Vector3.UP
	var top := up * h
	kit.turned_box(foot, dims, tall * basis, ROCKS[rng.randi() % ROCKS.size()])
	if snow_line == INF:
		return
	# The cap is a smaller block in the same corner, standing a little proud.
	var lift := h * 0.02
	var cap := clampf((height - snow_line) / (height * 0.67), 0.2, 0.45)
	kit.turned_box(foot + tall * (top - basis * (dims * cap * 0.5) + up * lift), dims * cap, tall * basis, WHITE, SceneryKit.PLAIN)
	# Snow lies down the ridges below the cap in uneven patches, each a small
	# block in the same corner as the cap, set at a point down one ridge so it
	# wraps the ridge like the cap wraps the top.
	for s in streaks:
		var i := rng.randi() % 3
		var axis := Vector3(1.0 if i == 0 else 0.0, 1.0 if i == 1 else 0.0, 1.0 if i == 2 else 0.0)
		var others := Vector3.ONE - axis
		var t := cap * rng.randf_range(0.5, 0.75)
		var size := cap * rng.randf_range(0.45, 0.6)
		for part in 2 + rng.randi() % 2:
			# Shorter down the ridge than across it, a little proud of both faces.
			var down := rng.randf_range(0.5, 0.9)
			var patch := dims * size * (others + axis * down)
			var corner := top - basis * (axis * dims * t) + basis * (others * lift * 0.5)
			kit.turned_box(foot + tall * (corner - basis * (patch * 0.5)), patch, tall * basis, WHITE, SceneryKit.PLAIN)
			# The next one overlaps this one, so they stay joined.
			t += size * down * rng.randf_range(0.6, 0.85)
			size *= rng.randf_range(0.55, 0.75)


## A cable car line up to a peak: a station at the bottom, two pylons, a
## station up on a rocky crag, and two cars going up and down the cables.
## The pylons stand 15 m either side of the middle, so it can span a
## road put across it (see SPANNING).
static func cable_car(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var bottom := -27.0
	var station := 27.0
	var low := Vector3(bottom + 2.0, 7.2, 0.0)
	var high := Vector3(station - 2.0, 21.6, 0.0)
	# The bottom station, sunk a little so it sits on a slope.
	_box(kit, at, Vector3(bottom, -2.0, 0.0), Vector3(7.0, 9.0, 6.0), facing, TAN)
	_box(kit, at, Vector3(bottom, 7.0, 0.0), Vector3(7.6, 0.4, 6.6), facing, RED, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(bottom, 0.0, 3.0), Vector3(2.4, 2.4, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
	# The top station stands on legs against a steep crag. The crag has its
	# own random numbers, the same wherever it is.
	var own := RandomNumberGenerator.new()
	own.seed = 7
	_crag(kit, at + _turn(Vector3(station + 7.0, 0.0, 0.0), facing), 30.0, 25.0, 0, own, 2.6)
	_box(kit, at, Vector3(station + 7.0, -1.0, 0.0), Vector3(7.0, 8.0, 7.0), facing, ROCKS[0])
	for z in [-2.4, 2.4]:
		_box(kit, at, Vector3(station - 2.9, -1.0, z), Vector3(1.0, 14.0, 1.0), facing, LIGHT_GREY)
	_box(kit, at, Vector3(station, 13.0, 0.0), Vector3(7.0, 10.2, 6.0), facing, TAN)
	_box(kit, at, Vector3(station, 23.2, 0.0), Vector3(7.6, 0.4, 6.6), facing, RED, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(station - 3.5, 19.2, 0.0), Vector3(0.1, 2.4, 3.0), facing, GLASS, SceneryKit.SMOOTH, false)
	# Two cables, resting on the pylons' arms.
	var along := high - low
	for z in [-1.2, 1.2]:
		var a := at + _turn(low + Vector3(0.0, 0.0, z), facing)
		var b := at + _turn(high + Vector3(0.0, 0.0, z), facing)
		kit.turned_box((a + b) * 0.5, Vector3(0.12, (b - a).length(), 0.12), Basis(Quaternion(Vector3.UP, (b - a).normalized())), BLACK)
	for t in [0.2, 0.8]:
		var top: Vector3 = low + along * t
		_box(kit, at, Vector3(top.x, -3.0, 0.0), Vector3(1.0, top.y + 2.4, 1.0), facing, LIGHT_GREY)
		_box(kit, at, Vector3(top.x, top.y - 0.6, 0.0), Vector3(0.6, 0.5, 2.8), facing, LIGHT_GREY)
	# The cars ride up and down the cables, one each way. Each hangs from a
	# carriage on top of its cable, out past the end of the pylon arms, so it
	# goes by them.
	var up := _turn(along.normalized(), facing)
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var hang := at + _turn(low + along * 0.5 + Vector3(0.0, 0.0, 1.2 * side), facing)
		var out := _turn(Vector3(0.0, 0.0, side), facing)
		var way := up if k == 0 else -up
		kit.begin_mover(Transform3D(Basis(Quaternion(Vector3.UP, way)), hang), { "bob": along.length() * 0.36, "rate": 0.12 })
		kit.box(hang + Vector3.UP * 0.08, _turn_size(Vector3(1.0, 0.25, 0.3), facing), DARK_GREY, SceneryKit.SMOOTH, false)
		kit.box(hang + Vector3.UP * 0.2 + out * 0.5, _turn_size(Vector3(0.15, 0.15, 1.0), facing), DARK_GREY, SceneryKit.SMOOTH, false)
		kit.box(hang + out * 0.95 + Vector3.DOWN * 1.4, Vector3(0.15, 1.75, 0.15), DARK_GREY, SceneryKit.SMOOTH, false)
		kit.box(hang + out * 0.95 + Vector3.DOWN * 3.6, _turn_size(Vector3(2.8, 2.2, 2.0), facing), [RED, YELLOW][k], SceneryKit.WINDOWS, false)
		kit.box(hang + out * 0.95 + Vector3.DOWN * 1.5, _turn_size(Vector3(3.0, 0.2, 2.2), facing), DARK_GREY, SceneryKit.SMOOTH, false)
		kit.end_mover()


## A ski jump: a run in from a tower down to the lip, on a steel frame, and a
## long white landing hill out the other side.
static func ski_jump(kit: SceneryKit, at: Vector3, facing: int) -> void:
	# Moved along a little so the start hut stays inside its room.
	at += _turn(Vector3(2.0, 0.0, 0.0), facing)
	var top := Vector3(-30.0, 26.0, 0.0)
	var lip := Vector3(-8.0, 8.0, 0.0)
	var down := lip - top
	var spin := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5)
	var slope := spin * Basis(Vector3.BACK, atan2(down.y, down.x))
	kit.turned_box(at + _turn((top + lip) * 0.5, facing), Vector3(down.length(), 0.5, 3.0), slope, WHITE)
	for z in [-1.6, 1.6]:
		kit.turned_box(at + _turn((top + lip) * 0.5 + Vector3(0.0, 0.45, z), facing), Vector3(down.length(), 0.6, 0.2), slope, RED)
	for x in [-26.0, -20.0, -14.0, -9.0]:
		var y: float = lip.y + (lip.x - x) / (lip.x - top.x) * (top.y - lip.y)
		for z in [-1.2, 1.2]:
			_box(kit, at, Vector3(x, 0.0, z), Vector3(0.5, y - 0.2, 0.5), facing, LIGHT_GREY)
	# The start tower and its hut.
	_box(kit, at, Vector3(top.x - 2.0, 0.0, 0.0), Vector3(3.0, top.y, 3.0), facing, LIGHT_GREY)
	_box(kit, at, Vector3(top.x - 2.0, top.y, 0.0), Vector3(4.0, 3.0, 4.4), facing, RED, SceneryKit.WINDOWS)
	_box(kit, at, Vector3(top.x - 2.0, top.y + 3.0, 0.0), Vector3(4.6, 0.4, 5.0), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	# The landing hill, in steps under a smooth white slope.
	var land_top := Vector3(-6.0, 7.0, 0.0)
	var land_end := Vector3(30.0, 0.3, 0.0)
	for k in 8:
		var x := land_top.x + 1.5 + k * 4.5
		var h := land_top.y * (1.0 - (k + 0.5) / 8.0)
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(4.5, h, 7.0), facing, WHITE)
	var run := land_end - land_top
	kit.turned_box(at + _turn((land_top + land_end) * 0.5, facing), Vector3(run.length(), 0.4, 7.0), spin * Basis(Vector3.BACK, atan2(run.y, run.x)), WHITE)
	# A red line across the landing hill where a good jump lands.
	var mark := land_top + run * 0.45 + Vector3(0.0, 0.22, 0.0)
	kit.turned_box(at + _turn(mark, facing), Vector3(0.4, 0.06, 7.2), spin * Basis(Vector3.BACK, atan2(run.y, run.x)), RED)
	# The judges' tower beside the landing hill.
	_box(kit, at, Vector3(4.0, 0.0, -6.0), Vector3(2.6, 9.0, 2.6), facing, TAN)
	_box(kit, at, Vector3(4.0, 9.0, -6.0), Vector3(3.2, 1.6, 3.2), facing, GLASS, SceneryKit.SMOOTH)
	_box(kit, at, Vector3(4.0, 10.6, -6.0), Vector3(3.6, 0.3, 3.6), facing, RED, SceneryKit.SMOOTH, false)


# The canyon.

## Red rock in bands, darkest at the bottom, with a pale band now and then.
const RED_ROCK := [Color("#8e3b27"), Color("#a0452e"), Color("#b5582c"), Color("#c46a3c")]
const PALE_ROCK := Color("#e2b98a")
const CACTUS_GREEN := Color("#4f7f3a")
const WOOD := Color("#8a5a3a")
const RUST := Color("#9a4a22")


## A flat topped mountain of red rock in bands, standing on a skirt of fallen
## rock. `size` scales it; a far one isn't solid.
static func mesa(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, size: float, solid: bool) -> void:
	var own := RandomNumberGenerator.new()
	own.seed = rng.randi()
	var w := own.randf_range(46.0, 58.0) * size
	var d := own.randf_range(30.0, 40.0) * size
	var h := own.randf_range(28.0, 38.0) * size
	_rock_skirt(kit, at, w, d, h * 0.2, own)
	_rock_bands(kit, at, w * 0.8, d * 0.8, h, own, solid)
	# A lower shoulder off one end, and a few towers standing out from the
	# sides, so it isn't one plain block.
	var end := Vector3(w * own.randf_range(0.38, 0.45) * (-1.0 if own.randf() < 0.5 else 1.0), 0.0, d * own.randf_range(-0.15, 0.15))
	_rock_bands(kit, at + end, w * 0.4, d * 0.6, h * own.randf_range(0.5, 0.7), own, false)
	for k in 3:
		var side := -1.0 if own.randf() < 0.5 else 1.0
		var out := Vector3(own.randf_range(-0.3, 0.3) * w, 0.0, side * d * 0.42)
		_rock_bands(kit, at + out, w * own.randf_range(0.12, 0.2), d * own.randf_range(0.15, 0.25), h * own.randf_range(0.6, 0.95), own, false)


## A tall narrow tower of red rock, sometimes with a thin spire beside it.
static func butte(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, size: float, solid: bool) -> void:
	var own := RandomNumberGenerator.new()
	own.seed = rng.randi()
	var w := own.randf_range(13.0, 17.0) * size
	var h := own.randf_range(30.0, 42.0) * size
	_rock_skirt(kit, at, w * 1.6, w * 1.4, h * 0.22, own)
	_rock_bands(kit, at, w, w * own.randf_range(0.7, 0.9), h, own, solid)
	if own.randf() < 0.6:
		var a := own.randf() * TAU
		var spire := at + Vector3(cos(a), 0.0, sin(a)) * w * 0.85
		_rock_bands(kit, spire, w * 0.3, w * 0.3, h * own.randf_range(0.6, 0.85), own, false)


## A block of rock `w` by `d` and `h` tall in smooth bands of red, each a
## little off from the one under it and narrowing a touch towards the top.
static func _rock_bands(kit: SceneryKit, at: Vector3, w: float, d: float, h: float, rng: RandomNumberGenerator, solid: bool) -> void:
	var bands := maxi(3, roundi(h / 4.0))
	var band := h / bands
	for k in bands:
		var f := 1.0 - 0.12 * float(k) / bands
		var colour: Color = RED_ROCK[mini(k * RED_ROCK.size() / bands, RED_ROCK.size() - 1)]
		if k > 0 and k < bands - 1 and rng.randf() < 0.25:
			colour = PALE_ROCK
		var shift := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
		kit.box(at + shift + Vector3.UP * band * k, Vector3(w * f, band, d * f), colour.darkened(0.15), SceneryKit.PLAIN, solid and k == 0)
	# A darker cap on top.
	kit.box(at + Vector3.UP * h, Vector3(w * 0.86, 0.6, d * 0.86), RED_ROCK[0].darkened(0.15), SceneryKit.PLAIN, false)


## Fallen rock in steps round the foot of a mesa or butte.
static func _rock_skirt(kit: SceneryKit, at: Vector3, w: float, d: float, h: float, rng: RandomNumberGenerator) -> void:
	var steps := 3
	for k in steps:
		var f := 1.0 - 0.18 * k
		kit.box(at + Vector3(rng.randf_range(-1.0, 1.0), h / steps * k, rng.randf_range(-1.0, 1.0)), Vector3(w * f, h / steps, d * f), RED_ROCK[1 + k % 2].darkened(0.1), SceneryKit.PLAIN, false)


## A few red boulders, a big one with smaller ones leaning on it.
static func red_rocks(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var big := Vector3(1.8 + rng.randf() * 0.8, 1.1 + rng.randf() * 0.5, 1.6 + rng.randf() * 0.8)
	kit.box(at, big, RED_ROCK[1], SceneryKit.BRICK, true)
	kit.box(at + Vector3(rng.randf_range(-0.3, 0.3), big.y, rng.randf_range(-0.3, 0.3)), big * Vector3(0.7, 0.45, 0.7), RED_ROCK[2])
	for k in 2:
		var a := rng.randf() * TAU
		var size := Vector3(0.8 + rng.randf() * 0.5, 0.5 + rng.randf() * 0.4, 0.8 + rng.randf() * 0.5)
		kit.box(at + Vector3(cos(a), 0.0, sin(a)) * (big.x * 0.5 + size.x * 0.4), size, RED_ROCK[[0, 3][k]], SceneryKit.BRICK, false)


## A tall saguaro cactus, round and chunky, with one to three arms that turn
## up, and sometimes a flower on top.
static func saguaro(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := 5.5 + rng.randf() * 2.5
	kit.cylinder(at, 0.5, h, CACTUS_GREEN, SceneryKit.BRICK, true)
	kit.cylinder(at + Vector3.UP * h, 0.38, 0.35, CACTUS_GREEN.lightened(0.08), SceneryKit.SMOOTH)
	var arms := 1 + rng.randi() % 3
	var turn := rng.randf() * TAU
	for k in arms:
		var a := turn + k * TAU / arms + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		var y := h * rng.randf_range(0.35, 0.6)
		var reach := 1.4 + rng.randf() * 0.3
		kit.turned_cylinder(at + out * reach * 0.5 + Vector3.UP * y, 0.32, reach, Basis(Quaternion(Vector3.UP, out)), CACTUS_GREEN)
		var up := 1.2 + rng.randf() * 1.4
		kit.cylinder(at + out * reach + Vector3.UP * (y - 0.3), 0.32, up + 0.3, CACTUS_GREEN)
		kit.cylinder(at + out * reach + Vector3.UP * (y + up), 0.24, 0.2, CACTUS_GREEN.lightened(0.08), SceneryKit.SMOOTH)
	if rng.randf() < 0.4:
		kit.cylinder(at + Vector3.UP * (h + 0.35), 0.2, 0.2, [WHITE, PINK, YELLOW][rng.randi() % 3], SceneryKit.SMOOTH)


## A wooden water tank on four legs with a pointed roof and a spout.
static func water_tower(kit: SceneryKit, at: Vector3) -> void:
	var legs := 7.0
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			kit.box(at + Vector3(x, 0.0, z), Vector3(0.45, legs, 0.45), WOOD.darkened(0.2), SceneryKit.BRICK, true)
	for y in [2.2, 4.8]:
		for s in [-1.8, 1.8]:
			kit.box(at + Vector3(s, y, 0.0), Vector3(0.2, 0.25, 3.6), WOOD.darkened(0.3), SceneryKit.SMOOTH, false)
			kit.box(at + Vector3(0.0, y, s), Vector3(3.6, 0.25, 0.2), WOOD.darkened(0.3), SceneryKit.SMOOTH, false)
	kit.box(at + Vector3.UP * legs, Vector3(5.2, 0.3, 5.2), WOOD.darkened(0.25), SceneryKit.SMOOTH, false)
	kit.cylinder(at + Vector3.UP * (legs + 0.3), 2.5, 3.8, WOOD, SceneryKit.BRICK)
	for y in [0.6, 1.9, 3.2]:
		kit.cylinder(at + Vector3.UP * (legs + 0.3 + y), 2.58, 0.18, BLACK, SceneryKit.SMOOTH)
	kit.cone(at + Vector3.UP * (legs + 4.1), 2.8, 1.8, DARK_GREY)
	# The spout swung up against the side.
	kit.box(at + Vector3(2.6, legs - 0.6, 0.0), Vector3(0.3, 1.4, 0.3), BLACK, SceneryKit.SMOOTH, false)


## An old west saloon: a false front taller than the roof with a sign on it,
## a porch with posts, swinging doors and a hitching rail.
static func saloon(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var w := 9.0
	var d := 8.0
	var wood: Color = [WOOD, Color("#9a6440"), Color("#b07a4a")][rng.randi() % 3]
	var trim: Color = [RED, GREEN, DARK_BLUE][rng.randi() % 3]
	_box(kit, at, Vector3.ZERO, Vector3(w, 5.0, d), facing, wood)
	_roof(kit, at + Vector3.UP * 5.0, w, d, deg_to_rad(16.0), facing + 1, wood.darkened(0.35))
	# The false front, stepped at the top.
	_box(kit, at, Vector3(0.0, 0.0, d * 0.5), Vector3(w + 0.4, 7.2, 0.4), facing, wood.lightened(0.08))
	_box(kit, at, Vector3(0.0, 7.2, d * 0.5), Vector3(w * 0.5, 0.9, 0.4), facing, wood.lightened(0.08))
	_box(kit, at, Vector3(0.0, 8.1, d * 0.5), Vector3(w * 0.5 + 0.4, 0.2, 0.5), facing, trim, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 7.2, d * 0.5), Vector3(w + 0.6, 0.2, 0.5), facing, trim, SceneryKit.SMOOTH, false)
	# The sign: a pale board in a coloured frame, with a few dark letters.
	_box(kit, at, Vector3(0.0, 5.3, d * 0.5 + 0.25), Vector3(6.4, 1.5, 0.1), facing, trim, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 5.45, d * 0.5 + 0.3), Vector3(6.0, 1.2, 0.1), facing, PALE_ROCK.lightened(0.3), SceneryKit.SMOOTH, false)
	for k in 6:
		_box(kit, at, Vector3(-2.25 + k * 0.9, 5.7, d * 0.5 + 0.36), Vector3(0.5, 0.7, 0.05), facing, BLACK, SceneryKit.SMOOTH, false)
	# Windows and the swinging doors.
	for x in [-3.0, 3.0]:
		_box(kit, at, Vector3(x, 1.2, d * 0.5 + 0.2), Vector3(1.6, 1.6, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(x, 3.6, d * 0.5 + 0.2), Vector3(1.2, 1.2, 0.1), facing, GLASS, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.0, d * 0.5 + 0.2), Vector3(1.8, 2.6, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)
	for x in [-0.45, 0.45]:
		_box(kit, at, Vector3(x, 0.8, d * 0.5 + 0.3), Vector3(0.8, 1.2, 0.1), facing, wood.darkened(0.3), SceneryKit.SMOOTH, false)
	# The porch, its posts and its roof. None of it is solid, so karts
	# don't ride up onto it.
	_box(kit, at, Vector3(0.0, 0.0, d * 0.5 + 1.4), Vector3(w + 0.4, 0.25, 2.6), facing, wood.darkened(0.2), SceneryKit.BRICK, false)
	for x in [-4.4, -1.5, 1.5, 4.4]:
		_box(kit, at, Vector3(x, 0.4, d * 0.5 + 2.5), Vector3(0.3, 3.0, 0.3), facing, wood.darkened(0.2), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 3.4, d * 0.5 + 1.4), Vector3(w + 0.6, 0.25, 2.8), facing, trim.darkened(0.2), SceneryKit.SMOOTH, false)
	# A hitching rail and a barrel.
	for x in [-3.0, 3.0]:
		_box(kit, at, Vector3(x, 0.0, d * 0.5 + 4.4), Vector3(0.25, 1.1, 0.25), facing, wood.darkened(0.3), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.9, d * 0.5 + 4.4), Vector3(6.4, 0.2, 0.2), facing, wood.darkened(0.3), SceneryKit.SMOOTH, false)
	kit.cylinder(at + _turn(Vector3(w * 0.5 + 1.0, 0.0, d * 0.5 + 1.0), facing), 0.5, 1.1, WOOD.darkened(0.1), SceneryKit.BRICK)
	kit.cylinder(at + _turn(Vector3(w * 0.5 + 1.0, 0.35, d * 0.5 + 1.0), facing), 0.53, 0.1, BLACK, SceneryKit.SMOOTH)


## The mouth of an old mine in a heap of red rock, with a timber frame, and
## rails coming out of it with two ore carts, one full of gold.
static func mine_carts(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	# The rock heap and the mine mouth at the back.
	_box(kit, at, Vector3(0.0, 0.0, -4.5), Vector3(11.0, 3.0, 6.0), facing, RED_ROCK[1])
	_box(kit, at, Vector3(0.3, 3.0, -5.0), Vector3(8.0, 2.4, 5.0), facing, RED_ROCK[2])
	_box(kit, at, Vector3(-0.4, 5.4, -5.4), Vector3(4.6, 1.6, 3.6), facing, RED_ROCK[3])
	_box(kit, at, Vector3(0.0, 0.0, -1.45), Vector3(2.8, 3.0, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)
	for x in [-1.6, 1.6]:
		_box(kit, at, Vector3(x, 0.0, -1.35), Vector3(0.45, 3.4, 0.45), facing, WOOD.darkened(0.2), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 3.4, -1.35), Vector3(4.0, 0.5, 0.5), facing, WOOD.darkened(0.2), SceneryKit.SMOOTH, false)
	# The rails, on sleepers, running out to the front.
	for k in 7:
		_box(kit, at, Vector3(0.0, 0.0, -1.0 + k * 1.0), Vector3(1.8, 0.12, 0.35), facing, WOOD.darkened(0.35), SceneryKit.SMOOTH, false)
	for x in [-0.55, 0.55]:
		_box(kit, at, Vector3(x, 0.12, 2.0), Vector3(0.12, 0.12, 6.8), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	for k in 2:
		var z := 0.6 + k * 2.6
		var load: Color = YELLOW if k == 0 else [DARK_GREY, RED_ROCK[0]][rng.randi() % 2]
		for x in [-0.55, 0.55]:
			for zz in [-0.55, 0.55]:
				var wheel := at + _turn(Vector3(x, 0.4, z + zz), facing)
				kit.turned_cylinder(wheel, 0.3, 0.15, Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5) * Basis(Vector3.BACK, PI * 0.5), BLACK)
		_box(kit, at, Vector3(0.0, 0.5, z), Vector3(1.6, 1.0, 2.0), facing, RUST)
		_box(kit, at, Vector3(0.0, 1.45, z), Vector3(1.8, 0.15, 2.2), facing, DARK_GREY, SceneryKit.SMOOTH, false)
		for n in 5:
			_box(kit, at, Vector3(rng.randf_range(-0.5, 0.5), 1.5, z + rng.randf_range(-0.6, 0.6)), Vector3(0.45, 0.4, 0.45), facing, load, SceneryKit.SMOOTH, false)


## A farm windpump: a steel lattice tower with a wheel of blades that turns
## in the wind, a tail fin, and a round tank at its foot.
static func windpump(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var h := 10.0
	var spread := 1.6
	var top_spread := 0.4
	# Four legs leaning in, and rungs across.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var foot := at + Vector3(x * spread, 0.0, z * spread)
			var head := at + Vector3(x * top_spread, h, z * top_spread)
			kit.turned_box((foot + head) * 0.5, Vector3(0.18, foot.distance_to(head), 0.18), Basis(Quaternion(Vector3.UP, (head - foot).normalized())), LIGHT_GREY)
	for k in 4:
		var y := 1.5 + k * 2.2
		var s := lerpf(spread, top_spread, y / h) * 2.0
		for side in [-1.0, 1.0]:
			kit.box(at + Vector3(side * s * 0.5, y, 0.0), Vector3(0.12, 0.12, s), LIGHT_GREY, SceneryKit.SMOOTH, false)
			kit.box(at + Vector3(0.0, y, side * s * 0.5), Vector3(s, 0.12, 0.12), LIGHT_GREY, SceneryKit.SMOOTH, false)
	kit.box(at, Vector3(0.6, 0.6, 0.6), DARK_GREY, SceneryKit.SMOOTH, true)
	kit.box(at + Vector3.UP * h, Vector3(1.2, 0.5, 1.2), DARK_GREY, SceneryKit.SMOOTH, false)
	var face := Basis(Vector3.UP, -posmod(facing, 4) * PI * 0.5)
	# The tail fin out the back.
	kit.turned_box(at + Vector3.UP * (h + 0.7) + face * Vector3(0.0, 0.0, -1.6), Vector3(0.1, 0.2, 3.0), face, DARK_GREY)
	kit.turned_box(at + Vector3.UP * (h + 0.7) + face * Vector3(0.0, 0.0, -3.4), Vector3(0.1, 1.4, 1.8), face, RED)
	var hub := at + Vector3.UP * (h + 0.7) + face * Vector3(0.0, 0.0, 0.9)
	kit.begin_mover(Transform3D(face, hub), { "spin": Vector3.BACK, "speed": 1.4 })
	for k in 12:
		var blade := face * Basis(Vector3.BACK, k * TAU / 12.0) * Basis(Vector3.UP, 0.4)
		kit.turned_box(hub + face * Basis(Vector3.BACK, k * TAU / 12.0) * Vector3(0.0, 1.35, 0.0), Vector3(0.5, 1.7, 0.06), blade, WHITE)
	kit.turned_cylinder(hub, 0.5, 0.3, face * Basis(Vector3.RIGHT, PI * 0.5), RED)
	kit.end_mover()
	# The water tank, a little way off.
	var tank := at + face * Vector3(2.8, 0.0, 1.0)
	kit.cylinder(tank, 1.5, 1.0, LIGHT_GREY, SceneryKit.BRICK, true)
	kit.cylinder(tank + Vector3.UP * 0.9, 1.35, 0.12, WATER, SceneryKit.WATER)


# The jungle.

const LEAVES := [Color("#3d8a35"), Color("#4ea13e"), Color("#62b043"), Color("#3a7d3e")]
const VINE := Color("#5f8f2a")
const BARK := Color("#7a5a3c")
const TEMPLE := Color("#b9b29c")
const MOSS := Color("#6a8a3a")
const BASALT := Color("#948f80")
const KARST := [Color("#8d8c80"), Color("#9a988b"), Color("#7f7e74"), Color("#a5a396")]
const ROPE := Color("#b89a62")
const THATCH := Color("#b99a58")


## A tall rainforest tree: a pale trunk on wide roots, a big flat crown in
## two layers with a lower one off to the side, and vines hanging down.
static func jungle_tree(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := 7.0 + rng.randf() * 3.5
	kit.cylinder(at + Vector3.DOWN * 0.5, 0.55, h + 0.5, BARK, SceneryKit.BRICK, true)
	# Two crossed fins through the trunk make the four buttress roots.
	var turn := rng.randf() * PI
	for k in 2:
		kit.turned_box(at + Vector3.UP * 0.6, Vector3(0.25, 1.8, 3.1), Basis(Vector3.UP, turn + k * PI * 0.5), BARK.darkened(0.15))
	var green: Color = LEAVES[rng.randi() % LEAVES.size()]
	var size := 6.0 + rng.randf() * 2.0
	kit.box(at + Vector3.UP * h, Vector3(size, 1.8, size), green, SceneryKit.BRICK, false)
	kit.box(at + Vector3(0.3, h + 1.8, -0.2), Vector3(size * 0.65, 1.2, size * 0.65), green.lightened(0.1), SceneryKit.BRICK, false)
	# A lower branch with its own crown.
	var a := rng.randf() * TAU
	var out := Vector3(cos(a), 0.0, sin(a))
	var y := h * rng.randf_range(0.55, 0.7)
	var tip := at + out * 2.6 + Vector3.UP * (y + 1.2)
	var foot := at + Vector3.UP * y
	kit.turned_box((foot + tip) * 0.5, Vector3(0.3, foot.distance_to(tip), 0.3), Basis(Quaternion(Vector3.UP, (tip - foot).normalized())), BARK)
	kit.box(tip, Vector3(3.2, 1.2, 3.2), green.darkened(0.05), SceneryKit.BRICK, false)
	# Vines hanging down from the big crown.
	for k in 2:
		var b := turn + k * PI + rng.randf_range(-0.6, 0.6)
		var r := rng.randf_range(1.5, size * 0.42)
		var drop := rng.randf_range(2.5, h - 2.0)
		kit.box(at + Vector3(cos(b) * r, h - drop, sin(b) * r), Vector3(0.14, drop, 0.14), VINE, SceneryKit.SMOOTH, false)
	if rng.randf() < 0.08:
		parrot(kit, tip + Vector3.UP * 0.6, rng.randi() % 4, rng)


## A young rainforest tree for the undergrowth: a thin trunk with a small
## crown, and a vine.
static func jungle_sapling(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := 3.5 + rng.randf() * 2.0
	kit.box(at, Vector3(0.3, h, 0.3), BARK, SceneryKit.BRICK, true)
	var green: Color = LEAVES[rng.randi() % LEAVES.size()]
	var size := 2.4 + rng.randf() * 1.0
	kit.box(at + Vector3.UP * h, Vector3(size, 1.0, size), green, SceneryKit.BRICK, false)
	kit.box(at + Vector3.UP * (h + 1.0), Vector3(size * 0.6, 0.7, size * 0.6), green.lightened(0.1), SceneryKit.BRICK, false)


## A big leafy bush: a wide clump with a smaller one on top.
static func jungle_bush(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var green: Color = LEAVES[rng.randi() % LEAVES.size()]
	var size := Vector3(rng.randf_range(2.2, 3.2), rng.randf_range(1.3, 1.9), rng.randf_range(2.2, 3.2))
	kit.box(at, size, green.darkened(0.08), SceneryKit.BRICK, false)
	kit.box(at + Vector3(rng.randf_range(-0.4, 0.4), size.y, rng.randf_range(-0.4, 0.4)), size * Vector3(0.6, 0.6, 0.6), green.lightened(0.08), SceneryKit.BRICK, false)


## A fern: a fan of long green fronds.
static func fern(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var green: Color = LEAVES[rng.randi() % LEAVES.size()].lightened(0.1)
	var count := 5
	var turn := rng.randf() * TAU
	for k in count:
		var a := turn + k * TAU / count
		var length := rng.randf_range(1.8, 2.5)
		var lift := rng.randf_range(0.45, 0.8)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -lift)
		kit.turned_box(at + Vector3(sin(a), 0.0, cos(a)) * length * 0.45 + Vector3.UP * (0.35 + sin(lift) * length * 0.5), Vector3(0.55, 0.06, length), basis, green if k % 2 == 0 else green.darkened(0.12))


## A parrot sitting on something, about a metre tall, facing `facing`: a
## round body, bright wings, a long tail hanging down and a big beak. It
## bobs its head, unless it's a far filler, which stays still so it can drop
## out in the distance like the others.
static func parrot(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var looks := [[RED, BLUE, YELLOW], [BLUE, YELLOW, BLUE.darkened(0.3)], [BRIGHT_GREEN, RED, BLUE]]
	var look: Array = looks[rng.randi() % looks.size()]
	var body: Color = look[0]
	var wing: Color = look[1]
	var tail: Color = look[2]
	var face := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5)
	# The body, the wings as one piece showing down both sides, and the tail.
	kit.turned_box(at + face * Vector3(0.0, 0.45, 0.0), Vector3(0.45, 0.65, 0.42), face * Basis(Vector3.RIGHT, 0.15), body)
	kit.turned_box(at + face * Vector3(0.0, 0.45, -0.04), Vector3(0.6, 0.6, 0.38), face * Basis(Vector3.RIGHT, 0.2), wing)
	kit.turned_box(at + face * Vector3(0.0, 0.05, -0.32), Vector3(0.18, 0.75, 0.08), face * Basis(Vector3.RIGHT, -0.35), tail)
	# The head, which bobs.
	var bob := 3.0 + rng.randf()
	if not kit.far:
		kit.begin_mover(Transform3D(face, at + face * Vector3(0.0, 0.8, 0.05)), { "bob": 0.04, "rate": bob })
	var head := at + face * Vector3(0.0, 0.8, 0.05)
	kit.turned_box(head + Vector3.UP * 0.18, Vector3(0.4, 0.36, 0.38), face, body)
	# A pale cheek patch across the face with a black eye each side, and the
	# hooked beak.
	kit.turned_box(head + face * Vector3(0.0, 0.2, 0.06), Vector3(0.43, 0.2, 0.2), face, WHITE)
	for x in [-0.215, 0.215]:
		kit.turned_box(head + face * Vector3(x, 0.24, 0.07), Vector3(0.02, 0.08, 0.08), face, BLACK)
	kit.turned_box(head + face * Vector3(0.0, 0.2, 0.27), Vector3(0.2, 0.24, 0.18), face, DARK_GREY)
	kit.end_mover()


## Two or three parrots on a wooden perch.
static func parrots(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	kit.box(at, Vector3(0.3, 2.4, 0.3), WOOD, SceneryKit.BRICK, true)
	_box(kit, at, Vector3(0.0, 2.4, 0.0), Vector3(2.4, 0.2, 0.2), facing, WOOD.darkened(0.15), SceneryKit.SMOOTH, false)
	var count := 2 + rng.randi() % 2
	for k in count:
		var x := -0.8 + k * 1.6 / maxf(count - 1, 1)
		parrot(kit, at + _turn(Vector3(x, 2.5, 0.0), facing), facing, rng)


## A stepped pyramid of pale stone from the old jungle cities: terraces
## going up, a wide stair up the front, a little temple on top with a dark
## door, and moss and vines over it all.
static func stepped_pyramid(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var tiers := 6
	var base := 24.0
	var rise := 2.4
	var inset := 1.7
	for k in tiers:
		var w := base - k * inset * 2.0
		var bottom := -2.0 if k == 0 else k * rise
		var tall := rise + (2.0 if k == 0 else 0.0)
		_box(kit, at, Vector3(0.0, bottom, 0.0), Vector3(w, tall, w), facing, TEMPLE.darkened(0.06 * (k % 2)), SceneryKit.BRICK, k < 2)
		# A ledge along the top of each terrace, with moss on it here and there.
		_box(kit, at, Vector3(0.0, (k + 1) * rise - 0.3, 0.0), Vector3(w + 0.3, 0.3, w + 0.3), facing, TEMPLE.lightened(0.08), SceneryKit.SMOOTH, false)
		for m in 3:
			var side := rng.randi() % 4
			var along := rng.randf_range(-0.4, 0.4) * w
			var spot := Vector3(along, (k + 1) * rise, w * 0.5 - 0.6)
			_box(kit, at, _turn(spot, side), _turn_size(Vector3(rng.randf_range(1.5, 3.5), 0.4, 1.2), side), facing, MOSS, SceneryKit.BRICK, false)
			if rng.randf() < 0.5:
				var hang := rng.randf_range(1.0, rise)
				_box(kit, at, _turn(spot + Vector3(0.0, -hang, 0.7), side), _turn_size(Vector3(0.15, hang, 0.15), side), facing, VINE, SceneryKit.SMOOTH, false)
	# The stair up the front, as one block per step from the ground, with a
	# darker rail each side.
	var top := tiers * rise
	var front := base * 0.5
	var back := base * 0.5 - (tiers - 1) * inset
	var steps := 24
	for s in steps:
		var y := float(s + 1) / steps * top
		var z := front - (front - back) * float(s) / steps
		_box(kit, at, Vector3(0.0, -2.0, z - 0.2), Vector3(5.0, y + 2.0, 0.8), facing, TEMPLE.lightened(0.05), SceneryKit.SMOOTH, false)
	var slope := atan2(top, front - back)
	var length := Vector2(front - back, top).length()
	for x in [-2.8, 2.8]:
		var mid := _turn(Vector3(x, top * 0.5 + 0.3, (front + back) * 0.5), facing)
		var basis := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5) * Basis(Vector3.RIGHT, slope)
		kit.turned_box(at + mid, Vector3(0.7, 0.7, length + 0.4), basis, TEMPLE.darkened(0.15))
	# The temple on top, with a red band, a dark door and a crest on its roof.
	var room := back - 1.0
	_box(kit, at, Vector3(0.0, top, 0.0), Vector3(room * 1.6, 3.6, room * 1.4), facing, TEMPLE.lightened(0.04))
	_box(kit, at, Vector3(0.0, top + 2.7, 0.0), Vector3(room * 1.6 + 0.3, 0.5, room * 1.4 + 0.3), facing, Color("#a0452e"), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, top, room * 0.7 + 0.02), Vector3(1.6, 2.4, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, top + 3.6, 0.0), Vector3(room * 1.2, 0.6, room * 1.0), facing, TEMPLE)
	_box(kit, at, Vector3(0.0, top + 4.2, -0.4), Vector3(room * 1.0, 2.4, 0.6), facing, TEMPLE.darkened(0.05))
	for x in [-1.0, 1.0]:
		_box(kit, at, Vector3(x, top + 5.0, -0.08), Vector3(0.6, 0.8, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)
	# A couple of small trees grown on the terraces.
	for t in 2:
		var k := 1 + rng.randi() % (tiers - 2)
		var w := base - k * inset * 2.0
		var spot := Vector3(rng.randf_range(-0.3, 0.3) * w, k * rise, (-1.0 if t == 0 else 1.0) * (w * 0.5 - inset * 0.5))
		if absf(spot.x) < 3.5 and spot.z > 0.0:
			spot.x = 4.5
		var where := at + _turn(spot, facing)
		kit.box(where, Vector3(0.3, 1.2, 0.3), BARK, SceneryKit.SMOOTH, false)
		kit.box(where + Vector3.UP * 1.2, Vector3(2.0, 1.0, 2.0), LEAVES[t], SceneryKit.BRICK, false)


## A big round stone head with a helmet, looking out from under a heavy
## brow with a broad nose and a little smile, sat on the ground.
static func stone_head(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var stone := BASALT.lightened(rng.randf_range(-0.05, 0.08))
	var face := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5)
	# Built at 1, then scaled up so it stands out as a landmark from the road.
	var k := 1.8
	# The jaw, the face and the top of the head.
	_box(kit, at, Vector3(0.0, -0.5, 0.0) * k, Vector3(2.6, 1.3, 2.4) * k, facing, stone.darkened(0.05))
	_box(kit, at, Vector3(0.0, 0.8, 0.0) * k, Vector3(3.0, 1.9, 2.7) * k, facing, stone)
	_box(kit, at, Vector3(0.0, 2.7, 0.0) * k, Vector3(2.8, 0.5, 2.5) * k, facing, stone)
	# The helmet, with a band across the front and a strap down each side.
	_box(kit, at, Vector3(0.0, 3.0, -0.05) * k, Vector3(3.2, 0.8, 2.85) * k, facing, stone.darkened(0.08), SceneryKit.BRICK, false)
	_box(kit, at, Vector3(0.0, 3.8, -0.1) * k, Vector3(2.7, 0.4, 2.4) * k, facing, stone.darkened(0.08), SceneryKit.BRICK, false)
	_box(kit, at, Vector3(0.0, 2.95, 1.35) * k, Vector3(3.0, 0.35, 0.25) * k, facing, stone.lightened(0.1), SceneryKit.SMOOTH, false)
	for x in [-1.55, 1.55]:
		_box(kit, at, Vector3(x, 1.2, 0.3) * k, Vector3(0.2, 1.8, 0.7) * k, facing, stone.darkened(0.08), SceneryKit.SMOOTH, false)
		# A round plug in each ear.
		kit.turned_cylinder(at + _turn(Vector3(x * 1.06, 1.5, 0.0) * k, facing), 0.45 * k, 0.25 * k, face * Basis(Vector3.BACK, PI * 0.5), stone.lightened(0.06))
	# The brow, the eyes looking out, the broad nose and the lips.
	var front := 1.35
	_box(kit, at, Vector3(0.0, 2.35, front) * k, Vector3(2.4, 0.25, 0.25) * k, facing, stone.darkened(0.05), SceneryKit.SMOOTH, false)
	for x in [-0.65, 0.65]:
		_box(kit, at, Vector3(x, 1.85, front) * k, Vector3(0.75, 0.38, 0.1) * k, facing, stone.lightened(0.25), SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(x * 0.92, 1.88, front + 0.06) * k, Vector3(0.28, 0.32, 0.06) * k, facing, BLACK, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 1.15, front) * k, Vector3(0.55, 0.8, 0.35) * k, facing, stone.lightened(0.04), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 1.0, front + 0.1) * k, Vector3(1.0, 0.4, 0.35) * k, facing, stone.lightened(0.04), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.45, front) * k, Vector3(1.3, 0.38, 0.22) * k, facing, stone.lightened(0.08), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.6, front + 0.12) * k, Vector3(1.0, 0.07, 0.04) * k, facing, BLACK, SceneryKit.SMOOTH, false)
	for x in [-0.55, 0.55]:
		_box(kit, at, Vector3(x, 0.66, front + 0.12) * k, Vector3(0.18, 0.07, 0.04) * k, facing, BLACK, SceneryKit.SMOOTH, false)
	# Moss on top.
	for m in 2:
		_box(kit, at, Vector3(rng.randf_range(-0.8, 0.8), 4.2, rng.randf_range(-0.8, 0.4)) * k, Vector3(rng.randf_range(0.8, 1.4), 0.15, rng.randf_range(0.8, 1.2)) * k, facing, MOSS, SceneryKit.BRICK, false)


## A waterfall pouring off a mossy cliff into a round pool, with foam where
## it lands and ferns and trees along the top.
static func waterfall(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var w := 18.0
	var h := 13.0 + rng.randf() * 3.0
	# The cliff in rough bands, each a little set back from the one below.
	var bands := 4
	for k in bands:
		var y := -2.0 + k * (h + 2.0) / bands
		var tall := (h + 2.0) / bands
		var colour: Color = ROCKS[k % ROCKS.size()].darkened(0.05)
		_box(kit, at, Vector3(rng.randf_range(-0.6, 0.6), y, -5.0 - k * 0.4), Vector3(w - k * 0.8, tall, 9.0), facing, colour, SceneryKit.PLAIN, k == 0)
		# Moss along each ledge.
		_box(kit, at, Vector3(rng.randf_range(-3.0, 3.0), y + tall - 0.2, -0.6 - k * 0.4), Vector3(w * 0.5, 0.4, 0.8), facing, MOSS, SceneryKit.PLAIN, false)
	# Boulders along the foot.
	for k in 4:
		var x := (-1.0 if k % 2 == 0 else 1.0) * rng.randf_range(4.0, 8.0)
		_box(kit, at, Vector3(x, -0.4, rng.randf_range(0.0, 1.5)), Vector3(rng.randf_range(1.5, 3.0), rng.randf_range(1.0, 2.2), rng.randf_range(1.5, 2.5)), facing, ROCKS[k % ROCKS.size()], SceneryKit.PLAIN, false)
	# A notch at the top where the stream comes over, and the falling water.
	_box(kit, at, Vector3(0.0, h - 0.05, -6.0), Vector3(3.8, 0.15, 8.0), facing, WATER, SceneryKit.WATER, false)
	_box(kit, at, Vector3(0.0, -0.2, -0.4), Vector3(3.4, h - 0.2, 0.6), facing, Color("#6fb6e0"), SceneryKit.WATER, false)
	for k in 6:
		var y := rng.randf_range(1.0, h - 2.0)
		_box(kit, at, Vector3(rng.randf_range(-1.2, 1.2), y, -0.05), Vector3(0.25, rng.randf_range(1.5, 3.5), 0.1), facing, WHITE.darkened(0.05), SceneryKit.SMOOTH, false)
	# The pool and the foam.
	var pool := at + _turn(Vector3(0.0, 0.0, 3.2), facing)
	kit.cylinder(pool + Vector3.DOWN * 0.1, 4.2, 0.2, WATER, SceneryKit.WATER)
	for k in 7:
		var a := k * TAU / 7.0 + rng.randf() * 0.4
		kit.box(pool + Vector3(cos(a) * 4.6, -0.2, sin(a) * 4.6), Vector3(1.4, 0.7, 1.4), ROCKS[k % ROCKS.size()], SceneryKit.PLAIN, false)
	for k in 4:
		kit.box(pool + _turn(Vector3(rng.randf_range(-1.4, 1.4), 0.0, rng.randf_range(-2.6, -1.6)), facing), Vector3(0.9, 0.3, 0.9), WHITE, SceneryKit.SMOOTH, false)
	# Ferns and a couple of trees along the top.
	for k in 3:
		var spot := Vector3(rng.randf_range(-w * 0.4, w * 0.4), h, rng.randf_range(-8.0, -2.5))
		if absf(spot.x) < 3.0:
			spot.x = 4.0 * signf(spot.x + 0.01)
		fern(kit, at + _turn(spot, facing), rng)
	for x in [-6.5, 6.5]:
		var top := at + _turn(Vector3(x, h, -6.0), facing)
		kit.box(top, Vector3(0.5, 2.5, 0.5), BARK, SceneryKit.SMOOTH, false)
		kit.box(top + Vector3.UP * 2.5, Vector3(4.0, 1.2, 4.0), LEAVES[1], SceneryKit.BRICK, false)


## A rope bridge from `from` to `to`: planks hung between two ropes,
## sagging in the middle, with hand ropes along each side. It stays still.
static func _rope_span(kit: SceneryKit, from: Vector3, to: Vector3, wide: float, sag: float) -> void:
	var along := to - from
	var flat := Vector3(along.x, 0.0, along.z).normalized()
	var side := flat.cross(Vector3.UP).normalized()
	var planks := maxi(6, int(along.length() / 0.9))
	var deck: Array[Vector3] = []
	for k in planks + 1:
		var t := float(k) / planks
		deck.append(from + along * t + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	for k in planks:
		var a: Vector3 = deck[k]
		var b: Vector3 = deck[k + 1]
		kit.turned_box((a + b) * 0.5, Vector3(wide, 0.08, a.distance_to(b) * 0.75), Basis.looking_at(b - a), WOOD.darkened(0.1 * (k % 2)), SceneryKit.SMOOTH)
	# The hand ropes, a straight piece over every two planks, on posts.
	for s in [-1.0, 1.0]:
		for k in range(0, planks, 2):
			var a: Vector3 = deck[k] + side * s * wide * 0.5 + Vector3.UP * 1.0
			var b: Vector3 = deck[mini(k + 2, planks)] + side * s * wide * 0.5 + Vector3.UP * 1.0
			kit.turned_box((a + b) * 0.5, Vector3(0.08, 0.08, a.distance_to(b) + 0.05), Basis.looking_at(b - a), ROPE, SceneryKit.SMOOTH)
			if k > 0:
				kit.box(deck[k] + side * s * wide * 0.5, Vector3(0.05, 1.0, 0.05), ROPE.darkened(0.15), SceneryKit.SMOOTH, false)


## A rope bridge between two banks of rock with wooden posts on them, far
## enough apart for a road through the middle (see SPANNING).
static func rope_bridge(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var span := 15.0
	var bank := 6.0
	for s in [-1.0, 1.0]:
		_box(kit, at, Vector3(s * (span + 0.5), -1.0, 0.0), Vector3(5.0, bank + 1.0, 7.0), facing, ROCKS[1], SceneryKit.PLAIN)
		_box(kit, at, Vector3(s * (span + 0.8), bank, 0.0), Vector3(4.0, 0.3, 6.0), facing, MOSS, SceneryKit.PLAIN, false)
		for z in [-1.1, 1.1]:
			_box(kit, at, Vector3(s * (span - 1.0), bank, z), Vector3(0.35, 2.0, 0.35), facing, WOOD.darkened(0.2), SceneryKit.SMOOTH, false)
			_box(kit, at, Vector3(s * (span - 1.0), bank + 2.0, z), Vector3(0.45, 0.2, 0.45), facing, WOOD.darkened(0.35), SceneryKit.SMOOTH, false)
		fern(kit, at + _turn(Vector3(s * (span + 2.0), bank + 0.3, rng.randf_range(-2.0, 2.0)), facing), rng)
	var from := at + _turn(Vector3(-(span - 1.0), bank + 0.2, 0.0), facing)
	var to := at + _turn(Vector3(span - 1.0, bank + 0.2, 0.0), facing)
	_rope_span(kit, from, to, 1.9, 1.0)


## A walkway up in the treetops: two giant trees with a deck round each and
## a rope bridge between them, a ladder up one, and parrots on the rails.
static func canopy_walk(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var gap := 9.0
	var deck := 9.0
	for s in [-1.0, 1.0]:
		var foot := at + _turn(Vector3(s * gap, 0.0, 0.0), facing)
		kit.cylinder(foot + Vector3.DOWN * 0.5, 1.0, deck + 7.0, BARK, SceneryKit.BRICK, true)
		for k in 4:
			var a := k * TAU / 4.0 + PI * 0.25
			kit.turned_box(foot + Vector3(cos(a), 0.0, sin(a)) * 1.6 + Vector3.UP * 0.9, Vector3(0.35, 2.6, 2.0), Basis(Vector3.UP, -a + PI * 0.5), BARK.darkened(0.15))
		# The deck round the trunk, with posts and a rail.
		kit.box(foot + Vector3.UP * deck, Vector3(4.6, 0.3, 4.6), WOOD, SceneryKit.BRICK, false)
		for x in [-2.1, 2.1]:
			for z in [-2.1, 2.1]:
				kit.box(foot + Vector3(x, deck + 0.3, z), Vector3(0.2, 1.1, 0.2), WOOD.darkened(0.2), SceneryKit.SMOOTH, false)
		for k in 4:
			var out := _turn(Vector3(0.0, 0.0, 2.1), k)
			kit.box(foot + out + Vector3.UP * (deck + 1.3), _turn_size(Vector3(4.4, 0.15, 0.15), k), ROPE, SceneryKit.SMOOTH, false)
		# The crown, high over the deck.
		var green: Color = LEAVES[rng.randi() % LEAVES.size()]
		kit.box(foot + Vector3.UP * (deck + 5.0), Vector3(8.0, 1.2, 8.0), green.darkened(0.12), SceneryKit.BRICK, false)
		kit.box(foot + Vector3.UP * (deck + 6.2), Vector3(10.0, 1.6, 10.0), green, SceneryKit.BRICK, false)
		kit.box(foot + Vector3.UP * (deck + 7.8), Vector3(6.0, 1.0, 6.0), green.lightened(0.12), SceneryKit.BRICK, false)
		for k in 5:
			var b := rng.randf() * TAU
			var top := foot + Vector3(cos(b) * 3.5, deck + 5.0, sin(b) * 3.5)
			var drop := rng.randf_range(2.0, 6.0)
			kit.box(top + Vector3.DOWN * drop, Vector3(0.12, drop, 0.12), VINE, SceneryKit.SMOOTH, false)
		parrot(kit, foot + _turn(Vector3(rng.randf_range(-1.5, 1.5), deck + 1.4, 2.1), facing), facing, rng)
	# A ladder up the first trunk.
	var ladder := at + _turn(Vector3(-gap, 0.0, 1.15), facing)
	for x in [-0.4, 0.4]:
		kit.box(ladder + _turn(Vector3(x, 0.0, 0.0), facing), Vector3(0.12, deck, 0.12), WOOD.darkened(0.3), SceneryKit.SMOOTH, false)
	for k in int(deck / 0.6):
		_box(kit, ladder, Vector3(0.0, 0.5 + k * 0.6, 0.0), Vector3(0.9, 0.1, 0.1), facing, WOOD.darkened(0.3), SceneryKit.SMOOTH, false)
	var from := at + _turn(Vector3(-gap + 2.3, deck + 0.15, 0.0), facing)
	var to := at + _turn(Vector3(gap - 2.3, deck + 0.15, 0.0), facing)
	_rope_span(kit, from, to, 1.6, 1.2)


## A tower of grey limestone standing straight up out of the jungle, in
## rough bands, with trees on its ledges and its top and vines down the
## sides. `size` scales it; a far one isn't solid.
static func karst(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, size: float, solid: bool) -> void:
	var own := RandomNumberGenerator.new()
	own.seed = rng.randi()
	var w := own.randf_range(14.0, 20.0) * size
	var d := own.randf_range(12.0, 18.0) * size
	var h := own.randf_range(30.0, 44.0) * size
	var bands := maxi(4, roundi(h / 5.0))
	var band := h / bands
	for k in bands:
		# Wider in the middle than at the foot, like it's been worn away.
		var f := 0.85 + 0.25 * sin(PI * (float(k) + 0.5) / bands) - 0.2 * float(k) / bands
		var shift := Vector3(own.randf_range(-0.5, 0.5), 0.0, own.randf_range(-0.5, 0.5)) * size
		var colour: Color = KARST[own.randi() % KARST.size()]
		kit.box(at + shift + Vector3.UP * (band * k - (2.0 if k == 0 else 0.0)), Vector3(w * f, band + (2.0 if k == 0 else 0.0), d * f), colour, SceneryKit.PLAIN, solid and k == 0)
		# Jungle growing on the ledges.
		for side in [-1.0, 1.0]:
			if k > 0 and own.randf() < 0.8:
				var corner := Vector3(own.randf_range(-0.3, 0.3) * w * f, band * k, side * d * f * 0.42)
				kit.box(at + shift + corner, Vector3(w * own.randf_range(0.3, 0.6), 1.6 * size, d * 0.25), LEAVES[own.randi() % LEAVES.size()].darkened(0.1), SceneryKit.PLAIN, false)
		if own.randf() < 0.5:
			var drop := band * own.randf_range(0.8, 1.6)
			var x := own.randf_range(-0.4, 0.4) * w * f
			kit.box(at + shift + Vector3(x, band * (k + 1) - drop, d * f * 0.5), Vector3(0.4 * size, drop, 0.4 * size), VINE.darkened(0.1), SceneryKit.PLAIN, false)
	# A jungle crown over the top.
	kit.box(at + Vector3.UP * h, Vector3(w * 0.85, 2.0 * size, d * 0.85), LEAVES[0], SceneryKit.PLAIN, false)
	kit.box(at + Vector3(own.randf_range(-1.0, 1.0), h + 2.0 * size, own.randf_range(-1.0, 1.0)), Vector3(w * 0.55, 1.6 * size, d * 0.55), LEAVES[2], SceneryKit.PLAIN, false)


## A house on stilts with a steep roof of thatch, a ladder to its porch and
## a canoe pulled up by it.
static func jungle_hut(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var stilts := 2.2
	for x in [-2.2, 2.2]:
		for z in [-1.8, 1.8]:
			_box(kit, at, Vector3(x, -0.5, z), Vector3(0.3, stilts + 0.5, 0.3), facing, BARK, SceneryKit.BRICK, true)
	_box(kit, at, Vector3(0.0, stilts, 0.6), Vector3(5.2, 0.3, 5.4), facing, WOOD.darkened(0.15), SceneryKit.BRICK, false)
	var walls: Color = [Color("#b89a62"), Color("#a8875a"), Color("#c2a46c")][rng.randi() % 3]
	_box(kit, at, Vector3(0.0, stilts + 0.3, -0.3), Vector3(4.6, 2.4, 3.6), facing, walls)
	# Bamboo poles up the front.
	for k in 6:
		_box(kit, at, Vector3(-2.0 + k * 0.8, stilts + 0.3, 1.52), Vector3(0.12, 2.4, 0.1), facing, walls.darkened(0.2), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, stilts + 0.3, 1.58), Vector3(1.0, 1.8, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)
	_roof(kit, at + Vector3.UP * (stilts + 2.7), 5.2, 4.6, deg_to_rad(38.0), facing + 1, THATCH, false)
	_box(kit, at, Vector3(0.0, stilts + 2.7, -0.3), Vector3(4.8, 0.3, 4.0), facing, THATCH.darkened(0.15), SceneryKit.SMOOTH, false)
	# A ladder up to the porch.
	for x in [-0.4, 0.4]:
		_box(kit, at, Vector3(x, 0.0, 3.6), Vector3(0.1, stilts + 0.3, 0.1), facing, WOOD.darkened(0.3), SceneryKit.SMOOTH, false)
	for k in 4:
		_box(kit, at, Vector3(0.0, 0.4 + k * 0.5, 3.6), Vector3(0.9, 0.08, 0.1), facing, WOOD.darkened(0.3), SceneryKit.SMOOTH, false)
	# The canoe, pointed at both ends.
	var canoe: Color = [RED, WOOD, Color("#9a6440")][rng.randi() % 3]
	_box(kit, at, Vector3(3.6, 0.0, 2.0), Vector3(0.8, 0.4, 3.0), facing, canoe, SceneryKit.SMOOTH, false)
	for z in [-1.0, 1.0]:
		_box(kit, at, Vector3(3.6, 0.05, 2.0 + z * 1.75), Vector3(0.55, 0.35, 0.5), facing, canoe, SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(3.6, 0.1, 2.0 + z * 2.15), Vector3(0.3, 0.32, 0.3), facing, canoe, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(3.6, 0.3, 2.0), Vector3(0.55, 0.12, 2.8), facing, BLACK, SceneryKit.SMOOTH, false)


# The city, always raced at night. Windows light up by themselves after dark
# (SceneryKit.WINDOWS), and signs and lanterns glow, so nothing here needs a
# real light.

const CITY_WALLS := [Color("#5b6470"), Color("#7a7f86"), Color("#4e5d6e"), Color("#8a7a6a"), Color("#c9b79c"), Color("#6a5a50")]
const NEON := [Color("#ff4fa3"), Color("#36d6f4"), Color("#f5cd2f"), Color("#8cff5a"), Color("#b39dff"), Color("#ff7a2a")]
const CONCRETE := Color("#9a9a94")
const LANTERN := Color("#ff5a3a")


## An office block with lit windows and a flat roof, with a box of machinery
## on top. Never wider than 10.5 m, so it fits its room.
static func city_block(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(7.5, 10.5)
	var d := rng.randf_range(7.5, 10.5)
	var h := rng.randf_range(10.0, 26.0)
	var colour: Color = CITY_WALLS[rng.randi() % CITY_WALLS.size()]
	_box(kit, at, Vector3.ZERO, Vector3(w, h, d), facing, colour, SceneryKit.WINDOWS)
	_box(kit, at, Vector3(0.0, h, 0.0), Vector3(w + 0.3, 0.4, d + 0.3), facing, colour.darkened(0.35), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(rng.randf_range(-1.5, 1.5), h + 0.4, rng.randf_range(-1.5, 1.5)), Vector3(3.0, 1.8, 2.4), facing, LIGHT_GREY, SceneryKit.SMOOTH, false)


## A row of three narrow terraced houses with lit windows, each its own
## colour, under one roof.
static func townhouses(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(7.0, 9.5)
	for k in 3:
		var colour: Color = [Color("#8a4a3a"), Color("#c9b79c"), Color("#f2f3f2"), Color("#6a5a50"), Color("#a05a3a")][rng.randi() % 5]
		_box(kit, at, Vector3(-4.0 + k * 4.0, 0.0, 0.0), Vector3(4.0, h, 6.0), facing, colour, SceneryKit.WINDOWS)
	_roof(kit, at + Vector3.UP * h, 12.0, 6.0, deg_to_rad(30.0), facing, DARK_GREY, false)
	_box(kit, at, Vector3(0.0, 0.0, 3.05), Vector3(12.0, 0.6, 0.1), facing, BLACK, SceneryKit.SMOOTH, false)


## A traffic light on a post, its lamps lit red, amber and green.
static func traffic_light(kit: SceneryKit, at: Vector3, facing: int) -> void:
	kit.cylinder(at, 0.12, 3.4, DARK_GREY, SceneryKit.SMOOTH, true)
	_box(kit, at, Vector3(0.0, 3.2, 0.1), Vector3(0.5, 1.5, 0.4), facing, BLACK, SceneryKit.SMOOTH, false)
	for k in 3:
		var lamp: Color = [Color("#3ae86a"), Color("#ffb020"), Color("#ff3b24")][k]
		_box(kit, at, Vector3(0.0, 3.3 + k * 0.45, 0.32), Vector3(0.3, 0.3, 0.06), facing, lamp, SceneryKit.GLOW, false)


## A glowing sign on two posts, in a bright colour.
static func neon_sign(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var colour: Color = NEON[rng.randi() % NEON.size()]
	for x in [-1.6, 1.6]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(0.25, 2.4, 0.25), facing, DARK_GREY)
	_box(kit, at, Vector3(0.0, 2.4, 0.0), Vector3(4.4, 1.8, 0.3), facing, BLACK, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 2.6, 0.12), Vector3(3.8, 1.4, 0.1), facing, colour, SceneryKit.GLOW, false)


## A small tree in a square planter.
static func street_tree(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	kit.box(at, Vector3(1.6, 0.5, 1.6), CONCRETE, SceneryKit.BRICK, false)
	kit.cylinder(at + Vector3.UP * 0.5, 0.15, 2.0, BROWN, SceneryKit.BRICK, true)
	var leaves: Color = [GREEN, BRIGHT_GREEN, Color("#3a7d3e")][rng.randi() % 3]
	kit.box(at + Vector3.UP * 2.3, Vector3(2.2, 1.6, 2.2), leaves, SceneryKit.BRICK, false)
	kit.box(at + Vector3.UP * 3.9, Vector3(1.4, 0.8, 1.4), leaves.lightened(0.1), SceneryKit.BRICK, false)


## A length of steel crash barrier on posts, along the way it faces.
static func armco(kit: SceneryKit, at: Vector3, facing: int) -> void:
	for x in [-2.8, 0.0, 2.8]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(0.2, 0.8, 0.2), facing, DARK_GREY)
	_box(kit, at, Vector3(0.0, 0.35, 0.15), Vector3(6.2, 0.35, 0.1), facing, LIGHT_GREY, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.8, 0.0), Vector3(6.2, 0.08, 0.3), facing, LIGHT_GREY, SceneryKit.SMOOTH, false)


## A red phone box with a lit window band and a domed top.
static func phone_box(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3.ZERO, Vector3(1.0, 2.5, 1.0), facing, RED)
	_box(kit, at, Vector3(0.0, 1.0, 0.0), Vector3(1.04, 1.1, 1.04), facing, Color("#ffe6b0"), SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, 2.5, 0.0), Vector3(1.15, 0.3, 1.15), facing, RED.darkened(0.15), SceneryKit.SMOOTH, false)


## A red double decker bus parked side on, with lit windows on both decks.
static func double_decker(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3(0.0, 0.4, 0.0), Vector3(10.5, 4.0, 2.5), facing, RED)
	for y in [1.5, 3.3]:
		_box(kit, at, Vector3(0.0, y, 0.0), Vector3(10.0, 0.8, 2.56), facing, Color("#ffe6b0"), SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, 4.4, 0.0), Vector3(10.3, 0.15, 2.3), facing, RED.darkened(0.2), SceneryKit.SMOOTH, false)
	for x in [-3.6, 3.4]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(1.1, 0.8, 2.6), facing, BLACK, SceneryKit.SMOOTH, false)


## A three wheeled taxi with a canopy roof, in a bright colour.
static func tuk_tuk(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var colour: Color = [YELLOW, AZURE, RED, GREEN][rng.randi() % 4]
	_box(kit, at, Vector3(0.0, 0.3, 0.3), Vector3(1.4, 0.8, 2.2), facing, colour)
	_box(kit, at, Vector3(0.0, 1.1, 0.0), Vector3(0.1, 0.9, 0.1), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 2.0, 0.5), Vector3(1.5, 0.15, 2.6), facing, colour.darkened(0.3), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.0, 0.3), Vector3(1.5, 0.4, 2.0), facing, BLACK, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.9, -0.85), Vector3(0.5, 0.2, 0.06), facing, Color("#fff1d6"), SceneryKit.GLOW, false)


## A tall narrow building covered in glowing signs: two long ones down the
## front and a big one on the roof.
static func neon_tower(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(30.0, 40.0)
	var colour: Color = CITY_WALLS[rng.randi() % 3]
	_box(kit, at, Vector3.ZERO, Vector3(11.0, h, 9.0), facing, colour, SceneryKit.WINDOWS)
	_box(kit, at, Vector3(0.0, h, 0.0), Vector3(11.4, 0.5, 9.4), facing, colour.darkened(0.4), SceneryKit.SMOOTH, false)
	for x in [-3.8, 3.8]:
		_box(kit, at, Vector3(x, 4.0, 4.7), Vector3(1.6, h - 8.0, 0.4), facing, NEON[rng.randi() % NEON.size()], SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, h + 0.5, 0.0), Vector3(0.4, 2.0, 0.4), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, h + 2.5, 0.0), Vector3(9.0, 3.0, 0.4), facing, NEON[rng.randi() % NEON.size()], SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, 0.0, 4.55), Vector3(6.0, 3.0, 0.1), facing, Color("#ffe6b0"), SceneryKit.GLOW, false)


## A red gate with two cross beams and paper lanterns glowing along the
## lower one.
static func lantern_gate(kit: SceneryKit, at: Vector3, facing: int) -> void:
	for x in [-3.0, 3.0]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(0.6, 6.0, 0.6), facing, RED)
	_box(kit, at, Vector3(0.0, 4.6, 0.0), Vector3(7.4, 0.5, 0.5), facing, RED, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 6.0, 0.0), Vector3(9.0, 0.6, 0.8), facing, BLACK, SceneryKit.SMOOTH, false)
	for x in [-1.8, -0.6, 0.6, 1.8]:
		_box(kit, at, Vector3(x, 3.5, 0.0), Vector3(0.6, 0.9, 0.6), facing, LANTERN, SceneryKit.GLOW, false)


## A road going into a tunnel under a grassy bank: a concrete face with a
## dark mouth, lamps over it, and the road running in.
static func tunnel_mouth(kit: SceneryKit, at: Vector3, facing: int) -> void:
	_box(kit, at, Vector3(0.0, 0.0, -4.0), Vector3(20.0, 8.0, 8.0), facing, Color("#4f6a44"), SceneryKit.PLAIN)
	_box(kit, at, Vector3(0.0, 0.0, 0.2), Vector3(16.0, 7.0, 0.8), facing, CONCRETE)
	_box(kit, at, Vector3(0.0, 0.0, 0.5), Vector3(10.0, 5.0, 0.4), facing, Color("#0e1014"), SceneryKit.PLAIN, false)
	_box(kit, at, Vector3(0.0, 5.4, 0.7), Vector3(7.0, 0.3, 0.2), facing, Color("#fff1d6"), SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, -0.05, 4.0), Vector3(10.0, 0.1, 6.0), facing, DARK_GREY, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.0, 4.0), Vector3(0.3, 0.02, 5.0), facing, WHITE, SceneryKit.SMOOTH, false)


## A very tall tower in steps, getting narrower up to a spire. `size`
## scales it, and only its base is solid, if `solid`.
static func spire_tower(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, size: float, solid: bool) -> void:
	var colour: Color = [Color("#7fa6c9"), Color("#5b7fa3"), Color("#a3b5c4")][rng.randi() % 3]
	var w := 14.0 * size
	var y := 0.0
	for k in 4:
		var h := (16.0 + rng.randf() * 10.0) * size
		kit.box(at + Vector3.UP * y, Vector3(w, h, w), colour, SceneryKit.WINDOWS, solid and k == 0)
		y += h
		w *= 0.7
	kit.cylinder(at + Vector3.UP * y, 0.6 * size, 22.0 * size, LIGHT_GREY, SceneryKit.SMOOTH)
	kit.box(at + Vector3.UP * (y + 22.0 * size), Vector3(0.8, 0.8, 0.8) * size, Color("#ff3b24"), SceneryKit.GLOW, false)


## A clock tower in pale stone with a lit clock face on each side, a belfry
## and a pointed spire.
static func clock_tower(kit: SceneryKit, at: Vector3, facing: int) -> void:
	var stone := Color("#c9b79c")
	_box(kit, at, Vector3.ZERO, Vector3(6.0, 22.0, 6.0), facing, stone)
	_box(kit, at, Vector3(0.0, 22.0, 0.0), Vector3(7.0, 6.0, 7.0), facing, stone.darkened(0.1), SceneryKit.BRICK, false)
	_box(kit, at, Vector3(0.0, 23.0, 0.0), Vector3(7.2, 4.0, 4.0), facing, Color("#fff1d6"), SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, 23.0, 0.0), Vector3(4.0, 4.0, 7.2), facing, Color("#fff1d6"), SceneryKit.GLOW, false)
	_box(kit, at, Vector3(0.0, 28.0, 0.0), Vector3(5.6, 4.0, 5.6), facing, stone.darkened(0.2), SceneryKit.BRICK, false)
	kit.cone(at + Vector3.UP * 32.0, 3.6, 9.0, Color("#3a4a3a"), SceneryKit.SMOOTH)
	kit.cylinder(at + Vector3.UP * 41.0, 0.12, 2.0, YELLOW, SceneryKit.SMOOTH)


## A stretch of raised expressway beside the road, on concrete pillars, with
## its own lamps.
static func overpass(kit: SceneryKit, at: Vector3, facing: int) -> void:
	for x in [-11.0, 0.0, 11.0]:
		_box(kit, at, Vector3(x, 0.0, 0.0), Vector3(2.0, 8.0, 2.0), facing, CONCRETE)
		_box(kit, at, Vector3(x, 7.0, 0.0), Vector3(2.4, 1.0, 9.0), facing, CONCRETE.darkened(0.1), SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 8.0, 0.0), Vector3(30.0, 1.2, 10.0), facing, CONCRETE, SceneryKit.SMOOTH, false)
	for z in [-4.8, 4.8]:
		_box(kit, at, Vector3(0.0, 9.2, z), Vector3(30.0, 0.9, 0.4), facing, LIGHT_GREY, SceneryKit.SMOOTH, false)
	for x in [-10.0, 0.0, 10.0]:
		_box(kit, at, Vector3(x, 9.2, 4.8), Vector3(0.2, 3.0, 0.2), facing, LIGHT_GREY, SceneryKit.SMOOTH, false)
		_box(kit, at, Vector3(x, 12.0, 4.2), Vector3(0.5, 0.25, 1.2), facing, Color("#fff1d6"), SceneryKit.LAMP, false)


## A temple spire in gold: square steps, a round bell and a long point.
static func chedi(kit: SceneryKit, at: Vector3) -> void:
	var gold := Color("#e0b030")
	kit.box(at, Vector3(10.0, 1.5, 10.0), WHITE, SceneryKit.BRICK, true)
	kit.box(at + Vector3.UP * 1.5, Vector3(7.5, 1.5, 7.5), WHITE, SceneryKit.BRICK, false)
	kit.cylinder(at + Vector3.UP * 3.0, 3.2, 5.0, gold, SceneryKit.SMOOTH)
	kit.cone(at + Vector3.UP * 8.0, 3.2, 3.0, gold, SceneryKit.SMOOTH)
	kit.cylinder(at + Vector3.UP * 11.0, 0.9, 2.0, gold.lightened(0.1), SceneryKit.SMOOTH)
	kit.cone(at + Vector3.UP * 13.0, 0.9, 9.0, gold, SceneryKit.SMOOTH)


# Fans.

const SHIRTS := [RED, BLUE, YELLOW, GREEN, WHITE, ORANGE, PINK, AZURE, DARK_BLUE, LIME]
const TROUSERS := [BLUE, BLACK, DARK_GREY, TAN, DARK_BLUE, WHITE, BROWN]
## Hair, and some caps in team colours.
const HAIR := [BROWN, BLACK, YELLOW, ORANGE, DARK_GREY, BROWN, BLACK, RED, BLUE]


## A brick figure fan standing at `offset` in a prop facing `facing`, looking out
## the front of it (towards +Z before it's turned).
static func fan(kit: SceneryKit, at: Vector3, offset: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var where := Transform3D(Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5 + PI + rng.randf_range(-0.25, 0.25)), at + _turn(offset, facing))
	kit.fan(where, SHIRTS[rng.randi() % SHIRTS.size()], TROUSERS[rng.randi() % TROUSERS.size()], HAIR[rng.randi() % HAIR.size()])


## A few fans behind a little fence, for a corner.
static func fan_line(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	for k in 4:
		_box(kit, at, Vector3(-3.0 + k * 2.0, 0.0, 0.6), Vector3(0.15, 1.0, 0.15), facing, WHITE, SceneryKit.SMOOTH, false)
	_box(kit, at, Vector3(0.0, 0.8, 0.6), Vector3(6.2, 0.12, 0.1), facing, WHITE, SceneryKit.SMOOTH, false)
	var x := -2.6
	while x < 2.6:
		fan(kit, at, Vector3(x, 0.0, rng.randf_range(-0.6, 0.1)), facing, rng)
		x += rng.randf_range(0.55, 0.9)
	kit.new_crowd()


# Up in the sky. Everything here floats, on an island of its own or in the
# air, and none of it is solid, since nothing stands under it.

## The balloon colours, in pairs for the stripes.
const BALLOON_STRIPES := [[RED, YELLOW], [BLUE, WHITE], [ORANGE, YELLOW], [Color("#7a3fa0"), PINK], [GREEN, YELLOW], [RED, WHITE], [AZURE, YELLOW]]


## A floating island that leaves nothing solid behind, for a sky prop to
## stand on.
static func _sky_isle(kit: SceneryKit, top: Vector3, radius: float, rng: RandomNumberGenerator, trees: int, falls: bool) -> void:
	var keep := kit.solids.size()
	floating_island(kit, top, radius, rng, trees, falls)
	kit.solids.resize(keep)


## A hot air balloon floating `lift` metres up: a wicker basket on ropes
## under a smooth round balloon in two colours of panels, narrowing to its
## mouth over the burner.
static func hot_air_balloon(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator, lift: float) -> void:
	var base := at + Vector3.UP * lift
	var stripes: Array = BALLOON_STRIPES[rng.randi() % BALLOON_STRIPES.size()]
	kit.box(base, Vector3(1.6, 1.1, 1.6), BROWN, SceneryKit.PLAIN, false)
	kit.box(base + Vector3.UP * 1.1, Vector3(1.8, 0.25, 1.8), TAN, SceneryKit.PLAIN, false)
	for x in [-0.75, 0.75]:
		for z in [-0.75, 0.75]:
			kit.box(base + Vector3(x, 1.35, z), Vector3(0.12, 2.0, 0.12), DARK_GREY, SceneryKit.SMOOTH, false)
	kit.cylinder(base + Vector3.UP * 2.6, 0.45, 0.5, DARK_GREY, SceneryKit.PLAIN)
	# The round top, and a cone below it down to the mouth. The panels are
	# thin slices of the same shapes a little bigger, which show through as
	# stripes from top to bottom.
	var centre := base + Vector3.UP * 9.2
	var size := Vector3(9.6, 10.4, 9.6)
	var neck := 3.8
	var below := centre + Vector3.DOWN * (2.6 + neck * 0.5)
	kit.ball(centre, size, Basis.IDENTITY, stripes[0])
	kit.stretched("cones", below, Vector3(8.3, neck, 8.3), Basis(Vector3.RIGHT, PI), stripes[0])
	for k in 4:
		var turn := Basis(Vector3.UP, k * PI * 0.25)
		kit.ball(centre, Vector3(size.x * 0.6, size.y * 1.04, size.z * 1.04), turn, stripes[1])
		kit.stretched("cones", below, Vector3(8.3 * 0.6, neck, 8.3 * 1.04), turn * Basis(Vector3.RIGHT, PI), stripes[1])
	kit.cylinder(base + Vector3.UP * 3.0, 1.15, 0.6, stripes[1], SceneryKit.PLAIN)


## An airship `length` metres long cruising past `lift` metres up, side on to
## the way it faces and centred on `at`: a smooth round hull with a red band,
## fins at the tail and a cabin with windows underneath, and two propellers.
static func airship(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator, lift: float, length := 26.0) -> void:
	var centre := at + Vector3.UP * lift
	var face := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5)
	var along := face * Basis(Vector3.BACK, PI * 0.5)
	var axis := face * Vector3.LEFT
	var hull: Color = [WHITE, LIGHT_GREY, Color("#e8d8b0")][rng.randi() % 3]
	var thick := 9.2
	kit.ball(centre, Vector3(thick, length, thick), along, hull)
	kit.ball(centre, Vector3(thick * 1.03, length * 0.12, thick * 1.03), along, RED)
	# Fins round the tail, sitting on the hull where it narrows.
	var tail := length * 0.38
	var hull_there := thick * 0.5 * sqrt(1.0 - pow(tail / (length * 0.5), 2.0))
	for k in 4:
		var fin := along * Basis(Vector3.UP, k * PI * 0.5)
		kit.turned_box(centre + axis * tail + fin * Vector3(0.0, 0.0, hull_there + 1.2), Vector3(0.3, 3.6, 3.0), fin, RED, SceneryKit.PLAIN)
	kit.turned_box(centre + Vector3.DOWN * 5.0 - axis * 1.0, Vector3(7.0, 1.6, 2.2), face, TAN, SceneryKit.PLAIN)
	kit.turned_box(centre + Vector3.DOWN * 4.9 - axis * 1.0, Vector3(6.0, 0.6, 2.3), face, GLASS)
	kit.turned_box(centre + Vector3.DOWN * 4.2 - axis * 1.0, Vector3(3.0, 0.8, 0.6), face, DARK_GREY, SceneryKit.PLAIN)
	for side in [-1.0, 1.0]:
		var hub: Vector3 = centre + Vector3.DOWN * 4.6 + axis * 3.5 + face * Vector3(0.0, 0.0, side * 2.0)
		kit.turned_box(hub, Vector3(0.4, 0.4, 0.4), face, DARK_GREY, SceneryKit.PLAIN)
		kit.turned_box(hub + axis * 0.3, Vector3(0.15, 2.4, 0.3), face * Basis(Vector3.RIGHT, 0.3), BROWN, SceneryKit.PLAIN)


## A big island with trees and a waterfall pouring off it, and a smaller
## one below that the water lands on and spills off again. The lower one and
## its spray stay inside ROOM (16 m) and DEPTH.
static func falls_isle(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	_sky_isle(kit, at + Vector3.DOWN * 3.0, 11.0, rng, 3, true)
	var a := rng.randf() * TAU
	_sky_isle(kit, at + Vector3(cos(a) * 8.5, -24.0, sin(a) * 8.5), 6.5, rng, 1, true)


## A rainbow standing on two clouds, side on to the way it faces. Its feet
## are well below the road. Its bands are plain, with no seams.
static func rainbow(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var face := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5)
	var foot := at + Vector3.DOWN * 10.0
	var bands := [RED, ORANGE, YELLOW, GREEN, BLUE, Color("#7a3fa0")]
	var steps := 9
	for b in bands.size():
		var r := 16.0 - b * 1.2
		for k in steps:
			var t := (k + 0.5) / steps * PI
			var spot := foot + face * Vector3(cos(t) * r, sin(t) * r, 0.0)
			var tilt := face * Basis(Vector3.BACK, t)
			kit.turned_box(spot, Vector3(1.25, r * PI / steps + 0.4, 1.0), tilt, bands[b], SceneryKit.PLAIN)
	for side in [-1.0, 1.0]:
		cloud(kit, foot + face * Vector3(side * 13.0, 0.0, 0.0), 10.0, rng)


## A tall weather vane on its own island: a pole with the four arms of the
## compass, and a golden rooster on an arrow at the top. A little shed
## stands by its foot.
static func weather_vane(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var top := at + Vector3.DOWN * 4.0
	_sky_isle(kit, top, 7.0, rng, 1, false)
	var gold := Color("#e0b030")
	kit.box(top, Vector3(1.4, 0.6, 1.4), DARK_GREY, SceneryKit.BRICK, false)
	kit.cylinder(top + Vector3.UP * 0.6, 0.25, 11.0, DARK_GREY, SceneryKit.SMOOTH)
	var y := top.y + 9.0
	var c := Vector3(top.x, y, top.z)
	for k in 4:
		var arm := Basis(Vector3.UP, k * PI * 0.5)
		kit.turned_box(c + arm * Vector3(0.0, 0.0, 1.4), Vector3(0.2, 0.2, 2.8), arm, DARK_GREY)
		kit.turned_box(c + arm * Vector3(0.0, 0.0, 2.9), Vector3(0.7, 0.7, 0.2), arm, gold)
	var face := Basis(Vector3.UP, posmod(facing, 4) * PI * 0.5 + 0.6)
	var v := Vector3(top.x, y + 2.4, top.z)
	kit.turned_box(v, Vector3(5.0, 0.2, 0.2), face, gold)
	kit.turned_box(v + face * Vector3(2.7, 0.0, 0.0), Vector3(0.8, 0.8, 0.2), face * Basis(Vector3.BACK, PI * 0.25), gold)
	kit.turned_box(v + face * Vector3(-2.6, 0.0, 0.0), Vector3(0.6, 1.2, 0.15), face, gold)
	# The rooster: body, tail feathers fanned up, head with a red comb.
	var r := v + Vector3.UP * 1.0
	kit.turned_box(r, Vector3(1.8, 1.0, 0.3), face, gold)
	for k in 3:
		kit.turned_box(r + face * Vector3(-1.0, 0.6, 0.0), Vector3(0.35, 1.6, 0.25), face * Basis(Vector3.BACK, 0.3 + k * 0.35), gold)
	kit.turned_box(r + face * Vector3(0.9, 0.8, 0.0), Vector3(0.6, 0.7, 0.3), face, gold)
	kit.turned_box(r + face * Vector3(0.9, 1.25, 0.0), Vector3(0.45, 0.3, 0.25), face, RED)
	kit.turned_box(r + face * Vector3(1.3, 0.75, 0.0), Vector3(0.35, 0.15, 0.2), face, ORANGE)
	kit.box(top + _turn(Vector3(3.0, 0.0, -1.5), facing), Vector3(2.4, 2.0, 2.0), RED, SceneryKit.BRICK, false)
	_roof(kit, top + _turn(Vector3(3.0, 2.0, -1.5), facing), 2.6, 2.2, 0.5, facing, WHITE)


## A windmill on its own island, its sails turning, with a fence round it.
static func windmill_isle(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var top := at + Vector3.DOWN * 5.0
	_sky_isle(kit, top, 9.0, rng, 2, rng.randf() < 0.5)
	var keep := kit.solids.size()
	windmill(kit, top, facing, 1.2)
	kit.solids.resize(keep)
	for k in 6:
		var a := k * TAU / 6.0
		kit.box(top + Vector3(cos(a), 0.0, sin(a)) * 5.0, Vector3(0.2, 1.0, 0.2), WHITE, SceneryKit.SMOOTH, false)


## A lighthouse on its own island, so airships find their way in the
## clouds, with the keeper's hut beside it.
static func sky_lighthouse(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var top := at + Vector3.DOWN * 7.0
	_sky_isle(kit, top, 8.0, rng, 0, false)
	var keep := kit.solids.size()
	lighthouse(kit, top)
	kit.solids.resize(keep)
	kit.box(top + Vector3(3.8, 0.0, 1.0), Vector3(3.0, 2.2, 2.4), WHITE, SceneryKit.BRICK, false)
	_roof(kit, top + Vector3(3.8, 2.2, 1.0), 3.2, 2.6, 0.5, 0, RED)


## An airship docked nose first at a tall mooring mast on a big island, with
## a little station hut at the mast's foot.
static func sky_dock(kit: SceneryKit, at: Vector3, facing: int, rng: RandomNumberGenerator) -> void:
	var top := at + Vector3.DOWN * 4.0
	_sky_isle(kit, top, 12.0, rng, 1, false)
	var mast := top + _turn(Vector3(-11.0, 0.0, 0.0), facing)
	for k in 6:
		kit.cylinder(mast + Vector3.UP * k * 3.0, 0.9 - k * 0.06, 3.0, RED if k % 2 == 0 else WHITE, SceneryKit.BRICK)
	kit.cylinder(mast + Vector3.UP * 18.0, 1.6, 0.4, DARK_GREY, SceneryKit.SMOOTH)
	kit.cone(mast + Vector3.UP * 18.4, 0.6, 1.4, YELLOW, SceneryKit.GLOW)
	# The ship's nose meets the top of the mast, and its tail stays inside
	# the dock's room.
	airship(kit, mast + _turn(Vector3(12.0, 0.0, 0.0), facing), facing + 2, rng, 18.0, 24.0)
	kit.box(top + _turn(Vector3(-7.0, 0.0, 4.5), facing), Vector3(4.0, 2.6, 3.0), BLUE, SceneryKit.BRICK, false)
	_roof(kit, top + _turn(Vector3(-7.0, 2.6, 4.5), facing), 4.4, 3.4, 0.5, facing, WHITE)


## A small island well below the road, now and then with a tree or a trickle
## of water off its edge.
static func sky_isle(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var radius := rng.randf_range(3.0, 6.0)
	_sky_isle(kit, at + Vector3.DOWN * rng.randf_range(10.0, 22.0), radius, rng, rng.randi() % 3 if radius > 4.0 else 0, radius > 5.0 and rng.randf() < 0.3)


## A small cloud drifting a little below the road.
static func cloud_puff(kit: SceneryKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	cloud(kit, at + Vector3.DOWN * rng.randf_range(5.0, 14.0), rng.randf_range(7.0, 12.0), rng)
