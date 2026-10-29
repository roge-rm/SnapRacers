extends SceneTree

## Timed runs down a long straight in the rain past one puddle, an AI driver
## made to go straight through it and one made to go round, at a few
## build-up steps. A big one full of deep water costs more to drive through
## than going round it, and a small one is worth driving through. The AI
## left to choose for itself picks whichever is quicker. Prints a table of
## the times lost against the same run with no puddle. Last a stock bike
## and trike go straight through a big full one at speed and have to stay
## upright and on the road.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/puddle_feel_test.gd

## The puddle's middle along the track, and where the clock starts and stops.
const AT := 200.0
const CLOCK := [120.0, 420.0]
## Each kind as [half long, half wide, across].
const KINDS := {
	"big": [8.0, 3.2, 0.0],
	"small": [2.6, 1.2, 0.6],
}
## How far the puddle's grown at each step: 0.3 of the way, 0.6 and full.
const LEVELS := [0.3, 0.6, 1.0]
## Stock karts on two and three wheels to send through a big full one.
const RIDERS := ["long_fork", "sunday_trike"]


## Drives straight through whatever's in its line.
class Through:
	extends AIDriver

	func _dodge_patches() -> float:
		return 0.0


## Goes round any water in its line. It weighs lines as the AI does but
## makes the water cost a hundred times more, and as it could miss a small one
## between its steps, it also looks far more finely and counts any water
## found that way as costing more than moving over.
class Round:
	extends AIDriver

	func _line_cost(across: float, most := INF) -> float:
		var cost := super(across, most / 100.0) * 100.0
		var see := maxf(SEE_PATCH, kart.linear_velocity.length() * SEE_PATCH_TIME)
		var half := kart.width() * 0.5
		var ahead := -PATCH_STEP
		while ahead <= see:
			var at := offset + ahead
			var right := track.right_at(at)
			var point := track.point_at(at) + right * across
			var x := -half
			while x <= half:
				if kart.puddles.factor_at(point + right * x) > 0.02:
					return cost + 1.0
				x += 0.4
			ahead += 0.4
		return cost


