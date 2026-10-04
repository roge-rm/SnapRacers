extends SceneTree

## The weather and the time of day: left to chance they suit the course and
## come out the same for the same seed, and picking them sticks.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/weather_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var a := Conditions.resolve("orchard", Conditions.RANDOM, Conditions.RANDOM, 1234)
	var b := Conditions.resolve("orchard", Conditions.RANDOM, Conditions.RANDOM, 1234)
	check(a.to_dict() == b.to_dict(), "the same seed gives the same weather and time (%s)" % a.describe())
	check(Conditions.from_dict(a.to_dict()).to_dict() == a.to_dict(), "and they come through being sent online unchanged")

	var counts := {}
	for theme in ["desert", "frost", "malta", "orchard", "hall_red"]:
		counts[theme] = {}
		for seed in 500:
			var c := Conditions.resolve(theme, Conditions.RANDOM, Conditions.RANDOM, seed)
			counts[theme][c.weather] = counts[theme].get(c.weather, 0) + 1
			if theme == "hall_red":
				counts[theme]["indoor"] = counts[theme].get("indoor", 0) + (1 if c.indoor and not c.dark() else 0)
	check(not counts.desert.has("rain") and not counts.desert.has("snow") and counts.desert.get("dust", 0) > 100, "deserts never rain or snow, and get dust storms %s" % [counts.desert])
	check(counts.frost.get("snow", 0) > 200, "frosty courses snow more often than not %s" % [counts.frost])
	check(counts.malta.get("clear", 0) > 350, "beaches are mostly sunny %s" % [counts.malta])
	check(counts.orchard.size() >= 4, "and anywhere else gets a mix %s" % [counts.orchard])
	check(counts.hall_red.get("indoor", 0) == 500, "halls are always indoors and lit")

	var picked := Conditions.resolve("desert", "snow", "night", 7)
	check(picked.weather == "snow" and picked.time == "night", "a picked weather and time stick, even ones that don't suit the course")
	check(Conditions.picked("rain", "fog") == "rain" and Conditions.picked(Conditions.RANDOM, "fog") == "fog" and Conditions.picked(Conditions.RANDOM, Conditions.RANDOM) == Conditions.RANDOM, "the player's pick comes first, then the course's")
	check(Conditions.resolve("orchard", "clear", "night", 1).dark() and not Conditions.resolve("orchard", "clear", "day", 1).dark() and Conditions.resolve("orchard", "fog", "day", 1).dark(), "it's dark at night and in fog, not on a clear day")

	# A course keeps its own weather and time through saving.
	var course := CourseDesign.starter()
	course.weather = "storm"
	course.time = "dusk"
	var again := CourseDesign.from_dict(course.to_dict())
	var track := TrackPath.from_dict(course.to_dict())
	check(again.weather == "storm" and again.time == "dusk" and track.weather == "storm" and track.time == "dusk", "a course keeps its own weather and time")

	# Puddles come out the same for the same seed, and only in the rain.
	var peach := TrackPath.load_file("res://data/tracks/peach_pit.json")
	var first := Puddles.new(peach, 5, 1.0)
	var second := Puddles.new(peach, 5, 1.0)
	check(first.spots.size() >= 10 and str(first.spots) == str(second.spots), "puddles come out the same for the same seed (%d of them)" % first.spots.size())
	var spot: Array = first.spots[0]
	check(first.factor_at(spot[0]) > 0.99 and first.factor_at(spot[0] + Vector3(spot[1] + 1.0, 0.0, 0.0)) == 0.0, "a point in the middle of one is in it, and one past its edge isn't")
	first.free()
	second.free()

	# At night the lamps light the ground around them and nothing far away.
	var lamps: Array[Vector3] = [Vector3(0, 10, 0), Vector3(200, 10, 0)]
	var made := CourseLamps.light_map(lamps)
	var image: Image = made[0].get_image()
	var area: Vector4 = made[1]
	var at := func(x: float, z: float) -> Color: return image.get_pixel(int((x - area.x) * area.z * image.get_width()), int((z - area.y) * area.w * image.get_height()))
	check(at.call(0.0, 0.0).r > 0.5 and at.call(100.0, 0.0).r == 0.0 and at.call(0.0, 0.0).a > 0.1, "a lamp lights the ground under it, not far away, and knows how high it is")
	check(Conditions.resolve("orchard", "clear", "dusk", 1).dark() and not Conditions.resolve("orchard", "clear", "morning", 1).dark() and not Conditions.resolve("hall_red", "clear", "night", 1).dark(), "the lamps come on at dusk, not in the morning, and never in a hall")
	root.add_child(Runner.new(self))


