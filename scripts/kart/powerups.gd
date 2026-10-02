class_name Powerups
extends RefCounted

## The power-ups you pick up on the track. A kart holds up to two, one on
## each gadget button, and what you get is drawn at random when you drive
## through a box. The karts at the back get more of the strong ones, and the
## leader gets more of the ones for keeping others behind.

## How many a kart can hold.
const HOLD := 2

## Each one's name on its button, how many goes it has, and how likely it is
## for a kart at the front, the front half, the back half and the back.
const ALL := {
	"turbo": {"name": "Turbo", "uses": 1, "odds": [2, 4, 5, 3]},
	"big_turbo": {"name": "Big turbo", "uses": 1, "odds": [0, 2, 4, 5]},
	"triple_turbo": {"name": "Triple turbo", "uses": 3, "odds": [0, 1, 3, 5]},
	"tow": {"name": "Tow rope", "uses": 1, "odds": [0, 1, 3, 4]},
	"wall": {"name": "Brick wall", "uses": 1, "odds": [3, 2, 1, 0]},
	"shockwave": {"name": "Shockwave", "uses": 1, "odds": [1, 2, 2, 2]},
	"spikes": {"name": "Spike trap", "uses": 1, "odds": [3, 2, 1, 0]},
	"dropper": {"name": "Bricks", "uses": 1, "odds": [5, 3, 1, 0]},
	"marbles": {"name": "Marbles", "uses": 1, "odds": [5, 3, 1, 0]},
	"cannon": {"name": "Cannon", "uses": 1, "odds": [1, 3, 3, 2]},
	"homing": {"name": "Homing brick", "uses": 1, "odds": [0, 2, 3, 3]},
	"shield": {"name": "Shield", "uses": 1, "odds": [4, 3, 2, 1]},
	"repair": {"name": "Repair kit", "uses": 1, "odds": [1, 2, 2, 2]},
	"ghost": {"name": "Ghost", "uses": 1, "odds": [1, 2, 2, 2]},
	"lightning": {"name": "Lightning", "uses": 1, "odds": [0, 0, 1, 3]},
}


## A power-up for a kart in `place` (1 is first) out of `field` karts.
static func pick(place: int, field: int, rng: RandomNumberGenerator) -> String:
	var band := band_of(place, field)
	var total := 0
	for kind in ALL:
		total += int(ALL[kind].odds[band])
	var roll := rng.randi_range(1, total)
	for kind in ALL:
		roll -= int(ALL[kind].odds[band])
		if roll <= 0:
			return kind
	return "turbo"


## Which of the four bands of odds a place falls in: 0 for the leader, then
## the front half, the back half and the last place or two.
static func band_of(place: int, field: int) -> int:
	if field <= 1 or place <= 1:
		return 0
	var share := float(place - 1) / float(field - 1)
	if share < 0.5:
		return 1
	if share < 0.85:
		return 2
	return 3


static func name_of(kind: String) -> String:
	return ALL.get(kind, {}).get("name", "")
