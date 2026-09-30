class_name KartSound
extends Node3D

## What a kart sounds like as it drives: its engine, its tires squealing when
## it slides, a rumble on grass and dirt, and (for the karts people drive)
## the wind. It also plays the knocks and crashes, and any one shot sound
## that should follow the kart around goes on it too (see Sounds.play_at).
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

var kart: Kart
## Whether to play the wind, which only the karts people drive do.
var wind := false
var _engine: AudioStreamPlayer3D
var _jet: AudioStreamPlayer3D
var _skid: AudioStreamPlayer3D
var _rumble: AudioStreamPlayer3D
var _wind: AudioStreamPlayer3D
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
	_rumble = _loop(Sounds.stream("loop/rumble"), -4.0)
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
		if info.def.kind == "engine" and float(info.def.get("power", 0.0)) > most:
			most = float(info.def.get("power", 0.0))
			best = info.def.id
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
	_set_level(_skid, 0.0 if hushed else skid, -6.0)
	_skid.pitch_scale = 0.9 + skid * 0.2
	var rumble := kart.rough * clampf(speed / 6.0, 0.0, 1.0) if on_ground else 0.0
	_set_level(_rumble, 0.0 if hushed else rumble, -4.0)
	var gust := clampf((speed - 8.0) / 20.0, 0.0, 1.0) if wind else 0.0
	_set_level(_wind, 0.0 if hushed else gust, -10.0)
	_engine.stream_paused = hushed or _engine.stream == null
	_jet.stream_paused = hushed or _jet.stream == null

	_knock_wait = maxf(_knock_wait - delta, 0.0)
	if _knock > BUMP and _knock_wait <= 0.0:
		_knock_wait = KNOCK_GAP
		var loud := clampf(_knock / CRASH, 0.3, 1.0)
		Sounds.play_at("fx/crash" if _knock > CRASH else "fx/bump", self, linear_to_db(loud), randf_range(0.9, 1.1))
	_knock = 0.0


func _loop(stream: AudioStream, level: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = Sounds.EFFECTS_BUS
	player.volume_db = level
	player.unit_size = 6.0
	player.max_distance = 80.0
	add_child(player)
	if stream != null and Sounds.audible():
		player.play()
	player.stream_paused = true
	return player


func _set_stream(player: AudioStreamPlayer3D, stream: AudioStream) -> void:
	if player.stream == stream:
		return
	player.stream = stream
	if stream != null and player.is_inside_tree() and Sounds.audible():
		player.play()
	# It starts paused, and _process() lets it be heard when it should be, so
	# a kart built behind the splash screen never makes a sound.
	player.stream_paused = true


## Sets a loop's loudness, 0 to 1, pausing it when it's silent so it costs
## nothing.
func _set_level(player: AudioStreamPlayer3D, amount: float, level: float) -> void:
	if player.stream == null:
		return
	if amount < 0.02:
		player.stream_paused = true
		return
	player.stream_paused = false
	player.volume_db = level + linear_to_db(amount)
