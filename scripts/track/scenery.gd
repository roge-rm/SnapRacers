class_name Scenery
extends Node3D

## Dresses a track with everything around it, built out of bricks.
##
## The road runs out onto grass on both sides, and nothing solid goes within
## RUNOFF of it. Where two stretches of road run close, a line of soft tire
## stacks goes halfway across the grass between them. Past the grass there's a
## grandstand and a pit building on the start straight, billboards on the
## straights, flags at the start and marshal posts at the corners. Each course
## has a theme (a peach farm, a coal mine, a desert city, a castle) with its
## own landmarks, trees and buildings, and its own colours for the ground,
## curbs, walls and sky.
##
## It works out how far every patch of ground is from the road, so nothing goes
## on the road or too close to it, and the big landmarks go where you'll see
## them. Everything is placed from a seed made from the course's name, so a
## course looks the same every time.

const CELL := 4.0 # metres, for the map of how far the ground is from the road
const REACH := 80.0 # how far out from the road scenery goes
const MAX_FILLERS := 280
## How many undergrowth plants at most, and how far past the runoff they go.
const MAX_UNDERGROWTH := 400
const UNDERGROWTH_REACH := 10.0 # metres
## Only scenery closer to the road than this is solid. Nothing further out
## can be hit, so lower graphics settings can leave some out.
const SOLID_REACH := 60.0
## Grass between the edge of the road and anything you could hit.
const RUNOFF := 10.0
## Props this small (by Props.ROOM) come down whole when hit. Bigger ones only
## break where they're hit.
const SMALL := 3.2
## Props too big to break, like hills and lakes.
## Where each lamp along the road is (see _lamp_posts()).
var lamps: Array[Vector3] = []
const UNBREAKABLE := ["mountain", "snowy_peak", "mesa", "butte", "karst", "waterfall", "volcano", "slag_heap", "dune", "lake", "pond", "lava_pool", "old_banking", "red_roof", "bridge",
	"hot_air_balloon", "airship", "falls_isle", "rainbow", "weather_vane", "windmill_isle", "sky_lighthouse", "sky_dock", "sky_isle", "cloud_puff"]
## Two stretches of road closer than this (middle to middle) get a line of
## tire stacks between them.
const BARRIER_REACH := 2.0 * TrackPiece.TILE
## How far apart the stacks in a line are, and how far apart the spots
## between the roads are worked out.
const STACK_EVERY := 0.8
const BARRIER_STEP := 4.0
## Indoors: how far past the curbs the barriers run, how far the hall's walls
## are from the road, and how high the roof beams are.
const INDOOR_RUNOFF := 3.0
const HALL_MARGIN := 40.0
const HALL_HEIGHT := 12.0
## Up in the sky, how many islands go around the road at most, and clouds
## below it.
const SKY_ISLANDS := 40
const SKY_CLOUDS := 40
## How far the shore is past the furthest road on the sea's side, how wide
## the beach is, and how far out the sea goes.
const SHORE := 55.0
const BEACH := 16.0
const SEA_OUT := 900.0
## How far apart the hall's roof beams and the lights along them are.
const BEAM_EVERY := 16.0
const LIGHT_EVERY := 12.0
## Outdoors, how far apart the lamp posts along the road are. They take turns
## on each side.
const LAMP_EVERY := 20.0

