class_name KartSound
extends Node3D

## What a kart sounds like as it drives: its engine, its tires squealing when
## it slides, a rumble on grass and dirt, a splash in water, and (for the
## karts people drive) the wind. It also plays the knocks and crashes, and
## any one shot sound that should follow the kart around goes on it too (see
## Sounds.play_at).
##
## The engine is three loops of that kind of engine running (see
## sound/engine and EngineSound): low and high revs on the throttle and one
## off it. A kart with more than one engine sounds like its most powerful
## one, and a jet roars on top of whatever else it's got. The karts people
## drive are louder than the AI's, so a pack of karts doesn't drone.
##
## It's all worked out from what the kart's doing, so a kart driven over the
## network would sound the same.

## The engine's level at full for a kart a person drives and for the rest,
## in dB, and how near the rest have to be to be heard at full.
const ENGINE_LEVEL := -6.0
const AI_ENGINE_LEVEL := -12.0
const UNIT_SIZE := 6.0
const AI_UNIT_SIZE := 4.0
## The wind's levels at full: the hiss and the low buffet.
const WIND_LEVEL := -11.0
const WIND_LOW_LEVEL := -14.0
## How hard a knock has to be to make a sound, and to be a crash, in newton
## seconds.
const BUMP := 180.0
const CRASH := 700.0
## Once a knock's made a sound, the next one waits this long.
const KNOCK_GAP := 0.25
## The splash of wheels rolling through water, at full.
const SPLASH_LEVEL := -3.0
## A drift's tire sound: its level at full, seconds to fade in and out, and
## the surfaces' loops (anything else sounds like tarmac).
const DRIFT_LEVEL := -6.0
const DRIFT_IN := 0.15
const DRIFT_OUT := 0.3
const WHOOSH_LEVEL := -13.0
const DRIFT_SURFACE := {
	"dirt": "dirt", "gravel": "dirt", "mud": "dirt", "grass": "dirt", "shallows": "water",
	"snow": "snow", "ice": "snow",
}

var kart: Kart
## Whether a person drives this kart: they hear the wind and their engine
## is louder.
var wind := false:
	set(value):
		wind = value
		_fit_level()
## The engine's low, high and off loops.
var _engine: AudioStreamPlayer3D
var _engine_high: AudioStreamPlayer3D
var _engine_off: AudioStreamPlayer3D
var _engine_name := ""
var _revs: EngineSound
var _spool := 0.0
var _wind_low: AudioStreamPlayer3D
## The wind's gusts: now, aiming for, and seconds before a new aim. Its own
## random numbers, so the race's are left alone.
var _gust := 0.0
var _gust_aim := 0.0
var _gust_wait := 0.0
var _rng := RandomNumberGenerator.new()
var _jet: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _rumble: AudioStreamPlayer3D
var _splash: AudioStreamPlayer3D
var _wind: AudioStreamPlayer3D
var _drift_soft: AudioStreamPlayer3D
var _drift_hard: AudioStreamPlayer3D
var _drift_surface := ""
var _drift_gain := 0.0
var _drift_pitch := 1.0
var _boosts_seen := 0
var _top_speed := 20.0
var _knock := 0.0
var _knock_wait := 0.0


func _init(owner_kart: Kart) -> void:
	kart = owner_kart
	name = "Sound"


func _ready() -> void:
	_rng.randomize()
	_engine = _loop(null, 0.0)
	_engine_high = _loop(null, 0.0)
	_engine_off = _loop(null, 0.0)
	_jet = _loop(null, -2.0)
	_skid = _loop(Sounds.stream("loop/skid"), -6.0)
	_drift_soft = _loop(null, DRIFT_LEVEL)
	_drift_hard = _loop(null, DRIFT_LEVEL)
	_boosts_seen = kart.boost_count
	_rumble = _loop(Sounds.stream("loop/rumble"), -4.0)
	_splash = _loop(Sounds.stream("loop/splash"), SPLASH_LEVEL)
	_wind = _loop(Sounds.stream("loop/wind"), WIND_LEVEL)
	_wind_low = _loop(Sounds.stream("loop/wind_low"), WIND_LOW_LEVEL)
	_fit_level()
	if kart.stats != null:
		refit(kart.stats)


