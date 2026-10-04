class_name Conditions
extends RefCounted

## The weather and the time of day for a race. They're picked before it
## starts and stay the same all race. Left to chance, they suit the course:
## snowy courses mostly snow, deserts get dust storms and never rain, and
## beaches are mostly sunny. Halls are always the same, since they're indoors.
##
## A race's conditions travel online as a dictionary, worked out once by the
## host, so everyone races in the same weather with the same puddles.

const WEATHERS := ["clear", "rain", "snow", "fog", "storm", "dust"]
const TIMES := ["morning", "day", "evening", "dusk", "night"]
const RANDOM := "random"

## What each kind is called on the screen.
const WEATHER_NAMES := {
	"random": "Random", "clear": "Clear", "rain": "Rain", "snow": "Snow",
	"fog": "Fog", "storm": "Storm", "dust": "Dust storm",
}
const TIME_NAMES := {
	"random": "Random", "morning": "Morning", "day": "Day", "evening": "Evening",
	"dusk": "Dusk", "night": "Night",
}

## Each course theme's climate. Any theme not here is temperate.
const CLIMATE_OF := {
	"frost": "snowy",
	"varmland": "nordic", "trondelag": "nordic",
	"desert": "desert", "park_desert": "desert",
	"golden_hills": "dry", "mine": "dry",
	"gran_canaria": "beach", "sardinia": "beach", "malta": "beach", "trulli": "beach",
	"brittany": "coastal", "phillip_island": "coastal", "delta": "coastal", "kent_downs": "coastal",
	"volcano": "volcanic",
	"space": "space",
	"hall_red": "indoor", "hall_green": "indoor", "hall_blue": "indoor", "hall_neon": "indoor",
}

## How likely each weather is in each climate, in the order of WEATHERS:
## clear, rain, snow, fog, storm, dust.
const WEATHER_ODDS := {
	"temperate": [55, 20, 5, 10, 10, 0],
	"coastal": [40, 30, 3, 15, 12, 0],
	"nordic": [40, 10, 35, 15, 0, 0],
	"snowy": [30, 0, 60, 10, 0, 0],
	"beach": [82, 8, 0, 3, 7, 0],
	"desert": [65, 0, 0, 0, 0, 35],
	"dry": [70, 0, 0, 5, 10, 15],
	"volcanic": [55, 0, 0, 25, 20, 0],
	"space": [85, 0, 0, 15, 0, 0],
}
## And each time of day, in the order of TIMES.
const TIME_ODDS := [20, 35, 20, 13, 12]

## How much the road grips and drags in each weather, times what it would
## dry.
const GRIP := {"rain": 0.78, "storm": 0.72, "snow": 0.62, "dust": 0.9}
const DRAG := {"snow": 1.25, "dust": 1.1}

var weather := "clear"
var time := "day"
## For anything else left to chance in the race, like where the puddles are.
var seed := 0
## Whether it's a hall, where the weather and time never change anything.
var indoor := false


## A clear day, the way every race used to be.
static func clear_day() -> Conditions:
	return Conditions.new()


## Works out the conditions for a race on a course with this theme. A pick
## of RANDOM is left to chance, weighted for the course's climate, using the
## seed, so the same seed always gives the same conditions.
static func resolve(theme: String, weather_pick: String, time_pick: String, chance_seed: int) -> Conditions:
	var c := Conditions.new()
	c.seed = chance_seed
	var climate: String = CLIMATE_OF.get(theme, "temperate")
	if climate == "indoor":
		c.indoor = true
		return c
	var rng := RandomNumberGenerator.new()
	rng.seed = chance_seed
	c.weather = weather_pick if WEATHERS.has(weather_pick) else WEATHERS[rng.rand_weighted(PackedFloat32Array(WEATHER_ODDS[climate]))]
	c.time = time_pick if TIMES.has(time_pick) else TIMES[rng.rand_weighted(PackedFloat32Array(TIME_ODDS))]
	return c


## The pick to use: the player's own if they made one, otherwise the
## course's, otherwise RANDOM.
static func picked(player_pick: String, course_pick: String) -> String:
	if player_pick != RANDOM and player_pick != "":
		return player_pick
	if course_pick != RANDOM and course_pick != "":
		return course_pick
	return RANDOM


static func from_dict(data: Dictionary) -> Conditions:
	var c := Conditions.new()
	c.weather = str(data.get("weather", "clear"))
	c.time = str(data.get("time", "day"))
	c.seed = int(data.get("seed", 0))
	c.indoor = bool(data.get("indoor", false))
	return c


func to_dict() -> Dictionary:
	return {"weather": weather, "time": time, "seed": seed, "indoor": indoor}


## Whether it's dark enough that lamps and kart lights come on.
func dark() -> bool:
	return not indoor and (time in ["dusk", "night"] or weather in ["storm", "fog", "dust"])


## How much the road grips, and drags, times what it would in the dry.
func grip() -> float:
	return 1.0 if indoor else GRIP.get(weather, 1.0)


func drag() -> float:
	return 1.0 if indoor else DRAG.get(weather, 1.0)


## How wet the road is, from 0 to 1.
func wet() -> float:
	if indoor:
		return 0.0
	# A snowy road's been cleared, so it's wet too.
	return {"rain": 0.8, "storm": 1.0, "snow": 0.55}.get(weather, 0.0)


## How much snow lies about, from 0 to 1.
func snow() -> float:
	return 1.0 if weather == "snow" and not indoor else 0.0


## How it reads on the screen, like "Rain at dusk".
func describe() -> String:
	if indoor:
		return "Indoors"
	return "%s, %s" % [WEATHER_NAMES[weather], TIME_NAMES[time].to_lower()]
