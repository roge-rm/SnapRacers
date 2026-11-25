class_name EngineSound
extends RefCounted

## How one kart's engine is running, worked out from what the kart's doing,
## and how loud and how fast to play its three loops (see tools/sound/engines.py):
## low and high on the throttle, faded between by the revs, and off when it's
## being pushed along off the throttle.
##
## It runs through pretend gears, so the revs climb, drop at a shift and
## climb again, flare at a launch or in the air and blip on a downshift.
## Each kart gets its own small differences, picked at random, and its revs
## and level wander a little, slowly and at random, so two karts with the
## same engine never sound the same. It's sound only and its random numbers
## are its own, so nothing here touches the race.
##
## tools/sound/engine_demo.py does the same sums to make the listening demos,
## so a change here wants making there too.

## The revs (0 idle, 1 the top) each loop was made at.
const LOW := 0.15
const OFF := 0.45
const HIGH := 0.75
## For each engine: how many times its idle the top revs are, its gears (0
## for one that holds its revs, like a hybrid's), how loud it idles (0 to 1)
## and how far the revs flare when the clutch slips at a launch.
const TYPES := {
	"engine_small": [5.0, 1, 0.6, 0.35],
	"engine_micro": [2.6, 1, 0.7, 0.3],
	"engine_big": [5.0, 5, 0.5, 0.3],
	"engine_twin": [5.5, 5, 0.7, 0.3],
	"engine_diesel": [3.2, 5, 0.8, 0.2],
	"engine_v8": [5.0, 4, 0.8, 0.3],
	"engine_rotary": [5.5, 5, 0.65, 0.35],
	"engine_flat4": [5.0, 5, 0.75, 0.3],
	"electric_motor": [6.0, 1, 0.12, 0.0],
	"electric_big": [6.0, 1, 0.12, 0.0],
	"engine_hybrid": [5.0, 0, 0.25, 0.0],
	"pedals": [3.0, 3, 0.0, 0.0],
}
## How long a shift cuts the power, in seconds.
const SHIFT_TIME := 0.14

var span := 5.0
var gears := 5
var idle_level := 0.6
var slip := 0.3
var rev := 0.0
var load := 0.0
var gear := 0
var _shift_left := 0.0
var _rng := RandomNumberGenerator.new()
## This kart's own differences.
var detune := 1.0
var _bias := 0.0
var _high_db := 0.0
var _off_db := 0.0
var _shift_at := 0.9
var _rough := 0.006
## Slow random wanders: [now, aiming for, time left before a new aim].
var _pitch_walk := [0.0, 0.0, 0.0]
var _level_walk := [0.0, 0.0, 0.0]
var _rough_walk := [0.0, 0.0, 0.0]


func _init(engine: String, seed := -1) -> void:
	if seed < 0:
		_rng.randomize()
	else:
		_rng.seed = seed
	var type: Array = TYPES.get(engine, TYPES["engine_small"])
	span = type[0]
	gears = type[1]
	idle_level = type[2]
	slip = type[3]
	detune = 1.0 + _rng.randf_range(-0.04, 0.04)
	_bias = _rng.randf_range(-0.08, 0.08)
	_high_db = _rng.randf_range(-2.0, 2.0)
	_off_db = _rng.randf_range(-2.0, 2.0)
	_shift_at = _rng.randf_range(0.86, 0.94)
	_rough = _rng.randf_range(0.003, 0.012)


## Where the revs would be in gear g at this fraction of top speed.
func _wheel_rev(speed: float, g: int) -> float:
	var top := pow(float(g + 1) / gears, 0.7) * 1.08
	return (speed / top * span - 1.0) / (span - 1.0)


## Moves things on by delta seconds. speed is the fraction of top speed.
func step(delta: float, speed: float, throttle: float, grounded: bool, locked: bool, boosting: bool) -> void:
	speed = clampf(speed, 0.0, 1.2)
	if boosting:
		throttle = 1.0
	_shift_left = maxf(_shift_left - delta, 0.0)
	var free := locked or not grounded
	var want := 0.0
	if free:
		want = throttle * (0.75 if locked else 0.95)
	elif gears == 0:
		want = lerpf(speed * 0.55, 0.3 + 0.5 * speed, throttle)
	else:
		if gear >= gears:
			gear = gears - 1
		if gear < gears - 1 and (_wheel_rev(speed, gear) > _shift_at and throttle > 0.3 or _wheel_rev(speed, gear) > 0.98):
			gear += 1
			if throttle > 0.3:
				_shift_left = SHIFT_TIME * _rng.randf_range(0.8, 1.2)
		elif gear > 0 and _wheel_rev(speed, gear) < 0.22:
			gear -= 1
		want = maxf(_wheel_rev(speed, gear), slip * throttle)
	want = clampf(want, 0.0, 1.0)
	var rate := 0.0
	if want > rev:
		rate = (8.0 if free else 4.0 + 6.0 * throttle)
	else:
		rate = 14.0 if _shift_left > 0.0 else 3.0
	rev = lerpf(rev, want, 1.0 - exp(-delta * rate))
	var want_load := 0.15 * throttle if _shift_left > 0.0 else throttle
	load = lerpf(load, want_load, 1.0 - exp(-delta * (12.0 if want_load > load else 7.0)))
	_walk(_pitch_walk, delta, 0.4, 1.6)
	_walk(_level_walk, delta, 0.3, 1.2)
	_walk(_rough_walk, delta, 0.02, 0.07)


## Eases a value towards a random aim, picking a new one at random times.
func _walk(walk: Array, delta: float, soonest: float, latest: float) -> void:
	walk[2] -= delta
	if walk[2] <= 0.0:
		walk[1] = _rng.randf_range(-1.0, 1.0)
		walk[2] = _rng.randf_range(soonest, latest)
	walk[0] = lerpf(float(walk[0]), float(walk[1]), 1.0 - exp(-delta * 2.5 / soonest))


## The pitch to play the loop made at revs `at`.
func pitch(at: float) -> float:
	var wobble := 1.0 + 0.012 * float(_pitch_walk[0]) + _rough * (1.0 - rev) * float(_rough_walk[0])
	return detune * wobble * (1.0 + (span - 1.0) * rev) / (1.0 + (span - 1.0) * at)


## How loud each loop is, low, high and off, as gains.
func levels() -> Vector3:
	var x := smoothstep(LOW + 0.05 + _bias, HIGH - 0.05 + _bias, rev) * PI * 0.5
	var overrun := smoothstep(0.06, 0.3, rev)
	var on_amount := load + (1.0 - load) * (1.0 - overrun) * idle_level
	var on_db := lerpf(-6.0, 0.0, load) + lerpf(-4.0, 0.0, rev)
	var off_amount := (1.0 - load) * overrun
	var wander := db_to_linear(1.5 * float(_level_walk[0]))
	var on := on_amount * db_to_linear(on_db) * wander
	return Vector3(on * cos(x), on * sin(x) * db_to_linear(_high_db), off_amount * db_to_linear(-5.0 + 3.0 * rev + _off_db) * wander)
