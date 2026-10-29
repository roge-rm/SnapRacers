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


## How much road one kind covers at each point of the race, in square metres
## (for drifts, times how deep).
func _cover(patches: Puddles) -> float:
	var total := 0.0
	for i in patches.spots.size():
		total += PI * patches.radius_now[i] * patches.radius_now[i] * (patches.growth(i) if patches is Drifts else 1.0)
	return total


## Puddles or drifts start few and small and build up over the race, only
## ever up, and come out exactly the same however the progress gets there.
func _check_build_up(peach: TrackPath, kind: GDScript, what: String, done: String) -> void:
	var a: Puddles = kind.new(peach, 9, 1.0)
	var b: Puddles = kind.new(peach, 9, 1.0)
	var started := func(p: Puddles) -> int: return Array(p.radius_now).filter(func(r: float) -> bool: return r > 0.0).size()
	var start_cover := _cover(a)
	var start_count: int = started.call(a)
	a.grow(0.5)
	var middle_cover := _cover(a)
	var middle_count: int = started.call(a)
	a.grow(1.0)
	var end_cover := _cover(a)
	var all_full := true
	for i in a.spots.size():
		all_full = all_full and a.radius_now[i] == a.spots[i][1] and a.growth(i) == 1.0
	# About a quarter have started before GO. Drifts start a bunch at a time,
	# so their share swings more.
	check(start_count < a.spots.size() * 0.4 and start_cover < end_cover * 0.1, "%s start few and small (%d of %d, %.0f m2)" % [what, start_count, a.spots.size(), start_cover])
	check(middle_count > start_count and middle_cover > start_cover * 3.0 and middle_cover < end_cover, "half way there are more and bigger (%d, %.0f m2)" % [middle_count, middle_cover])
	check(all_full and end_cover > 0.0, "and by the end the road's %s, every one full (%.0f m2)" % [done, end_cover])
	a.grow(0.3)
	check(a.level == 1.0 and _cover(a) == end_cover, "%s never go back" % what)
	# The other one gets there in little steps, the way a race does.
	var steps := 0
	var same_all_way := true
	var c: Puddles = kind.new(peach, 9, 1.0)
	while steps < 200:
		steps += 1
		b.grow(steps * 0.00737)
		c.grow(steps * 0.00737)
		same_all_way = same_all_way and b.radius_now == c.radius_now
	b.grow(1.0)
	check(same_all_way and b.radius_now == a.radius_now and b.level == a.level, "two lots of %s with the same seed and progress agree exactly, however they got there" % what)
	a.free()
	b.free()
	c.free()


## The water's drawn as deep as a kart finds it: at the corners, the
## middles of the sides and the middle of each triangle of the water's
## mesh, the depth worked out from the vertices the way its shader does
## matches factor_at(), at a few points in the build-up.
func _check_drawn_depth(peach: TrackPath) -> void:
	for level in [0.2, 0.5, 1.0]:
		var puddles := Puddles.new(peach, 5, 1.0)
		puddles.grow(level)
		var draw := puddles.get_child(0) as MeshInstance3D
		var arrays: Array = draw.mesh.surface_get_arrays(0)
		var shapes: Image = (draw.material_override as ShaderMaterial).get_shader_parameter("shapes").get_image()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var worst := 0.0
		var wet := 0
		var mixed := 0
		for t in range(0, indices.size(), 3):
			var corners: Array = [indices[t], indices[t + 1], indices[t + 2]]
			for k in Puddles.SLOTS:
				var id: float = arrays[Mesh.ARRAY_CUSTOM2][corners[0] * 4 + k]
				if arrays[Mesh.ARRAY_CUSTOM2][corners[1] * 4 + k] != id or arrays[Mesh.ARRAY_CUSTOM2][corners[2] * 4 + k] != id:
					mixed += 1
			for weights in [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [0.5, 0.5, 0.0], [0.0, 0.5, 0.5], [0.5, 0.0, 0.5], [1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0]]:
				var drawn: Array = _drawn(puddles, shapes, arrays, corners, weights)
				var found := puddles.factor_at(drawn[1])
				worst = maxf(worst, absf(drawn[0] - found))
				wet += 1 if drawn[0] > 0.0 or found > 0.0 else 0
		check(wet > 1000 and mixed == 0 and worst < 0.005, "the water's drawn as deep as a kart finds it, at %.0f%% (%d wet points, off by %.4f at most, %d triangles with two puddles in one slot)" % [level * 100.0, wet, worst, mixed])
		puddles.free()


