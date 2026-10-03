extends SceneTree

## Crashes karts into a wall and checks what breaks. A gentle bump shouldn't
## cost anything, a crash at full speed should knock parts off, and a reset
## should put them all back.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/damage_test.gd


class Runner:
	extends Node

	var gentle: Kart
	var hard: Kart
	var tick := 0
	var failures := 0
	var hard_speed := 0.0
	var gentle_speed := 0.0
	var shot: Array[Kart] = []

	func _ready() -> void:
		add_child(TestTrack.new())
		# A wall across both lanes, well away from the jump and the bricks.
		var wall := StaticBody3D.new()
		wall.collision_layer = Kart.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(80.0, 3.0, 1.0)
		shape.shape = box
		wall.add_child(shape)
		wall.position = Vector3(60.0, 1.5, 60.0)
		add_child(wall)

		var design := KartDesign.load_file("res://data/karts/stock/starter.json")
		gentle = Kart.new()
		gentle.build(design)
		gentle.transform = Transform3D(Basis.IDENTITY, Vector3(40.0, 0.05, 64.0))
		add_child(gentle)
		hard = Kart.new()
		hard.build(design)
		hard.transform = Transform3D(Basis.IDENTITY, Vector3(80.0, 0.05, 100.0))
		add_child(hard)
		# A kart and a bike hit by power-ups, well off to the side.
		for which in ["starter", "dirt_bike"]:
			var hit := Kart.new()
			hit.build(KartDesign.load_file("res://data/karts/stock/%s.json" % which))
			hit.transform = Transform3D(Basis.IDENTITY, Vector3(-60.0 - shot.size() * 10.0, 0.05, 100.0))
			add_child(hit)
			shot.append(hit)

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _physics_process(_delta: float) -> void:
		tick += 1
		# Remember how fast each was going just before it hit.
		if gentle.global_position.z > 62.0:
			gentle_speed = maxf(gentle_speed, gentle.forward_speed)
		if hard.global_position.z > 62.0:
			hard_speed = maxf(hard_speed, hard.forward_speed)
		match tick:
			30:
				gentle.controls.throttle = 0.3
				hard.controls.throttle = 1.0
			330:
				gentle.controls.throttle = 0.0
				hard.controls.throttle = 0.0
				check(gentle_speed > 3.0, "the gentle kart reached the wall (%.1f m/s)" % gentle_speed)
				check(gentle.lost.is_empty(), "a bump at %.0f km/h costs nothing (lost %s)" % [gentle_speed * 3.6, gentle.lost.keys()])
				check(hard_speed > 12.0, "the hard kart reached the wall fast (%.1f m/s)" % hard_speed)
				check(not hard.lost.is_empty(), "a crash at %.0f km/h knocks parts off (lost %d)" % [hard_speed * 3.6, hard.lost.size()])
				check(hard.stats.has_seat, "the seat and driver stay on")
				check(hard.stats.parts.size() == hard.design.parts.size() - hard.lost.size(), "what's left adds up")
				var pieces := get_children().filter(func(n): return n is Debris).size()
				check(pieces == hard.lost.size(), "each lost part is a loose piece (%d pieces)" % pieces)
				check(hard.mass < gentle.mass, "the damaged kart is lighter (%.0f kg against %.0f kg)" % [hard.mass, gentle.mass])
				hard.controls.reset = true
			331:
				hard.controls.reset = false
			334:
				check(hard.lost.is_empty(), "reset puts every part back")
				check(hard.stats.parts.size() == hard.design.parts.size(), "and the kart is whole again")
				check(is_equal_approx(hard.mass, gentle.mass), "at its full weight (%.0f kg)" % hard.mass)
				check(hard.slowdown_left > 0.0, "with the reset slowdown")
				# Knock a front wheel off the gentle kart by hand.
				var wheel := -1
				for i in gentle.design.parts.size():
					if gentle.design.parts[i].id == "w_kart":
						wheel = i
						break
				gentle.lose_parts([wheel] as Array[int])
			335:
				check(gentle.wheels.size() == 3, "losing a wheel leaves three")
			410:
				# Power-up hits knock bodywork off, never what it needs to
				# drive. A bike has no bodywork, so nothing comes off it.
				for kart in shot:
					var wheels := kart.wheels.size()
					for n in 4:
						kart.knock_off_a_part()
					var gone: Array = kart.lost.keys().map(func(i): return kart.design.parts[i].id)
					check((not gone.is_empty() or kart.design.name == "Dirt Bike") and kart.wheels.size() == wheels and kart.stats.steering != null, "four power-up hits on the %s leave its wheels and steering (lost %s)" % [kart.design.name, gone])
			420:
				var tilt := rad_to_deg(gentle.global_basis.y.angle_to(Vector3.UP))
				check(tilt > 3.0, "and the kart sags onto that corner (%.1f degrees)" % tilt)
				print("All damage checks passed." if failures == 0 else "%d damage checks failed." % failures)
				get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