func _exit_tree() -> void:
	# Stopped here, so nothing's left playing when the game closes.
	for player in find_children("*", "AudioStreamPlayer3D", false, false):
		player.stop()


## Picks the engine sound for the kart as it is now, after it's built or has
## lost or got back some parts.
static func engine_for(stats: KartStats) -> String:
	var best := ""
	var most := 0.0
	for info in stats.parts:
		if float(info.def.get("power", 0.0)) > most:
			most = float(info.def.get("power", 0.0))
			# A remodelled engine sounds like the one it was made from.
			best = info.def.get("sound", info.def.id)
	return best


func refit(stats: KartStats) -> void:
	if _engine == null:
		return
	_top_speed = maxf(stats.top_speed(), 5.0)
	var engine := engine_for(stats)
	if engine != _engine_name:
		_engine_name = engine
		_revs = EngineSound.new(engine) if engine != "" else null
	_set_stream(_engine, Sounds.stream("engine/%s_low" % engine) if engine != "" else null)
	_set_stream(_engine_high, Sounds.stream("engine/%s_high" % engine) if engine != "" else null)
	_set_stream(_engine_off, Sounds.stream("engine/%s_off" % engine) if engine != "" else null)
	_set_stream(_jet, Sounds.stream("engine/jet") if stats.thrust > 0.0 else null)


## A knock the kart just took (from Kart._feel_knocks). The hardest one in a
## frame makes the sound.
func knocked(amount: float) -> void:
	_knock = maxf(_knock, amount)


func _process(delta: float) -> void:
	var controls := kart.controls
	var throttle := controls.throttle if controls != null else 0.0
	var hushed := Sounds.hushed
	var velocity := kart.remote_velocity if kart.remote else kart.linear_velocity
	var speed := velocity.length()
	var grounded := 0
	for w in kart.wheels:
		if w.grounded:
			grounded += 1
	var on_ground := grounded >= 2
	_play_engine(delta, throttle, on_ground, hushed)
	var sideways := absf(velocity.dot(kart.global_basis.x))
	var skid := clampf((sideways - 1.5) / 5.0, 0.0, 1.0) if on_ground else 0.0
	var drifting := _drift(delta, velocity, speed, on_ground, hushed)
	_set_level(_skid, 0.0 if hushed or drifting else skid, -6.0)
	_skid.pitch_scale = 0.9 + skid * 0.2
	# Wheels in water splash instead of rumbling.
	var wet := _wet() if on_ground else 0.0
	var rumble := kart.rough * (1.0 - wet) * clampf(speed / 6.0, 0.0, 1.0) if on_ground else 0.0
	_set_level(_rumble, 0.0 if hushed else rumble, -4.0)
	_set_level(_splash, 0.0 if hushed else wet * clampf(speed / 8.0, 0.0, 1.0), SPLASH_LEVEL)
	_splash.pitch_scale = 0.9 + 0.2 * clampf(speed / 25.0, 0.0, 1.0)
	_play_wind(delta, speed, on_ground, hushed)

	_knock_wait = maxf(_knock_wait - delta, 0.0)
	if _knock > BUMP and _knock_wait <= 0.0:
		_knock_wait = KNOCK_GAP
		var loud := clampf(_knock / CRASH, 0.3, 1.0)
		Sounds.play_at("fx/crash" if _knock > CRASH else "fx/bump", self, linear_to_db(loud), randf_range(0.9, 1.1))
	_knock = 0.0


