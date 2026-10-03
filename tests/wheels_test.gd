extends SceneTree

## Karts side by side with their wheels overlapping a little, the way they
## end up racing wheel to wheel. The faster one has to get past instead of
## its wheels hooking onto the other's (see Kart._keep_wheels_apart()), and
## neither gets turned much.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/wheels_test.gd

const OVERLAPS := [0.1, 0.2, 0.3]
const DESIGNS := ["starter", "classic", "downforce"]


class Runner:
	extends Node

	var failures := 0
	var tick := 0
	var pairs := []

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func kart_at(design: String, x: float, z: float) -> Kart:
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/stock/%s.json" % design))
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.05, z))
		add_child(kart)
		return kart

	func _ready() -> void:
		add_child(TestTrack.new())
		var x := -120.0
		for design in DESIGNS:
			var probe := kart_at(design, -300.0, 0.0)
			# Where the outsides of its wheels are.
			var wide := 0.0
			for wheel in probe.wheels:
				wide = maxf(wide, absf(wheel.rest.x) + wheel.width * 0.5)
			probe.queue_free()
			for overlap in OVERLAPS:
				var slow := kart_at(design, x, 110.0)
				var fast := kart_at(design, x + wide * 2.0 - overlap, 112.0)
				pairs.append([design, overlap, slow, fast, 0.0])
				x += 15.0

	func _physics_process(_delta: float) -> void:
		tick += 1
		if tick == 40:
			for p in pairs:
				p[2].linear_velocity = Vector3(0, 0, -14.0)
				p[2].controls.throttle = 0.5
				p[3].linear_velocity = Vector3(0, 0, -19.0)
				p[3].controls.throttle = 1.0
		if tick > 40:
			for p in pairs:
				p[4] = maxf(p[4], maxf(absf(p[2].global_rotation.y), absf(p[3].global_rotation.y)))
		if tick == 160:
			for p in pairs:
				var ahead: float = p[2].global_position.z - p[3].global_position.z
				check(ahead > 2.0 and rad_to_deg(p[4]) < 10.0, "the faster %s gets past with its wheels %.0f cm over the other's (%.1f m ahead, turned %.0f degrees at most)" % [p[0].capitalize(), p[1] * 100.0, ahead, rad_to_deg(p[4])])
			print("All wheel checks passed." if failures == 0 else "%d wheel checks failed." % failures)
			get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
