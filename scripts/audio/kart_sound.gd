class_name KartSound
extends Node3D

## What a kart sounds like as it drives: its engine, its tires squealing when
## it slides, a rumble on grass and dirt, a splash in water, and (for the
## karts people drive) the wind. It also plays the knocks and crashes, and
## any one shot sound that should follow the kart around goes on it too (see
## Sounds.play_at).
##
## The engine is a loop of that kind of engine running (see sound/engine),
## pitched up as the kart speeds up. A kart with more than one engine sounds
## like its most powerful one, and a jet roars on top of whatever else it's
## got.
##
## It's all worked out from what the kart's doing, so a kart driven over the
## network would sound the same.

## The engine's pitch standing still and flat out.
const IDLE_PITCH := 0.6
const TOP_PITCH := 1.9
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
## Whether to play the wind, which only the karts people drive do.
var wind := false
var _engine: AudioStreamPlayer3D
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
var _rev := 0.0
var _knock := 0.0
var _knock_wait := 0.0


func _init(owner_kart: Kart) -> void:
	kart = owner_kart
	name = "Sound"


func _ready() -> void:
	_engine = _loop(null, 0.0)
	_jet = _loop(null, -2.0)
	_skid = _loop(Sounds.stream("loop/skid"), -6.0)
	_drift_soft = _loop(null, DRIFT_LEVEL)
	_drift_hard = _loop(null, DRIFT_LEVEL)
	_boosts_seen = kart.boost_count
	_rumble = _loop(Sounds.stream("loop/rumble"), -4.0)
	_splash = _loop(Sounds.stream("loop/splash"), SPLASH_LEVEL)
	_wind = _loop(Sounds.stream("loop/wind"), -10.0)
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
	_set_stream(_engine, Sounds.stream("engine/" + engine) if engine != "" else null)
	_set_stream(_jet, Sounds.stream("engine/jet") if stats.thrust > 0.0 else null)


## A knock the kart just took (from Kart._feel_knocks). The hardest one in a
## frame makes the sound.
func knocked(amount: float) -> void:
	_knock = maxf(_knock, amount)


func _process(delta: float) -> void:
	var controls := kart.controls
	var throttle := controls.throttle if controls != null else 0.0
	var hushed := Sounds.hushed
	# Revs follow the speed, with a little extra for the throttle, and on the
	# grid you can rev it up.
	var ratio := clampf(absf(kart.forward_speed) / _top_speed, 0.0, 1.0)
	var want := ratio * 0.85 + throttle * 0.15
	if kart.locked:
		want = throttle * 0.45
	_rev = lerpf(_rev, want, 1.0 - exp(-delta * 5.0))
	_engine.pitch_scale = lerpf(IDLE_PITCH, TOP_PITCH, _rev)
	_engine.volume_db = lerpf(-9.0, 0.0, maxf(throttle, _rev * 0.6))
	_jet.pitch_scale = lerpf(0.8, 1.3, _rev)
	_jet.volume_db = lerpf(-14.0, -2.0, throttle)

	var velocity := kart.remote_velocity if kart.remote else kart.linear_velocity
	var speed := velocity.length()
	var grounded := 0
	for w in kart.wheels:
		if w.grounded:
			grounded += 1
	var on_ground := grounded >= 2
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
	var gust := clampf((speed - 8.0) / 20.0, 0.0, 1.0) if wind else 0.0
	_set_level(_wind, 0.0 if hushed else gust, -10.0)
	_run(_engine, not hushed)
	_run(_jet, not hushed)

	_knock_wait = maxf(_knock_wait - delta, 0.0)
	if _knock > BUMP and _knock_wait <= 0.0:
		_knock_wait = KNOCK_GAP
		var loud := clampf(_knock / CRASH, 0.3, 1.0)
		Sounds.play_at("fx/crash" if _knock > CRASH else "fx/bump", self, linear_to_db(loud), randf_range(0.9, 1.1))
	_knock = 0.0


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
			Sounds.play_at("fx/drift_whoosh_%d" % clampi(kart.boost_level, 1, 3), self, WHOOSH_LEVEL)
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
func _set_level(player: AudioStreamPlayer3D, amount: float, level: float) -> void:
	_run(player, amount >= 0.02)
	if amount >= 0.02:
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
		player.play()
	if player.stream_paused:
		player.stream_paused = false
