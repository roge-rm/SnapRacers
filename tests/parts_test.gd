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
	check(too_far.problems().has("The steering has to be right in front of the seat."), "steering out of reach is a problem %s" % [too_far.problems()])
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

	# The parts modelled by tools/parts join by their own connectors. A wheel
	# goes onto the stub of an axle, and a curved slope onto studs.
	var made := PartCatalog.ids().filter(func(id): return PartCatalog.get_part(id).has("mesh"))
	check(made.size() >= 100, "there are the modelled parts too (%d)" % made.size())
	check(made.all(func(id): return ResourceLoader.exists(PartCatalog.get_part(id).mesh)), "and every one has its mesh")
	var plate_place := Transform3D(Basis.IDENTITY, Vector3(140.0, 27.2, 100.0))
	var axle_plate := { "id": "p_axle_plate_2x6", "place": plate_place }
	# The axle stub on the left runs across from x 0 to 20 at (y 3.2, z 10),
	# and the wheel's hub runs across its middle at (y 24, z 24).
	var wheel := { "id": "w_kart", "place": Transform3D(Basis.IDENTITY, plate_place.origin + Vector3(0.0, 3.2 - 24.0, 10.0 - 24.0)) }
	check(KartDesign.joined(wheel, axle_plate), "a wheel goes onto an axle's stub")
	check(not KartDesign.clash(wheel.id, wheel.place, axle_plate.id, axle_plate.place), "without going through the plate it sticks out of")
	var curve := { "id": "p_curve_2x4", "place": Transform3D(Basis.IDENTITY, plate_place.origin + Vector3(20.0, 12.8, 0.0)) }
	check(KartDesign.joined(curve, axle_plate), "a curved slope clicks onto the studs")
	var floating := { "id": "p_curve_2x4", "place": Transform3D(Basis.IDENTITY, plate_place.origin + Vector3(20.0, 20.0, 0.0)) }
	check(not KartDesign.joined(floating, axle_plate), "but not when it's held up off them")

	# A round brick stacks between a plate and a smooth tile, including when
	# the whole stack is turned onto its side or upside down.
	var round_stack := true
	var round_gap := true
	var smooth_top := true
	for turn in Grid.turns():
		var stack_place := Transform3D(turn, plate_place.origin)
		var bottom := { "id": "p_round_plate_1x1", "place": stack_place }
		var brick := { "id": "p_round_brick_1x1", "place": stack_place * Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)) }
		var tile := { "id": "p_round_tile_1x1", "place": stack_place * Transform3D(Basis.IDENTITY, Vector3(0, 32, 0)) }
		round_stack = round_stack and KartDesign.joined(bottom, brick) and KartDesign.joined(brick, tile)
		round_stack = round_stack and not KartDesign.clash(bottom.id, bottom.place, brick.id, brick.place) and not KartDesign.clash(brick.id, brick.place, tile.id, tile.place)
		var lifted := { "id": tile.id, "place": stack_place * Transform3D(Basis.IDENTITY, Vector3(0, 40, 0)) }
		round_gap = round_gap and not KartDesign.joined(brick, lifted)
		smooth_top = smooth_top and not KartDesign.joined(tile, lifted)
	check(round_stack, "a round 1×1 brick stacks on a plate and holds a round tile in all 24 turns")
	check(round_gap, "a round tile held above the brick stays disconnected")
	check(smooth_top, "the smooth round tile has no stud to hold another tile")

	_mounting_parts()
	_shaped_parts()
	_catalogue_compatibility()

	var window: BaseMaterial3D = PartVisuals.glass(Color("#8fd3f4"))
	check(window.cull_mode == BaseMaterial3D.CULL_BACK, "glass culls its inside")
	check(window.albedo_color.a < 0.15 and window.albedo_color.b - window.albedo_color.r < 0.05, "window glass is almost clear, not blue (a=%.2f)" % window.albedo_color.a)
	var red_glass: BaseMaterial3D = PartVisuals.glass(Color("#c4281c"))
	check(red_glass.albedo_color.r > 0.5 and red_glass.albedo_color.a > 0.2, "red lamp glass keeps its colour")
	check(KartMesh.material("glass").cull_mode == BaseMaterial3D.CULL_BACK, "baked kart glass culls its inside too")
	check(KartMesh.material("plastic").disable_receive_shadows and KartMesh.material("glass").disable_receive_shadows, "and the cab doesn't pick up sun shadows")

	print("All parts checks passed." if failures == 0 else "%d parts checks failed." % failures)
	quit(1 if failures > 0 else 0)


