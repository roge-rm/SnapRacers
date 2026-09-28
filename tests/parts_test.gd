extends SceneTree

## Checks the parts and what they do to a kart: every part can be built and
## turned, streamlined shapes cut the drag, a windscreen shelters the driver,
## a laid back seat trades control for less drag, steering has to be in reach,
## a jet pushes, and off-road tires keep their grip on grass.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/parts_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## A kart from a list of [id, x, y, z, rot].
func kart(parts: Array) -> KartDesign:
	var design := KartDesign.new()
	for p in parts:
		design.parts.append({ "id": p[0], "at": Vector3i(p[1], p[2], p[3]), "rot": p[4] if p.size() > 4 else 0 })
	return design


## The starter's chassis, wheels, seat and steering, plus these parts.
func base(extra: Array, seat := "seat") -> KartDesign:
	var parts := [
		["plate_6x10", 7, 2, 7],
		["wheel_small", 6, 0, 8], ["wheel_small", 13, 0, 8],
		["wheel_small", 6, 0, 13], ["wheel_small", 13, 0, 13],
		["steering_wheel", 9, 3, 10],
		[seat, 9, 3, 11],
		["engine_small", 9, 3, 15],
	]
	return kart(parts + extra)


func drag(design: KartDesign) -> float:
	return KartStats.compute(design).drag_area


