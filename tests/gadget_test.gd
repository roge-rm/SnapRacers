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
		check(not holder.give("marbles") and holder.full(), "but not a third")
		holder.free()

		karts.turbo = kart_with(["turbo"], Vector3(-80, 0.05, 100))
		karts.plain = kart_with([], Vector3(-70, 0.05, 100))
		karts.tower = kart_with(["tow"], Vector3(-60, 0.05, 100))
		karts.towed = kart_with([], Vector3(-60, 0.05, 50))
		karts.lone_tower = kart_with(["tow"], Vector3(-115, 0.05, -100))
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
		karts.waller = kart_with(["wall"], Vector3(100, 0.05, -60))
		karts.wall_hitter = kart_with([], Vector3(85, 0.05, -40))
		karts.shocked = kart_with([], Vector3(-100, 0.05, -60))
		karts.shocked_far = kart_with([], Vector3(-100, 0.05, -80))
		karts.shocked_shielded = kart_with(["shield"], Vector3(-95, 0.05, -60))
		karts.spiker = kart_with(["spikes"], Vector3(60, 0.05, -110))
		karts.spiked = kart_with([], Vector3(100, 0.05, -10))
		karts.unspiked = kart_with([], Vector3(115, 0.05, -10))
		karts.marbler = kart_with(["marbles"], Vector3(100, 0.05, 100))
		karts.slider = kart_with([], Vector3(120, 0.05, 60))
		karts.gripper = kart_with([], Vector3(130, 0.05, 60))
		karts.homer = kart_with(["homing"], Vector3(-100, 0.05, 60))
		karts.hunted = kart_with([], Vector3(-92, 0.05, 36))
		karts.ghost = kart_with(["ghost"], Vector3(-120, 0.05, 20))
		karts.in_the_way = kart_with([], Vector3(-120, 0.05, 12))
		karts.zapped = kart_with([], Vector3(-100, 0.05, 115))
		karts.unzapped = kart_with([], Vector3(-110, 0.05, 115))
		karts.zap_blocked = kart_with(["shield"], Vector3(-90, 0.05, 115))
		karts.popped = kart_with([], Vector3(107.5, 0.05, -10))

		steps = [_start, _turbo, _turbo_check, _others, _tow_check, _others_check, _repair_check, _ram_check, _marbles, _marbles_check, _wall, _wall_check, _shockwave, _shockwave_check, _spikes, _spikes_check, _spike_pops, _spike_pops_check, _blasts, _blasts_check, _drop_looks, _ghost, _ghost_check, _tow_targets, _boxes]

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
		check(Kart.ZAP_TIME >= 5.0, "lightning lasts five seconds (%.1f)" % Kart.ZAP_TIME)
		check(karts.zapped.zapped_left > 4.5, "and starts with that time left (%.1f)" % karts.zapped.zapped_left)
		var bolts: Array = karts.zapped.get_children().filter(func(n): return n is ZapFx)
		check(bolts.size() == 1 and bolts[0].visible, "with a bolt on the kart")
		karts.zap_blocked.shield_left = Kart.SHIELD_TIME
		karts.zap_blocked.zap()
		check(karts.zap_blocked.zapped_left <= 0.0, "a shield stops the lightning")
		check(karts.zap_blocked.get_children().filter(func(n): return n is ZapFx).is_empty(), "and no bolt shows")
		karts.zap_blocked.shield_left = 0.0
		karts.zap_blocked.zap()
		check(karts.zap_blocked.use_gadget(0), "a struck kart can put its shield up")
		check(karts.zap_blocked.zapped_left <= 0.0, "a shield put up after a strike ends the slowdown")
		check(karts.zap_blocked.get_children().filter(func(n): return n is ZapFx and not n.is_queued_for_deletion()).is_empty(), "and the bolt")
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
		check(karts.zapped.zapped_left > 3.0, "and it's still going after a second and a half (%.1f left)" % karts.zapped.zapped_left)
		check(karts.zapped.get_children().filter(func(n): return n is ZapFx).size() == 1, "with the bolt still on")
		for kart in [karts.turbo, karts.plain, karts.zapped, karts.unzapped]:
			kart.controls.throttle = 0.0
			kart.controls.brake = 1.0
		return 1

	func _others() -> int:
		karts.target.set_meta("was", karts.target.global_position)
		karts.shielded.set_meta("was", karts.shielded.global_position)
		for name in ["gunner", "shielded", "gunner2", "dropper", "big_turbo", "homer"]:
			karts[name].use_gadget(0)
		# A tow rope onto the kart ahead. Here there's no race to say who's
		# ahead, so the rope's thrown by hand, and one used with nobody in
		# reach is a turbo instead.
		var rope := TowRope.throw(karts.tower, karts.towed)
		add_child(rope)
		karts.tower.set_meta("start_z", karts.tower.global_position.z)
		check(karts.lone_tower.use_gadget(0) and karts.lone_tower.boost_left > 0.0, "a tow rope with nobody in reach is a turbo")
		# The homing brick goes after the kart ahead and off to one side.
		for shot in get_children().filter(func(n): return n is BrickShot and n.shooter == karts.homer):
			shot.chasing = karts.hunted
		for go in 3:
			check(karts.triple.use_gadget(0), "a triple turbo fires (%d of 3)" % (go + 1))
			karts.triple._gadget_wait[0] = 0.0
		check(karts.triple.held[0] == "", "three times, then it's gone")
		return 20

	func _tow_check() -> int:
		var pulled: float = karts.tower.get_meta("start_z") - karts.tower.global_position.z
		check(pulled > 0.3 and karts.tower.tow != null, "a tow rope pulls the kart towards the one ahead (%.1f m)" % pulled)
		return 40

	func _others_check() -> int:
		check(karts.big_turbo.boost_left > 0.0, "a big turbo lasts longer than a plain one (%.1f s left)" % karts.big_turbo.boost_left)
		check(Kart.CANNON_PARTS >= 3, "a cannonball knocks several parts off (%d)" % Kart.CANNON_PARTS)
		check(Kart.CANNON_WHEEL_CHANCE >= 0.5, "and often a wheel (chance %.2f)" % Kart.CANNON_WHEEL_CHANCE)
		check(karts.target.lost.size() >= Kart.CANNON_PARTS, "a cannonball knocks several parts off the kart it hits (%d lost)" % karts.target.lost.size())
		var shoved: float = karts.target.get_meta("was").distance_to(karts.target.global_position)
		check(shoved > 2.0, "and shoves it (%.1f m)" % shoved)
		check(karts.shielded.lost.is_empty(), "but not off a kart with its shield up")
		var shielded_shove: float = karts.shielded.get_meta("was").distance_to(karts.shielded.global_position)
		check(shielded_shove > 2.0, "though the shield still gets shoved (%.1f m)" % shielded_shove)
		check(karts.hunted.lost.size() >= 1, "a homing brick turns and finds a kart off to one side (%d lost)" % karts.hunted.lost.size())
		var piles := get_children().filter(func(n): return n is BrickPile).size()
		check(piles == BrickPile.DROP.size(), "a brick dropper leaves a pile of bricks behind (%d)" % piles)
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

	## Marbles are scattered behind the kart. Then one kart slides sideways across
	## them while another does the same on the ground beside it.
	func _marbles() -> int:
		check(karts.marbler.use_gadget(0), "marbles can be used")
		var traps := get_children().filter(func(n): return n is BrickTrap)
		check(traps.size() == 1 and traps[0].global_position.z > karts.marbler.global_position.z, "and scatters them behind the kart")
		var trap := BrickTrap.new()
		add_child(trap)
		trap.global_position = Vector3(120, 0.03, 60)
		for kart in [karts.slider, karts.gripper]:
			kart.linear_velocity = Vector3(6.0, 0.0, 0.0)
		return 30

	func _marbles_check() -> int:
		var slid: float = karts.slider.linear_velocity.x
		var gripped: float = karts.gripper.linear_velocity.x
		check(slid > gripped + 1.5, "a kart on marbles keeps sliding where one off it grips (%.1f against %.1f m/s)" % [slid, gripped])
		return 0

	## A brick wall goes down behind a kart, and a kart driving into it sets
	## the bricks tumbling.
	func _wall() -> int:
		check(karts.waller.use_gadget(0), "a brick wall can be used")
		var walls := get_children().filter(func(n): return n is BrickWall)
		check(walls.size() == 1 and walls[0].global_position.z > karts.waller.global_position.z, "and goes down behind the kart")
		karts.wall_hitter.global_position = walls[0].global_position + Vector3(0.0, 0.05, 12.0)
		karts.wall_hitter.linear_velocity = Vector3(0.0, 0.0, -14.0)
		karts.wall_hitter.controls.throttle = 1.0
		return 70

	func _wall_check() -> int:
		var wall: BrickWall = get_children().filter(func(n): return n is BrickWall)[0]
		var loose: int = wall._bricks.filter(func(b): return not b.freeze).size()
		check(loose > 0, "a kart driving into it sets bricks tumbling (%d)" % loose)
		check(karts.wall_hitter.forward_speed < 12.0, "and it slows the kart down (%.1f m/s)" % karts.wall_hitter.forward_speed)
		var colours := wall_colours(wall)
		var mixed := {}
		for colour in colours:
			mixed[colour] = true
		check(mixed.size() >= 3, "the wall's bricks are a mix of colours (%d)" % mixed.size())
		var tumbled: Array = wall._bricks.filter(func(b): return not b.freeze)
		check(tumbled.all(func(b): return b.get_child(1).material_override.albedo_color == b.get_meta("colour")), "and a tumbling brick keeps its colour")
		var same := BrickWall.new()
		same.colour_seed = wall.colour_seed
		add_child(same)
		var other := BrickWall.new()
		other.colour_seed = wall.colour_seed + 1
		add_child(other)
		check(wall_colours(same) == colours, "a wall from the same drop has the same colours on every machine")
		check(wall_colours(other) != colours, "and the next drop has different ones")
		check(karts.waller.drops == 1, "the kart counts what it drops")
		same.free()
		other.free()
		karts.wall_hitter.controls.throttle = 0.0
		return 0

	func wall_colours(wall: BrickWall) -> Array:
		return wall._bricks.map(func(b): return b.get_meta("colour"))

	## A stand-in for a kart on the road, at this spot, facing this way.
	func marker(at: Vector3, facing := Vector3.FORWARD) -> Node3D:
		var spot := Node3D.new()
		add_child(spot)
		spot.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), at)
		return spot

	## A tow rope only catches a kart a few lengths ahead along the road, in
	## front and going the same way.
	func _tow_targets() -> int:
		var from := marker(Vector3(300, 0, 0))
		var length := 500.0
		var at := 100.0
		var beside := {"kart": marker(Vector3(303, 0, 0)), "offset": at}
		var behind := {"kart": marker(Vector3(300, 0, 10)), "offset": at - 10.0}
		var close := {"kart": marker(Vector3(300, 0, -4)), "offset": at + 4.0}
		var far := {"kart": marker(Vector3(300, 0, -20)), "offset": at + 20.0}
		var further := {"kart": marker(Vector3(300, 0, -30)), "offset": at + 30.0}
		var out_of_reach := {"kart": marker(Vector3(300, 0, -70)), "offset": at + 70.0}
		# Across a hairpin, 15 m off to the side, going the other way, but
		# 50 m ahead along the road.
		var hairpin := {"kart": marker(Vector3(315, 0, -2), Vector3.BACK), "offset": at + 50.0}
		check(TowRope.NEAREST >= 5.0 and TowRope.NEAREST <= 8.0, "the rope needs a kart two or three lengths ahead (%.0f m)" % TowRope.NEAREST)
		check(TowRope.pick(from, at, [beside, behind, close], length) == null, "a tow rope doesn't catch a kart beside, behind or just ahead")
		check(TowRope.pick(from, at, [beside, further, far, close], length) == far.kart, "it catches the nearest kart far enough ahead")
		check(TowRope.pick(from, at, [out_of_reach], length) == null, "but not one out of reach")
		check(TowRope.pick(from, at, [hairpin], length) == null, "or one across a hairpin")
		# Just behind the line, with the kart ahead just over it, which counts
		# whatever lap either is on.
		check(TowRope.pick(from, length - 5.0, [{"kart": far.kart, "offset": 15.0}], length) == far.kart, "it catches a kart ahead over the finish line")
		check(TowRope.pick(from, 10.0, [{"kart": behind.kart, "offset": length - 5.0}], length) == null, "and not one behind over the line")
		# Two the same distance ahead go to the first one listed.
		var twin := {"kart": marker(Vector3(301, 0, -20)), "offset": at + 20.0}
		check(TowRope.pick(from, at, [twin, far], length) == twin.kart and TowRope.pick(from, at, [far, twin], length) == far.kart, "and a tie goes the same way every time")
		check(TowRope.target(karts.tower) == null, "with no race around there's nothing to catch")
		for node in get_children().filter(func(n): return n.get_class() == "Node3D" and n.get_script() == null):
			node.queue_free()
		return 1

	## A shockwave shoves the karts near it away, and knocks parts off one
	## close by, unless its shield's up.
	func _shockwave() -> int:
		var at: Vector3 = karts.shocked.global_position + Vector3(2.5, 0.0, 0.0)
		for kart in [karts.shocked, karts.shocked_far, karts.shocked_shielded]:
			kart.set_meta("was", kart.global_position)
		karts.shocked_shielded.use_gadget(0)
		karts.shocked.shoved_from(at)
		karts.shocked_far.shoved_from(at)
		karts.shocked_shielded.shoved_from(at)
		return 20

	func _shockwave_check() -> int:
		var moved: float = karts.shocked.get_meta("was").x - karts.shocked.global_position.x
		check(moved > 2.0, "a shockwave shoves a kart beside it away (%.1f m)" % moved)
		check(karts.shocked.lost.size() >= 1, "and knocks a part off it, being so close (%d)" % karts.shocked.lost.size())
		check(karts.shocked_shielded.lost.is_empty(), "but not off a kart with its shield up")
		var far_moved: float = karts.shocked_far.global_position.distance_to(karts.shocked_far.get_meta("was"))
		check(far_moved < 0.05, "and a kart out of reach isn't touched (%.2f m)" % far_moved)
		return 0

	## Glue leaves a sticky patch that slows a kart driving over it, without
	## spinning it.
	func _spikes() -> int:
		check(karts.spiker.use_gadget(0), "a spike trap can be used")
		var patch := BrickTrap.new("spikes")
		add_child(patch)
		patch.global_position = Vector3(100, 0.03, -16)
		Kart.spike_pop_chance = 0.0
		for kart in [karts.spiked, karts.unspiked]:
			kart.linear_velocity = Vector3(0.0, 0.0, -14.0)
			kart.set_meta("heading", kart.global_basis.z)
		return 50

	func _spikes_check() -> int:
		var stuck: float = karts.spiked.forward_speed
		var free: float = karts.unspiked.forward_speed
		check(stuck < free - 1.5, "a kart over spikes is slowed (%.1f against %.1f m/s)" % [stuck, free])
		var turned := rad_to_deg(absf(karts.spiked.get_meta("heading").signed_angle_to(karts.spiked.global_basis.z, Vector3.UP)))
		check(turned < 10.0, "without being spun round (%.0f degrees)" % turned)
		return 0

	## Spikes hit fast pop the first tire that runs over them and nothing else.
	func _spike_pops() -> int:
		var patch := BrickTrap.new("spikes")
		add_child(patch)
		patch.global_position = Vector3(107.5, 0.03, -16)
		Kart.spike_pop_chance = 1.0
		karts.popped.linear_velocity = Vector3(0.0, 0.0, -14.0)
		return 50

	func _spike_pops_check() -> int:
		Kart.spike_pop_chance = 0.9
		var wheels := 0
		var others := 0
		for i in karts.popped.lost:
			if PartCatalog.get_part(karts.popped.design.parts[i].id).get("kind", "") == "wheel":
				wheels += 1
			else:
				others += 1
		check(wheels == 1 and karts.unspiked.lost.is_empty(), "spikes pop one tire of a kart that hits them fast (%d popped)" % wheels)
		check(others == 0, "and take nothing else (%d other parts)" % others)
		return 0

	## A shockwave and a cannonball throw dropped bricks about and knock walls
	## down.
	func _blasts() -> int:
		var shocked := BrickWall.new()
		add_child(shocked)
		shocked.global_position = Vector3(-40, 0.0, -100)
		var pile := BrickPile.new()
		add_child(pile)
		pile.global_position = Vector3(-37, 0.3, -100)
		var shot_at := BrickWall.new()
		add_child(shot_at)
		shot_at.global_position = Vector3(0, 0.0, -100)
		karts.blasts = [shocked, pile, shot_at]
		BrickPile.blast(get_tree(), Vector3(-40, 0.0, -96), Kart.SHOCK_REACH, BrickPile.SHOCK_SPEED)
		var ball := BrickShot.new()
		ball._dress()
		add_child(ball)
		ball.global_position = Vector3(0, 0.6, -94)
		ball.linear_velocity = Vector3(0, 0, -BrickShot.SPEED)
		return 30

	func _blasts_check() -> int:
		var shocked: BrickWall = karts.blasts[0]
		var pile: BrickPile = karts.blasts[1]
		var shot_at: BrickWall = karts.blasts[2]
		var loose: int = shocked.bricks().filter(func(b): return not b.freeze).size()
		check(not shocked.standing(), "a shockwave knocks a whole wall down nearby (%d of %d loose)" % [loose, shocked.bricks().size()])
		check(pile.global_position.distance_to(Vector3(-37, 0.3, -100)) > 1.0, "and throws dropped bricks about")
		var hit: int = shot_at.bricks().filter(func(b): return not b.freeze).size()
		check(hit >= 6, "a cannonball blasts a wall apart (%d of %d loose)" % [hit, shot_at.bricks().size()])
		for node in karts.blasts:
			node.queue_free()
		return 1

	## Each drop of bricks has its own sizes and colours, the same on every
	## machine.
	func _drop_looks() -> int:
		var looks := func(pile: Array[BrickPile]) -> Array:
			var out := []
			for brick in pile:
				out.append([(brick.get_child(0).shape as BoxShape3D).size, brick.get_child(1).material_override.albedo_color])
				brick.free()
			return out
		var kart: Kart = karts.plain
		kart.drops = 5
		var first: Array = looks.call(BrickPile.drop_behind(kart))
		var next: Array = looks.call(BrickPile.drop_behind(kart))
		kart.drops = 5
		var again: Array = looks.call(BrickPile.drop_behind(kart))
		check(first != next, "each drop of bricks looks different")
		check(first == again, "and the same drop looks the same on every machine")
		var sizes := {}
		for each in first + next:
			sizes[each[0]] = true
		check(sizes.size() >= 4, "with a mix of sizes (%d)" % sizes.size())
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
		check(leader.get("marbles", 0) + leader.get("dropper", 0) > last.get("marbles", 0) + last.get("dropper", 0) + 300, "and the leader gets more marbles and bricks")
		var strong := func(counts: Dictionary) -> int: return counts.get("big_turbo", 0) + counts.get("triple_turbo", 0)
		check(strong.call(last) > strong.call(leader) + 300, "while last place gets more big and triple turbos (%d against %d)" % [strong.call(last), strong.call(leader)])
		check(last.get("tow", 0) > leader.get("tow", 0) + 200 and leader.get("wall", 0) + leader.get("spikes", 0) > last.get("wall", 0) + last.get("spikes", 0) + 300, "tow ropes go to the back, and walls and spikes to the front")
		check(not leader.has("spring") and not last.has("spring"), "and there are no springs any more")
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
