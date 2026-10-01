extends SceneTree

## Tries every power-up on the test track and checks it does what it says,
## that a kart holds two at most, that the boxes hand them out, and that the
## karts at the back get the strong ones more often.
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

	## The starter kart as it was built on the stud grid, before parts had
	## their own connectors, so a ram plate goes on where its front bricks were.
	const OLD_STARTER := "res://tests/data/old_starter.json"

	## The starter kart holding these power-ups, at this spot facing -Z, with
	## a ram plate on the front if asked.
	func kart_with(powerups: Array, at: Vector3, ram := false) -> Kart:
		var design := KartDesign.load_file(OLD_STARTER)
		if ram:
			design.parts = design.parts.filter(func(p): return p.id != "brick_1x6")
			design.parts.append({ "id": "ram_plate", "at": Vector3i(7, 3, 7), "rot": 0 })
		check(design.problems().is_empty(), "a kart like that is fine %s" % [design.problems()])
		var kart := Kart.new()
		kart.build(design)
		kart.transform = Transform3D(Basis.IDENTITY, at)
		add_child(kart)
		for kind in powerups:
			kart.give(kind)
		return kart

	func _ready() -> void:
		add_child(TestTrack.new())

		# Two at most.
		var holder := Kart.new()
		holder.build(KartDesign.load_file(OLD_STARTER))
		check(holder.give("turbo") and holder.give("shield"), "a kart can hold two power-ups")
		check(not holder.give("oil") and holder.full(), "but not a third")
		holder.free()

		karts.turbo = kart_with(["turbo"], Vector3(-80, 0.05, 100))
		karts.plain = kart_with([], Vector3(-70, 0.05, 100))
		karts.spring = kart_with(["spring"], Vector3(-60, 0.05, 100))
		karts.gunner = kart_with(["cannon", "shield"], Vector3(-40, 0.05, 100))
		karts.target = kart_with([], Vector3(-40, 0.05, 88))
		karts.shielded = kart_with(["shield"], Vector3(-20, 0.05, 88))
		karts.gunner2 = kart_with(["cannon"], Vector3(-20, 0.05, 100))
		karts.dropper = kart_with(["dropper", "repair"], Vector3(0, 0.05, 100))
		karts.triple = kart_with(["triple_turbo"], Vector3(20, 0.05, 100))
		karts.rammer = kart_with([], Vector3(40, 0.05, 110), true)
		karts.rammed = kart_with([], Vector3(40, 0.05, 92))
		karts.bumper = kart_with([], Vector3(60, 0.05, 110))
		karts.bumped = kart_with([], Vector3(60, 0.05, 92))
		karts.big_turbo = kart_with(["big_turbo"], Vector3(80, 0.05, 100))
		karts.super_spring = kart_with(["super_spring"], Vector3(-60, 0.05, 80))
		karts.oiler = kart_with(["oil"], Vector3(100, 0.05, 100))
		karts.slider = kart_with([], Vector3(120, 0.05, 60))
		karts.gripper = kart_with([], Vector3(130, 0.05, 60))
		karts.homer = kart_with(["homing"], Vector3(-100, 0.05, 60))
		karts.hunted = kart_with([], Vector3(-92, 0.05, 36))
		karts.ghost = kart_with(["ghost"], Vector3(-120, 0.05, 20))
		karts.in_the_way = kart_with([], Vector3(-120, 0.05, 12))
		karts.zapped = kart_with([], Vector3(-100, 0.05, 115))
		karts.unzapped = kart_with([], Vector3(-110, 0.05, 115))

		steps = [_start, _turbo, _turbo_check, _others, _springs_check, _others_check, _repair_check, _ram_check, _oil, _oil_check, _ghost, _ghost_check, _boxes]

	func _start() -> int:
		for kart in [karts.turbo, karts.plain, karts.rammer, karts.bumper, karts.zapped, karts.unzapped]:
			kart.controls.throttle = 1.0
		return 90

	func _turbo() -> int:
		check(karts.turbo.use_gadget(0), "a turbo can be used")
		check(karts.turbo.held[0] == "" and not karts.turbo.use_gadget(0), "and then it's gone")
		# Both steer a little while the turbo's on, and neither should spin.
		for kart in [karts.turbo, karts.plain]:
			kart.controls.steer = 0.15
			kart.set_meta("heading", kart.global_basis.z)
		karts.zapped.zap()
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
		var slowed: float = karts.zapped.forward_speed
		var normal: float = karts.unzapped.forward_speed
		check(slowed < normal - 2.0, "lightning slows a kart right down (%.1f against %.1f m/s)" % [slowed, normal])
		for kart in [karts.turbo, karts.plain, karts.zapped, karts.unzapped]:
			kart.controls.throttle = 0.0
			kart.controls.brake = 1.0
		return 1

	func _others() -> int:
		for name in ["spring", "gunner", "shielded", "gunner2", "dropper", "super_spring", "big_turbo", "homer"]:
			karts[name].use_gadget(0)
		# The homing brick goes after the kart ahead and off to one side.
		for shot in get_children().filter(func(n): return n is BrickShot and n.shooter == karts.homer):
			shot.chasing = karts.hunted
		for go in 3:
			check(karts.triple.use_gadget(0), "a triple turbo fires (%d of 3)" % (go + 1))
			karts.triple._gadget_wait[0] = 0.0
		check(karts.triple.held[0] == "", "three times, then it's gone")
		return 20

	func _springs_check() -> int:
		check(karts.spring.global_position.y > 0.7, "a spring hops the kart up (%.2f m)" % karts.spring.global_position.y)
		check(karts.super_spring.global_position.y > karts.spring.global_position.y + 0.3, "a super spring hops it higher (%.2f m)" % karts.super_spring.global_position.y)
		return 40

	func _others_check() -> int:
		check(karts.big_turbo.boost_left > 0.0, "a big turbo lasts longer than a plain one (%.1f s left)" % karts.big_turbo.boost_left)
		check(karts.target.lost.size() >= 1, "a cannon brick knocks a part off the kart it hits (%d lost)" % karts.target.lost.size())
		check(karts.shielded.lost.is_empty(), "but not off a kart with its shield up")
		check(karts.hunted.lost.size() >= 1, "a homing brick turns and finds a kart off to one side (%d lost)" % karts.hunted.lost.size())
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
		return 150

	func _ram_check() -> int:
		check(karts.rammed.lost.size() > karts.bumped.lost.size(), "a ram plate knocks off more than a plain bumper (%d against %d)" % [karts.rammed.lost.size(), karts.bumped.lost.size()])
		check(karts.rammer.lost.is_empty() or karts.rammer.lost.size() < karts.rammed.lost.size(), "and the rammer comes off better")
		return 0

	## Oil leaves a slick behind the kart. Then one kart slides sideways across
	## a slick while another does the same on the ground beside it.
	func _oil() -> int:
		check(karts.oiler.use_gadget(0), "oil can be used")
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

	## A ghost drives straight through a kart parked in its way.
	func _ghost() -> int:
		check(karts.ghost.use_gadget(0) and karts.ghost.ghost_left > 0.0, "a ghost can be used")
		karts.ghost.linear_velocity = Vector3(0.0, 0.0, -10.0)
		karts.ghost.controls.throttle = 1.0
		return 60

	func _ghost_check() -> int:
		check(karts.ghost.global_position.z < karts.in_the_way.global_position.z - 3.0, "and goes right through a kart in the way (%.1f m past it)" % (karts.in_the_way.global_position.z - karts.ghost.global_position.z))
		check(karts.ghost.lost.is_empty() and karts.in_the_way.lost.is_empty(), "without knocking anything off either of them")
		return 0

	## The boxes, and what they hand out.
	func _boxes() -> int:
		var line := TrackPath.from_dict({ "pieces": [{ "type": "straight", "length": 30 }] })
		line.start = Transform3D(Basis.IDENTITY, Vector3(200.0, 0.0, 0.0))
		line.build()
		var field := PowerupField.new(line)
		add_child(field)
		check(field.spots.size() >= 3, "there are rows of boxes along the road (%d)" % field.spots.size())
		var picker := kart_with([], field.spots[0].origin - Vector3(0.0, 0.7, 0.0))
		var got := field.collect(picker)
		check(got != "" and picker.held[0] == got, "driving through a box gives you a power-up (%s)" % got)
		check(field.collect(picker) == "", "and that box is gone for you until it comes back")
		var full := kart_with(["turbo", "shield"], field.spots[1].origin - Vector3(0.0, 0.7, 0.0))
		check(field.collect(full) == "", "a kart with both buttons full leaves the box")

		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var leader := {}
		var last := {}
		for n in 2000:
			var a := Powerups.pick(1, 8, rng)
			var b := Powerups.pick(8, 8, rng)
			leader[a] = leader.get(a, 0) + 1
			last[b] = last.get(b, 0) + 1
		check(not leader.has("lightning") and last.get("lightning", 0) > 100, "the leader never gets lightning and last place often does (%d)" % last.get("lightning", 0))
		check(leader.get("oil", 0) + leader.get("dropper", 0) > last.get("oil", 0) + last.get("dropper", 0) + 300, "and the leader gets more oil and bricks")
		var strong := func(counts: Dictionary) -> int: return counts.get("big_turbo", 0) + counts.get("triple_turbo", 0)
		check(strong.call(last) > strong.call(leader) + 300, "while last place gets more big and triple turbos (%d against %d)" % [strong.call(last), strong.call(leader)])
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