## Each theme: ground colour, curb and wall colours, the sky, its landmarks
## (placed first, biggest first) and its fillers with how often each turns
## up. A theme by the sea has "sea", and the sea runs along one side of the
## course with a sandy beach, a pier and boats. "floor" is what you drive on
## beside the road (grass, sand, snow, dirt, mud, hall). An indoor theme also has
## the colour behind everything, and the colours of the hall and its lights.
## A theme up in the sky has "void": there's no ground, and floating islands
## and clouds go under and around the road instead (see _sky_islands()).
## A theme in the mountains has "peaks": a ring of big snowy peaks stands far
## out round the course (see _far_peaks()). A canyon theme has "mesas": a
## ring of red mesas and buttes stands far out instead (see _far_mesas()),
## and "mesas_out" says how far past the scenery, 70 m if it's left out.
## A jungle theme has "karsts": a ring of tall green topped rock towers
## stands far out (see _far_karsts()). "undergrowth" is small cheap fillers
## packed in thick along the road (see _undergrowth()), and "filler_reach"
## keeps the fillers within that many metres past the runoff, 64 if it's
## left out. A city theme has "skyline": a ring of tall lit towers stands
## far out (see _far_skyline()), and "undergrowth_max" caps how many
## undergrowth props it gets, MAX_UNDERGROWTH if it's left out.
## "filler_max" caps the fillers the same way, MAX_FILLERS if it's left out.
## "drop" puts road up in the air on a ridge, with the ground falling away
## that many metres below the hills beside it, like a mountain road (see
## Terrain).
## "litter" draws the ground as a jungle floor with fallen leaves and bare
## dirt. It's only a look, the grip stays the floor's.
const THEMES := {
	"orchard": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["barn", "silo", "pond", "barn"],
		"fillers": {"peach": 6, "broadleaf": 2, "hay": 2, "fence": 2, "bush": 1, "house": 1},
	},
	"trulli": {
		"ground": "#8fa251", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["church", "trullo", "trullo", "trullo"],
		"fillers": {"olive": 6, "trullo": 2, "cypress": 1, "rocks": 1, "villa": 1},
	},
	"lake": {
		"ground": "#4b9f4a", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"landmarks": ["lake", "lake", "villa", "villa"],
		"fillers": {"lemon": 3, "cypress": 4, "villa": 1, "bush": 1},
	},
	"mine": {
		"ground": "#5e8a4c", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#7b2e2f",
		"landmarks": ["headframe", "slag_heap", "chimney", "headframe"],
		"fillers": {"birch": 3, "house": 2, "broadleaf": 2, "rocks": 2, "chimney": 1},
	},
	"delta": {
		"ground": "#5a9150", "curbs": ["#237841", "#f2f2f2"], "wall": "#0d69ab",
		"landmarks": ["lake", "lighthouse", "stilt_hut", "stilt_hut"],
		"fillers": {"reeds": 5, "pond": 2, "stilt_hut": 1, "bush": 2, "birch": 1},
	},
	"pit": {
		"ground": "#a08058", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#da8540",
		"floor": "dirt",
		"landmarks": ["excavator", "wind_turbine", "wind_turbine", "slag_heap"],
		"fillers": {"rocks": 4, "containers": 1, "wind_turbine": 1, "bush": 2},
	},
	"industry": {
		"ground": "#8f978f", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#0d69ab",
		"floor": "dirt",
		"landmarks": ["factory", "factory", "crane", "tanks"],
		"fillers": {"containers": 4, "chimney": 1, "tanks": 1, "bush": 1},
	},
	"amber": {
		"ground": "#4b9f4a", "curbs": ["#da8540", "#f2f2f2"], "wall": "#da8540",
		"landmarks": ["bridge", "church", "house", "house"],
		"fillers": {"birch": 4, "pine": 2, "house": 2, "bush": 1},
	},
	"timber": {
		"ground": "#3f8040", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["mountain", "mountain", "lake", "cabin"],
		"fillers": {"pine": 6, "maple": 3, "cabin": 1, "rocks": 1},
	},
	"frost": {
		"ground": "#e6edf2", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"sky": ["#7ea7d8", "#e6eef6"],
		"floor": "snow",
		"landmarks": ["mountain", "cottage", "cottage", "church"],
		"fillers": {"snowy_pine": 7, "cottage": 1, "snowman": 1, "rocks": 1},
	},
	"desert": {
		"ground": "#d9c38c", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#d7c599",
		"sky": ["#4d8fd6", "#f2e2c4"],
		"floor": "sand",
		"landmarks": ["skyscraper", "skyscraper", "skyscraper", "skyscraper", "skyscraper", "dune"],
		"fillers": {"dune": 3, "palm": 4, "tent": 1, "rocks": 1},
	},
	"railway": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#237841",
		"landmarks": ["station", "church", "castle_wall", "house"],
		"fillers": {"broadleaf": 4, "pine": 3, "house": 1, "bush": 1},
	},
	"windmill": {
		"ground": "#c9aa6c", "curbs": ["#d8261c", "#f2cd37"], "wall": "#c4281c",
		"sky": ["#3f86d6", "#dce8f2"],
		"floor": "sand",
		"landmarks": ["big_windmill", "big_windmill", "big_windmill", "house"],
		"fillers": {"windmill": 2, "olive": 3, "rocks": 2, "house": 1, "bush": 1},
	},
	"space": {
		"ground": "#8fae6a", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"landmarks": ["rocket", "radar", "radar", "factory"],
		"fillers": {"palm": 5, "radar": 1, "bush": 2},
	},
	"volcano": {
		"ground": "#5c534c", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#7b2e2f",
		"sky": ["#6d7c96", "#e8b98a"],
		"floor": "dirt",
		"landmarks": ["volcano", "ruins", "ruins", "lava_pool", "lava_pool"],
		"fillers": {"rocks": 4, "lava_pool": 1, "cypress": 2, "ruins": 1},
	},
	"castle": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2cd37"], "wall": "#635f61",
		"landmarks": ["castle", "lake", "tower", "tower"],
		"fillers": {"tent": 3, "broadleaf": 3, "castle_wall": 1, "house": 1},
	},
	"sakura": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["ferris_wheel", "pagoda", "lake", "pagoda"],
		"fillers": {"sakura": 5, "pine": 2, "bush": 2, "house": 1},
	},
	"ardennes": {
		"ground": "#3f7a3a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#237841",
		"sky": ["#6f9bd0", "#dde6ee"],
		"landmarks": ["mountain", "church", "cottage", "cabin"],
		"fillers": {"pine": 6, "broadleaf": 3, "cottage": 1, "rocks": 1},
	},
	"royal_park": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"landmarks": ["old_banking", "villa", "lake", "villa"],
		"fillers": {"broadleaf": 5, "cypress": 2, "bush": 2, "villa": 1},
	},
	"kent_downs": {
		"ground": "#4b9f4a", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#f2f3f2",
		"landmarks": ["oast_house", "spectator_bank", "oast_house", "barn"],
		"fillers": {"broadleaf": 4, "bush": 3, "fence": 2, "hay": 1},
	},
	"brittany": {
		"ground": "#5a9a48", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"landmarks": ["standing_stones", "spectator_bank", "church", "standing_stones"],
		"fillers": {"broadleaf": 3, "bush": 3, "rocks": 2, "house": 1, "pine": 1},
	},
	"varmland": {
		"ground": "#3f7f3a", "curbs": ["#f2cd37", "#0d69ab"], "wall": "#7b2e2f",
		"landmarks": ["spectator_bank", "lake", "cottage", "cottage"],
		"fillers": {"pine": 6, "birch": 2, "rocks": 2, "cottage": 1},
	},
	"trondelag": {
		"ground": "#4f8f45", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#143044",
		"sky": ["#5f8fc6", "#e8eef2"],
		"landmarks": ["control_tower", "spectator_bank", "mountain", "cabin"],
		"fillers": {"pine": 4, "birch": 3, "rocks": 2, "cabin": 1},
	},
	"hall_red": {
		"indoor": true, "backdrop": "#1a1c22", "floor": "hall", "hall": "#e4e4e0", "lights": "#fff4d6",
		"ground": "#9b9b99", "curbs": ["#c4281c", "#f2f3f2"], "wall": "#c4281c",
		"landmarks": ["viewing_deck", "kart_office", "kart_row", "kart_row"],
		"fillers": {"tire_pile": 3, "pallets": 2, "kart_row": 1},
	},
	"hall_green": {
		"indoor": true, "backdrop": "#161c1a", "floor": "hall", "hall": "#dfe6e0", "lights": "#e8f6ff",
		"ground": "#959794", "curbs": ["#4b9f4a", "#f2f3f2"], "wall": "#237841",
		"landmarks": ["viewing_deck", "kart_office", "kart_row"],
		"fillers": {"tire_pile": 2, "pallets": 2, "kart_row": 1},
	},
	"hall_blue": {
		"indoor": true, "backdrop": "#161a22", "floor": "hall", "hall": "#e0e4ea", "lights": "#f4f8ff",
		"ground": "#999a9d", "curbs": ["#0d69ab", "#f2f3f2"], "wall": "#0d69ab",
		"landmarks": ["viewing_deck", "kart_office", "kart_row", "kart_row"],
		"fillers": {"tire_pile": 3, "pallets": 1, "kart_row": 1},
	},
	"hall_neon": {
		"indoor": true, "backdrop": "#120d1c", "floor": "hall", "hall": "#3a3346", "lights": "#e4adc8",
		"ground": "#7b7982", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#7a3fa0",
		"landmarks": ["viewing_deck", "kart_office", "kart_row"],
		"fillers": {"tire_pile": 3, "pallets": 1, "kart_row": 1},
	},
	"park_wonder": {
		"ground": "#4b9f4a", "curbs": ["#0d69ab", "#f2cd37"], "wall": "#0d69ab",
		"supports": "lattice", "supports_colour": "#f2cd37",
		"landmarks": ["mountain", "ferris_wheel", "drop_tower", "carousel"],
		"fillers": {"broadleaf": 3, "bush": 2, "tent": 1, "pine": 2},
	},
	"park_lake": {
		"ground": "#58a84e", "curbs": ["#c4281c", "#f2f3f2"], "wall": "#c4281c",
		"supports": "lattice", "supports_colour": "#f2f3f2",
		"landmarks": ["lake", "lighthouse", "drop_tower", "carousel"],
		"fillers": {"broadleaf": 3, "bush": 2, "tent": 1, "reeds": 1},
	},
	"park_carolina": {
		"ground": "#4f9a45", "curbs": ["#da8540", "#f2f3f2"], "wall": "#da8540",
		"supports": "lattice", "supports_colour": "#0d69ab",
		"landmarks": ["ferris_wheel", "carousel", "drop_tower", "tent"],
		"fillers": {"pine": 3, "broadleaf": 2, "tent": 1, "bush": 2},
	},
	"gran_canaria": {
		"ground": "#dcc693", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#f2f3f2",
		"sky": ["#3e8fe0", "#f6ead2"], "sea": true, "floor": "sand",
		"landmarks": ["beach_hotel", "lighthouse", "sandcastle", "beach_hotel"],
		"fillers": {"palm": 5, "parasols": 3, "beach_hut": 2, "windsurf": 2, "lifeguard_tower": 1, "dune": 1},
	},
	"sardinia": {
		"ground": "#a3a466", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#f2f3f2",
		"sky": ["#3a86d8", "#eef2f4"], "sea": true,
		"landmarks": ["watchtower", "villa", "lighthouse", "villa"],
		"fillers": {"stone_pine": 4, "olive": 2, "rocks": 3, "bush": 2, "villa": 1, "parasols": 1},
	},
	"malta": {
		"ground": "#cdb984", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#d9b77e",
		"sky": ["#3f8ad8", "#f4ead6"], "sea": true, "floor": "sand",
		"landmarks": ["harbour_fort", "church", "harbour_fort", "watchtower"],
		"fillers": {"rocks": 3, "palm": 2, "cactus": 2, "olive": 1, "house": 1},
	},
	"phillip_island": {
		"ground": "#62a14b", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"sky": ["#4f8fd0", "#e6eef2"], "sea": true,
		"landmarks": ["lighthouse", "spectator_bank", "control_tower", "penguins"],
		"fillers": {"gum_tree": 3, "bush": 3, "penguins": 1, "rocks": 1, "fence": 1},
	},
	"park_desert": {
		"ground": "#d9c38c", "curbs": ["#c4281c", "#f2f3f2"], "wall": "#c4281c",
		"supports": "lattice", "supports_colour": "#c4281c", "sky": ["#3f86d6", "#f4e9d0"],
		"floor": "sand",
		"landmarks": ["red_roof", "skyscraper", "dune", "dune"],
		"fillers": {"palm": 4, "dune": 1, "cactus": 1, "rocks": 1},
	},
	"sky": {
		"ground": "#4b9f4a", "curbs": ["#0d69ab", "#f2f3f2"], "wall": "#f2f3f2",
		"sky": ["#3c8fe0", "#d6ecfa", "#a7d2f0"], "void": true,
		"landmarks": [],
		"fillers": {},
	},
	"sky_falls": {
		"ground": "#4b9f4a", "curbs": ["#5ab4e5", "#f2f3f2"], "wall": "#f2f3f2",
		"sky": ["#3c8fe0", "#d6ecfa", "#a7d2f0"], "void": true,
		"landmarks": ["falls_isle", "rainbow", "falls_isle", "hot_air_balloon"],
		"fillers": {"sky_isle": 5, "cloud_puff": 3, "hot_air_balloon": 1},
		"filler_max": 40,
	},
	"sky_isles": {
		"ground": "#4b9f4a", "curbs": ["#f2cd37", "#0d69ab"], "wall": "#0d69ab",
		"sky": ["#4a96e0", "#e2f0fa", "#b4d8f0"], "void": true,
		"landmarks": ["windmill_isle", "weather_vane", "windmill_isle", "weather_vane", "hot_air_balloon"],
		"fillers": {"sky_isle": 5, "cloud_puff": 3, "hot_air_balloon": 1},
		"filler_max": 40,
	},
	"sky_port": {
		"ground": "#4b9f4a", "curbs": ["#c4281c", "#f2f3f2"], "wall": "#c4281c",
		"sky": ["#3a84d4", "#f0e6d6", "#b0cfe8"], "void": true,
		"landmarks": ["sky_dock", "airship", "airship", "sky_lighthouse"],
		"fillers": {"sky_isle": 4, "cloud_puff": 4, "airship": 1},
		"filler_max": 34,
	},
	"sky_balloons": {
		"ground": "#4b9f4a", "curbs": ["#da8540", "#f2f3f2"], "wall": "#f2f3f2",
		"sky": ["#4290dc", "#f6e8d8", "#bcd8ee"], "void": true,
		"landmarks": ["hot_air_balloon", "rainbow", "hot_air_balloon", "sky_lighthouse", "hot_air_balloon"],
		"fillers": {"hot_air_balloon": 4, "sky_isle": 3, "cloud_puff": 3},
		"filler_max": 44,
	},
	"alps_meadow": {
		"ground": "#5b9e46", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#c4281c",
		"sky": ["#3a86d8", "#e6eef6"], "peaks": true,
		"landmarks": ["alpine_church", "chalet", "chalet", "snowy_peak"],
		"fillers": {"pine": 5, "cows": 3, "chalet": 1, "fence": 1, "rocks": 1, "hay": 1},
	},
	"alps_snow": {
		"ground": "#e6edf2", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#0d69ab",
		"sky": ["#5f96d8", "#e8f0f8"], "peaks": true, "floor": "snow",
		"landmarks": ["ski_jump", "snowy_chalet", "snowy_chalet", "alpine_church"],
		"fillers": {"snowy_pine": 7, "snowy_chalet": 1, "snowman": 1, "rocks": 1},
	},
	"alps_lake": {
		"ground": "#54964a", "curbs": ["#0d69ab", "#f2f2f2"], "wall": "#0d69ab",
		"sky": ["#3f8ad8", "#e2ecf4"], "peaks": true,
		"landmarks": ["cable_car", "lake", "chalet", "alpine_church"],
		"fillers": {"pine": 4, "birch": 2, "chalet": 1, "cows": 2, "rocks": 1},
	},
	"alps_pass": {
		"ground": "#8a9670", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#635f61",
		"sky": ["#4a86cc", "#eaf0f6"], "peaks": true,
		"drop": 26.0, "supports": "rock", "supports_colour": "#7f7b76",
		"landmarks": ["snowy_peak", "cable_car", "snowy_chalet", "snowy_peak"],
		"fillers": {"rocks": 5, "snowy_pine": 3, "pine": 1, "cows": 1, "snowman": 1},
	},
	"canyon_cactus": {
		"ground": "#c69c74", "curbs": ["#a0452e", "#f2f3f2"], "wall": "#a0452e",
		"sky": ["#3f86d6", "#f4dcc0"], "mesas": true, "floor": "dirt",
		"landmarks": ["mesa", "saloon", "water_tower", "windpump"],
		"fillers": {"saguaro": 7, "cactus": 2, "red_rocks": 2},
	},
	"canyon_ranch": {
		"ground": "#c8a27a", "curbs": ["#f2cd37", "#1b2a34"], "wall": "#694030",
		"sky": ["#4a8ed8", "#f2e0c6"], "mesas": true, "mesas_out": 10.0, "floor": "dirt",
		"landmarks": ["butte", "mesa", "water_tower", "saloon", "windpump", "butte"],
		"fillers": {"saguaro": 5, "red_rocks": 4, "cactus": 3, "windpump": 1, "water_tower": 1, "fence": 1},
	},
	"canyon_mesa": {
		"ground": "#bb8a68", "curbs": ["#a0452e", "#f2f3f2"], "wall": "#8e3b27",
		"sky": ["#3a80d0", "#f6d8b8"], "mesas": true, "floor": "dirt",
		"supports": "rock", "supports_colour": "#a0452e",
		"landmarks": ["mesa", "butte", "mesa", "butte"],
		"fillers": {"red_rocks": 5, "saguaro": 2, "cactus": 2},
	},
	"canyon_mine": {
		"ground": "#c09670", "curbs": ["#f2cd37", "#694030"], "wall": "#694030",
		"sky": ["#4588d4", "#f0dcc4"], "mesas": true, "floor": "dirt",
		"landmarks": ["mine_carts", "butte", "water_tower", "saloon"],
		"fillers": {"red_rocks": 3, "cactus": 2, "mine_carts": 1, "windpump": 1, "saguaro": 1},
	},
	"jungle_canopy": {
		"ground": "#356e30", "curbs": ["#a5ca18", "#1b2a34"], "wall": "#237841",
		"sky": ["#4a92d0", "#e4efe0"], "karsts": true,
		"landmarks": ["canopy_walk", "canopy_walk", "parrots", "jungle_hut", "parrots"],
		"fillers": {"jungle_tree": 4, "jungle_sapling": 4, "palm": 1, "bush": 1},
		"filler_reach": 34.0, "litter": true,
		"undergrowth": {"fern": 3, "jungle_sapling": 2, "jungle_bush": 3},
	},
	"jungle_falls": {
		"ground": "#3b6e31", "curbs": ["#a5ca18", "#f2f3f2"], "wall": "#0d69ab",
		"sky": ["#5590c8", "#e2ece2"], "karsts": true,
		"landmarks": ["waterfall", "rope_bridge", "waterfall", "jungle_hut", "pond"],
		"fillers": {"jungle_tree": 4, "jungle_sapling": 4, "palm": 1, "bush": 1},
		"filler_reach": 34.0, "litter": true,
		"undergrowth": {"fern": 3, "jungle_sapling": 2, "jungle_bush": 3},
	},
	"jungle_temple": {
		"ground": "#46783a", "curbs": ["#a0452e", "#f2f3f2"], "wall": "#958a73",
		"sky": ["#3f8ad8", "#eaf0dc"], "karsts": true,
		"landmarks": ["stepped_pyramid", "stone_head", "stone_head", "ruins", "stone_head"],
		"fillers": {"jungle_tree": 4, "jungle_sapling": 4, "palm": 1, "ruins": 1},
		"filler_reach": 34.0, "litter": true,
		"undergrowth": {"fern": 3, "jungle_sapling": 2, "jungle_bush": 3},
	},
	"jungle_swamp": {
		"ground": "#5a6a34", "curbs": ["#a5ca18", "#694030"], "wall": "#694030",
		"sky": ["#6a8aa8", "#d8e0d8"], "karsts": true, "floor": "mud",
		"landmarks": ["karst", "rope_bridge", "jungle_hut", "jungle_hut", "karst"],
		"fillers": {"jungle_tree": 4, "jungle_sapling": 3, "pond": 1, "palm": 1, "bush": 1},
		"filler_reach": 34.0,
		"undergrowth": {"fern": 2, "reeds": 1, "jungle_sapling": 2, "jungle_bush": 3},
	},
	"city_tokyo": {
		"ground": "#5d6266", "curbs": ["#c4281c", "#f2f3f2"], "wall": "#f2f3f2",
		"sky": ["#3f6aa8", "#dfe6ee"], "skyline": true, "floor": "dirt",
		"landmarks": ["tunnel_mouth", "neon_tower", "neon_tower", "lantern_gate", "pagoda", "lantern_gate"],
		"fillers": {"city_block": 6, "neon_sign": 2, "street_tree": 2, "armco": 1},
		"filler_reach": 44.0,
		"undergrowth": {"street_tree": 2, "traffic_light": 1, "neon_sign": 1},
		"undergrowth_max": 70,
	},
	"city_dubai": {
		"ground": "#a8977a", "curbs": ["#f5cd2f", "#1b2a34"], "wall": "#d7c599",
		"sky": ["#4a8ed8", "#f2e6d2"], "skyline": true, "floor": "dirt",
		"landmarks": ["spire_tower", "spire_tower", "skyscraper", "skyscraper", "spire_tower"],
		"fillers": {"city_block": 6, "palm": 2, "neon_sign": 1, "armco": 1},
		"filler_reach": 44.0,
		"undergrowth": {"street_tree": 1, "traffic_light": 1},
		"undergrowth_max": 70,
	},
	"city_london": {
		"ground": "#5f665e", "curbs": ["#c4281c", "#f2f3f2"], "wall": "#c4281c",
		"sky": ["#5a7fa8", "#e2e6ea"], "skyline": true, "floor": "dirt",
		"landmarks": ["clock_tower", "double_decker", "townhouses", "double_decker", "townhouses"],
		"fillers": {"townhouses": 5, "city_block": 2, "street_tree": 3, "double_decker": 1, "armco": 1},
		"filler_reach": 44.0,
		"undergrowth": {"street_tree": 2, "phone_box": 1, "traffic_light": 1},
		"undergrowth_max": 70,
	},
	"city_bangkok": {
		"ground": "#5e625a", "curbs": ["#f5cd2f", "#c4281c"], "wall": "#f5cd2f",
		"sky": ["#4a86c8", "#e8e6dc"], "skyline": true, "floor": "dirt",
		"landmarks": ["overpass", "chedi", "overpass", "chedi"],
		"fillers": {"city_block": 6, "neon_sign": 2, "tuk_tuk": 1, "armco": 1},
		"filler_reach": 44.0,
		"undergrowth": {"street_tree": 2, "tuk_tuk": 1, "traffic_light": 1, "neon_sign": 1},
		"undergrowth_max": 70,
	},
	"golden_hills": {
		"ground": "#a8965c", "curbs": ["#d8261c", "#f2f2f2"], "wall": "#da8540",
		"sky": ["#3f86d6", "#e8eef2"], "floor": "dirt",
		"landmarks": ["mountain", "mountain", "barn", "house"],
		"fillers": {"broadleaf": 4, "rocks": 3, "bush": 2, "fence": 1},
	},
}

