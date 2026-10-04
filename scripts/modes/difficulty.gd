class_name Difficulty
extends RefCounted

## How good the AI drivers are. You pick a level before a Grand Prix or a race
## against the AI, and a Grand Prix keeps it for all four races.
##
## Each level sets:
## - skill: how close to their kart's grip limit the AI dare corner, from the
##   slowest driver to the quickest. The field stays spread out, and which
##   driver's quickest is drawn at random for each race, or once for a Grand
##   Prix (see Game.draw_ranks()).
## - pace: how hard they push their engines, as a fraction. Lower levels take
##   it easier on the straights too, not just in the bends.
## - mistakes: the chance of going into a bend too fast or too slow.
## - loop_nerves: the chance of losing their nerve on the way up a loop,
##   backing off and falling off it.
## - gadgets: how often they use a gadget when the moment's right, from 0 to 1.
## - catch_up: how much extra push they get when they're a long way behind
##   you, as a fraction.
## - ease_off: how much they lift off when they're a long way ahead of you.
## - slides: whether they slide round the tightest bends (see Kart.sliding),
##   which only the best drivers do, and only where it's quicker.

const LEVELS := ["easy", "normal", "hard", "expert"]
const DEFAULT := "normal"

const SETTINGS := {
	"easy": {
		"name": "Easy",
		"about": "Relaxed drivers who make mistakes and wait for you.",
		"skill": [0.44, 0.54],
		"pace": 0.65,
		"mistakes": 0.25,
		"loop_nerves": 0.15,
		"gadgets": 0.3,
		"catch_up": 0.0,
		"ease_off": 0.3,
	},
	"normal": {
		"name": "Normal",
		"about": "A fair race, with the odd slip.",
		"skill": [0.64, 0.74],
		"pace": 0.78,
		"mistakes": 0.1,
		"loop_nerves": 0.0,
		"gadgets": 0.7,
		"catch_up": 0.04,
		"ease_off": 0.2,
	},
	"hard": {
		"name": "Hard",
		"about": "Quick drivers who rarely slip and make the most of their power-ups.",
		"skill": [0.8, 0.9],
		"pace": 0.89,
		"mistakes": 0.02,
		"loop_nerves": 0.0,
		"gadgets": 1.0,
		"catch_up": 0.06,
		"ease_off": 0.0,
	},
	"expert": {
		"name": "Expert",
		"about": "Drivers right on the limit who never let up.",
		"skill": [0.95, 0.99],
		"pace": 1.0,
		"mistakes": 0.0,
		"loop_nerves": 0.0,
		"gadgets": 1.0,
		"catch_up": 0.0,
		"ease_off": 0.0,
		"slides": true,
	},
}
## How far behind you (or ahead) the AI have to be, in metres, before catch
## up (or easing off) starts, and how much further before it's at its most.
## They're for a lap of LAP metres, and grow with longer ones, so a gap feels
## the same on any course.
const CATCH_UP_FROM := 60.0
const CATCH_UP_OVER := 150.0
const EASE_OFF_FROM := 40.0
const EASE_OFF_OVER := 100.0
const LAP := 800.0


static func name_of(level: String) -> String:
	return SETTINGS.get(level, SETTINGS[DEFAULT]).name


static func about(level: String) -> String:
	return SETTINGS.get(level, SETTINGS[DEFAULT]).about


## Sets an AI driver up for this level. `rank` is where the driver comes in
## the field's pecking order, 0 for the quickest, out of `field` drivers.
static func apply(ai: AIDriver, level: String, rank: int, field: int) -> void:
	var s: Dictionary = SETTINGS.get(level, SETTINGS[DEFAULT])
	var skill: Array = s.skill
	ai.skill = lerpf(skill[1], skill[0], float(rank) / maxf(field - 1, 1))
	ai.pace = s.pace
	ai.mistakes = s.mistakes
	ai.loop_nerves = s.loop_nerves
	ai.gadget_sense = s.gadgets
	ai.slides = s.get("slides", false)
	ai.catch_up = s.catch_up
	ai.ease_off = s.ease_off


## How hard to push compared with usual, for an AI driver this far behind the
## nearest person racing (negative is ahead of them), on a lap this long.
static func push_for(behind: float, catch_up: float, ease_off: float, lap := LAP) -> float:
	var scale := maxf(lap / LAP, 1.0)
	if behind > CATCH_UP_FROM * scale:
		return 1.0 + catch_up * clampf((behind - CATCH_UP_FROM * scale) / (CATCH_UP_OVER * scale), 0.0, 1.0)
	if -behind > EASE_OFF_FROM * scale:
		return 1.0 - ease_off * clampf((-behind - EASE_OFF_FROM * scale) / (EASE_OFF_OVER * scale), 0.0, 1.0)
	return 1.0