class Runner:
	extends Node

	var track: TrackPath
	var kart: Kart
	var ai: AIDriver
	var offset := 2.0
	var tick := 0
	var started := -1.0
	var last := 0.0
	var failures := 0
	## Each run as [kind, level, how it drives], and a stock kart's name
	## after that if it isn't the starter kart.
	var runs: Array = []
	var run := -1
	var times := {}
	var wettest := {}
	var slowest := {}
	var lost_line := {}
	## For each run, the least its up pointed up and the furthest it got
	## from the middle of the road, in metres.
	var least_up := {}
	var widest := {}

	func _ready() -> void:
		track = TrackPath.from_dict({ "pieces": [{ "type": "straight", "length": 14 }] })
		add_child(TrackBuilder.new(track))
		runs.append(["none", 1.0, "through"])
		for kind in KINDS:
			for level in LEVELS:
				for how in ["through", "round", "own"]:
					runs.append([kind, level, how])
		for rider in RIDERS:
			runs.append(["big", 1.0, "through " + rider, rider])
		_next()

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _next() -> void:
		if kart != null:
			kart.queue_free()
			kart.puddles.queue_free()
			ai.queue_free()
		run += 1
		if run >= runs.size():
			_report()
			return
		var r: Array = runs[run]
		kart = Kart.new()
		var design := "res://tests/data/legacy/starter.json" if r.size() < 4 else "res://data/karts/stock/%s.json" % r[3]
		kart.build(KartDesign.load_file(design))
		kart.transform = track.place_at(2.0, 0.05)
		kart.weather_grip = Conditions.GRIP.rain
		kart.puddles = Puddles.new()
		if r[0] != "none":
			var kind: Array = KINDS[r[0]]
			var place := track.place_at(AT, 0.0)
			var level: float = r[1]
			# Started so it's grown this far now.
			var still := PackedFloat32Array()
			still.resize(Puddles.WOBBLE.size() * 2)
			kart.puddles.add_shaped(place.origin + place.basis.x * kind[2], -place.basis.z, kind[0], kind[1], -level * Puddles.GROW, still)
		add_child(kart.puddles)
		add_child(kart)
		match r[2]:
			"through", "through long_fork", "through sunday_trike":
				ai = Through.new()
			"round":
				ai = Round.new()
			_:
				ai = AIDriver.new()
		ai.kart = kart
		ai.track = track
		kart.controls = ai.controls
		add_child(ai)
		offset = 2.0
		tick = 0
		started = -1.0
		last = 2.0
		wettest[run] = 0.0
		slowest[run] = INF
		least_up[run] = 1.0
		widest[run] = 0.0

	func _physics_process(_delta: float) -> void:
		if run >= runs.size() or kart == null:
			return
		tick += 1
		offset = track.offset_of(kart.global_position, offset, 30.0)
		ai.offset = offset
		for w: Kart.Wheel in kart.wheels:
			wettest[run] = maxf(wettest[run], kart.puddles.factor_at(w.contact) if w.grounded else 0.0)
		if offset > AT - 20.0:
			slowest[run] = minf(slowest[run], kart.linear_velocity.length())
		least_up[run] = minf(least_up[run], kart.global_basis.y.dot(track.up_at(offset)))
		widest[run] = maxf(widest[run], absf((kart.global_position - track.point_at(offset)).dot(track.right_at(offset))))
		if started < 0.0 and offset >= CLOCK[0]:
			started = tick - (offset - CLOCK[0]) / maxf(offset - last, 0.001)
		if offset >= CLOCK[1]:
			times[run] = (tick - (offset - CLOCK[1]) / maxf(offset - last, 0.001) - started) / 60.0
			_next()
			return
		last = offset
		if tick > 60 * 40:
			check(false, "run %s gets down the straight (it's at %.0f m)" % [runs[run], offset])
			times[run] = INF
			_next()

	func _time(kind: String, level: float, how: String) -> float:
		for i in runs.size():
			if runs[i][0] == kind and is_equal_approx(runs[i][1], level) and runs[i][2] == how:
				return times[i] - times[0]
		return NAN

	func _deepest(kind: String, level: float, how: String) -> float:
		for i in runs.size():
			if runs[i][0] == kind and is_equal_approx(runs[i][1], level) and runs[i][2] == how:
				return wettest[i]
		return NAN

	## The deepest water a wheel met and the slowest it went, as text.
	func _wet(kind: String, level: float, how: String) -> String:
		for i in runs.size():
			if runs[i][0] == kind and is_equal_approx(runs[i][1], level) and runs[i][2] == how:
				return "%.2f %4.1f" % [wettest[i], slowest[i]]
		return ""

	func _report() -> void:
		print("  time lost against no puddle (%.2f s, slowest %.1f m/s), in s, with the deepest water a wheel met and the slowest in m/s" % [times[0], slowest[0]])
		print("  puddle  grown  through              round                own choice")
		for kind in KINDS:
			for level in LEVELS:
				print("  %-6s  %4.1f   %+.3f (%s)  %+.3f (%s)  %+.3f (%s)" % [kind, level, _time(kind, level, "through"), _wet(kind, level, "through"), _time(kind, level, "round"), _wet(kind, level, "round"), _time(kind, level, "own"), _wet(kind, level, "own")])
		check(_time("big", 1.0, "through") > _time("big", 1.0, "round"), "going round a big deep puddle is quicker than through it")
		for level in LEVELS:
			check(_time("small", level, "through") < _time("small", level, "round"), "driving through a small one grown %.1f is quicker than round it" % level)
		# The AI's way counts as through if it met water at least half as
		# deep as the run made to go through.
		for kind in KINDS:
			for level in LEVELS:
				var through := _time(kind, level, "through") < _time(kind, level, "round")
				var went := _deepest(kind, level, "own") > _deepest(kind, level, "through") * 0.5
				check(went == through, "the AI goes %s a %s one grown %.1f, the quicker way (%+.3f)" % ["through" if through else "round", kind, level, _time(kind, level, "own")])
		for i in runs.size():
			if runs[i].size() < 4:
				continue
			print("  %-13s through a big full one: %+.3f s (%s), least up %.2f, furthest out %.1f m" % [runs[i][3], times[i] - times[0], _wet("big", 1.0, runs[i][2]), least_up[i], widest[i]])
			check(times[i] < INF and least_up[i] > 0.7, "the %s stays upright through a big full puddle at speed" % runs[i][3])
			check(widest[i] < track.width * 0.5 - 1.0, "and on the road (%.1f m out at most)" % widest[i])
		print("All puddle feel checks passed." if failures == 0 else "%d puddle feel checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