var track: TrackPath
var theme: Dictionary
## Only the landmarks put down by hand, with no trackside things or trees,
## for the track editor.
var only_landmarks := false
## Places kept clear of scenery, as [middle, radius] (like the dirt inside a
## cut bend).
var keep_clear: Array = []
## Strips to keep clear too, like a railway: [from, to, half width] each.
var keep_off: Array = []

var _rng := RandomNumberGenerator.new()
var _kit := SceneryKit.new()
var _placed: Array = [] # [position, radius], and how far down it reaches for sky props in Props.DEPTH
## The sea, seen from above, as (x, z), or empty. `_out` is the way from the
## shore out to sea.
var _sea := Rect2()
var _out := Vector2.ZERO
var _origin := Vector2.ZERO
var _cols := 0
var _rows := 0
var _dist := PackedFloat32Array()
var _near := PackedVector2Array() # the nearest road point to each cell
var _road_clear := 10.0
## Indoors, the hall's floor seen from above, as (x, z). Outdoors it's empty.
var _hall := Rect2()
## How high the ground is at a spot (x, z), for hilly courses. It's flat
## unless the track builder says otherwise.
var ground: Callable = func(_x: float, _z: float) -> float: return 0.0
var _hash := {} # 16 m cell -> track sample indices
## Whether the theme has no ground, with everything floating on islands.
var _floating := false


static func theme_named(id: String) -> Dictionary:
	return THEMES.get(id, THEMES["orchard"])


func _init(path: TrackPath, theme_id: String) -> void:
	track = path
	theme = theme_named(theme_id)
	_floating = theme.get("void", false)
	_rng.seed = hash(track.name)


