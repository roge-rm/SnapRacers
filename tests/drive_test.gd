extends SceneTree

## Drives the starter kart on the test track with no screen and checks that it
## settles on its wheels, gets up to speed, turns, brakes and resets.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/drive_test.gd


class Runner:
	extends Node

	var kart: Kart
	var track: TestTrack
	var tick := 0
	var failures: Array[String] = []
	var start_yaw := 0.0
	var top_speed := 0.0
	var stopped_at := -1

	func _ready() -> void:
		track = TestTrack.new()
		add_child(track)
		kart = Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/starter.json"))
		# Out on the open grass, well away from the jump and the brick pile.
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(80.0, 0.05, 100.0))
		add_child(kart)
		print("Starter kart: %.0f kg, %.0f W, drag area %.2f m2, %d wheels" % [kart.mass, kart.power, kart.drag_area, kart.wheels.size()])

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures.append(what)

	func _physics_process(_delta: float) -> void:
		tick += 1
		var c := kart.controls
		var up := kart.global_basis.y
		if c.brake > 0.0 and stopped_at == -1 and kart.forward_speed < 0.5:
			stopped_at = tick
		match tick:
			60:
				var grounded := kart.wheels.filter(func(w): return w.grounded).size()
				check(grounded == kart.wheels.size(), "all four wheels on the ground after settling (%d)" % grounded)
				check(up.y > 0.98, "sitting level (up.y %.3f)" % up.y)
				check(kart.linear_velocity.length() < 0.2, "at rest (%.2f m/s)" % kart.linear_velocity.length())
				c.throttle = 1.0
			90:
				check(kart.forward_speed > 3.0, "pulls away in half a second (%.1f m/s)" % kart.forward_speed)
			360:
				top_speed = kart.forward_speed
				check(top_speed > 18.0, "reaches a decent speed in five seconds (%.1f m/s)" % top_speed)
				check(absf(kart.global_position.x - 80.0) < 1.5, "drives straight (drifted %.2f m)" % (kart.global_position.x - 80.0))
				check(up.y > 0.95, "stays level at speed (up.y %.3f)" % up.y)
				start_yaw = kart.global_rotation.y
				c.steer = 1.0
			480:
				var turned := rad_to_deg(angle_difference(start_yaw, kart.global_rotation.y))
				check(turned < -30.0, "turns right when steering right (%.0f degrees)" % turned)
				check(up.y > 0.8, "doesn't roll over in the turn (up.y %.3f)" % up.y)
				c.steer = 0.0
				c.throttle = 0.0
				c.brake = 1.0
			660:
				var took := (stopped_at - 480) / 60.0 if stopped_at != -1 else INF
				check(took < 2.5, "brakes to a stop in under 2.5 s (%.2f s)" % took)
				check(kart.forward_speed > -6.5, "reverses no faster than 6 m/s (%.1f m/s)" % kart.forward_speed)
				c.brake = 0.0
				c.reset = true
			661:
				c.reset = false
			662:
				check(kart.slowdown_left > 0.0, "reset starts the slowdown")
			720:
				check(kart.global_basis.y.y > 0.98, "upright after a reset")
				if failures.is_empty():
					print("All drive checks passed.")
				else:
					print("%d drive checks failed." % failures.size())
				get_tree().quit(1 if not failures.is_empty() else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
