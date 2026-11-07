extends SceneTree

## Marble grip, drift assists and recovery with the same kart and controls.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/marbles_test.gd
class Runner:
	extends Node
	var failures := 0

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func frames(count: int) -> void:
		for i in count:
			await get_tree().physics_frame

	func make_kart(key := "kart_kid", at := Vector3(0, 0.05, 12)) -> Kart:
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/stock/%s.json" % key), Kart.default_driver())
		kart.position = at
		add_child(kart)
		return kart

	func sample(marbles: bool, drift: bool, offroad := 0.0, immune := "", neutral := false) -> Dictionary:
		seed(101)
		var kart := make_kart()
		await frames(60)
		for wheel in kart.wheels:
			# Keep geometry, mass and base grip fixed to isolate tread compensation.
			wheel.offroad = offroad
		var trap: BrickTrap
		if marbles:
			trap = BrickTrap.new("marbles")
			trap.position = Vector3(0, 0.01, 0)
			add_child(trap)
			if neutral:
				trap.set_meta("grip", 1.0)
				trap.set_meta("drag", 1.0)
		if immune == "ghost":
			kart.ghost_left = 10.0
		elif immune == "shield":
			kart.shield_left = 10.0
		kart.linear_velocity = Vector3(0, 0, -20)
		kart.controls.throttle = 1.0
		var started := -1
		var least := 1.0
		var partial := false
		var slide_contact := 0
		var slowest := 20.0
		var yaw := 0.0
		for frame in 240:
			if started < 0 and kart.position.z <= (6.0 if drift else 3.0):
				started = frame
			kart.controls.steer = 0.5 if started >= 0 and frame - started < 45 else 0.0
			kart.controls.brake = 1.0 if drift and started >= 0 and frame - started < 6 else 0.0
			await frames(1)
			least = minf(least, kart._marble_grip)
			partial = partial or (kart._marble_grip > 0.13 and kart._marble_grip < 0.99)
			if kart._marble_grip < 0.99 and kart.sliding and not kart.slide_kick:
				slide_contact += 1
			slowest = minf(slowest, kart.forward_speed)
			yaw = maxf(yaw, absf(kart.rotation.y))
		var result := { "position": kart.position, "velocity": kart.linear_velocity, "least": least, "partial": partial, "slide_contact": slide_contact, "recovered": is_equal_approx(kart._marble_grip, 1.0), "slowest": slowest, "yaw": yaw, "lost": kart.lost.size() }
		kart.queue_free()
		if trap != null:
			trap.queue_free()
		await frames(3)
		return result

	func _ready() -> void:
		var ground := StaticBody3D.new()
		ground.collision_layer = Kart.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(500, 2, 500)
		shape.shape = box
		shape.position.y = -1.0
		ground.add_child(shape)
		add_child(ground)
		var valid := true
		for id in PartCatalog.ids():
			var part := PartCatalog.get_part(id)
			if part.get("kind", "") != "wheel":
				continue
			for grip in [0.0, 0.05, 0.12, 0.3, 0.5, 0.75, 1.0, 1.2]:
				var friction := Kart.ground_grip(grip, part.get("offroad", 0.0))
				valid = valid and is_finite(friction) and friction >= 0.0
		check(valid, "every tire has finite, nonnegative grip on ice, terrain and road")
		check(Kart.ground_grip(0.5, 0.6) > Kart.ground_grip(0.5, 0.0) and Kart.ground_grip(0.5, 0.0) > Kart.ground_grip(0.5, -0.3), "knobbly tires keep their terrain advantage and slicks their penalty")
		check(is_equal_approx(Kart.ground_grip(1.0, -0.3), 1.0) and is_equal_approx(Kart.ground_grip(1.2, 0.6), 1.2), "road and high-grip surfaces keep their grip")
		for drift in [false, true]:
			var mode := "held drift" if drift else "steering"
			var control := await sample(false, drift)
			var marble := await sample(true, drift)
			check(absf(control.position.x - marble.position.x) > 2.0, "%s loses its line over marbles (%.2f m apart)" % [mode, control.position.distance_to(marble.position)])
			check(marble.least < 0.13 and marble.partial and marble.recovered, "%s follows partial wheel contact and recovers after the patch" % mode)
			check(marble.slowest > 14.0 and marble.yaw < PI * 0.5 and marble.lost == 0 and marble.velocity.is_finite(), "%s remains moving, recoverable and undamaged" % mode)
			if drift:
				check(marble.slide_contact > 5, "the drift stays held while its assist loses grip on marbles")
			for offroad in [-0.3, 0.6, 0.7]:
				var tread := await sample(true, drift, offroad)
				check(tread.position.distance_to(marble.position) < 0.01 and tread.velocity.distance_to(marble.velocity) < 0.01, "%s marble handling is independent of tread compensation %.1f" % [mode, offroad])
			for immune in ["ghost", "shield"]:
				var protected := await sample(true, drift, 0.0, immune)
				var baseline := await sample(true, drift, 0.0, immune, true)
				check(is_equal_approx(protected.least, 1.0) and protected.position.distance_to(baseline.position) < 0.2, "%s %s keeps normal grip through marbles" % [immune, mode])
		for key in ["long_fork", "sunday_trike", "kart_kid"]:
			var trap := BrickTrap.new("marbles")
			trap.position.y = 0.01
			add_child(trap)
			var kart := make_kart(key, Vector3(0, 0.05, 0))
			await frames(60)
			check(kart.wheels.all(func(w): return w.grounded) and is_equal_approx(kart._marble_grip, 0.12) and kart.global_basis.y.dot(Vector3.UP) > 0.95, "%s has full marble contact and stays upright on %d wheels" % [key, kart.wheels.size()])
			kart.queue_free()
			trap.queue_free()
			await frames(3)
		print("All marble checks passed." if failures == 0 else "%d marble checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)

func _initialize() -> void:
	root.add_child(Runner.new())