func _ready() -> void:
	_road_clear = track.width * 0.5 + TrackPath.KERB + RUNOFF
	_map_distances()
	_hash_track()
	var indoor: bool = theme.get("indoor", false)
	if indoor:
		_hall = _hall_floor()
	if theme.get("sea", false):
		_plan_sea()
	if not only_landmarks:
		_trackside()
		if not _floating:
			_under_jumps()
	# Landmarks put down by hand go exactly where they were put. Without any,
	# the theme places its own where you'll see them.
	for mark in track.landmarks:
		var at: Array = mark.get("at", [0.0, 0.0])
		_add(str(mark.get("prop", "")), Vector3(float(at[0]), 0.0, float(at[1])), int(mark.get("facing", 0)))
	if track.landmarks.is_empty() and not only_landmarks:
		var landmarks: Array = theme.get("landmarks", [])
		landmarks = landmarks.duplicate()
		landmarks.sort_custom(func(a, b): return Props.ROOM.get(a, 3.0) > Props.ROOM.get(b, 3.0))
		for lm in landmarks:
			_place_landmark(lm)
	if not only_landmarks:
		_fill()
		_undergrowth()
		if _floating:
			_sky_islands()
		if indoor:
			_build_hall()
		if theme.get("peaks", false):
			_far_peaks()
		if theme.get("mesas", false):
			_far_mesas()
		if theme.get("karsts", false):
			_far_karsts()
		if theme.get("skyline", false):
			_far_skyline()
	if _sea.size != Vector2.ZERO:
		_build_sea()
	# Only things near the road need to be solid. And nothing that ended up on
	# the road itself may be, or karts would pile into it (the walls keep
	# them off everything else).
	var road_edge := track.width * 0.5 + TrackPath.KERB
	_kit.solids = _kit.solids.filter(func(s): return _distance_at(s[0].origin) < SOLID_REACH and not _near_other_road(s[0].origin, road_edge, 0, 0.0))
	_kit.build(self)


# How far the ground is from the road.

func _map_distances() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in track.points:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	_origin = lo - Vector2.ONE * REACH
	_cols = int((hi.x - lo.x + REACH * 2.0) / CELL) + 1
	_rows = int((hi.y - lo.y + REACH * 2.0) / CELL) + 1
	_dist.resize(_cols * _rows)
	_dist.fill(INF)
	_near.resize(_cols * _rows)
	for p in track.points:
		var flat := Vector2(p.x, p.z)
		var c := _cell_of(flat)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var cx := c.x + dx
				var cy := c.y + dy
				if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
					continue
				var i := cy * _cols + cx
				var d := _centre(cx, cy).distance_to(flat)
				if d < _dist[i]:
					_dist[i] = d
					_near[i] = flat
	# Spread the nearest road point out across the map in two sweeps, one
	# forwards and one backwards (the usual trick for a distance map).
	for pass_back in [false, true]:
		var ys := range(_rows) if not pass_back else range(_rows - 1, -1, -1)
		var xs := range(_cols) if not pass_back else range(_cols - 1, -1, -1)
		var step := -1 if not pass_back else 1
		for y in ys:
			for x in xs:
				var i: int = y * _cols + x
				var here := _centre(x, y)
				for n in [Vector2i(x + step, y), Vector2i(x, y + step), Vector2i(x + step, y + step), Vector2i(x - step, y + step)]:
					if n.x < 0 or n.y < 0 or n.x >= _cols or n.y >= _rows:
						continue
					var j: int = n.y * _cols + n.x
					if _dist[j] == INF:
						continue
					var d: float = here.distance_to(_near[j])
					if d < _dist[i]:
						_dist[i] = d
						_near[i] = _near[j]


func _cell_of(flat: Vector2) -> Vector2i:
	return Vector2i(int((flat.x - _origin.x) / CELL), int((flat.y - _origin.y) / CELL))


func _centre(x: int, y: int) -> Vector2:
	return _origin + Vector2(x + 0.5, y + 0.5) * CELL


func _distance_at(at: Vector3) -> float:
	var c := _cell_of(Vector2(at.x, at.z))
	if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows:
		return INF
	return _dist[c.y * _cols + c.x]


func _hash_track() -> void:
	for k in track.points.size():
		var p := track.points[k]
		var key := Vector2i(floori(p.x / 16.0), floori(p.z / 16.0))
		if not _hash.has(key):
			_hash[key] = []
		_hash[key].append(k)


## Whether anything within `radius` of `at` is road that isn't within `skip`
## metres along the track of the sample `own` (so a tire stack can sit beside
## its own corner but not on the next bit of road over).
func _near_other_road(at: Vector3, radius: float, own: int, skip: float) -> bool:
	var key := Vector2i(floori(at.x / 16.0), floori(at.z / 16.0))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for k in _hash.get(key + Vector2i(dx, dy), []):
				var along := absf(track.distances[k] - track.distances[own])
				along = minf(along, track.length - along)
				if along < skip:
					continue
				var p := track.points[k]
				if Vector2(p.x - at.x, p.z - at.z).length() < radius:
					return true
	return false


func _free(at: Vector3, radius: float) -> bool:
	if _distance_at(at) < _road_clear + radius:
		return false
	for spot in _placed:
		if Vector2(spot[0].x - at.x, spot[0].z - at.z).length() < spot[1] + radius:
			return false
	for spot in keep_clear:
		if Vector2(spot[0].x - at.x, spot[0].z - at.z).length() < spot[1] + radius:
			return false
	return not _on_strip(at, radius)


## How many small things (ones that come down whole) stand within `radius`
## of `at`, or -1 if it isn't clear ground: too near the road, under
## something big, on a railway, in the sea, outside the hall or up in the sky.
## Without `off_road` it can be right by the road.
func clutter_at(at: Vector3, radius: float, off_road := true) -> int:
	if _floating or (off_road and _distance_at(at) < _road_clear + radius) or _on_strip(at, radius) or not _inside_hall(at, radius):
		return -1
	for spot in keep_clear:
		if Vector2(spot[0].x - at.x, spot[0].z - at.z).length() < spot[1] + radius:
			return -1
	var small := 0
	for spot in _placed:
		if Vector2(spot[0].x - at.x, spot[0].z - at.z).length() < spot[1] + radius:
			if spot[1] > SMALL:
				return -1
			small += 1
	return small


## Whether anything within `radius` of `at` is on one of the strips in
## `keep_off`.
func _on_strip(at: Vector3, radius: float) -> bool:
	for strip in keep_off:
		var a := Vector2(strip[0].x, strip[0].z)
		var b := Vector2(strip[1].x, strip[1].z)
		var p := Vector2(at.x, at.z)
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < strip[2] + radius:
			return true
	return false


## Which quarter turn faces from `at` toward the road.
func _facing_road(at: Vector3) -> int:
	var c := _cell_of(Vector2(at.x, at.z))
	var i := clampi(c.y, 0, _rows - 1) * _cols + clampi(c.x, 0, _cols - 1)
	var to := _near[i] - Vector2(at.x, at.z)
	return _facing_for(Vector3(to.x, 0.0, to.y))


## The quarter turn whose front (+Z at facing 0) points most along `dir`.
static func _facing_for(dir: Vector3) -> int:
	if absf(dir.x) > absf(dir.z):
		return 1 if dir.x > 0.0 else 3
	return 0 if dir.z > 0.0 else 2


## The spot moved up or down onto the ground.
func _grounded(at: Vector3) -> Vector3:
	return Vector3(at.x, ground.call(at.x, at.z), at.z)


func _add(prop: String, at: Vector3, facing := -1) -> void:
	at = _grounded(at)
	var f := facing if facing >= 0 else _facing_road(at)
	if not UNBREAKABLE.has(prop):
		_kit.begin(prop, Props.ROOM.get(prop, 3.0) <= SMALL)
	Props.add(_kit, prop, at, _rng, f)
	_kit.done()
	if Props.DEPTH.has(prop):
		_placed.append([at, Props.ROOM.get(prop, 3.0), Props.DEPTH[prop]])
	else:
		_placed.append([at, Props.ROOM.get(prop, 3.0)])


# Along the road.

func _trackside() -> void:
	# Up in the sky there's nothing to cut across on, so no tire stacks.
	if not _floating:
		_tire_lines()
	if theme.get("indoor", false):
		_barrier_lines()
	else:
		_lamp_posts()
	var edge := track.width * 0.5 + TrackPath.KERB + RUNOFF
	_start_area(edge)
	var straight_run := 0.0
	var board_side := 1.0
	var boards := [Color(theme.curbs[0]), Props.BLUE, Props.YELLOW, Props.GREEN, Props.WHITE]
	var corners := 0
	for k in track.points.size():
		var p := track.points[k]
		var d := track.distances[k]
		var ahead := track.forwards[(k + 4) % track.points.size()]
		var behind := track.forwards[(k - 4 + track.points.size()) % track.points.size()]
		# How much the road turns over 8 m, positive turning left. Over 0.2 is
		# a proper corner (tighter than about 40 m), not a gentle slant.
		var turn := behind.cross(ahead).y
		# Nothing for marshals and billboards to stand on up in the sky.
		var flat_ground := p.y < 0.6 and track.ups[k].y > 0.95 and track.solids[k] and not track.stickies[k] and not _floating
		if absf(turn) > 0.2 and flat_ground:
			straight_run = 0.0
			# The outside of a left turn is on the right, and the other way
			# around.
			var outside := signf(turn)
			if int(d) % 97 == 0:
					corners += 1
					var post := p + track.rights[k] * outside * (edge + 4.0)
					post = _grounded(post)
					if _free(post, 1.5) and not _near_other_road(post, edge + 3.0, k, 25.0):
						_kit.begin("marshal_post", true)
						Props.marshal_post(_kit, post, _facing_for(p - post))
						_kit.done()
						# Every other corner has a few fans watching too.
						var fans_at := _grounded(p + track.rights[k] * outside * (edge + 9.0))
						if corners % 2 == 0 and _free(fans_at, 3.5) and not _near_other_road(fans_at, edge + 7.0, k, 25.0):
							Props.fan_line(_kit, fans_at, _facing_for(p - fans_at), _rng)
							_placed.append([fans_at, 3.5])
						_placed.append([post, 1.5])
		elif flat_ground:
			straight_run += 1.0
			if straight_run > 30.0 and int(straight_run) % 40 == 0:
				var spot := p + track.rights[k] * board_side * (edge + 3.5)
				spot = _grounded(spot)
				if _free(spot, 3.2) and not _near_other_road(spot, edge + 3.0, k, 25.0):
					_kit.begin("billboard", true)
					Props.billboard(_kit, spot, _facing_for(p - spot), boards[_rng.randi() % boards.size()])
					_kit.done()
					_placed.append([spot, 3.2])
				board_side = -board_side


