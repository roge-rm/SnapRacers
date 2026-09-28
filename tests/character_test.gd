extends SceneTree

## Builds every driver piece, checks the roster, and checks that drivers
## really do hold the steering wheel and follow it around.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/character_test.gd


class Runner:
	extends Node

	var failures := 0
	var tick := 0
	var kart: Kart
	var loose: Kart

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func hand_at(rig: CharacterRig, side: int) -> Vector3:
		return rig._hand[side].global_position

	func _ready() -> void:
		add_child(TestTrack.new())

		# Every style of every piece builds, sitting and standing.
		var built := 0
		for slot in CharacterDesign.SLOTS:
			for style in CharacterDesign.styles(slot):
				var who := CharacterDesign.load_file("res://data/characters/roster/racer.json")
				who.set_piece(slot, style)
				for sitting in [true, false]:
					var rig := CharacterRig.new(who, sitting)
					add_child(rig)
					built += 1 if rig.find_children("*", "MeshInstance3D", true, false).size() > 10 else 0
					rig.queue_free()
		var styles := 0
		for slot in CharacterDesign.SLOTS:
			styles += CharacterDesign.styles(slot).size()
		check(built == styles * 2, "every piece builds, sitting and standing (%d of %d)" % [built, styles * 2])

		# The roster.
		var classes := {}
		var names := []
		for file in DirAccess.get_files_at("res://data/characters/roster"):
			if file.ends_with(".json"):
				var who := CharacterDesign.load_file("res://data/characters/roster/" + file)
				names.append(who.name)
				classes[who.weight_class()] = true
		check(names.size() == 8, "eight drivers on the roster %s" % [names])
		check(classes.size() == 3, "light, medium and heavy are all there %s" % [classes.keys()])

		var racer := CharacterDesign.load_file("res://data/characters/roster/racer.json")
		var again := CharacterDesign.from_dict(racer.to_dict())
		check(again.to_dict() == racer.to_dict(), "a driver saves and loads the same")
		var tread := CharacterDesign.load_file("res://data/characters/roster/tread.json")
		var pip := CharacterDesign.load_file("res://data/characters/roster/pip.json")
		check(tread.weight_class() == "Heavy" and pip.weight_class() == "Light", "Tread is heavy (%.0f kg) and Pip is light (%.0f kg)" % [tread.mass(), pip.mass()])

		# A kart has to have something to steer with.
		var no_wheel := KartDesign.load_file("res://data/karts/stock/starter.json")
		no_wheel.parts = no_wheel.parts.filter(func(p): return PartCatalog.get_part(p.id).kind != "steering")
		check(no_wheel.problems().has("It needs a steering wheel or handlebars in front of the seat."), "a kart with no steering wheel says so")

		# A heavy driver and a light one make different karts.
		var design := KartDesign.load_file("res://data/karts/stock/starter.json")
		kart = Kart.new()
		kart.build(design, tread)
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(60.0, 0.05, 100.0))
		add_child(kart)
		var light := Kart.new()
		light.build(design, pip)
		check(kart.mass - light.mass > 15.0, "a heavy driver makes a heavier kart (%.0f against %.0f kg)" % [kart.mass, light.mass])
		light.free()
		loose = Kart.new()
		loose.build(design, racer)
		loose.transform = Transform3D(Basis.IDENTITY, Vector3(80.0, 0.05, 100.0))
		add_child(loose)

	func _physics_process(_delta: float) -> void:
		tick += 1
		match tick:
			30:
				var rig: CharacterRig = kart._rig
				var wheel: SteeringVisual = kart._steering
				check(rig != null and wheel != null, "the kart has a driver and a steering wheel")
				var grips := wheel.grips(0.0)
				var left: Vector3 = wheel.global_transform * grips[0]
				var right: Vector3 = wheel.global_transform * grips[1]
				check(hand_at(rig, 0).distance_to(left) < 0.03 and hand_at(rig, 1).distance_to(right) < 0.03, "the hands are on the wheel (%.3f and %.3f m off)" % [hand_at(rig, 0).distance_to(left), hand_at(rig, 1).distance_to(right)])
				kart.controls.throttle = 0.4
				kart.controls.steer = 1.0
				# Knock the steering wheel off the other kart.
				for i in loose.design.parts.size():
					if loose.design.parts[i].id == "steering_wheel":
						var one: Array[int] = [i]
						loose.lose_parts(one)
				loose.controls.throttle = 0.4
				loose.controls.steer = 1.0
			90:
				kart._pose_driver()
				var rig: CharacterRig = kart._rig
				var wheel: SteeringVisual = kart._steering
				var amount := kart.steer_angle / Kart.MAX_STEER
				check(amount > 0.3, "steering right turns the front wheels (%.2f of full lock)" % amount)
				var grips := wheel.grips(amount)
				var left: Vector3 = wheel.global_transform * grips[0]
				check(hand_at(rig, 0).distance_to(left) < 0.03, "and the hands follow the wheel around (%.3f m off)" % hand_at(rig, 0).distance_to(left))
				var straight: Vector3 = wheel.global_transform * wheel.grips(0.0)[0]
				check(left.distance_to(straight) > 0.04, "which really has turned (the left hand moved %.2f m)" % left.distance_to(straight))
				# Minifig arms only swing forward and back at the shoulder.
				for side in 2:
					var across: Vector3 = rig._arm[side].basis.x
					check(absf(across.x) > 0.999, "arm %d only swings at the shoulder (%s)" % [side, across])
				check(loose._steering == null and absf(loose.steer_angle) < 0.001, "with its steering wheel knocked off, a kart can't steer")
				print("All character checks passed." if failures == 0 else "%d character checks failed." % failures)
				get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