func _mounting_parts() -> void:
	var front := Basis(Vector3.RIGHT, -PI * 0.5)
	var back := Basis(Vector3.RIGHT, PI * 0.5)
	var mounts := true
	var opposite := true
	var centred := true
	var pins := true
	var axles := true
	var separated := true
	for turn in Grid.turns():
		var place := Transform3D(turn, Vector3(100, 100, 100))
		var bracket := KartDesign.placed_entry("p_inverted_bracket_1x2", place)
		var deck := KartDesign.placed_entry("p_plate_2x2", place * Transform3D(Basis.IDENTITY, Vector3(0, 24, 8)))
		var panel := KartDesign.placed_entry("p_tile_2x2", place * Transform3D(front, Vector3.ZERO))
		mounts = mounts and _joined_clear(bracket, deck) and _joined_clear(bracket, panel)
		mounts = mounts and not KartDesign.clash(deck.id, deck.place, panel.id, panel.place)

		var brick := KartDesign.placed_entry("p_opposite_stud_brick", place)
		var front_tile := KartDesign.placed_entry("p_tile_1x1", place * Transform3D(front, Vector3(0, 2, 0)))
		var back_tile := KartDesign.placed_entry("p_tile_1x1", place * Transform3D(back, Vector3(0, 22, 20)))
		opposite = opposite and _joined_clear(brick, front_tile) and _joined_clear(brick, back_tile)

		var bottom := KartDesign.placed_entry("p_plate_2x2", place)
		var jumper := KartDesign.placed_entry("p_jumper_2x2", place * Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
		var detail := KartDesign.placed_entry("p_brick_1x1", place * Transform3D(Basis.IDENTITY, Vector3(10, 16, 10)))
		centred = centred and _joined_clear(bottom, jumper) and _joined_clear(jumper, detail)
		var shifted := KartDesign.placed_entry(detail.id, place * Transform3D(Basis.IDENTITY, Vector3(0, 16, 10)))
		separated = separated and not KartDesign.joined(jumper, shifted)
		shifted = KartDesign.placed_entry(detail.id, place * Transform3D(Basis.IDENTITY, Vector3(10, 16, 0)))
		separated = separated and not KartDesign.joined(jumper, shifted)

		var pin_mount := KartDesign.placed_entry("p_technic_brick_1x2", place)
		var pin_mount_2 := KartDesign.placed_entry(pin_mount.id, place * Transform3D(Basis.IDENTITY, Vector3(20, 0, 0)))
		var pin := KartDesign.placed_entry("p_pin", place * Transform3D(Basis.IDENTITY, Vector3(0, 8.8, 15.2)))
		pins = pins and _joined_clear(pin_mount, pin) and _joined_clear(pin_mount_2, pin)
		pins = pins and not KartDesign.clash(pin_mount.id, pin_mount.place, pin_mount_2.id, pin_mount_2.place)
		var moved_pin := KartDesign.placed_entry(pin.id, place * Transform3D(Basis.IDENTITY, Vector3(0, 10.8, 15.2)))
		separated = separated and not KartDesign.joined(pin_mount, moved_pin)

		var axle_mount := KartDesign.placed_entry("p_axle_hole_brick_1x1", place)
		var axle_mount_2 := KartDesign.placed_entry(axle_mount.id, place * Transform3D(Basis.IDENTITY, Vector3(20, 0, 0)))
		var axle := KartDesign.placed_entry("p_axle_2", place * Transform3D(Basis.IDENTITY, Vector3(0, 7.2, 5.2)))
		axles = axles and _joined_clear(axle_mount, axle) and _joined_clear(axle_mount_2, axle)
		axles = axles and not KartDesign.clash(axle_mount.id, axle_mount.place, axle_mount_2.id, axle_mount_2.place)
		var wrong_pin := KartDesign.placed_entry("p_pin", axle.place)
		separated = separated and not KartDesign.joined(axle_mount, wrong_pin)
		var across := KartDesign.placed_entry(axle.id, place * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(5.2, 7.2, 10)))
		separated = separated and not KartDesign.joined(axle_mount, across)
	check(mounts, "an inverted bracket holds a front panel below a deck, with clearance behind the face, in all 24 turns")
	check(opposite, "opposite side studs hold two panels on a single brick in all 24 turns")
	check(centred, "a 2×2 jumper centres a 1×1 detail in both axes in all 24 turns")
	check(pins, "a pin joins two compact 1×2 hole bricks in all 24 turns")
	check(axles, "an existing axle passes through two 1×1 axle-hole mounts in all 24 turns")
	check(separated, "offset jumper details, displaced pins, round pins in axle holes and transverse axles stay disconnected")
	var mount := Transform3D.IDENTITY
	check(KartDesign.clash("p_axle_hole_brick_1x1", mount, "p_brick_1x1", mount), "an axle mount's walls still block a solid brick")
	check(Connectors.of("p_jumper_2x2").filter(func(c): return c.type == "stud").size() == 1, "the 2×2 jumper has just one centre stud")


