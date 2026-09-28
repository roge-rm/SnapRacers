extends SceneTree

## Checks the building rules and the garage's math with no screen.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/design_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var starter := KartDesign.load_file("res://data/karts/stock/starter.json")

	check(starter.problems().is_empty(), "the starter kart has no problems %s" % [starter.problems()])
	check(starter.groups().size() == 1, "the starter kart is all one piece")
	var stats := KartStats.compute(starter)
	var top := stats.top_speed() * 3.6
	check(top > 70.0 and top < 140.0, "the starter's top speed is sensible (%.0f km/h)" % top)
	check(stats.pull() > 0.5 and stats.pull() < 2.0, "the starter pulls away sensibly (%.2f g)" % stats.pull())

	# Taking the seat out leaves a kart with no driver.
	var no_seat := starter.duplicate_design()
	no_seat.parts = no_seat.parts.filter(func(p): return p.id != "seat")
	check(no_seat.problems().has("It needs a seat for the driver."), "a kart with no seat says it needs one")

	# A brick floating above the kart isn't held by anything.
	var floating := starter.duplicate_design()
	floating.parts.append({ "id": "brick_2x2", "at": Vector3i(1, 20, 1), "rot": 0 })
	check(floating.groups().size() == 2, "a floating brick is its own group")
	check(floating.problems().has("Some parts aren't attached to the rest."), "a floating brick is reported")

	# The spoiler sits on the engine and on the two 2x2 bricks either side of
	# it. Losing the engine alone leaves it held by the bricks, but losing all
	# three drops it.
	var engine := -1
	var spoiler := -1
	var side_bricks := []
	for i in starter.parts.size():
		match starter.parts[i].id:
			"engine_small":
				engine = i
			"spoiler_6":
				spoiler = i
			"brick_2x2":
				side_bricks.append(i)
	var seat := starter.seat_index()
	check(starter.detached_after({ engine: true }, seat).is_empty(), "losing just the engine drops nothing else")
	var all_under := { engine: true, side_bricks[0]: true, side_bricks[1]: true }
	check(Array(starter.detached_after(all_under, seat)) == [spoiler], "losing everything under the spoiler drops it too")

	# Fitting parts in. The chassis plate is at (7, 2, 7), 6 x 1 x 10.
	check(not starter.fits("brick_2x2", Vector3i(8, 2, 9), 0), "a brick can't go inside the chassis")
	check(starter.fits("brick_2x2", Vector3i(7, 3, 11), 0), "a brick fits in a free spot on the chassis")
	check(starter.attaches("brick_2x2", Vector3i(7, 3, 11), 0), "and it clicks onto the chassis studs")
	check(not starter.fits("brick_2x2", Vector3i(19, 0, 0), 0), "a brick can't stick out of the build area")
	check(not starter.attaches("brick_2x2", Vector3i(0, 0, 0), 0), "a brick off on its own isn't attached")

	# Wheels only go on by their axle, on the side.
	var plate := KartDesign.part_box("plate_6x10", Vector3i(7, 2, 7), 0)
	check(KartDesign.joined("wheel_small", KartDesign.part_box("wheel_small", Vector3i(6, 0, 8), 0), "plate_6x10", plate), "a wheel clips onto the side of the chassis")
	check(not KartDesign.joined("wheel_small", KartDesign.part_box("wheel_small", Vector3i(8, 3, 8), 0), "plate_6x10", plate), "a wheel sitting on top of the chassis isn't attached")

	# Looking straight down at the middle of the chassis.
	var empty_top := KartDesign.new()
	empty_top.parts.append({ "id": "plate_6x10", "at": Vector3i(7, 2, 7), "rot": 0 })
	var hit := BuildMath.cast(empty_top, Vector3(10.0, 25.0, 12.0), Vector3(0.0, -1.0, 0.0))
	check(hit.part == 0 and hit.normal == Vector3i(0, 1, 0), "looking down hits the top of the chassis")
	var at := BuildMath.placement(hit, Vector3i(2, 3, 2))
	check(at == Vector3i(9, 3, 11), "a 2x2 brick goes on top, centred where I looked (%s)" % at)

	# Looking at the left side of the chassis from the left, at axle height.
	hit = BuildMath.cast(empty_top, Vector3(-5.0, 2.5, 9.5), Vector3(1.0, 0.0, 0.0))
	check(hit.part == 0 and hit.normal == Vector3i(-1, 0, 0), "looking from the side hits the chassis side")
	at = BuildMath.placement(hit, Vector3i(1, 6, 3))
	check(at == Vector3i(6, 0, 8), "a wheel goes against the side, down on the floor (%s)" % at)
	check(empty_top.attaches("wheel_small", at, 0), "and that wheel is attached")

	# Looking at empty floor.
	hit = BuildMath.cast(empty_top, Vector3(2.0, 10.0, 2.0), Vector3(0.0, -1.0, 0.0))
	check(hit.part == -1 and hit.normal == Vector3i(0, 1, 0), "looking at empty floor hits the floor")

	# Aiming a stud off still finds a sensible spot. (9, 3, 14) would put a 2x2
	# brick right inside the engine.
	var near := BuildMath.nearest_spot(starter, "brick_2x2", Vector3i(9, 3, 14), 0)
	check(starter.fits("brick_2x2", near, 0) and starter.attaches("brick_2x2", near, 0), "a spot inside the engine moves to one that works (%s)" % near)
	check(BuildMath.nearest_spot(starter, "brick_2x2", Vector3i(7, 3, 11), 0) == Vector3i(7, 3, 11), "a spot that already works stays put")

	# Every kart that comes with the game has to be driveable.
	for file in DirAccess.get_files_at("res://data/karts/stock"):
		if file.ends_with(".json"):
			var kart := KartDesign.load_file("res://data/karts/stock/" + file)
			var stats_here := KartStats.compute(kart)
			check(kart.problems().is_empty(), "%s is driveable %s (%d kg, %d km/h)" % [kart.name, kart.problems(), stats_here.mass, stats_here.top_speed() * 3.6])

	# A painted part keeps its paint through saving and loading.
	var painted := KartDesign.load_file("res://data/karts/stock/featherlight.json")
	var again := KartDesign.from_dict(painted.to_dict())
	check(again.parts[5].get("color", Color.BLACK).is_equal_approx(Color("#0d69ab")), "paint survives a save and load")

	check(KartDesign.file_name_for("  My Kart!! 2 ") == "my_kart_2", "kart names make tidy file names")

	print("All design checks passed." if failures == 0 else "%d design checks failed." % failures)
	quit(1 if failures > 0 else 0)