## Lamp posts along the road, just past the runoff, taking turns on each side,
## on the flat away from other road (so never under a bridge). Where each
## lamp is goes in `lamps`, so the road can be lit around it at night (see
## CourseLamps).
func _lamp_posts() -> void:
	var edge := track.width * 0.5 + TrackPath.KERB + RUNOFF + 1.5
	var side := 1.0
	var next := 0.0
	for k in track.points.size():
		var d := track.distances[k]
		if d < next:
			continue
		var p := track.points[k]
		# On the ground (hills and all), not up on a bridge or a jump.
		var on_ground: bool = p.y - ground.call(p.x, p.z) < 0.6 and track.ups[k].y > 0.95 and track.solids[k] and not track.stickies[k]
		if not on_ground:
			continue
		var post := _grounded(p + track.rights[k] * side * edge)
		if _free(post, 1.0) and not _near_other_road(post, edge - 1.0, k, 30.0):
			_kit.begin("lamp_post", true)
			lamps.append(Props.lamp_post(_kit, post, _facing_for(p - post)))
			_kit.done()
			_pad(post, 3.5)
			_placed.append([post, 1.0])
			next = d + LAMP_EVERY
			side = -side


## Lines of soft tire stacks halfway across the grass wherever two stretches of
## road at the same level run close together, so nobody cuts across from one to
## the other.
##
## Every few metres it looks straight out to each side for other road well away
## from this bit of the lap. Each gap is only done from the stretch that comes
## first around the lap, so it's not lined twice.
func _tire_lines() -> void:
	var edge := track.width * 0.5 + TrackPath.KERB
	var count := track.points.size()
	var colours := [Color(theme.curbs[0]), Props.WHITE]
	for side in [-1.0, 1.0]:
		# The spot between the roads at each step, or INF where there's none.
		var spots: Array[Vector3] = []
		var next := 0.0
		for k in count:
			if track.distances[k] < next:
				continue
			next = track.distances[k] + BARRIER_STEP
			spots.append(_between(k, side, edge))
		var stacks := 0
		for n in spots.size():
			var a := spots[n]
			var b := spots[(n + 1) % spots.size()]
			if a == Vector3.INF or b == Vector3.INF or a.distance_to(b) > BARRIER_STEP * 2.0:
				continue
			var steps := maxi(1, int(a.distance_to(b) / STACK_EVERY))
			for i in steps:
				var at := a.lerp(b, float(i) / steps)
				if not keep_off.is_empty() and _on_strip(at, 1.0):
					continue
				_kit.begin("tires", false, true)
				Props.barrier_stack(_kit, at, colours[(stacks / 3) % 2])
				_kit.done()
				stacks += 1
			_placed.append([a, 2.0])


## Indoors, a low soft barrier runs along both sides of the road a little way
## past the curbs, the way an indoor kart track is lined all the way round.
## It leaves gaps where other road comes close, and on raised road, which has
## its own walls.
func _barrier_lines() -> void:
	var out := track.width * 0.5 + TrackPath.KERB + INDOOR_RUNOFF
	var colours := [Color(theme.curbs[0]), Color(theme.curbs[1])]
	var count := track.points.size()
	for side in [-1.0, 1.0]:
		var last := Vector3.INF
		var next := 0.0
		var pieces := 0
		for n in count + 1:
			var k := n % count
			if n < count and track.distances[k] < next:
				continue
			next = track.distances[k] + BARRIER_STEP * 0.75
			var p := track.points[k]
			var spot := Vector3.INF
			if track.solids[k] and not track.stickies[k] and p.y < TrackBuilder.RAISED and track.ups[k].y > 0.95:
				spot = _grounded(p + track.rights[k] * side * out)
				if _near_other_road(spot, out - 0.5, k, 30.0):
					spot = Vector3.INF
			if spot != Vector3.INF and last != Vector3.INF and last.distance_to(spot) < BARRIER_STEP * 2.0:
				var along := spot - last
				var basis := Basis.looking_at(Vector3(along.x, 0.0, along.z).normalized(), Vector3.UP)
				var size := Vector3(0.6, 0.9, along.length() + 0.3)
				var centre := (last + spot) * 0.5 + Vector3.UP * size.y * 0.5
				_kit.turned_box(centre, size, basis, colours[(pieces / 2) % 2], SceneryKit.SMOOTH)
				_kit.soft_box(Transform3D(basis, centre), size)
				pieces += 1
			last = spot


## The hall's floor: the course from above with room all round it.
func _hall_floor() -> Rect2:
	var box := Rect2(Vector2(track.points[0].x, track.points[0].z), Vector2.ZERO)
	for p in track.points:
		box = box.expand(Vector2(p.x, p.z))
	return box.grow(HALL_MARGIN)


## Whether something `room` across fits inside the hall. Outdoors there's no
## hall and everything fits.
func _inside_hall(at: Vector3, room: float) -> bool:
	if _sea.size != Vector2.ZERO and _sea.grow(BEACH * 0.5 + room).has_point(Vector2(at.x, at.z)):
		return false
	return _hall.size == Vector2.ZERO or _hall.grow(-room - 2.0).has_point(Vector2(at.x, at.z))


# By the sea.

## Which side the sea's on, picked from the course's name so it stays put,
## and where the shore is.
func _plan_sea() -> void:
	var low := Vector2(INF, INF)
	var high := -Vector2(INF, INF)
	for p in track.points:
		low = low.min(Vector2(p.x, p.z))
		high = high.max(Vector2(p.x, p.z))
	var side := absi(hash(track.name + " sea")) % 4
	var wide := SEA_OUT * 2.0 + (high - low).length()
	var middle := (low + high) * 0.5
	match side:
		0:
			_out = Vector2(0, 1)
			_sea = Rect2(Vector2(middle.x - wide * 0.5, high.y + SHORE), Vector2(wide, SEA_OUT))
		1:
			_out = Vector2(0, -1)
			_sea = Rect2(Vector2(middle.x - wide * 0.5, low.y - SHORE - SEA_OUT), Vector2(wide, SEA_OUT))
		2:
			_out = Vector2(1, 0)
			_sea = Rect2(Vector2(high.x + SHORE, middle.y - wide * 0.5), Vector2(SEA_OUT, wide))
		_:
			_out = Vector2(-1, 0)
			_sea = Rect2(Vector2(low.x - SHORE - SEA_OUT, middle.y - wide * 0.5), Vector2(SEA_OUT, wide))


## The sea and its beach, a pier out into it, waves breaking on the sand,
## and boats out on the water.
func _build_sea() -> void:
	var level := 0.0
	# On a hilly course the sea sits as high as the ground gets near the
	# shore, so no hill pokes up through it.
	var shore_mid := _sea.get_center() - _out * _sea.size.dot(_out.abs()) * 0.5
	var along := Vector2(_out.y, _out.x).abs()
	for k in range(-20, 21):
		for d in [0.0, 20.0, 40.0]:
			var spot: Vector2 = shore_mid + along * k * 20.0 + _out * d
			level = maxf(level, ground.call(spot.x, spot.y))
	var centre := _sea.get_center()
	var sea_size := Vector3(_sea.size.x, 0.2, _sea.size.y)
	_kit.box(Vector3(centre.x, level - 0.05, centre.y), sea_size, Color("#1e6fb5"), SceneryKit.WATER, false)
	# The beach, a band of sand along the shore on the land side.
	var beach := _sea.grow_individual(
		BEACH if _out.x > 0.0 else 0.0, BEACH if _out.y > 0.0 else 0.0,
		BEACH if _out.x < 0.0 else 0.0, BEACH if _out.y < 0.0 else 0.0)
	var beach_centre := beach.get_center()
	_kit.box(Vector3(beach_centre.x, level - 0.08, beach_centre.y), Vector3(beach.size.x, 0.2, beach.size.y), Props.TAN, SceneryKit.SMOOTH, false)
	# Waves breaking just off the sand.
	for k in range(-24, 25):
		var spot: Vector2 = shore_mid + along * (k * 18.0 + _rng.randf_range(-5.0, 5.0)) + _out * _rng.randf_range(2.0, 9.0)
		var size := Vector3(along.x, 0.0, along.y) * _rng.randf_range(5.0, 11.0) + Vector3(_out.x, 0.0, _out.y).abs() * 0.5 + Vector3.UP * 0.12
		_kit.box(Vector3(spot.x, level + 0.08, spot.y), size, Props.WHITE, SceneryKit.SMOOTH, false)
	# A pier straight out from the middle of the shore.
	var pier_from := shore_mid - _out * 6.0
	for k in 12:
		var spot: Vector2 = pier_from + _out * (k * 4.0 + 2.0)
		var deck := Vector3(along.x, 0.0, along.y) * 4.0 + Vector3(_out.x, 0.0, _out.y).abs() * 4.1 + Vector3.UP * 0.3
		_kit.box(Vector3(spot.x, level + 1.2, spot.y), deck, Props.BROWN, SceneryKit.SMOOTH, false)
		for side in [-1.8, 1.8]:
			var post: Vector2 = spot + along * side
			_kit.box(Vector3(post.x, level - 1.0, post.y), Vector3(0.3, 2.2, 0.3), Props.DARK_TAN, SceneryKit.BRICK, false)
	var end := pier_from + _out * 50.0
	_kit.box(Vector3(end.x, level + 1.35, end.y), Vector3(3.0, 2.4, 3.0), Props.WHITE, SceneryKit.BRICK, false)
	_kit.box(Vector3(end.x, level + 3.75, end.y), Vector3(3.4, 0.3, 3.4), Props.RED, SceneryKit.SMOOTH, false)
	# Boats out on the water.
	for k in 7:
		var spot: Vector2 = shore_mid + along * _rng.randf_range(-260.0, 260.0) + _out * _rng.randf_range(40.0, 300.0)
		_boat(Vector3(spot.x, level, spot.y), _rng.randf() * TAU)