## The engine's three loops, from how it's running, and the jet's roar
## spooling up and down.
func _play_engine(delta: float, throttle: float, on_ground: bool, hushed: bool) -> void:
	var base := ENGINE_LEVEL if wind else AI_ENGINE_LEVEL
	if _revs != null:
		_revs.step(delta, absf(kart.forward_speed) / _top_speed, throttle, on_ground, kart.locked, kart.boost_left > 0.0)
		var gains := _revs.levels()
		var layers := [_engine, _engine_high, _engine_off]
		var made_at := [EngineSound.LOW, EngineSound.HIGH, EngineSound.OFF]
		for i in 3:
			layers[i].pitch_scale = clampf(_revs.pitch(made_at[i]), 0.25, 3.0)
			_set_level(layers[i], 0.0 if hushed else gains[i], base, 0.01)
	_spool = lerpf(_spool, throttle, 1.0 - exp(-delta * (0.9 if throttle > _spool else 1.4)))
	_jet.pitch_scale = lerpf(0.7, 1.3, _spool)
	_set_level(_jet, 0.0 if hushed else lerpf(0.2, 1.0, _spool), base + 1.0, 0.01)


## The wind, rising with speed, in gusts at random times, and louder in the
## air with the wheels quiet.
func _play_wind(delta: float, speed: float, on_ground: bool, hushed: bool) -> void:
	if not wind:
		_run(_wind, false)
		_run(_wind_low, false)
		return
	_gust_wait -= delta
	if _gust_wait <= 0.0:
		_gust_aim = pow(_rng.randf(), 2.0)
		_gust_wait = _rng.randf_range(1.2, 5.0)
	_gust = lerpf(_gust, _gust_aim, 1.0 - exp(-delta * 1.2))
	var fast := clampf((speed - 6.0) / 24.0, 0.0, 1.0)
	var air := 1.4 if not on_ground else 1.0
	var amount := fast * fast * (0.7 + 0.5 * _gust) * air
	_set_level(_wind, 0.0 if hushed else amount, WIND_LEVEL)
	_wind.pitch_scale = 0.85 + 0.3 * fast + 0.08 * _gust
	_set_level(_wind_low, 0.0 if hushed else fast * (0.6 + 0.6 * _gust), WIND_LOW_LEVEL)
	_wind_low.pitch_scale = 0.9 + 0.2 * fast


## A person's engine carries further than an AI's.
func _fit_level() -> void:
	for player in [_engine, _engine_high, _engine_off, _jet]:
		if player != null:
			player.unit_size = UNIT_SIZE if wind else AI_UNIT_SIZE


## The tire sound of a drift, soft fading to hard with how hard and fast it
## slips, and the whoosh when its boost starts. Returns whether a drift is
## being heard, so the plain skid keeps quiet. Only played, never fed back
## into the kart.
func _drift(delta: float, velocity: Vector3, speed: float, on_ground: bool, hushed: bool) -> bool:
	var sideways := absf(velocity.dot(kart.global_basis.x))
	var slipping := (sideways > 3.0) if kart.remote else kart.sliding
	var want := slipping and on_ground and not hushed
	var before := _drift_gain
	_drift_gain = move_toward(_drift_gain, 1.0 if want else 0.0, delta / (DRIFT_IN if want else DRIFT_OUT))
	if not kart.remote and kart.boost_count != _boosts_seen:
		_boosts_seen = kart.boost_count
		if kart.boost_level > 0 and not hushed:
			_boost(boost_size(kart.boost_given))
	if _drift_gain <= 0.0:
		if before > 0.0:
			_drift_soft.stop()
			_drift_hard.stop()
		return false
	var surface := _drift_surface_now()
	if surface != _drift_surface or before <= 0.0:
		if before <= 0.0:
			_drift_pitch = randf_range(0.95, 1.05)
		_drift_surface = surface
		_set_stream(_drift_soft, Sounds.stream("loop/drift_%s_soft" % surface))
		_set_stream(_drift_hard, Sounds.stream("loop/drift_%s_hard" % surface))
	var slip := clampf(sideways / 7.0, 0.0, 1.0) * (0.5 + 0.5 * clampf(speed / 20.0, 0.0, 1.0))
	var loud := _drift_gain * (0.45 + 0.55 * slip)
	_drift_soft.volume_db = DRIFT_LEVEL + linear_to_db(maxf(loud * (1.0 - slip), 0.0001))
	_drift_hard.volume_db = DRIFT_LEVEL + linear_to_db(maxf(loud * slip, 0.0001))
	var pitch := _drift_pitch * (0.92 + 0.16 * slip)
	_drift_soft.pitch_scale = pitch
	_drift_hard.pitch_scale = pitch
	for player in [_drift_soft, _drift_hard]:
		if not player.playing and player.stream != null and Sounds.audible():
			player.play(randf() * player.stream.get_length())
	return true