## The water drawn at this point in a triangle of the puddles' mesh, as the
## shader works it out, and the point on the road under it.
func _drawn(puddles: Puddles, shapes: Image, arrays: Array, corners: Array, weights: Array) -> Array:
	var world := Vector3.ZERO
	var up := Vector3.ZERO
	var road_in := 0.0
	var along := [0.0, 0.0, 0.0, 0.0]
	var across := [0.0, 0.0, 0.0, 0.0]
	for j in 3:
		var v: int = corners[j]
		world += arrays[Mesh.ARRAY_VERTEX][v] * weights[j]
		up += arrays[Mesh.ARRAY_NORMAL][v] * weights[j]
		road_in += arrays[Mesh.ARRAY_TEX_UV][v].x * weights[j]
		for k in Puddles.SLOTS:
			along[k] += arrays[Mesh.ARRAY_CUSTOM0][v * 4 + k] * weights[j]
			across[k] += arrays[Mesh.ARRAY_CUSTOM1][v * 4 + k] * weights[j]
	var w := []
	for k in Puddles.SLOTS:
		var id: int = roundi(arrays[Mesh.ARRAY_CUSTOM2][corners[0] * 4 + k])
		if id < 0:
			w.append(Puddles.LOWEST)
			continue
		var size := shapes.get_pixel(3, id)
		var u: float = along[k]
		var x := u * size.r
		var y: float = (across[k] - size.b * u * u) * size.g
		var r2 := x * x + y * y
		var r := sqrt(maxf(r2, 1e-12))
		var c := x / r
		var s := y / r
		var ck := c
		var sk := s
		var far := 1.0
		for n in 6:
			if n > 0:
				var next := ck * c - sk * s
				sk = sk * c + ck * s
				ck = next
			var bump := shapes.get_pixel(n / 2, id)
			far += (bump.r * ck + bump.g * sk) if n % 2 == 0 else (bump.b * ck + bump.a * sk)
		var g := clampf((puddles.level - size.a) / Puddles.GROW, 0.0, 1.0)
		var grown := lerpf(Puddles.SMALLEST, 1.0, g)
		w.append(maxf((grown * grown if g > 0.0 else -100.0) - r2 / (far * far), Puddles.LOWEST))
	var depth := minf(Puddles._join(Puddles._join(Puddles._join(w[0], w[1]), w[2]), w[3]) + Puddles._shore(world), road_in * Puddles.EDGE_STEEP)
	return [clampf(depth, 0.0, 1.0), world - up.normalized() * Puddles.LIFT]


