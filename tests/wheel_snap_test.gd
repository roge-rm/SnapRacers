extends SceneTree

## Checks wheels only snap onto axles and pins: every wheel held over a kart
## with a plate, a handle, an axle plate and a fork only gets axle and pin
## dots, a wheel put anywhere along a fork's axle goes on in the middle of it,
## Slide still moves it off the middle, and every stock vehicle still loads
## with its wheels on axles or pins.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/wheel_snap_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## How far the wheel's middle is from the middle of the line it's on, along
## the line, in the fine unit.
func off_middle(design: KartDesign, wheel: String, place: Transform3D, spot: Dictionary) -> float:
	var line: Dictionary = Connectors.of(design.parts[spot.part].id)[spot.index]
	var mid: Vector3 = spot.at + spot.axis * (line.length * 0.5 - spot.along)
	return absf((place * (PartCatalog.fine_size(wheel) * 0.5) - mid).dot(spot.axis))


func _init() -> void:
	var wheels := PartCatalog.ids().filter(func(id: String) -> bool: return KartDesign.is_wheel(id))
	var kart := KartDesign.new()
	kart.parts.append({ "id": "brick_2x4", "at": Vector3i(1, 0, 1), "rot": 0 })
	kart.parts.append({ "id": "p_plate_handle_1x2", "at": Vector3i(8, 0, 1), "rot": 0 })
	kart.parts.append({ "id": "p_axle_plate_2x6", "at": Vector3i(1, 0, 12), "rot": 0 })
	kart.parts.append({ "id": "b_fork_sport", "at": Vector3i(12, 6, 12), "rot": 0 })
	var types := {}
	for spot in Snap.open_spots(kart):
		types[spot.type] = true
	check(types.has("stud") and types.has("side") and types.has("bar") and types.has("axle"), "the kart has studs, sides, a bar and axles %s" % [types.keys()])
	var wrong := []
	var none := []
	for wheel in wheels:
		var spots := Snap.spots_for(kart, wheel)
		if not spots.any(func(s: Dictionary) -> bool: return s.part == 3):
			none.append(wheel)
		for spot in spots:
			if not spot.type in ["axle", "pin"]:
				wrong.append("%s on %s" % [wheel, spot.type])
		# Nor any way on by anything but its hub, even onto a stud or side.
		for spot in Snap.open_spots(kart):
			for way in Snap.ways(wheel, spot, Basis.IDENTITY, spot.at):
				if way.own.type != "hub" or not spot.type in ["axle", "pin"]:
					wrong.append("%s by %s on %s" % [wheel, way.own.type, spot.type])
					break
	check(wrong.is_empty(), "every wheel (%d) only goes on axles and pins %s" % [wheels.size(), wrong.slice(0, 10)])
	check(none.is_empty(), "and every wheel gets dots on the fork's axle %s" % [none])

	# A wheel put on at any dot along a fork's axle goes on in the middle.
	for fork in ["b_fork_sport", "b_moto_fork", "b_fork_chopper_long", "b_fork_scooter_small"]:
		for wheel in ["w_moto", "w_scooter_small", "w_scrambler"]:
			var bike := KartDesign.new()
			bike.parts.append({ "id": fork, "at": Vector3i(9, 10, 10), "rot": 0 })
			var spots := Snap.spots_for(bike, wheel)
			var worst := 0.0
			var went := 0
			for spot in spots:
				var way := Snap.way_on(bike, wheel, spot, Basis.IDENTITY)
				if way.is_empty() or not way.fits:
					continue
				went += 1
				worst = maxf(worst, off_middle(bike, wheel, way.place, spot))
				if not KartDesign.joined({ "id": wheel, "place": way.place }, bike.parts[0]):
					worst = INF
			if went == 0:
				continue
			check(went == spots.size() and worst <= 1.0, "%s on %s goes on in the middle from each of %d dots (%d, %.1f off)" % [wheel, fork, spots.size(), went, worst])

	# Slide still moves it off the middle, and back round.
	var bike := KartDesign.new()
	bike.parts.append({ "id": "b_fork_sport", "at": Vector3i(9, 10, 10), "rot": 0 })
	var first: Dictionary = Snap.spots_for(bike, "w_moto")[0]
	var way := Snap.way_on(bike, "w_moto", first, Basis.IDENTITY)
	var on: Dictionary = way.get("spot", first)
	var slid := Snap.slid(bike, "w_moto", on, way)
	check(Snap.slides(on, way) and absf((slid.place.origin - way.place.origin).length() - Snap.SLIDE) < 0.01, "Slide moves a wheel on a fork off the middle")

	# On a long axle it goes where it's put, as before.
	var quad := KartDesign.new()
	quad.parts.append({ "id": "b_quad_frame", "at": Vector3i(6, 4, 4), "rot": 0 })
	var long := Snap.spots_for(quad, "w_quad").filter(func(s: Dictionary) -> bool: return s.step == 0)
	var plain := Snap.best(quad, "w_quad", Snap.ways("w_quad", long[0], Basis.IDENTITY, long[0].at))
	var chosen := Snap.way_on(quad, "w_quad", long[0], Basis.IDENTITY)
	check(not long.is_empty() and chosen.place.is_equal_approx(plain.place), "on a quad's long axle a wheel goes on where it's put")

	# Every stock vehicle loads, can be driven, and has every wheel on an axle
	# or a pin.
	var off := []
	var bad := []
	var count := 0
	for file in DirAccess.get_files_at("res://data/karts/stock"):
		if not file.ends_with(".json"):
			continue
		count += 1
		var design := KartDesign.load_file("res://data/karts/stock/" + file)
		if not design.problems().is_empty():
			bad.append("%s %s" % [file, design.problems()])
		for i in design.parts.size():
			var w: Dictionary = design.parts[i]
			if not KartDesign.is_wheel(w.id):
				continue
			var held := false
			for c in Connectors.placed(w.id, KartDesign.place_of(w)):
				if c.type != "hub":
					continue
				for j in design.parts.size():
					if j == i:
						continue
					for o in Connectors.placed(design.parts[j].id, KartDesign.place_of(design.parts[j])):
						if o.type in ["axle", "pin"] and Connectors.meet(c, o):
							held = true
							break
					if held:
						break
				if held:
					break
			if not held:
				off.append("%s wheel %d" % [file, i])
	check(count >= 40 and bad.is_empty(), "the %d stock vehicles load and can be driven %s" % [count, bad])
	check(off.is_empty(), "and every one of their wheels is on an axle or a pin %s" % [off])

	print("%d failed" % failures if failures else "all passed")
	quit(1 if failures else 0)
