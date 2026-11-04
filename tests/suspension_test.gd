extends SceneTree

## Saves wheel tuning and compares ride height and compression under the
## same landing impulse, including different settings on the same kart.

class Runner:
	extends Node
	var failures := 0
	var tick := 0
	var karts: Array[Kart] = []
	var rests: Array[float] = []
	var lowest: Array[float] = []
	var presets := ["soft", "medium", "hard", "mixed"]

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _ready() -> void:
		_data()
		add_child(TestTrack.new())
		for preset in presets:
			var design := KartDesign.load_file("res://tests/data/legacy/starter.json")
			var n := 0
			for part in design.parts:
				if KartDesign.is_wheel(part.id):
					KartDesign.set_suspension(part, KartDesign.SUSPENSION[n % 3] if preset == "mixed" else preset)
					n += 1
			var kart := Kart.new()
			kart.build(design)
			kart.position = Vector3(80.0 + karts.size() * 15.0, 0.05, 100.0)
			add_child(kart)
			karts.append(kart)

	func _data() -> void:
		var data := {"parts": [
			{"id": "wheel_small", "at": [6, 0, 8], "suspension": "soft"},
			{"id": "wheel_small", "pos": [1, 2, 3], "suspension": "hard"},
			{"id": "wheel_small", "at": [6, 0, 12]},
			{"id": "wheel_small", "at": [6, 0, 16], "suspension": "unknown"},
			{"id": "plate_6x10", "at": [7, 2, 7], "suspension": "hard"},
		]}
		var design := KartDesign.from_dict(data)
		var expected := ["soft", "hard", "medium", "medium", "medium"]
		check(design.parts.map(KartDesign.suspension_of) == expected, "old and new placements read wheel tuning, with medium for absent, unknown and non-wheel values")
		var saved := JSON.parse_string(JSON.stringify(design.to_dict())) as Dictionary
		check(KartDesign.from_dict(saved).parts.map(KartDesign.suspension_of) == expected, "JSON saves and reloads each wheel's tuning")
		check(design.duplicate_design().parts.map(KartDesign.suspension_of) == expected, "duplicating a kart keeps independent wheel settings")
		var raised := design.duplicate_design()
		var before := KartDesign.place_of(raised.parts[0]).origin
		raised.raise(3)
		check(raised.parts.map(KartDesign.suspension_of) == expected and KartDesign.place_of(raised.parts[0]).origin.is_equal_approx(before + Vector3.UP * Grid.PLATE_FINE * 3.0), "raising the kart to fit a lower part preserves every wheel's tuning")
		check(not saved.parts[2].has("suspension") and not saved.parts[3].has("suspension") and not saved.parts[4].has("suspension"), "medium and invalid settings do not add saved tuning")
		KartDesign.set_suspension(design.parts[0], "medium")
		check(KartDesign.suspension_of(design.parts[0]) == "medium" and not design.parts[0].has("suspension"), "medium clears an earlier tuning choice")

	func _physics_process(_delta: float) -> void:
		tick += 1
		if tick == 120:
			for i in karts.size():
				var kart := karts[i]
				rests.append(kart.position.y)
				lowest.append(kart.position.y)
				check(kart.wheels.all(func(w): return w.grounded) and kart.linear_velocity.length() < 0.05 and kart.global_basis.y.y > 0.995, "%s suspension settles level with all wheels grounded" % presets[i])
			check(rests.max() - rests.min() < 0.002, "all presets and mixed wheels keep the same ride height (range %.5f m)" % (rests.max() - rests.min()))
			for n in karts[1].wheels.size():
				var soft: Kart.Wheel = karts[0].wheels[n]
				var medium: Kart.Wheel = karts[1].wheels[n]
				var hard: Kart.Wheel = karts[2].wheels[n]
				check(soft.damper < medium.damper and medium.damper < hard.damper and is_equal_approx(soft.standing_load, medium.standing_load) and is_equal_approx(medium.standing_load, hard.standing_load), "wheel %d damping follows stiffness while its static traction load stays the same" % n)
			for i in 3:
				karts[i].apply_central_impulse(Vector3.DOWN * karts[i].mass * 0.5)
		if tick > 120 and tick <= 180:
			for i in 3:
				lowest[i] = minf(lowest[i], karts[i].position.y)
		if tick == 300:
			var travel := [rests[0] - lowest[0], rests[1] - lowest[1], rests[2] - lowest[2]]
			check(travel[0] > travel[1] + 0.001 and travel[1] > travel[2] + 0.001, "the same landing compresses soft more than medium, and medium more than hard (%.4f / %.4f / %.4f m)" % travel)
			check(range(3).all(func(i): return absf(karts[i].position.y - rests[i]) < 0.002 and karts[i].linear_velocity.length() < 0.05), "all presets settle back to their original ride height after landing")
			for kart in karts:
				kart.apply_central_impulse(Vector3.DOWN * kart.mass * 1.5)
		if tick == 480:
			check(range(karts.size()).all(func(i): return absf(karts[i].position.y - rests[i]) < 0.002 and karts[i].linear_velocity.length() < 0.05 and karts[i].global_basis.y.y > 0.995), "bump stops settle a harder landing on every preset and a mixed kart")
			print("All suspension checks passed." if failures == 0 else "%d suspension checks failed." % failures)
			get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
