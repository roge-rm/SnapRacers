extends SceneTree

## Rides the stock Superbike and Tourer on the test track with no screen. The bike has to stay upright on its own, standing still,
## through a slalom and in a hard turn, and lean into the bends the right way.
## The trike mustn't tip over in a hard turn either. It also checks the
## building rules for two wheels.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/bike_test.gd


class Runner:
	extends Node

	var kart: Kart
	var track: TestTrack
	var tick := 0
	var failures: Array[String] = []
	var start_yaw := 0.0
	var most_roll := 0.0
	var most_lean := 0.0
	var gentle_lean := 0.0
	var gentle_bars := 0.0
	var lean_right := false
	var on_trike := false

	## A motorbike built from bits, in the fine unit, with the front wheel in a
	## fork and the back one in a swingarm, joined by a plate along the top,
	## for checking the building rules.
	static func bike() -> KartDesign:
		var design := KartDesign.new()
		design.name = "Test bike"
		for p in [
			["w_moto", Vector3(192, 0, 74)],
			["b_fork", Vector3(180, 32.4, 100)],
			["w_moto", Vector3(192, 0, 194)],
			["b_swingarm", Vector3(180, 32.4, 160)],
			["p_brick_2x2", Vector3(180, 72.4, 160)],
			["p_plate_2x10", Vector3(180, 96.4, 100)],
			["b_bars", Vector3(160, 104.4, 100)],
			["b_tank", Vector3(180, 104.4, 120)],
			["b_saddle", Vector3(180, 104.4, 160)],
			["engine_small", Vector3(180, 104.4, 220)],
		]:
			design.parts.append(KartDesign.placed_entry(p[0], Transform3D(Basis.IDENTITY, p[1])))
		return design


	func _ready() -> void:
		track = TestTrack.new()
		add_child(track)
		_ride(KartDesign.load_file("res://data/karts/stock/superbike.json"))

	func _ride(design: KartDesign) -> void:
		if kart != null:
			kart.queue_free()
		kart = Kart.new()
		kart.build(design)
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(50.0, 0.05, 120.0))
		add_child(kart)
		print("%s: %.0f kg, %d wheels, wheelbase %.2f m" % [design.name, kart.mass, kart.wheels.size(), kart.wheelbase])

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures.append(what)

	## How far it's rolled over from upright, in degrees.
	func roll() -> float:
		return rad_to_deg(acos(clampf(kart.global_basis.y.y, -1.0, 1.0)))

	func _physics_process(_delta: float) -> void:
		tick += 1
		var c := kart.controls
		if tick > 30:
			most_roll = maxf(most_roll, roll())
		if on_trike:
			_trike_ride(c)
			return
		match tick:
			1:
				var problems := bike().problems()
				check(problems.is_empty(), "the bike can race %s" % [problems])
				check(kart.upright > 0.9, "and it's held upright, being a bike (%.2f)" % kart.upright)
				var side_by_side := bike()
				side_by_side.parts[2] = KartDesign.placed_entry("w_moto", Transform3D(Basis.IDENTITY, Vector3(260, 0, 74)))
				check(side_by_side.problems().has("Two wheels have to be one behind the other."), "two wheels side by side can't race %s" % [side_by_side.problems()])
			90:
				var grounded := kart.wheels.filter(func(w): return w.grounded).size()
				check(grounded == 2, "both wheels on the ground after settling (%d)" % grounded)
				check(roll() < 3.0, "standing upright on its own (%.1f degrees)" % roll())
				# Not flat out, or it runs out of room on the test track.
				c.throttle = 0.6
			330:
				check(kart.forward_speed > 12.0, "gets up to speed (%.1f m/s)" % kart.forward_speed)
				check(absf(kart.global_position.x - 50.0) < 1.5, "rides straight (drifted %.2f m)" % (kart.global_position.x - 50.0))
				most_roll = 0.0
				# A small correction, not a turn.
				c.steer = 0.12
			331, 340, 350, 360, 370, 380, 389:
				gentle_lean = maxf(gentle_lean, absf(rad_to_deg(kart.lean)))
				gentle_bars = maxf(gentle_bars, absf(rad_to_deg(kart.shown_steer())))
			390:
				check(gentle_lean < 3.0, "a small correction hardly leans it (%.1f degrees)" % gentle_lean)
				check(gentle_bars < 4.0, "or turns the bars (%.1f degrees)" % gentle_bars)
				most_roll = 0.0
			391, 451, 511, 571:
				c.steer = 1.0 if (tick - 391) % 120 == 0 else -1.0
			631:
				check(most_roll < 8.0, "stays upright through a slalom (rolled %.1f degrees at most)" % most_roll)
				start_yaw = kart.global_rotation.y
				c.steer = 1.0
				most_roll = 0.0
			691:
				lean_right = kart.lean > 0.0 and kart.looks().basis.y.x > 0.0
				most_lean = rad_to_deg(kart.lean)
				# The fork comes with the bars, and turns with them.
				var front: Kart.Wheel = kart.wheels.filter(func(w): return w.steered)[0]
				var fork_turn: float = kart._steering._wheel.basis.z.signed_angle_to(Vector3.BACK, Vector3.UP) if kart._steering != null else 0.0
				var wheel_turn := front.visual.basis.x.signed_angle_to(Vector3.RIGHT, Vector3.UP)
				check(absf(fork_turn) > 0.01 and is_equal_approx(snappedf(fork_turn, 0.001), snappedf(wheel_turn, 0.001)), "the fork and bars turn with the front wheel (%.1f and %.1f degrees)" % [rad_to_deg(fork_turn), rad_to_deg(wheel_turn)])
				check(absf(rad_to_deg(wheel_turn)) > 6.0 and absf(rad_to_deg(wheel_turn)) < 20.0, "and at speed a hard turn shows, but not full lock (%.0f degrees at %.0f m/s)" % [rad_to_deg(wheel_turn), kart.forward_speed])
			751:
				var turned := rad_to_deg(angle_difference(start_yaw, kart.global_rotation.y))
				check(turned < -40.0, "turns right when steering right (%.0f degrees)" % turned)
				check(most_roll < 8.0, "and stays upright in a hard turn (rolled %.1f degrees at most)" % most_roll)
				check(lean_right and most_lean > 10.0, "while it leans into the bend (%.0f degrees)" % most_lean)
				c.steer = -1.0
			811:
				check(kart.lean < 0.0, "and the other way going left (%.0f degrees)" % rad_to_deg(kart.lean))
				c.steer = 0.0
				c.throttle = 0.0
				c.brake = 1.0
			991:
				check(absf(kart.forward_speed) < 1.0 or kart.forward_speed < 0.0, "stops")
				c.brake = 0.0
			1111:
				check(roll() < 3.0, "and stands upright again stopped (%.1f degrees)" % roll())
				check(absf(kart.lean) < deg_to_rad(2.0), "with no lean (%.1f degrees)" % rad_to_deg(kart.lean))
				on_trike = true
				tick = 0
				_ride(KartDesign.load_file("res://data/karts/stock/tourer.json"))

	func _trike_ride(c: KartControls) -> void:
		match tick:
			1:
				var problems := kart.design.problems()
				check(problems.is_empty(), "the trike can race %s" % [problems])
				check(kart.upright > 0.0 and kart.upright < 1.0, "and it's held up a little (%.2f)" % kart.upright)
			90:
				var grounded := kart.wheels.filter(func(w): return w.grounded).size()
				check(grounded == 3, "all three wheels on the ground after settling (%d)" % grounded)
				c.throttle = 1.0
			330:
				check(kart.forward_speed > 12.0, "gets up to speed (%.1f m/s)" % kart.forward_speed)
				c.steer = 1.0
				most_roll = 0.0
			510:
				check(most_roll < 15.0, "doesn't tip over in a hard turn (rolled %.1f degrees at most)" % most_roll)
				check(absf(kart.lean) < 0.01, "and doesn't lean like a bike")
				if failures.is_empty():
					print("All bike checks passed.")
				else:
					print("%d bike checks failed." % failures.size())
				get_tree().quit(1 if not failures.is_empty() else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
