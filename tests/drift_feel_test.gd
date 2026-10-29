extends SceneTree

## Timed runs down a long straight in the snow past one drift, an AI driver
## made to go straight through it and one made to go round, at a few
## build-up steps. A long deep one costs more to drive through than going
## round it, and a small one is worth driving through. The AI left to
## choose for itself picks whichever is quicker. Prints a table of the times
## lost against the same run with no drift.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/drift_feel_test.gd

## The drift's middle along the track, and where the clock starts and stops.
const AT := 200.0
const CLOCK := [120.0, 420.0]
## Each kind as [how, size, across, side]. A "lump" is like Drifts.add(),
## its crest across the road `size` to each side of its middle and running
## to the right, or the left for side -1; a "bank" is blown in from the
## right edge, or the left, `size` of the way across, 4 m wide; a "lane" runs
## down the road `size` metres long, 5 m wide. Those ending in _l are the
## one before mirrored.
const KINDS := {
	"small": ["lump", 1.2, 0.0, 1.0],
	"small_l": ["lump", 1.2, 0.0, -1.0],
	"off": ["lump", 1.2, 1.0, 1.0],
	"off_l": ["lump", 1.2, -1.0, -1.0],
	"lump": ["lump", 2.5, 0.0, 1.0],
	"lump_l": ["lump", 2.5, 0.0, -1.0],
	"bank": ["bank", 0.75, 0.0, 1.0],
	"bank_l": ["bank", 0.75, 0.0, -1.0],
	"lane": ["lane", 40.0, 0.0, 1.0],
}
## Where through and round are closer than this, in seconds, it's a tie and
## either way is fine.
const TIE := 0.02
## How far the drift's grown at each step: 0.3 of the way, 0.6 and full.
const LEVELS := [0.3, 0.6, 1.0]


## Drives straight through whatever's in its line.
class Through:
	extends AIDriver

	func _dodge_patches() -> float:
		return 0.0


