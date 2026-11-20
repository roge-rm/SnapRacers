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
## - top_speed: the share of their kart's top speed they go no faster than,
##   so they're slower on flowing courses too. 1 if it isn't set.
## - mistakes: the chance of going into a bend too fast or too slow.
## - loop_nerves: the chance of losing their nerve on the way up a loop,
##   backing off and falling off it.
## - gadgets: how often they notice a useful gadget opportunity.
## - gadget_reaction: seconds before using a newly acquired item.
## - gadget_planning: seconds ahead they judge moving targets and threats.
## - gadget_confidence: how certain they need a fixed shot to be.
## - catch_up: how much extra push they get when they're a long way behind
##   you, as a fraction.
## - ease_off: how much they lift off when they're a long way ahead of you.
## - line_follow: how much of the racing line they take, 1 right on it and 0
##   the middle of the road.
## - line_wander: how far they slowly wander either side of it, in metres,
##   more for the slower drivers in the field and less for the quicker.
## - line_late: how late they turn in, in metres.
## - branch_sense: how surely they take the quicker branch round a split,
##   0 to 1 (see AIDriver.pick_branch()).
## - racecraft: how much they set up passes for the next bend, tuck in to
##   slipstream and hold the side they picked, 0 to 1 (see AITrafficPlanner).
## - pass_wait: seconds they follow a kart that isn't much slower before
##   trying to pass it.

const LEVELS := ["easy", "normal", "hard", "expert"]
const DEFAULT := "normal"

