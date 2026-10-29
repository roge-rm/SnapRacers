extends SceneTree

## An AI driver down a long straight with a small puddle, a big deep one and
## then a deep snow drift in its line. It drives straight through the small
## puddle, has to steer round the big one and the drift, and drives straight
## through a drift that's only just started. Last a deep drift blown in
## from the right edge reaches most of the way across, and it keeps left of
## it.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/ai_weather_test.gd

## Each one as [along the track, across, radius], the big puddle half as
## wide as it's long.
const SMALL := [60.0, 0.6, 1.5]
const PUDDLE := [120.0, 0.0, 8.0]
const DEEP := [230.0, 1.0, 3.0]
const SHALLOW := [330.0, 0.0, 3.0]
## Along the track, how far across the road as a share, and how wide.
const TONGUE := [380.0, 0.7, 4.0]


class Runner:
	extends Node

	var track: TrackPath
	var kart: Kart
	var ai: AIDriver
	var offset := 2.0
	var tick := 0
	var failures := 0
	var most := {"small": 0.0, "puddle": 0.0, "deep": 0.0, "shallow": 0.0, "bank": 0.0}

	func _ready() -> void:
		track = TrackPath.from_dict({ "pieces": [{ "type": "straight", "length": 14 }] })
		add_child(TrackBuilder.new(track))
		kart = Kart.new()
		kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		kart.transform = track.place_at(2.0, 0.05)
		kart.weather_grip = Conditions.GRIP.snow
		kart.puddles = Puddles.new()
		kart.puddles.add(_spot(SMALL), SMALL[2])
		var still := PackedFloat32Array()
		still.resize(Puddles.WOBBLE.size() * 2)
		kart.puddles.add_shaped(_spot(PUDDLE), track.forward_at(PUDDLE[0]), PUDDLE[2], PUDDLE[2] * 0.4, -1.0, still)
		add_child(kart.puddles)
		kart.drifts = Drifts.new()
		kart.drifts.add(_spot(DEEP), DEEP[2])
		# Started a moment ago, so it's still low.
		kart.drifts.add(_spot(SHALLOW), SHALLOW[2], -Puddles.GROW * 0.2)
		kart.drifts.add_tongue(track, TONGUE[0], 1.0, TONGUE[1], TONGUE[2])
		add_child(kart.drifts)
		add_child(kart)
		ai = AIDriver.new()
		ai.kart = kart
		ai.track = track
		kart.controls = ai.controls
		add_child(ai)

	func _spot(spot: Array) -> Vector3:
		var place := track.place_at(spot[0], 0.0)
		return place.origin + place.basis.x * spot[1]

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _physics_process(_delta: float) -> void:
		tick += 1
		offset = track.offset_of(kart.global_position, offset, 30.0)
		ai.offset = offset
		var at := kart.global_position
		var wet := 0.0
		for w: Kart.Wheel in kart.wheels:
			wet = maxf(wet, kart.puddles.factor_at(w.contact) if w.grounded else 0.0)
		if absf(offset - SMALL[0]) < 10.0:
			most.small = maxf(most.small, wet)
		if absf(offset - PUDDLE[0]) < 20.0:
			most.puddle = maxf(most.puddle, wet)
		var depth := kart.drifts.factor_at(at)
		if absf(offset - DEEP[0]) < 10.0:
			most.deep = maxf(most.deep, depth)
		if absf(offset - SHALLOW[0]) < 10.0:
			most.shallow = maxf(most.shallow, depth)
		if absf(offset - TONGUE[0]) < 10.0:
			most.bank = maxf(most.bank, depth)
		if offset > TONGUE[0] + 25.0:
			check(most.small > 0.5, "it drives straight through a small puddle (%.2f deep under a wheel)" % most.small)
			check(most.puddle < 0.05, "it goes round a big deep puddle in its line (deepest in %.2f)" % most.puddle)
			check(most.deep < 0.05, "and round a deep drift (deepest in %.2f)" % most.deep)
			check(most.shallow > 0.04, "but straight through a drift that's only just started (%.2f deep)" % most.shallow)
			check(most.bank < 0.2, "and keeps clear of a deep drift blown in from the edge (deepest in %.2f)" % most.bank)
			finish()
		if tick == 60 * 40:
			check(false, "it gets down the straight in 40 s (it's at %.0f m)" % offset)
			finish()

	func finish() -> void:
		print("All AI weather checks passed." if failures == 0 else "%d AI weather checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