## Karts going into the same hard turn at the same speed, on a dry road, in
## rain and in snow, and through a puddle. The slippier it is, the less they
## get round.
class Runner:
	extends Node

	var test: SceneTree
	var karts := {}
	var start := {}
	var tick := 0
	var broken: Kart

	func _init(for_test: SceneTree) -> void:
		test = for_test

	func _ready() -> void:
		add_child(TestTrack.new())
		var x := -120.0
		for which in ["dry", "rain", "snow", "puddle"]:
			var kart := Kart.new()
			kart.build(KartDesign.load_file("res://data/karts/stock/starter.json"))
			kart.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.05, 110.0))
			kart.weather_grip = Conditions.GRIP.get(which, 1.0)
			kart.weather_drag = Conditions.DRAG.get(which, 1.0)
			if which == "puddle":
				# Rain, and a puddle big enough to turn in.
				kart.weather_grip = Conditions.GRIP.rain
				kart.puddles = Puddles.new()
				kart.puddles.add(Vector3(x, 0.0, 90.0), 30.0)
				add_child(kart.puddles)
			add_child(kart)
			karts[which] = kart
			x += 30.0
		# A kart with headlights: they're off by day, on in the dark, and stay
		# that way after it loses a part.
		var lit := Kart.new()
		lit.build(KartDesign.load_file("res://data/karts/stock/bruiser.json"))
		lit.transform = Transform3D(Basis.IDENTITY, Vector3(100.0, 0.05, -100.0))
		add_child(lit)
		test.check(lit._lamps != null and lit._pool != null and lit._lamps.get_shader_parameter("on") == 0.0 and not lit._pool.visible, "a kart's headlights are off by day")
		lit.lights_on = true
		test.check(lit._lamps.get_shader_parameter("on") == 1.0 and lit._pool.visible, "and on in the dark, lighting the road ahead")
		var plain := -1
		for i in lit.design.parts.size():
			if not PartCatalog.get_part(lit.design.parts[i].id).has("light") and PartCatalog.get_part(lit.design.parts[i].id).kind in ["brick", "body"]:
				plain = i
				break
		var lose: Array[int] = [plain]
		lit.lose_parts(lose)
		test.check(lit._lamps.get_shader_parameter("on") == 1.0 and lit._pool.visible, "and still on after it loses a part")
		broken = lit

	func _physics_process(_delta: float) -> void:
		tick += 1
		if tick == 40:
			for kart in karts.values():
				kart.linear_velocity = Vector3(0, 0, -15.0)
				kart.controls.throttle = 0.4
				kart.controls.steer = 1.0
				start[kart] = kart.global_rotation.y
			# A shove worked out as nonsense, which should never happen.
			broken._shove = Vector3(NAN, 0.0, 0.0)
		if tick == 100:
			var turned := {}
			for which in karts:
				var velocity: Vector3 = karts[which].linear_velocity
				turned[which] = rad_to_deg(absf(Vector3.FORWARD.signed_angle_to(Vector3(velocity.x, 0.0, velocity.z), Vector3.UP)))
			test.check(broken.global_transform.is_finite() and broken.linear_velocity.is_finite() and broken.global_position.distance_to(Vector3(100.0, 0.0, -100.0)) < 2.0, "a force that comes out as nonsense is left out, and the kart stays put (%s)" % broken.global_position)
			test.check(turned.rain < turned.dry and turned.snow < turned.rain and turned.puddle < turned.rain, "the slippier it is, the less a kart gets round a hard turn (dry %.0f, rain %.0f, snow %.0f, through a puddle %.0f degrees)" % [turned.dry, turned.rain, turned.snow, turned.puddle])
			print("All weather checks passed." if test.failures == 0 else "%d weather checks failed." % test.failures)
			test.quit(1 if test.failures > 0 else 0)