## Goes round any snow in its line. It weighs lines as the AI does but
## makes the snow cost a hundred times more, and as it could miss a small one
## between its steps, it also looks far more finely and counts any snow
## found that way as costing more than moving over.
class Round:
	extends AIDriver

	func _line_cost(across: float, most := INF) -> float:
		var cost := super(across, most / 100.0) * 100.0
		var see := maxf(SEE_PATCH, kart.linear_velocity.length() * SEE_PATCH_TIME)
		var half := kart.width() * 0.5 + 0.3
		var ahead := -PATCH_STEP
		while ahead <= see:
			var at := offset + ahead
			var right := track.right_at(at)
			var point := track.point_at(at) + right * across
			var x := -half
			while x <= half:
				if kart.drifts.factor_at(point + right * x) > 0.02:
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
	## Each run as [kind, level, how it drives].
	var runs: Array = []
	var run := -1
	var times := {}
	var deepest := {}
	var slowest := {}

	func _ready() -> void:
		track = TrackPath.from_dict({ "pieces": [{ "type": "straight", "length": 14 }] })
		add_child(TrackBuilder.new(track))
		runs.append(["none", 1.0, "through"])
		for kind in KINDS:
			for level in LEVELS:
				for how in ["through", "round", "own"]:
					runs.append([kind, level, how])
		_next()

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _next() -> void:
		if kart != null:
			kart.queue_free()
			kart.drifts.queue_free()
			ai.queue_free()
		run += 1
		if run >= runs.size():
			_report()
			return
		var r: Array = runs[run]
		kart = Kart.new()
		kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		kart.transform = track.place_at(2.0, 0.05)
		kart.weather_grip = Conditions.GRIP.snow
		kart.weather_drag = Conditions.DRAG.snow
		kart.drifts = Drifts.new()
		if r[0] != "none":
			var kind: Array = KINDS[r[0]]
			# Started so it's grown this far now.
			var start: float = -float(r[1]) * Puddles.GROW
			var place := track.place_at(AT, 0.0)
			var middle := place.origin + place.basis.x * float(kind[2])
			var side: float = kind[3]
			match kind[0]:
				"lump":
					var long: float = kind[1] * 4.0
					kart.drifts.add_tongue_at(middle - place.basis.x * side * long * Drifts.CREST, place.basis.x * side, kind[1] * 2.0, long, 1.0, start)
				"bank":
					kart.drifts.add_tongue(track, AT, side, kind[1], 4.0, start)
				"lane":
					var long: float = kind[1]
					kart.drifts.add_tongue_at(middle + place.basis.z * long * Drifts.CREST, -place.basis.z, 5.0, long, 1.0, start)
		add_child(kart.drifts)
		add_child(kart)
		match r[2]:
			"through":
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
		deepest[run] = 0.0
		slowest[run] = INF

	func _physics_process(_delta: float) -> void:
		if run >= runs.size() or kart == null:
			return
		tick += 1
		offset = track.offset_of(kart.global_position, offset, 30.0)
		ai.offset = offset
		for w: Kart.Wheel in kart.wheels:
			deepest[run] = maxf(deepest[run], kart.drifts.factor_at(w.contact) if w.grounded else 0.0)
		if offset > AT - 30.0:
			slowest[run] = minf(slowest[run], kart.linear_velocity.length())
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

	func _find(kind: String, level: float, how: String) -> int:
		for i in runs.size():
			if runs[i][0] == kind and is_equal_approx(runs[i][1], level) and runs[i][2] == how:
				return i
		return -1

	func _time(kind: String, level: float, how: String) -> float:
		return times[_find(kind, level, how)] - times[0]

	## Whether the AI's own way went through.
	func _went(kind: String, level: float) -> bool:
		return deepest[_find(kind, level, "own")] > deepest[_find(kind, level, "through")] * 0.5

	## The deepest snow a wheel met and the slowest it went, as text.
	func _snow(kind: String, level: float, how: String) -> String:
		var i := _find(kind, level, how)
		return "%.2f %4.1f" % [deepest[i], slowest[i]]

	func _report() -> void:
		print("  time lost against no drift (%.2f s, slowest %.1f m/s), in s, with the deepest snow a wheel met and the slowest in m/s" % [times[0], slowest[0]])
		print("  drift    grown  through              round                own choice")
		for kind in KINDS:
			for level in LEVELS:
				print("  %-7s  %4.1f   %+.3f (%s)  %+.3f (%s)  %+.3f (%s)" % [kind, level, _time(kind, level, "through"), _snow(kind, level, "through"), _time(kind, level, "round"), _snow(kind, level, "round"), _time(kind, level, "own"), _snow(kind, level, "own")])
		check(_time("lane", 1.0, "through") > _time("lane", 1.0, "round"), "going round a long deep drift is quicker than through it")
		for level in LEVELS:
			check(_time("small", level, "through") < _time("small", level, "round"), "driving through a small one grown %.1f is quicker than round it" % level)
		for kind in KINDS:
			for level in LEVELS:
				var i := _find(kind, level, "round")
				if deepest[_find(kind, level, "through")] > 0.1:
					check(deepest[i] < 0.05, "made to go round a %s one grown %.1f it misses it (%.2f deep)" % [kind, level, deepest[i]])
		# The AI's way counts as through if it met snow at least half as deep
		# as the run made to go through. A line between the two that's at
		# least as quick as the quicker way is fine too.
		for kind in KINDS:
			for level in LEVELS:
				var through := _time(kind, level, "through") < _time(kind, level, "round")
				if absf(_time(kind, level, "through") - _time(kind, level, "round")) < TIE:
					print("  tie   through and round a %s one grown %.1f are within %.2f s, so not checked" % [kind, level, TIE])
					continue
				var as_quick := _time(kind, level, "own") <= minf(_time(kind, level, "through"), _time(kind, level, "round")) + 0.01
				check(_went(kind, level) == through or as_quick, "the AI goes %s a %s one grown %.1f, the quicker way (%+.3f)" % ["through" if through else "round", kind, level, _time(kind, level, "own")])
		# Mirrored, it makes the same choice and loses about the same.
		for kind in KINDS:
			if not KINDS.has(kind + "_l"):
				continue
			for level in LEVELS:
				var gap := absf(_time(kind, level, "own") - _time(kind + "_l", level, "own"))
				check(_went(kind, level) == _went(kind + "_l", level) and gap < 0.05, "the AI does the same with a %s one grown %.1f mirrored (%.3f s apart)" % [kind, level, gap])
		print("All drift feel checks passed." if failures == 0 else "%d drift feel checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
