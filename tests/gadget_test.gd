extends SceneTree

## Tries every gadget on the test track and checks it does what it says, and
## that studs pay for them.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/gadget_test.gd


class Runner:
	extends Node

	var failures := 0
	var tick := 0
	var steps: Array[Callable] = []
	var wait := 0
	var karts := {}

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	## The starter kart with these gadgets on it, at this spot facing -Z.
	func kart_with(gadgets: Array, at: Vector3, swap_bumper := false) -> Kart:
		var design := KartDesign.load_file("res://data/karts/stock/starter.json")
		# The starter comes with a turbo, so clear it and each kart only has the
		# gadgets being tried.
		design.parts = design.parts.filter(func(p): return PartCatalog.get_part(p.id).kind != "gadget")
		if swap_bumper:
			design.parts = design.parts.filter(func(p): return p.id != "brick_1x6")
		var spots := [Vector3i(7, 3, 10), Vector3i(11, 3, 10)]
		for i in gadgets.size():
			var at_cell: Vector3i = Vector3i(7, 3, 7) if gadgets[i] == "ram_plate" else spots[i]
			design.parts.append({ "id": gadgets[i], "at": at_cell, "rot": 0 })
		check(design.problems().is_empty(), "a kart with %s is fine %s" % [gadgets, design.problems()])
		var kart := Kart.new()
		kart.build(design)
		kart.transform = Transform3D(Basis.IDENTITY, at)
		add_child(kart)
		return kart

	func _ready() -> void:
		add_child(TestTrack.new())

		# Too many gadgets.
		var three := KartDesign.load_file("res://data/karts/stock/starter.json")
		three.parts = three.parts.filter(func(p): return p.id != "turbo")
		for spot in [Vector3i(7, 3, 10), Vector3i(11, 3, 10), Vector3i(9, 6, 11)]:
			three.parts.append({ "id": "turbo", "at": spot, "rot": 0 })
		check(three.problems().has("Only two gadgets fit on a kart."), "a third gadget is one too many")

		karts.turbo = kart_with(["turbo"], Vector3(-80, 0.05, 100))
		karts.plain = kart_with([], Vector3(-70, 0.05, 100))
		karts.spring = kart_with(["spring"], Vector3(-60, 0.05, 100))
		karts.gunner = kart_with(["brick_cannon", "shield"], Vector3(-40, 0.05, 100))
		karts.target = kart_with([], Vector3(-40, 0.05, 88))
		karts.shielded = kart_with(["shield"], Vector3(-20, 0.05, 88))
		karts.gunner2 = kart_with(["brick_cannon"], Vector3(-20, 0.05, 100))
		karts.dropper = kart_with(["brick_dropper", "repair_kit"], Vector3(0, 0.05, 100))
		karts.magnet = kart_with(["magnet"], Vector3(20, 0.05, 100))
		karts.rammer = kart_with(["ram_plate"], Vector3(40, 0.05, 110), true)
		karts.rammed = kart_with([], Vector3(40, 0.05, 92))
		karts.bumper = kart_with([], Vector3(60, 0.05, 110))
		karts.bumped = kart_with([], Vector3(60, 0.05, 92))
		karts.big_turbo = kart_with(["big_turbo"], Vector3(80, 0.05, 100))
		karts.super_spring = kart_with(["super_spring"], Vector3(-60, 0.05, 80))
		karts.oiler = kart_with(["oil_can"], Vector3(100, 0.05, 100))
		karts.slider = kart_with([], Vector3(120, 0.05, 60))
		karts.gripper = kart_with([], Vector3(130, 0.05, 60))

		steps = [_start, _turbo, _turbo_check, _others, _others_check, _repair_check, _ram_check, _oil, _oil_check]

	func _start() -> int:
		for kart in [karts.turbo, karts.plain]:
			kart.controls.throttle = 1.0
		karts.rammer.controls.throttle = 1.0
		karts.bumper.controls.throttle = 1.0
		return 90

	func _turbo() -> int:
		check(not karts.turbo.use_gadget(0), "a turbo can't be used with no studs")
		karts.turbo.add_studs(5)
		check(karts.turbo.use_gadget(0), "and can with enough")
		check(karts.turbo.studs == 2, "which costs its three studs (%d left)" % karts.turbo.studs)
		# Both steer a little while the turbo's on. The turbo used to push
		# through the back wheels and use up all their grip, so this spun it.
		for kart in [karts.turbo, karts.plain]:
			kart.controls.steer = 0.15
			kart.set_meta("heading", kart.global_basis.z)
		return 90

	func _turbo_check() -> int:
		var boosted: float = karts.turbo.forward_speed
		var plain: float = karts.plain.forward_speed
		check(boosted > plain + 1.5, "the turbo kart pulls ahead (%.1f against %.1f m/s)" % [boosted, plain])
		var turned := []
		for kart in [karts.turbo, karts.plain]:
			turned.append(rad_to_deg(absf(kart.get_meta("heading").signed_angle_to(kart.global_basis.z, Vector3.UP))))
			kart.controls.steer = 0.0
		check(turned[0] < turned[1] * 1.5 + 5.0, "a light steer with the turbo on turns it about as much as without (%.0f against %.0f degrees)" % turned)
		for kart in [karts.turbo, karts.plain]:
			kart.controls.throttle = 0.0
			kart.controls.brake = 1.0
		return 1

	func _others() -> int:
		karts.spring.add_studs(10)
		karts.spring.use_gadget(0)
		karts.gunner.add_studs(10)
		karts.gunner.use_gadget(0)
		karts.shielded.add_studs(10)
		karts.shielded.use_gadget(0)
		karts.gunner2.add_studs(10)
		karts.gunner2.use_gadget(0)
		karts.dropper.add_studs(10)
		karts.dropper.use_gadget(0)
		karts.super_spring.add_studs(10)
		karts.super_spring.use_gadget(0)
		karts.big_turbo.add_studs(10)
		karts.big_turbo.use_gadget(0)
		return 20

	func _others_check() -> int:
		check(karts.spring.global_position.y > 0.7, "a spring hops the kart up (%.2f m)" % karts.spring.global_position.y)
		check(karts.super_spring.global_position.y > karts.spring.global_position.y + 0.3, "a super spring hops it higher (%.2f m)" % karts.super_spring.global_position.y)
		check(karts.big_turbo.boost_left > Kart.TURBO_TIME, "a big turbo lasts longer than a plain one (%.1f s left)" % karts.big_turbo.boost_left)
		check(karts.target.lost.size() >= 1, "a cannon brick knocks a part off the kart it hits (%d lost)" % karts.target.lost.size())
		check(karts.shielded.lost.is_empty(), "but not off a kart with its shield up")
		var piles := get_children().filter(func(n): return n is BrickPile).size()
		check(piles == 3, "a brick dropper leaves three bricks behind (%d)" % piles)
		var one: Array[int] = [5, 6]
		karts.dropper.lose_parts(one)
		check(karts.dropper.lost.size() >= 2, "the dropper loses a couple of parts")
		karts.dropper.use_gadget(1)
		return 5

	func _repair_check() -> int:
		check(karts.dropper.lost.is_empty(), "a repair kit puts them back")
		check(karts.dropper.slowdown_left == 0.0, "without the reset slowdown")

		# For the magnet, put a stud on a short straight track four metres off
		# to the side.
		var line := TrackPath.from_dict({ "pieces": [{ "type": "straight", "length": 20 }] })
		line.start = Transform3D(Basis.IDENTITY, Vector3(200.0, 0.0, 0.0))
		line.build()
		var field := StudField.new(line)
		add_child(field)
		var spot: Transform3D = field.spots[0]
		karts.magnet.global_position = spot.origin + Vector3(4.0, -0.7, 0.0)
		karts.plain.global_position = spot.origin + Vector3(-4.0, -0.7, 0.0)
		check(field.collect(karts.plain) == 0, "without a magnet a stud four metres away stays put")
		check(field.collect(karts.magnet) >= 1, "a magnet picks it up")
		return 150

	func _ram_check() -> int:
		check(karts.rammed.lost.size() > karts.bumped.lost.size(), "a ram plate knocks off more than a plain bumper (%d against %d)" % [karts.rammed.lost.size(), karts.bumped.lost.size()])
		check(karts.rammer.lost.is_empty() or karts.rammer.lost.size() < karts.rammed.lost.size(), "and the rammer comes off better")
		return 0

	## An oil can leaves a slick behind the kart. Then one kart slides
	## sideways across a slick while another does the same on the ground
	## beside it.
	func _oil() -> int:
		karts.oiler.add_studs(10)
		check(karts.oiler.use_gadget(0), "an oil can can be used")
		var slicks := get_children().filter(func(n): return n is OilSlick)
		check(slicks.size() == 1 and slicks[0].global_position.z > karts.oiler.global_position.z, "and leaves a slick behind the kart")
		var slick := OilSlick.new()
		add_child(slick)
		slick.global_position = Vector3(120, 0.03, 60)
		for kart in [karts.slider, karts.gripper]:
			kart.linear_velocity = Vector3(6.0, 0.0, 0.0)
		return 30

	func _oil_check() -> int:
		var slid: float = karts.slider.linear_velocity.x
		var gripped: float = karts.gripper.linear_velocity.x
		check(slid > gripped + 1.5, "a kart on oil keeps sliding where one off it grips (%.1f against %.1f m/s)" % [slid, gripped])
		return 0

	func _physics_process(_delta: float) -> void:
		tick += 1
		if tick < 30:
			return
		if wait > 0:
			wait -= 1
			return
		if steps.is_empty():
			print("All gadget checks passed." if failures == 0 else "%d gadget checks failed." % failures)
			get_tree().quit(1 if failures > 0 else 0)
			return
		var step: Callable = steps.pop_front()
		wait = step.call()


func _initialize() -> void:
	root.add_child(Runner.new())