const SETTINGS := {
	"easy": {
		"racecraft": 0.3,
		"pass_wait": 2.0,
		"line_follow": 0.55,
		"line_wander": 1.3,
		"line_late": 7.0,
		"branch_sense": 0.25,
		"traffic_reaction": 0.65,
		"traffic_planning": 1.6,
		"traffic_clearance": 0.8,
		"traffic_mass_ratio": 0.0,
		"traffic_contact_closing": 0.0,
		"traffic_contact_side": 0.0,
		"traffic_contact_time": 0.0,
		"traffic_contact_cooldown": 3.0,
		"name": "Easy",
		"about": "Relaxed drivers who make mistakes and wait for you.",
		"skill": [0.42, 0.51],
		"pace": 0.61,
		"top_speed": 0.65,
		"mistakes": 0.25,
		"loop_nerves": 0.15,
		"gadgets": 0.3,
		"gadget_reaction": 0.85,
		"gadget_planning": 0.65,
		"gadget_confidence": 0.95,
		"catch_up": 0.0,
		"ease_off": 0.3,
	},
	"normal": {
		"racecraft": 0.6,
		"pass_wait": 1.0,
		"line_follow": 0.9,
		"line_wander": 1.0,
		"line_late": 2.0,
		"branch_sense": 0.45,
		"traffic_reaction": 0.45,
		"traffic_planning": 2.0,
		"traffic_clearance": 0.6,
		"traffic_mass_ratio": 0.0,
		"traffic_contact_closing": 0.0,
		"traffic_contact_side": 0.0,
		"traffic_contact_time": 0.0,
		"traffic_contact_cooldown": 3.0,
		"name": "Normal",
		"about": "A fair race, with the odd slip.",
		"skill": [0.55, 0.64],
		"pace": 0.65,
		"top_speed": 0.9,
		"mistakes": 0.1,
		"loop_nerves": 0.0,
		"gadgets": 0.7,
		"gadget_reaction": 0.55,
		"gadget_planning": 1.0,
		"gadget_confidence": 0.88,
		"catch_up": 0.04,
		"ease_off": 0.2,
	},
	"hard": {
		"racecraft": 0.85,
		"pass_wait": 0.5,
		"line_follow": 1.0,
		"line_wander": 0.5,
		"line_late": 0.0,
		"branch_sense": 0.85,
		"traffic_reaction": 0.3,
		"traffic_planning": 2.5,
		"traffic_clearance": 0.25,
		"traffic_mass_ratio": 1.25,
		"traffic_contact_closing": 1.5,
		"traffic_contact_side": 0.5,
		"traffic_contact_time": 0.2,
		"traffic_contact_cooldown": 3.0,
		"name": "Hard",
		"about": "Quick drivers who rarely slip and make the most of their power-ups.",
		"skill": [0.70, 0.80],
		"pace": 0.83,
		"mistakes": 0.02,
		"loop_nerves": 0.0,
		"gadgets": 1.0,
		"gadget_reaction": 0.3,
		"gadget_planning": 1.5,
		"gadget_confidence": 0.78,
		"catch_up": 0.06,
		"ease_off": 0.0,
	},
	"expert": {
		"racecraft": 1.0,
		"pass_wait": 0.3,
		"line_follow": 1.0,
		"line_wander": 0.2,
		"line_late": 0.0,
		"branch_sense": 1.0,
		"traffic_reaction": 0.2,
		"traffic_planning": 3.0,
		"traffic_clearance": 0.15,
		"traffic_mass_ratio": 1.1,
		"traffic_contact_closing": 2.5,
		"traffic_contact_side": 0.8,
		"traffic_contact_time": 0.35,
		"traffic_contact_cooldown": 2.0,
		"name": "Expert",
		"about": "Drivers right on the limit who never let up.",
		"skill": [0.95, 0.99],
		"pace": 1.0,
		"mistakes": 0.0,
		"loop_nerves": 0.0,
		"gadgets": 1.0,
		"gadget_reaction": 0.15,
		"gadget_planning": 2.0,
		"gadget_confidence": 0.68,
		"catch_up": 0.0,
		"ease_off": 0.0,
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
## With `traits` their own way of racing nudges it (see personalise()).
static func apply(ai: AIDriver, level: String, rank: int, field: int, traits: DriverTraits = null) -> void:
	var s: Dictionary = SETTINGS.get(level, SETTINGS[DEFAULT])
	var skill: Array = s.skill
	ai.skill = lerpf(skill[1], skill[0], float(rank) / maxf(field - 1, 1))
	ai.pace = s.pace
	ai.top_share = s.get("top_speed", 1.0)
	ai.mistakes = s.mistakes
	ai.loop_nerves = s.loop_nerves
	ai.gadget_sense = s.gadgets
	ai.gadget_reaction = s.gadget_reaction
	ai.gadget_planning = s.gadget_planning
	ai.gadget_confidence = s.gadget_confidence
	for setting in ["traffic_reaction", "traffic_planning", "traffic_clearance", "traffic_mass_ratio", "traffic_contact_closing", "traffic_contact_side", "traffic_contact_time", "traffic_contact_cooldown"]:
		ai.set(setting, s[setting])
	ai.line_follow = s.line_follow
	ai.line_wander = s.line_wander * lerpf(0.8, 1.2, float(rank) / maxf(field - 1, 1))
	ai.line_late = s.line_late
	ai.branch_sense = s.branch_sense
	ai.catch_up = s.catch_up
	ai.ease_off = s.ease_off
	ai.traffic_move_cost = 1.0
	ai.traffic_hold = 1.0
	ai.racecraft = s.racecraft
	ai.pass_wait = s.pass_wait
	ai.brake_late = 1.0
	ai.traits = traits if traits != null else DriverTraits.new()
	personalise(ai, ai.traits)


## How far each trait at 1 or -1 moves a setting, as a share of the level's
## value. Small enough that nobody drives like the next level, and settings
## a level has off (no rubbing below Hard, no mistakes at Expert) stay off.
const NUDGE := {
	"traffic_clearance": 0.3,
	"traffic_reaction": 0.15,
	"traffic_mass_ratio": 0.08,
	"traffic_contact_closing": 0.25,
	"traffic_contact_cooldown": 0.3,
	"traffic_move_cost": 0.4,
	"traffic_hold": 0.4,
	"pass_wait": 0.5,
	"mistakes": 0.35,
	"line_wander": 0.3,
	"brake_late": 0.06,
	"late_mistakes": 0.3,
}


## Nudges an AI driver's level settings by their traits: aggression packs
## them closer and quicker to react, and where the level allows rubbing,
## leaning on heavier karts sooner and more often. Patience makes a pass
## cost more before they pull out and holds the side they picked longer.
## Consistency means fewer misjudged bends and less wander. Late braking
## counts on more braking for bends, with more misjudged ones to match.
static func personalise(ai: AIDriver, traits: DriverTraits) -> void:
	var a := traits.aggression
	ai.traffic_clearance *= 1.0 - NUDGE.traffic_clearance * a
	ai.traffic_reaction *= 1.0 - NUDGE.traffic_reaction * a
	ai.traffic_mass_ratio *= 1.0 - NUDGE.traffic_mass_ratio * a
	ai.traffic_contact_closing *= 1.0 + NUDGE.traffic_contact_closing * a
	ai.traffic_contact_cooldown *= 1.0 - NUDGE.traffic_contact_cooldown * a
	ai.traffic_move_cost *= 1.0 + NUDGE.traffic_move_cost * traits.patience
	ai.traffic_hold *= 1.0 + NUDGE.traffic_hold * traits.patience
	ai.pass_wait *= clampf((1.0 + 0.35 * traits.patience) * (1.0 - 0.25 * a), 1.0 - NUDGE.pass_wait, 1.0 + NUDGE.pass_wait)
	# Only aggressive drivers defend, and never on Easy.
	ai.defends = ai.racecraft >= 0.5 and a > 0.2
	# Both together still stay within the share for mistakes.
	var slips := (1.0 - NUDGE.mistakes * traits.consistency) * (1.0 + NUDGE.late_mistakes * traits.late_braking)
	ai.mistakes *= clampf(slips, 1.0 - NUDGE.mistakes, 1.0 + NUDGE.mistakes)
	ai.line_wander *= 1.0 - NUDGE.line_wander * traits.consistency
	ai.brake_late *= 1.0 + NUDGE.brake_late * traits.late_braking


## How hard to push compared with usual, for an AI driver this far behind the
## nearest person racing (negative is ahead of them), on a lap this long.
static func push_for(behind: float, catch_up: float, ease_off: float, lap := LAP) -> float:
	var scale := maxf(lap / LAP, 1.0)
	if behind > CATCH_UP_FROM * scale:
		return 1.0 + catch_up * clampf((behind - CATCH_UP_FROM * scale) / (CATCH_UP_OVER * scale), 0.0, 1.0)
	if -behind > EASE_OFF_FROM * scale:
		return 1.0 - ease_off * clampf((-behind - EASE_OFF_FROM * scale) / (EASE_OFF_OVER * scale), 0.0, 1.0)
	return 1.0
