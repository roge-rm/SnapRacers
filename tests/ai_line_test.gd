extends Node

## An Easy, a Normal and an Expert AI driver each driving a lap on their
## racing lines on a few courses, in all four layouts. Each has to finish it
## without resetting or running off the road. First, two drivers seeded the
## same have to pick the same line all the way round. The race itself isn't
## compared, as the physics with sliding karts doesn't come out exactly the
## same twice, even before the racing line. Last, each drives a lap of a
## course with water, lava, mud, ice and sand painted as close to the road as
## they're allowed, which its line keeps clear of.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/ai_line_test.tscn

const COURSES := ["hairpin_hall", "lakeshore_plunge", "launchpad_loop"]
const LAYOUTS := [[false, false], [false, true], [true, false], [true, true]]
const LEVELS := ["easy", "normal", "expert"]
## The course painted all round for the last check, and the types it gets,
## in blocks of four by four squares.
const PAINTED := "lakeshore_plunge"
const PAINT_TYPES := ["water", "lava", "mud", "ice", "sand", "gravel", "slime"]
## The longest a lap may take, in seconds.
const GIVE_UP := 220.0
## Over the road's edge by this much, in metres, counts as off it, and a
## kart may be off it this long in a lap, in seconds.
const OFF_BY := 0.3
const OFF_FOR := 1.0

var failures := 0
var design: KartDesign
var track: TrackPath
var builder: TrackBuilder
var karts: Array[Kart] = []
var drivers: Array[AIDriver] = []
var offsets: Array[float] = []
var gone: Array[float] = []
var off: Array[float] = []
var resets: Array[int] = []
var finished: Array[int] = []


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	design = KartDesign.load_file("res://data/karts/stock/kart_kid.json")
	# The same seed picks the same line, and a different one doesn't.
	var path := TrackPath.load_file("res://data/tracks/hairpin_hall.json")
	path.apply_layout(false, false)
	var same := [_seeded(path, 7), _seeded(path, 7), _seeded(path, 8)]
	var apart := 0.0
	var other := 0.0
	var at := 0.0
	while at < path.length:
		apart = maxf(apart, absf(same[0].line_at(at) - same[1].line_at(at)))
		other = maxf(other, absf(same[0].line_at(at) - same[2].line_at(at)))
		at += 5.0
	check(apart == 0.0 and other > 0.05, "the same seed picks the same line (%.3f m apart, %.2f m with another seed)" % [apart, other])
	for driver in same:
		driver.free()
	for course in COURSES:
		for layout in LAYOUTS:
			var name := "%s%s%s" % [course, " mirrored" if layout[0] else "", " reversed" if layout[1] else ""]
			for level in LEVELS:
				await _race(course, layout[0], layout[1], level)
				check(finished[0] > 0 and resets[0] == 0 and off[0] <= OFF_FOR, "%s: %s finishes a lap (%s), %d resets, %.1f s off the road" % [name, level, "%.1f s" % (finished[0] / 60.0) if finished[0] > 0 else "%.0f m" % gone[0], resets[0], off[0]])
	for level in LEVELS:
		await _race(PAINTED, false, false, level, true)
		var painted := track.paint.count()
		check(painted > 100 and finished[0] > 0 and resets[0] == 0 and off[0] <= OFF_FOR, "%s painted (%d squares): %s finishes a lap (%s), %d resets, %.1f s off the road" % [PAINTED, painted, level, "%.1f s" % (finished[0] / 60.0) if finished[0] > 0 else "%.0f m" % gone[0], resets[0], off[0]])
	print("All AI line checks passed." if failures == 0 else "%d AI line checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _seeded(path: TrackPath, seed: int) -> AIDriver:
	var ai := AIDriver.new()
	ai.track = path
	Difficulty.apply(ai, "normal", 1, 3)
	ai.seed_line(seed)
	return ai


## Races one driver at `level` from the grid, on its own so it's its line
## that's tested and not its racecraft, until it's done a lap or GIVE_UP.
func _race(course: String, mirrored: bool, reversed: bool, level: String, painted := false) -> void:
	_clear()
	await get_tree().physics_frame
	track = TrackPath.load_file("res://data/tracks/%s.json" % course)
	track.apply_layout(mirrored, reversed)
	if painted:
		_paint_all_round()
	track.racing_line()
	builder = TrackBuilder.new(track)
	add_child(builder)
	for i in 1:
		var kart := Kart.new()
		kart.build(design)
		kart.paint = track.paint
		kart.transform = track.grid_slot(1)
		add_child(kart)
		var ai := AIDriver.new()
		ai.kart = kart
		ai.track = track
		Difficulty.apply(ai, level, 1, 3)
		ai.seed_line(1000 + LEVELS.find(level))
		kart.controls = ai.controls
		add_child(ai)
		karts.append(kart)
		drivers.append(ai)
		offsets.append(track.offset_of(kart.global_position))
		gone.append(0.0)
		off.append(0.0)
		resets.append(0)
		finished.append(0)
		var k := resets.size() - 1
		kart.was_reset.connect(func() -> void: resets[k] += 1)
		# Put back on the road where it was, like a race does.
		kart.reset_to = func(_where: Vector3) -> Transform3D: return track.place_at(offsets[k])
	for ai in drivers:
		ai.others = karts
	for tick in int(GIVE_UP * 60.0):
		await get_tree().physics_frame
		var all_done := true
		for i in karts.size():
			var kart := karts[i]
			var was := offsets[i]
			offsets[i] = track.offset_of(kart.global_position, was, 30.0)
			gone[i] += fposmod(offsets[i] - was + track.length * 0.5, track.length) - track.length * 0.5
			drivers[i].offset = offsets[i]
			var grounded := kart.wheels.any(func(w) -> bool: return w.grounded)
			var across := (kart.global_position - track.point_at(offsets[i])).dot(track.right_at(offsets[i]))
			if grounded and not track.on_road_across(offsets[i], across, -OFF_BY):
				off[i] += 1.0 / 60.0
			if finished[i] == 0 and gone[i] >= track.length:
				finished[i] = tick + 1
			all_done = all_done and finished[i] > 0
		if all_done:
			return


func _clear() -> void:
	for ai in drivers:
		ai.kart = null
		ai.queue_free()
	for kart in karts:
		kart.queue_free()
	if builder != null:
		builder.queue_free()
		builder = null
	karts.clear()
	drivers.clear()
	offsets.clear()
	gone.clear()
	off.clear()
	resets.clear()
	finished.clear()


## Paints every square within 40 m of the road that a type is allowed in,
## the types in blocks, so each comes as close to the road as it may.
func _paint_all_round() -> void:
	var near := {}
	for p in track.points:
		var square := PaintedAreas.square_at(p.x, p.z)
		for dz in range(-5, 6):
			for dx in range(-5, 6):
				near[square + Vector2i(dx, dz)] = true
	for square: Vector2i in near:
		var block := Vector2i(floori(square.x / 4.0), floori(square.y / 4.0))
		var type: String = PAINT_TYPES[posmod(block.x * 3 + block.y * 5, PAINT_TYPES.size())]
		if PaintedAreas.allowed(square, type, track):
			track.paint.set_square(square, type)