## A little boat: a hull, a deck and, for most, a mast and sail.
func _boat(at: Vector3, heading: float) -> void:
	var turn := Basis(Vector3.UP, heading)
	# It rocks gently on the water.
	_kit.begin_mover(Transform3D(Basis.IDENTITY, at), { "swing": turn * Vector3.BACK, "angle": 0.06, "rate": 1.1 })
	var hull: Color = [Props.WHITE, Props.RED, Props.BLUE, Props.YELLOW][_rng.randi() % 4]
	_kit.turned_box(at + Vector3.UP * 0.4, Vector3(2.4, 1.0, 7.0), turn, hull, SceneryKit.SMOOTH)
	_kit.turned_box(at + Vector3.UP * 0.95 + turn * Vector3(0.0, 0.0, 2.6), Vector3(1.6, 0.4, 2.0), turn, hull.lightened(0.2), SceneryKit.SMOOTH)
	if _rng.randf() < 0.7:
		_kit.turned_cylinder(at + Vector3.UP * 4.5, 0.08, 7.0, turn, Props.WHITE)
		_kit.turned_box(at + Vector3.UP * 4.0 + turn * Vector3(0.0, 0.0, -1.2), Vector3(0.05, 5.5, 2.6), turn, Props.WHITE, SceneryKit.SMOOTH)
	else:
		_kit.turned_box(at + Vector3.UP * 1.5 + turn * Vector3(0.0, 0.0, -1.0), Vector3(1.8, 1.2, 2.4), turn, Props.WHITE, SceneryKit.SMOOTH)
	_kit.end_mover()


## The hall around an indoor course: its walls with a coloured band round
## them, posts holding it up, and roof beams across it with rows of lights
## hanging under them. There's no roof over the top, so the sun still lights
## the floor, and the dark past the beams looks like the roof.
func _build_hall() -> void:
	var r := _hall
	var wall := Color(theme.get("hall", "#e4e4e0"))
	var band := Color(theme.wall)
	var light := Color(theme.get("lights", "#fff4d6"))
	var middle := r.get_center()
	# The four walls, each with a band along its inside.
	var walls := [
		[Vector3(middle.x, 0.0, r.position.y), Vector3(r.size.x + 1.0, HALL_HEIGHT, 1.0), Vector3(0.0, 0.0, 0.6)],
		[Vector3(middle.x, 0.0, r.end.y), Vector3(r.size.x + 1.0, HALL_HEIGHT, 1.0), Vector3(0.0, 0.0, -0.6)],
		[Vector3(r.position.x, 0.0, middle.y), Vector3(1.0, HALL_HEIGHT, r.size.y + 1.0), Vector3(0.6, 0.0, 0.0)],
		[Vector3(r.end.x, 0.0, middle.y), Vector3(1.0, HALL_HEIGHT, r.size.y + 1.0), Vector3(-0.6, 0.0, 0.0)],
	]
	for w in walls:
		_kit.box(w[0], w[1], wall, SceneryKit.BRICK, false)
		var strip: Vector3 = w[1] * Vector3(1.0, 0.0, 1.0) - w[2].abs() * 0.8 + Vector3(0.0, 1.2, 0.0)
		_kit.box(w[0] + w[2] + Vector3.UP * 3.0, strip, band, SceneryKit.SMOOTH, false)
	# Posts along the long walls and a beam across from each pair, with lights
	# along it. The beams go across the narrow way.
	var long_x := r.size.x >= r.size.y
	var length := r.size.x if long_x else r.size.y
	var span := r.size.y if long_x else r.size.x
	var along := BEAM_EVERY
	while along < length:
		var x := r.position.x + along if long_x else middle.x
		var z := middle.y if long_x else r.position.y + along
		var beam := Vector3(0.6, 1.0, span) if long_x else Vector3(span, 1.0, 0.6)
		_kit.box(Vector3(x, HALL_HEIGHT - 1.0, z), beam, Props.DARK_GREY, SceneryKit.SMOOTH, false)
		for end in [-0.5, 0.5]:
			var post := Vector3(x, 0.0, z + span * end) if long_x else Vector3(x + span * end, 0.0, z)
			post -= (Vector3(0.0, 0.0, signf(end)) if long_x else Vector3(signf(end), 0.0, 0.0)) * 1.0
			_kit.box(post, Vector3(1.0, HALL_HEIGHT - 1.0, 1.0), Props.LIGHT_GREY, SceneryKit.BRICK, false)
		var across := LIGHT_EVERY * 0.5
		while across < span:
			var at := Vector3(x, HALL_HEIGHT - 1.4, r.position.y + across) if long_x else Vector3(r.position.x + across, HALL_HEIGHT - 1.4, z)
			var size := Vector3(0.5, 0.25, 3.0) if long_x else Vector3(3.0, 0.25, 0.5)
			_kit.box(at, size, light, SceneryKit.GLOW, false)
			across += LIGHT_EVERY
		along += BEAM_EVERY


## The spot halfway across the grass between the road at sample `k` and other
## road out to one side (-1 left, 1 right), or INF if there's none close.
func _between(k: int, side: float, edge: float) -> Vector3:
	var p := track.points[k]
	if not track.solids[k] or track.stickies[k] or p.y > TrackBuilder.RAISED or track.ups[k].y < 0.985:
		return Vector3.INF
	var fwd := Vector3(track.forwards[k].x, 0.0, track.forwards[k].z).normalized()
	var right := Vector3(track.rights[k].x, 0.0, track.rights[k].z).normalized() * side
	var nearest := INF
	var partner := -1
	var looked := {}
	var reach := 0.0
	while reach <= BARRIER_REACH:
		var probe := p + right * reach
		var key := Vector2i(floori(probe.x / 16.0), floori(probe.z / 16.0))
		reach += 8.0
		if looked.has(key):
			continue
		looked[key] = true
		for j in _hash.get(key, []):
			var along := absf(track.distances[j] - track.distances[k])
			if minf(along, track.length - along) < BARRIER_REACH * 1.5:
				continue
			var v := track.points[j] - p
			if absf(v.y) > 2.0 or absf(v.dot(fwd)) > 6.0:
				continue
			var across := v.dot(right)
			if across > edge and across < nearest:
				nearest = across
				partner = j
	if partner < 0 or nearest > BARRIER_REACH or track.distances[partner] < track.distances[k]:
		return Vector3.INF
	# Walls all along both bits of road already keep karts from cutting across.
	# A cut bend's inside is open, so it still needs the tire line.
	var here: TrackPiece = track.pieces[track.piece_of[k]]
	var there: TrackPiece = track.pieces[track.piece_of[partner]]
	if here.forced_walls() and not here.cut and there.forced_walls() and not there.cut:
		return Vector3.INF
	var at := p + right * nearest * 0.5
	at = _grounded(at)
	# Not on any road (a crossing, say), or on a cut bend's dirt.
	if _near_other_road(at, edge + 1.0, k, 0.0):
		return Vector3.INF
	for spot in keep_clear:
		if Vector2(spot[0].x - at.x, spot[0].z - at.z).length() < spot[1]:
			return Vector3.INF
	return at


## A small island for something beside the road to stand on, up in the sky.
## It isn't solid, so they're kept back far enough that a kart running wide
## is put back before it gets there.
func _pad(top: Vector3, radius: float) -> void:
	if _floating:
		_island(top, radius, 0, false)


## A floating island, with nothing solid in it (see Props.floating_island()).
func _island(top: Vector3, radius: float, trees: int, waterfall: bool) -> void:
	var solid := _kit.solids.size()
	Props.floating_island(_kit, top, radius, _rng, trees, waterfall)
	_kit.solids.resize(solid)