## Lightning only runs in a storm outdoors, checked once both are in the tree.
func _check_lightning(hall: WeatherEffects, clear: WeatherEffects) -> void:
	check(not hall.is_processing(), "no lightning indoors")
	check(not clear.is_processing(), "no lightning in clear weather")
	hall.queue_free()
	clear.queue_free()


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
	var hall := Conditions.resolve("hall_red", "storm", "night", 1234)
	var hall_weather := WeatherEffects.new(hall, null)
	var clear_weather := WeatherEffects.new(Conditions.resolve("orchard", "clear", "day", 1234), null)
	root.add_child(hall_weather)
	root.add_child(clear_weather)
	_check_lightning.call_deferred(hall_weather, clear_weather)

	var picked := Conditions.resolve("desert", "snow", "night", 7)
	check(picked.weather == "snow" and picked.time == "night", "a picked weather and time stick, even ones that don't suit the course")
	check(Conditions.picked("rain", "fog") == "rain" and Conditions.picked(Conditions.RANDOM, "fog") == "fog" and Conditions.picked(Conditions.RANDOM, Conditions.RANDOM) == Conditions.RANDOM, "the player's pick comes first, then the course's")
	# A course or theme can always be at one time of day, whatever the player
	# picks, with the weather still left to chance.
	var city := Conditions.fixed_time("city", Conditions.RANDOM, false)
	check(city == "night" and Conditions.picked("day", Conditions.RANDOM, city) == "night", "a city course is always at night, even when you pick day")
	var city_themes := Scenery.THEMES.keys().filter(func(t): return Conditions.CLIMATE_OF.get(t, "") == "city")
	check(city_themes.size() >= 4 and city_themes.all(func(t): return Conditions.fixed_time(t, "day", true) == "night"), "every City Cup theme is at night (%d themes)" % city_themes.size())
	check(Conditions.fixed_time("orchard", "dusk", true) == "dusk" and Conditions.fixed_time("orchard", "dusk", false) == "" and Conditions.fixed_time("orchard", Conditions.RANDOM, true) == "", "a course can keep its own time of day, and only when it's set to")
	check(Conditions.picked("rain", Conditions.RANDOM, "") == "rain" and Conditions.picked(Conditions.RANDOM, "fog", "") == "fog", "without one the picks work as before")
	var weathers := {}
	for i in 200:
		var night := Conditions.resolve("orchard", Conditions.RANDOM, Conditions.picked(Conditions.RANDOM, Conditions.RANDOM, "night"), i)
		if night.time != "night":
			weathers["wrong time"] = true
		weathers[night.weather] = true
	check(not weathers.has("wrong time") and weathers.size() >= 3, "and the weather's still random at a fixed time %s" % [weathers.keys()])
	var kept := CourseDesign.starter()
	kept.time = "night"
	kept.fixed_time = true
	check(TrackPath.from_dict(kept.to_dict()).fixed_time and CourseDesign.from_dict(kept.to_dict()).fixed_time and not TrackPath.from_dict(CourseDesign.starter().to_dict()).fixed_time, "a course keeps whether its time is fixed")
	var dark_clear := Conditions.resolve("orchard", "clear", "night", 1)
	dark_clear.time_fixed = true
	check(dark_clear.records_allowed() and not Conditions.resolve("orchard", "clear", "night", 1).records_allowed(), "records count on a clear night where it's always night, not otherwise")
	check(Conditions.from_dict(dark_clear.to_dict()).time_fixed and not Conditions.clear_day().to_dict().has("time_fixed"), "online, everyone knows the time is fixed")
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
	first.grow(1.0)
	var spot: Array = first.spots[0]
	check(first.factor_at(spot[0]) > 0.99 and first.factor_at(spot[0] + Vector3(spot[1] + 1.0, 0.0, 0.0)) == 0.0, "a point in the middle of one is in it, and one past its edge isn't")
	first.free()
	_check_drawn_depth(peach)
	second.free()
	_check_build_up(peach, Puddles, "puddles", "wet")
	_check_build_up(peach, Drifts, "drifts", "snowed in")
	var dry := Puddles.new(peach, 5, 1.0)
	var snowy := Drifts.new(peach, 5, 1.0)
	check(str(dry.spots) != str(snowy.spots), "the drifts aren't where the puddles would be")
	dry.free()
	snowy.free()

	# At night the lamps light the ground around them and nothing far away.
	var lamps: Array[Vector3] = [Vector3(0, 10, 0), Vector3(200, 10, 0)]
	var made := CourseLamps.light_map(lamps)
	var image: Image = made[0].get_image()
	var area: Vector4 = made[1]
	var at := func(x: float, z: float) -> Color: return image.get_pixel(int((x - area.x) * area.z * image.get_width()), int((z - area.y) * area.w * image.get_height()))
	check(at.call(0.0, 0.0).r * CourseLamps.MOST > 0.9 and at.call(100.0, 0.0).r == 0.0 and at.call(0.0, 0.0).a > 0.1, "a lamp lights the ground under it, not far away, and knows how high it is")
	check(Conditions.resolve("orchard", "clear", "dusk", 1).dark() and not Conditions.resolve("orchard", "clear", "morning", 1).dark() and not Conditions.resolve("hall_red", "clear", "night", 1).dark(), "the lamps come on at dusk, not in the morning, and never in a hall")
	check(Conditions.resolve("orchard", "clear", "night", 1).beams() and Conditions.resolve("orchard", "dust", "dusk", 1).beams() and not Conditions.resolve("orchard", "dust", "day", 1).beams() and not Conditions.resolve("orchard", "fog", "morning", 1).beams(), "headlight beams light the road at dusk and night, not in daytime dust or fog")
	root.add_child(Runner.new(self))