func _init() -> void:
	# Every part has what it needs, and its look can be made every way around.
	var kinds := {}
	for id in PartCatalog.ids():
		var def := PartCatalog.get_part(id)
		var ok: bool = def.has("name") and def.has("kind") and def.has("mass") and def.size.x > 0 and def.size.y > 0 and def.size.z > 0
		kinds[def.kind] = kinds.get(def.kind, 0) + 1
		for rot in 4:
			var look := PartVisuals.make(def, Grid.to_metres(Vector3(Grid.rotated_size(def.size, rot))), rot)
			ok = ok and look != null
			look.free()
		if not ok:
			check(false, "%s is a whole part" % id)
	check(PartCatalog.ids().size() >= 50, "there are plenty of parts (%d)" % PartCatalog.ids().size())
	check(kinds.get("engine", 0) >= 8 and kinds.get("wheel", 0) >= 9 and kinds.get("seat", 0) >= 3, "with lots of engines, wheels and seats %s" % [kinds])
	check(PartCatalog.get_part("wedge_left_4x6").mirror == "wedge_right_4x6" and PartCatalog.get_part("wedge_right_4x6").mirror == "wedge_left_4x6", "a left wedge's mirror image is a right wedge")

	# Shapes and air.
	var flat := drag(base([["brick_2x2", 9, 3, 7]]))
	var sloped := drag(base([["slope_2x2", 9, 3, 7]]))
	var nosed := drag(base([["nose_2x2", 9, 3, 7]]))
	check(sloped < flat and nosed < sloped, "a slope at the front cuts the drag of a brick, and a nose cone more (%.3f, %.3f, %.3f)" % [flat, sloped, nosed])
	var tail_flat := drag(base([["brick_2x2", 9, 3, 17]]))
	var tail := drag(base([["slope_2x2", 9, 3, 17, 2]]))
	check(tail < tail_flat, "a slope turned around smooths the back too (%.3f against %.3f)" % [tail, tail_flat])
	var sideways := drag(base([["slope_2x2", 9, 3, 7, 1]]))
	check(is_equal_approx(sideways, flat), "but side on it's no better than a brick")

	var open := KartStats.compute(base([]))
	var screened := KartStats.compute(base([["brick_2x2", 9, 3, 8], ["windscreen_2", 9, 6, 8]]))
	check(screened.drag_parts.driver < open.drag_parts.driver * 0.7, "a windscreen in front shelters the driver (%.3f against %.3f)" % [screened.drag_parts.driver, open.drag_parts.driver])
	check(open.most_drag() == "wheels", "on a plain kart, most of the drag is the wheels")

	var faired := KartStats.compute(base([["wheel_fairing_1", 6, 2, 6], ["wheel_fairing_1", 13, 2, 6]]))
	check(faired.drag_parts.wheels < open.drag_parts.wheels * 0.75, "fairings in front of the wheels shield them (%.3f against %.3f)" % [faired.drag_parts.wheels, open.drag_parts.wheels])
	check(base([["wheel_fairing_1", 6, 2, 6], ["wheel_fairing_1", 13, 2, 6]]).problems().is_empty(), "and they clip onto the side of the chassis like wheels")

	# Ergonomics.
	var upright := KartStats.compute(base([]))
	var lying := KartStats.compute(kart([
		["plate_6x10", 7, 2, 7],
		["wheel_small", 6, 0, 8], ["wheel_small", 13, 0, 8],
		["wheel_small", 6, 0, 13], ["wheel_small", 13, 0, 13],
		["steering_wheel", 9, 3, 10], ["lay_down_seat", 9, 3, 11], ["engine_small", 9, 3, 15]]))
	check(lying.drag_parts.driver < upright.drag_parts.driver, "a driver lying down catches less wind (%.3f against %.3f)" % [lying.drag_parts.driver, upright.drag_parts.driver])
	check(lying.center_of_mass.y < upright.center_of_mass.y, "and sits lower")
	check(lying.control < upright.control and lying.recline > 0.5, "but can't steer as quickly (%d%%)" % roundi(lying.control * 100.0))
	var reaching := base([]).duplicate_design()
	reaching.parts[5].at = Vector3i(9, 3, 8)
	check(KartStats.compute(reaching).control < upright.control, "reaching a stud further for the steering costs control")
	var too_far := base([]).duplicate_design()
	too_far.parts[5].at = Vector3i(9, 3, 7)
	too_far.parts[0].at = Vector3i(7, 2, 6)
	check(too_far.problems().has("The driver can't reach the steering. It has to be right in front of the seat."), "steering out of reach is a problem %s" % [too_far.problems()])
	var bars := base([]).duplicate_design()
	bars.parts[5] = { "id": "handlebars", "at": Vector3i(8, 3, 10), "rot": 0 }
	check(KartStats.compute(bars).control > upright.control, "handlebars steer quicker than a wheel")

	# Engines and wheels.
	var jet := base([["jet", 11, 3, 13]])
	check(KartStats.compute(jet).top_speed() > upright.top_speed() + 3.0, "a jet adds speed (%d against %d km/h)" % [KartStats.compute(jet).top_speed() * 3.6, upright.top_speed() * 3.6])
	check(KartStats.compute(kart([["jet", 0, 0, 0]])).top_speed() > 0.0, "and pushes even with no engine driving the wheels")
	var grass := 0.6
	check(Kart.ground_grip(grass, PartCatalog.get_part("wheel_knobbly").offroad) > 0.8, "knobbly tires keep most of their grip on grass (%.2f)" % Kart.ground_grip(grass, 0.6))
	check(Kart.ground_grip(grass, PartCatalog.get_part("wheel_slick").offroad) < grass, "slicks lose even more there (%.2f)" % Kart.ground_grip(grass, -0.3))
	check(is_equal_approx(Kart.ground_grip(1.0, -0.3), 1.0), "and every tire grips the road the same way it always does")
	var mixed := KartStats.compute(base([]).duplicate_design())
	var wide_back := base([]).duplicate_design()
	wide_back.parts[3] = { "id": "wheel_slick", "at": Vector3i(5, 0, 13), "rot": 0 }
	wide_back.parts[4] = { "id": "wheel_slick", "at": Vector3i(13, 0, 13), "rot": 0 }
	check(is_equal_approx(KartStats.compute(wide_back).grip, mixed.grip), "cornering goes by the end that grips less, so slicks on the back alone don't add any")

	print("All parts checks passed." if failures == 0 else "%d parts checks failed." % failures)
	quit(1 if failures > 0 else 0)