## Floating islands for a theme with no ground: big ones well below the road
## every so often, more all around at all heights, and clouds below it all.
## Near the road they sit well down, so a kart that goes off is put back
## before it could land on one. Ones well away from the road drop out in the
## distance and on lower graphics like the trees do.
func _sky_islands() -> void:
	var lowest := INF
	# How high the road is at each point seen from above, the lowest where it
	# passes over itself, to look up from the distance map.
	var heights := {}
	for p in track.points:
		lowest = minf(lowest, p.y)
		var flat := Vector2(p.x, p.z)
		heights[flat] = minf(heights.get(flat, INF), p.y)
	var islands: Array = [] # [top, radius]
	var room := func(top: Vector3, radius: float) -> bool:
		for other in islands:
			if Vector2(other[0].x - top.x, other[0].z - top.z).length() < other[1] + radius + 6.0 and absf(other[0].y - top.y) < radius + other[1]:
				return false
		for spot in _placed:
			var depth: float = spot[2] if spot.size() > 2 else 25.0
			if Vector2(spot[0].x - top.x, spot[0].z - top.z).length() < spot[1] + radius + 2.0 and top.y > spot[0].y - depth:
				return false
		return true
	# Under the road.
	var next := 0.0
	for k in track.points.size():
		if track.distances[k] < next or track.stickies[k] or track.ups[k].y < 0.9:
			continue
		var p := track.points[k]
		var radius := _rng.randf_range(10.0, 16.0)
		var top := p + track.rights[k] * _rng.randf_range(-8.0, 8.0) + Vector3.DOWN * _rng.randf_range(18.0, 30.0)
		if room.call(top, radius):
			islands.append([top, radius])
			_island(top, radius, 1 + _rng.randi() % 3, _rng.randf() < 0.4)
		next = track.distances[k] + _rng.randf_range(80.0, 120.0)
	# All around, nearer ones lower down.
	var cells := []
	for i in _dist.size():
		if _dist[i] > _road_clear and _dist[i] < REACH:
			cells.append(i)
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var around := 0
	for i in cells:
		if around >= SKY_ISLANDS:
			break
		var d := _dist[i]
		var radius := _rng.randf_range(5.0, 9.0) + d * 0.08
		var c := _centre(i % _cols, i / _cols)
		var road: float = heights.get(_near[i], lowest)
		var gap := d - radius - track.width * 0.5
		var top := Vector3(c.x, road - _rng.randf_range(12.0, 24.0), c.y)
		if gap > 30.0:
			top.y = road + _rng.randf_range(-24.0, 10.0)
		if gap < 0.0 or not room.call(top, radius):
			continue
		islands.append([top, radius])
		around += 1
		_kit.far = gap > 30.0
		var trees := 0 if radius < 6.5 else 1 + _rng.randi() % 3
		var waterfall := radius > 8.0 and _rng.randf() < 0.35
		if _kit.far and not Graphics.draws_far(top):
			var kept := _kit
			_kit = SceneryKit.new()
			_island(top, radius, trees, waterfall)
			_kit = kept
		else:
			_island(top, radius, trees, waterfall)
	# Clouds below, spread across the whole course. They stay in the
	# distance, since you look down on them from all over.
	_kit.far = false
	var span := Vector2(_cols, _rows) * CELL
	var count := clampi(int(span.x * span.y / 5000.0), 12, SKY_CLOUDS)
	for n in count:
		var at := Vector3(_origin.x + _rng.randf() * span.x, lowest - _rng.randf_range(40.0, 60.0), _origin.y + _rng.randf() * span.y)
		Props.cloud(_kit, at, _rng.randf_range(18.0, 36.0), _rng)


## Something nasty in the gap of every jump: lava by the volcano, and water
## everywhere else.
func _under_jumps() -> void:
	var lava := track.theme == "volcano"
	# In the snowy mountains it's a ski jump, over snow and ice.
	var ice: bool = theme.get("peaks", false) and theme.get("floor", "") == "snow"
	for k in range(0, track.points.size(), 1):
		if track.solids[k]:
			continue
		var p := track.points[k]
		var flat_forward := Vector3(track.forwards[k].x, 0.0, track.forwards[k].z).normalized()
		var basis := Basis.looking_at(flat_forward, Vector3.UP)
		var size := Vector3(track.width + 6.0, 0.08, 1.2)
		var at := _grounded(p) + Vector3.UP * 0.04
		if ice:
			_kit.turned_box(at, size + Vector3(1.0, 0.0, 0.0), basis, Props.WHITE, SceneryKit.SMOOTH)
			_kit.turned_box(at + Vector3.UP * 0.02, size - Vector3(4.0, 0.0, 0.0), basis, Color("#bfe3f2"), SceneryKit.WATER)
		else:
			_kit.turned_box(at, size + Vector3(1.0, 0.0, 0.0), basis, Props.BLACK if lava else Props.TAN, SceneryKit.SMOOTH)
			_kit.turned_box(at + Vector3.UP * 0.02, size, basis, Props.LAVA if lava else Props.WATER, SceneryKit.GLOW if lava else SceneryKit.WATER)
		_placed.append([at, 3.0])


## Big snowy peaks in a ring far out round the course, their feet past the
## edge of the ground so the view goes all the way to the mountains. None of
## them is solid and none of them breaks.
func _far_peaks() -> void:
	var low := Vector2(INF, INF)
	var high := -Vector2(INF, INF)
	for p in track.points:
		low = low.min(Vector2(p.x, p.z))
		high = high.max(Vector2(p.x, p.z))
	var middle := (low + high) * 0.5
	var half := (high - low) * 0.5 + Vector2.ONE * (REACH + 45.0 + 70.0)
	var half_out := half
	var level := _far_level(middle, (high - low) * 0.5 + Vector2.ONE * (REACH + 45.0))
	var count := 18
	for k in count:
		var a := TAU * (k + _rng.randf_range(-0.25, 0.25)) / count
		var dir := Vector2(cos(a), sin(a))
		# Out to the edge of a box round the course, then further out.
		var reach := minf(half.x / maxf(absf(dir.x), 0.01), half.y / maxf(absf(dir.y), 0.01))
		var spot := middle + dir * (reach + _rng.randf_range(0.0, 140.0))
		var at := Vector3(spot.x, level - 5.0, spot.y)
		half_out = half_out.max((spot - middle).abs())
		# A lower graphics setting leaves some out, like far fillers. Marking
		# them far would hide them all, as they're always out of a far cell's range.
		if Graphics.draws_far(at):
			Props.snowy_peak(_kit, at, _rng, _rng.randf_range(1.6, 2.8), false)
		else:
			Props.snowy_peak(SceneryKit.new(), at, _rng, _rng.randf_range(1.6, 2.8), false)
	_far_floor(middle, half_out + Vector2.ONE * 150.0, level)


## Red mesas and buttes in a ring far out round the course, like
## _far_peaks(). None of them is solid and none of them breaks.
func _far_mesas() -> void:
	var low := Vector2(INF, INF)
	var high := -Vector2(INF, INF)
	for p in track.points:
		low = low.min(Vector2(p.x, p.z))
		high = high.max(Vector2(p.x, p.z))
	var middle := (low + high) * 0.5
	# A theme can bring them in closer, past the scenery but still clear of
	# everything else.
	var out: float = theme.get("mesas_out", 70.0)
	var half := (high - low) * 0.5 + Vector2.ONE * (REACH + 45.0 + out)
	var half_out := half
	var level := _far_level(middle, (high - low) * 0.5 + Vector2.ONE * (REACH + 45.0))
	var count := 16
	for k in count:
		var a := TAU * (k + _rng.randf_range(-0.25, 0.25)) / count
		var dir := Vector2(cos(a), sin(a))
		var reach := minf(half.x / maxf(absf(dir.x), 0.01), half.y / maxf(absf(dir.y), 0.01))
		var spot := middle + dir * (reach + _rng.randf_range(0.0, 160.0))
		var at := Vector3(spot.x, level - 1.0, spot.y)
		half_out = half_out.max((spot - middle).abs())
		var kit := _kit if Graphics.draws_far(at) else SceneryKit.new()
		if k % 3 == 1:
			Props.butte(kit, at, _rng, _rng.randf_range(1.4, 2.0), false)
		else:
			Props.mesa(kit, at, _rng, _rng.randf_range(1.6, 2.6), false)
	_far_floor(middle, half_out + Vector2.ONE * 150.0, level)


## Tall rock towers with jungle on top in a ring far out round the course,
## like _far_peaks(). None of them is solid and none of them breaks.
func _far_karsts() -> void:
	var low := Vector2(INF, INF)
	var high := -Vector2(INF, INF)
	for p in track.points:
		low = low.min(Vector2(p.x, p.z))
		high = high.max(Vector2(p.x, p.z))
	var middle := (low + high) * 0.5
	var half := (high - low) * 0.5 + Vector2.ONE * (REACH + 45.0 + 90.0)
	var half_out := half
	var level := _far_level(middle, (high - low) * 0.5 + Vector2.ONE * (REACH + 45.0))
	var count := 16
	for k in count:
		var a := TAU * (k + _rng.randf_range(-0.3, 0.3)) / count
		var dir := Vector2(cos(a), sin(a))
		var reach := minf(half.x / maxf(absf(dir.x), 0.01), half.y / maxf(absf(dir.y), 0.01))
		var spot := middle + dir * (reach + _rng.randf_range(0.0, 180.0))
		var at := Vector3(spot.x, level - 1.0, spot.y)
		half_out = half_out.max((spot - middle).abs())
		var kit := _kit if Graphics.draws_far(at) else SceneryKit.new()
		Props.karst(kit, at, _rng, _rng.randf_range(1.3, 2.4), false)
	_far_floor(middle, half_out + Vector2.ONE * 150.0, level)