func _joined_clear(a: Dictionary, b: Dictionary) -> bool:
	return KartDesign.joined(a, b) and not KartDesign.clash(a.id, a.place, b.id, b.place)


func _shaped_parts() -> void:
	var narrow_stack := true
	var smooth := true
	var inverted := true
	var underdeck := true
	var wedges := true
	var cutaways := true
	var mirrored := true
	for turn in Grid.turns():
		var place := Transform3D(turn, Vector3(100, 100, 100))
		var plate := KartDesign.placed_entry("p_plate_1x3", place)
		var brick := KartDesign.placed_entry("p_brick_1x3", place * Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
		var tile := KartDesign.placed_entry("p_tile_1x3", place * Transform3D(Basis.IDENTITY, Vector3(0, 32, 0)))
		narrow_stack = narrow_stack and _joined_clear(plate, brick) and _joined_clear(brick, tile)
		for size in ["1x3", "2x3"]:
			var bottom := KartDesign.placed_entry("p_plate_" + size, place)
			var top := KartDesign.placed_entry("p_tile_" + size, place * Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
			var above := KartDesign.placed_entry("p_plate_" + size, place * Transform3D(Basis.IDENTITY, Vector3(0, 16, 0)))
			smooth = smooth and _joined_clear(bottom, top) and not KartDesign.joined(top, above)
		for along in [2, 3]:
			var slope := KartDesign.placed_entry("p_inverted_slope_1x%d" % along, place)
			var foot := KartDesign.placed_entry("p_brick_1x1", place * Transform3D(Basis.IDENTITY, Vector3(0, -24, (along - 1) * 20)))
			var deck := KartDesign.placed_entry("p_plate_1x%d" % along, place * Transform3D(Basis.IDENTITY, Vector3(0, 24, 0)))
			inverted = inverted and _joined_clear(slope, foot) and _joined_clear(slope, deck)
			var below := KartDesign.placed_entry("p_tile_1x1", place * Transform3D(Basis.IDENTITY, Vector3(0, 0, -11 if along == 2 else 0)))
			underdeck = underdeck and not KartDesign.clash(slope.id, slope.place, below.id, below.place) and not KartDesign.joined(slope, below)
			below = KartDesign.placed_entry(below.id, place * Transform3D(Basis.IDENTITY, Vector3(0, 0, (along - 1) * 20)))
			underdeck = underdeck and KartDesign.clash(slope.id, slope.place, below.id, below.place)
		for side in ["left", "right"]:
			var wedge := KartDesign.placed_entry("p_wedge_2x4_" + side, place)
			var deck := KartDesign.placed_entry("p_plate_2x4", place * Transform3D(Basis.IDENTITY, Vector3(0, 8, 0)))
			var bottom := KartDesign.placed_entry("p_plate_2x4", place * Transform3D(Basis.IDENTITY, Vector3(0, -8, 0)))
			wedges = wedges and _joined_clear(wedge, deck) and _joined_clear(wedge, bottom)
			var beside := KartDesign.placed_entry("p_plate_1x1", place * Transform3D(Basis.IDENTITY, Vector3(-10 if side == "left" else 30, 0, 0)))
			cutaways = cutaways and not KartDesign.clash(wedge.id, wedge.place, beside.id, beside.place)
			beside = KartDesign.placed_entry(beside.id, place * Transform3D(Basis.IDENTITY, Vector3(0 if side == "left" else 20, 0, 0)))
			cutaways = cutaways and KartDesign.clash(wedge.id, wedge.place, beside.id, beside.place)
			var missing := KartDesign.placed_entry("p_plate_1x1", place * Transform3D(Basis.IDENTITY, Vector3(0 if side == "left" else 20, -8, 0)))
			cutaways = cutaways and not KartDesign.joined(wedge, missing)
			var twin_id: String = PartCatalog.get_part(wedge.id).mirror
			var twin := KartDesign.placed_entry(twin_id, Snap.mirror_place(wedge.id, wedge.place, 100))
			var again := KartDesign.placed_entry(PartCatalog.get_part(twin.id).mirror, Snap.mirror_place(twin.id, twin.place, 100))
			mirrored = mirrored and twin.id == "p_wedge_2x4_" + ("right" if side == "left" else "left") and again.id == wedge.id and again.place.is_equal_approx(wedge.place)
	check(narrow_stack, "a 1×3 brick stacks between a plate and tile in all 24 turns")
	check(smooth, "1×3 and 2×3 tiles attach below and have smooth tops in all 24 turns")
	check(inverted, "both narrow inverted slopes hold a deck and attach by their rear foot in all 24 turns")
	check(underdeck, "the inverted overhangs leave room below the front and block parts in the rear foot in all 24 turns")
	check(wedges, "both 2×4 wedges attach above and below in all 24 turns")
	check(cutaways, "both wedge cutaways accept a neighbouring plate, keep their solid edge and have no socket in the empty corner in all 24 turns")
	check(mirrored, "2×4 wedges swap sides and return to the same placement when mirrored twice in all 24 turns")
	var ids := ["p_inverted_slope_1x2", "p_inverted_slope_1x3", "p_brick_1x3", "p_tile_1x3", "p_tile_2x3", "p_wedge_2x4_left", "p_wedge_2x4_right"]
	var design := KartDesign.new()
	for i in ids.size():
		design.parts.append(KartDesign.grid_entry(ids[i], Vector3i(i * 3, 0, 0), i % 4))
	check(KartDesign.from_dict(design.to_dict()).to_dict() == design.to_dict(), "the new slopes, blocks and wedges keep their IDs and placements through saving")


func _catalogue_compatibility() -> void:
	var tile := KartDesign.grid_entry("tile_2x4", Vector3i.ZERO, 0)
	var above := KartDesign.grid_entry("brick_1x1", Vector3i(0, 1, 0), 0)
	var old_tile := KartDesign.new()
	old_tile.parts.assign([tile, above])
	var again := KartDesign.from_dict(old_tile.to_dict())
	check(again.parts[0].id == "tile_2x4" and again.groups().size() == 1 and old_tile.to_dict() == again.to_dict(), "a saved legacy tile keeps its ID, placement and original top connection through loading and copying")
	var smooth := KartDesign.placed_entry("p_tile_2x4", tile.place)
	check(not KartDesign.joined(smooth, above) and Connectors.of(smooth.id).all(func(c): return c.type == "socket"), "the offered 2×4 tile has only bottom sockets and cannot hold a brick on top")
	check(not PartCatalog.in_garage().has(tile.id) and PartCatalog.in_garage().has(smooth.id), "new builds get the smooth 2×4 tile from the drawer")
	var kept := true
	for id in ["plate_6x10", "plate_6x12"]:
		var plate := KartDesign.grid_entry(id, Vector3i(7, 2, 7), 0)
		var wheel := KartDesign.grid_entry("wheel_small", Vector3i(6, 0, 8), 0)
		var design := KartDesign.new()
		design.parts.assign([plate, wheel])
		var loaded := KartDesign.from_dict(design.to_dict())
		var generated: String = "p_" + id
		kept = kept and loaded.parts[0].id == id and loaded.groups().size() == 1 and design.to_dict() == loaded.to_dict()
		kept = kept and PartCatalog.in_garage().has(id) and PartCatalog.in_garage().has(generated)
		kept = kept and "side mounts" in PartCatalog.get_part(id).name
		kept = kept and Connectors.of(id).any(func(c): return c.type == "side") and not Connectors.of(generated).any(func(c): return c.type == "side")
		kept = kept and PartCatalog.get_part(id).mass == PartCatalog.get_part(generated).mass and PartCatalog.get_part(id).strength == PartCatalog.get_part(generated).strength
	check(kept, "both chassis sizes retain their saved side connections and remain available with side-mount labels beside the generated plates")