## How big a boost of this many seconds is, 0 to 1: a short drift boost
## (0.6 s) is near 0, a turbo (1.6 s) about half and a big turbo (2.8 s) 1.
static func boost_size(seconds: float) -> float:
	return clampf((seconds - 0.4) / 2.4, 0.0, 1.0)


## A boost's sound: a rush of air for its size, a turbo's roar over the
## middling and big ones and a thump under the big ones, each picked from a
## few and pitched at random so no two are the same.
func _boost(size: float) -> void:
	var tier := 1 if size < 0.2 else (2 if size < 0.5 else 3)
	var air := "fx/boost_air_%d_%d" % [tier, _rng.randi_range(1, 3)]
	Sounds.play_at(air, self, WHOOSH_LEVEL + lerpf(-2.0, 3.0, size) + _rng.randf_range(-1.5, 1.5), _rng.randf_range(0.9, 1.12) * (1.05 - 0.1 * size))
	if size >= 0.2:
		var roar := "fx/boost_roar_%d" % _rng.randi_range(1, 3)
		Sounds.play_at(roar, self, lerpf(-15.0, -7.0, size) + _rng.randf_range(-1.5, 1.5), _rng.randf_range(0.88, 1.1))
	if size >= 0.45:
		var thump := "fx/boost_thump_%d" % _rng.randi_range(1, 2)
		Sounds.play_at(thump, self, lerpf(-12.0, -6.0, size) + _rng.randf_range(-1.0, 1.0), _rng.randf_range(0.9, 1.1))


## How much the grounded wheels are in water, from 0 to 1: shallows or a
## deep puddle are 1.
func _wet() -> float:
	var total := 0.0
	var count := 0
	for w in kart.wheels:
		if w.grounded:
			total += _wet_wheel(w)
			count += 1
	return total / count if count > 0 else 0.0


func _wet_wheel(w: Kart.Wheel) -> float:
	return clampf(maxf(w.wade / TrackBuilder.SHALLOWS_WADE, w.water), 0.0, 1.0)


## Which set of drift loops the drive wheels are on.
func _drift_surface_now() -> String:
	for w in kart.wheels:
		if w.driven and w.grounded:
			if w.snow > 0.05:
				return "snow"
			if _wet_wheel(w) > 0.3:
				return "water"
			return DRIFT_SURFACE.get(w.surface, "tarmac")
	return _drift_surface if _drift_surface != "" else "tarmac"


func _loop(stream: AudioStream, level: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = Sounds.EFFECTS_BUS
	player.volume_db = level
	player.unit_size = 6.0
	player.max_distance = 80.0
	add_child(player)
	return player


func _set_stream(player: AudioStreamPlayer3D, stream: AudioStream) -> void:
	if player.stream == stream:
		return
	player.stop()
	player.stream = stream


## Sets a loop's loudness, 0 to 1, pausing it when it's silent so it costs
## nothing.
func _set_level(player: AudioStreamPlayer3D, amount: float, level: float, quietest := 0.02) -> void:
	_run(player, amount >= quietest)
	if amount >= quietest:
		player.volume_db = level + linear_to_db(amount)


## Plays a loop or pauses it. A loop only ever starts playing once it's meant
## to be heard, since one started and paused straight away still plays for a
## moment, which behind the splash screen was every kart at once.
##
## The pause is only changed when it needs to be. In a browser, unpausing a
## sound starts it again from a fresh copy of the whole thing.
func _run(player: AudioStreamPlayer3D, on: bool) -> void:
	if player.stream == null:
		return
	if not on:
		if player.playing and not player.stream_paused:
			player.stream_paused = true
		return
	if not player.playing:
		if not Sounds.audible():
			return
		# From a random place, so karts with the same loop don't line up.
		player.play(_rng.randf() * player.stream.get_length())
	if player.stream_paused:
		player.stream_paused = false