## Karts going into the same hard turn at the same speed, on a dry road, in
## rain and in snow, and through a puddle. The slippier it is, the less they
## get round.
class Runner:
	extends Node

	var test: SceneTree
	var karts := {}
	var rolling := {}
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
			kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
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
		# Karts rolling straight on: a wet road, through a puddle, a snowy
		# road, and through a shallow and a deep drift.
		x = 0.0
		for which in ["wet", "puddle", "snow", "shallow", "deep"]:
			var kart := Kart.new()
			kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
			kart.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.05, 110.0))
			var snowy: bool = which in ["snow", "shallow", "deep"]
			kart.weather_grip = Conditions.GRIP.snow if snowy else Conditions.GRIP.rain
			kart.weather_drag = Conditions.DRAG.snow if snowy else 1.0
			if which == "puddle":
				kart.puddles = Puddles.new()
				kart.puddles.add(Vector3(x, 0.0, 100.0), 30.0)
				add_child(kart.puddles)
			if which in ["shallow", "deep"]:
				kart.drifts = Drifts.new()
				# Started just now, or long since and full.
				kart.drifts.add(Vector3(x, 0.0, 100.0), 30.0, -Puddles.GROW * 0.3 if which == "shallow" else -1.0)
				add_child(kart.drifts)
			add_child(kart)
			rolling[which] = kart
			x += 30.0
		# A kart with headlights: they're off by day, on in the dark, and stay
		# that way after it loses a part.
		var lit := Kart.new()
		lit.build(KartDesign.load_file("res://tests/data/legacy/bruiser.json"))
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
		lit.beams = false
		test.check(lit._lamps.get_shader_parameter("on") == 1.0 and not lit._pool.visible, "and by day in the dust the lenses glow with no beam")
		lit.beams = true
		broken = lit

	func _physics_process(_delta: float) -> void:
		tick += 1
		if tick == 40:
			for kart in karts.values():
				kart.linear_velocity = Vector3(0, 0, -15.0)
				kart.controls.throttle = 0.4
				kart.controls.steer = 1.0
				start[kart] = kart.global_rotation.y
			for kart in rolling.values():
				kart.linear_velocity = Vector3(0, 0, -15.0)
				kart.controls.throttle = 1.0
			# A shove worked out as nonsense, which should never happen.
			broken._shove = Vector3(NAN, 0.0, 0.0)
		if tick == 100:
			var turned := {}
			for which in karts:
				var velocity: Vector3 = karts[which].linear_velocity
				turned[which] = rad_to_deg(absf(Vector3.FORWARD.signed_angle_to(Vector3(velocity.x, 0.0, velocity.z), Vector3.UP)))
			test.check(broken.global_transform.is_finite() and broken.linear_velocity.is_finite() and broken.global_position.distance_to(Vector3(100.0, 0.0, -100.0)) < 2.0, "a force that comes out as nonsense is left out, and the kart stays put (%s)" % broken.global_position)
			test.check(turned.rain < turned.dry and turned.snow < turned.rain and turned.puddle < turned.rain, "the slippier it is, the less a kart gets round a hard turn (dry %.0f, rain %.0f, snow %.0f, through a puddle %.0f degrees)" % [turned.dry, turned.rain, turned.snow, turned.puddle])
			var speeds := {}
			for which in rolling:
				speeds[which] = -rolling[which].linear_velocity.z
			test.check(speeds.puddle < speeds.wet - 0.3, "a full puddle holds a kart back (%.1f m/s against %.1f on the wet road)" % [speeds.puddle, speeds.wet])
			test.check(speeds.deep < speeds.shallow - 1.0 and speeds.shallow < speeds.snow - 0.05, "a deep drift holds a kart back hard, a shallow one a little (deep %.2f, shallow %.2f, snowy road %.2f m/s)" % [speeds.deep, speeds.shallow, speeds.snow])
			print("All weather checks passed." if test.failures == 0 else "%d weather checks failed." % test.failures)
			test.quit(1 if test.failures > 0 else 0)