## Tall towers with lit windows in a ring far out round the course, like
## _far_peaks(). None of them is solid and none of them breaks.
func _far_skyline() -> void:
	var low := Vector2(INF, INF)
	var high := -Vector2(INF, INF)
	for p in track.points:
		low = low.min(Vector2(p.x, p.z))
		high = high.max(Vector2(p.x, p.z))
	var middle := (low + high) * 0.5
	var half := (high - low) * 0.5 + Vector2.ONE * (REACH + 30.0)
	var half_out := half
	var level := _far_level(middle, (high - low) * 0.5 + Vector2.ONE * (REACH + 30.0))
	var count := 30
	for k in count:
		var a := TAU * (k + _rng.randf_range(-0.35, 0.35)) / count
		var dir := Vector2(cos(a), sin(a))
		var reach := minf(half.x / maxf(absf(dir.x), 0.01), half.y / maxf(absf(dir.y), 0.01))
		var spot := middle + dir * (reach + _rng.randf_range(0.0, 120.0))
		var at := Vector3(spot.x, level - 1.0, spot.y)
		half_out = half_out.max((spot - middle).abs())
		var kit := _kit if Graphics.draws_far(at) else SceneryKit.new()
		var w := _rng.randf_range(14.0, 26.0)
		var h := _rng.randf_range(40.0, 110.0)
		var colour: Color = Props.CITY_WALLS[_rng.randi() % Props.CITY_WALLS.size()].darkened(0.15)
		kit.box(at, Vector3(w, h, w * _rng.randf_range(0.7, 1.0)), colour, SceneryKit.WINDOWS, false)
		if _rng.randf() < 0.5:
			kit.box(at + Vector3.UP * h, Vector3(w * 0.6, h * 0.25, w * 0.6), colour, SceneryKit.WINDOWS, false)
	_far_floor(middle, half_out + Vector2.ONE * 150.0, level)


## How high the far ring and the ground under it go: a metre below the lowest
## ground on the baseplate, which is the whole box of `half` round `middle`,
## or the road.
func _far_level(middle: Vector2, half: Vector2) -> float:
	var lowest := 0.0
	for p in track.points:
		lowest = minf(lowest, p.y - 1.0)
	var x := middle.x - half.x
	while x <= middle.x + half.x:
		var z := middle.y - half.y
		while z <= middle.y + half.y:
			lowest = minf(lowest, ground.call(x, z))
			z += 8.0
		x += 8.0
	return lowest - 1.0


## Plain ground in the theme's colour from the edge of the baseplate out past
## the far ring, with its top at `level`, so the far peaks or mesas stand on
## something. A jungle floor's is darker and browner, about as the leaves and
## dirt look from far off (see BrickShaders.BASEPLATE).
func _far_floor(middle: Vector2, half: Vector2, level: float) -> void:
	var colour := Color(theme.get("ground", "#4b9f4a"))
	if theme.get("litter", false):
		colour = (colour.srgb_to_linear() * 0.78).lerp(Color(0.34, 0.25, 0.15).srgb_to_linear(), 0.3).linear_to_srgb()
	_kit.box(Vector3(middle.x, level - 1.0, middle.y), Vector3(half.x * 2.0, 1.0, half.y * 2.0), colour, SceneryKit.PLAIN, false)


## What the pit building looks like on this theme (see Props.pit_building()).
func _pit_style() -> String:
	if theme.get("peaks", false):
		return "alpine"
	if theme.get("mesas", false):
		return "western"
	if theme.get("karsts", false):
		return "jungle"
	if theme.get("skyline", false):
		return "city"
	return ""


## The grandstand and the pit building face each other across the start
## straight, with flags along it. The grandstand goes on the side with more
## room. On some courses other road comes back right beside the start
## straight, so each one is only built where it's clear of all of it, and
## left out if there's no room either side.
func _start_area(edge: float) -> void:
	var frame := track.frame_at(8.0)
	var fwd := -frame.basis.z
	var right := frame.basis.x
	var start_k := track._index_before(8.0)
	var sides: Array[float] = [1.0, -1.0]
	if _distance_at(frame.origin - right * (edge + 12.0)) > _distance_at(frame.origin + right * (edge + 12.0)):
		sides = [-1.0, 1.0]
	var built := 0
	for side in sides:
		if built == 2:
			break
		var front: Vector3 = frame.origin + right * side * (edge + 3.0) - fwd * 4.0
		front = _grounded(front)
		# The building goes back away from the road, so that's the way to look.
		if not _clear_of_other_road(front, fwd, right * side, 32.0, 8.0, start_k):
			continue
		_kit.begin("grandstand" if built == 0 else "pit_building", false)
		if built == 0:
			Props.grandstand(_kit, front, 30.0, _facing_for(-right * side), _rng)
		else:
			Props.pit_building(_kit, front, 30.0, _facing_for(-right * side), _pit_style())
		_kit.done()
		# Two islands side by side under it, kept well back from the road.
		for along: float in [-8.0, 8.0]:
			_pad(front + right * side * 7.0 + fwd * along + Vector3.DOWN * 0.1, 11.0)
		_placed.append([front + right * side * 3.5, 17.0])
		built += 1
	if _floating:
		return
	for k in 4:
		for side in [-1.0, 1.0]:
			var at: Vector3 = frame.origin + fwd * (18.0 + k * 6.0) + right * side * (edge + 1.5)
			at = _grounded(at)
			# The start straight can bend soon after the line, so check all the
			# road, not just other bits of it.
			if not _near_other_road(at, edge + 1.0, start_k, 0.0) and not _on_strip(at, 1.0):
				_kit.begin("flag", true)
				Props.flag(_kit, at, [Props.RED, Props.YELLOW, Props.BLUE, Props.GREEN][k])
				_kit.done()


## Whether a building `length` long and `depth` deep, with its front middle at
## `front` running along `along` and going back along `back`, stays clear of
## every bit of road, including the start straight it faces (which isn't
## always straight all the way along).
func _clear_of_other_road(front: Vector3, along: Vector3, back: Vector3, length: float, depth: float, own: int) -> bool:
	var edge := track.width * 0.5 + TrackPath.KERB + RUNOFF
	var x := -length * 0.5
	while x <= length * 0.5:
		for d in [0.0, depth * 0.5, depth]:
			if _near_other_road(front + along * x + back * d, edge, own, 0.0) or _on_strip(front + along * x + back * d, 3.0):
				return false
		x += 4.0
	return true


# The theme.

func _place_landmark(prop: String) -> void:
	var room: float = Props.ROOM.get(prop, 3.0)
	var best := Vector3.INF
	var best_score := -INF
	for y in _rows:
		for x in _cols:
			var d := _dist[y * _cols + x]
			if d < _road_clear + room or d > _road_clear + room + 45.0:
				continue
			var c := _centre(x, y)
			var at := Vector3(c.x, 0.0, c.y)
			if not _free(at, room) or not _inside_hall(at, room):
				continue
			# Close enough to the road to be seen, with a little randomness so
			# they don't all line up the same way.
			var score := -absf(d - (_road_clear + room + 8.0)) + _rng.randf() * 10.0
			if score > best_score:
				best_score = score
				best = at
	if best != Vector3.INF:
		_add(prop, best)


## Ferns, saplings and the like packed along the road on both sides, after
## the fillers, in whatever room they left.
func _undergrowth() -> void:
	var plants: Dictionary = theme.get("undergrowth", {})
	var total := 0
	for w in plants.values():
		total += w
	if total == 0:
		return
	var cells := []
	for i in _dist.size():
		if _dist[i] > _road_clear + 1.0 and _dist[i] < _road_clear + UNDERGROWTH_REACH:
			cells.append(i)
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	_kit.far = true
	var count := 0
	var most: int = theme.get("undergrowth_max", MAX_UNDERGROWTH)
	for i in cells:
		if count >= most:
			break
		var pick := _rng.randi() % total
		var prop := ""
		for name in plants:
			pick -= plants[name]
			if pick < 0:
				prop = name
				break
		var c := _centre(i % _cols, i / _cols)
		var at := Vector3(c.x + _rng.randf_range(-1.5, 1.5), 0.0, c.y + _rng.randf_range(-1.5, 1.5))
		if _free(at, Props.ROOM.get(prop, 3.0)) and _inside_hall(at, Props.ROOM.get(prop, 3.0)):
			_add(prop, at)
			count += 1
	_kit.far = false


func _fill() -> void:
	var fillers: Dictionary = theme.get("fillers", {})
	var total := 0
	for w in fillers.values():
		total += w
	if total == 0:
		return
	var cells := []
	var reach: float = theme.get("filler_reach", REACH * 0.8)
	for i in _dist.size():
		if _dist[i] > _road_clear + 1.5 and _dist[i] < _road_clear + reach:
			cells.append(i)
	# Shuffle with our own seed, so it's the same every time.
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	_kit.far = true
	var count := 0
	var most: int = theme.get("filler_max", MAX_FILLERS)
	for i in cells:
		if count >= most:
			break
		# Denser near the road, where you can see it.
		var d := _dist[i] - _road_clear
		if _rng.randf() > 0.75 - d / (REACH * 1.5):
			continue
		var pick := _rng.randi() % total
		var prop := ""
		for name in fillers:
			pick -= fillers[name]
			if pick < 0:
				prop = name
				break
		var c := _centre(i % _cols, i / _cols)
		var at := Vector3(c.x + _rng.randf_range(-1.0, 1.0), 0.0, c.y + _rng.randf_range(-1.0, 1.0))
		if _free(at, Props.ROOM.get(prop, 3.0)) and _inside_hall(at, Props.ROOM.get(prop, 3.0)):
			# Far off, where nothing can hit it, a lower graphics setting
			# leaves some out (see Graphics). It's still made, into a kit
			# that's thrown away, so everything after it comes out the same.
			if _dist[i] > SOLID_REACH + Props.ROOM.get(prop, 3.0) and not Graphics.draws_far(at):
				var kept := _kit
				_kit = SceneryKit.new()
				_add(prop, at)
				_kit = kept
			else:
				_add(prop, at)
			count += 1
	_kit.far = false
