extends SceneTree

## Shallows: a road surface of clear water over sand. A piece of it saves and
## loads, shares in a code, builds with its grip, drag and spray depth, and
## slows a kart a little more than sand without hydroplaning it.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/shallows_test.gd

var failures := 0
var world: Node3D


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func strip(at: Vector3, feel: Body) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	for key in ["grip", "drag", "surface", "wade"]:
		if feel.has_meta(key):
			body.set_meta(key, feel.get_meta(key))
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(8.0, 0.08, 400.0)
	body.add_child(shape)
	body.position = at
	world.add_child(body)


## Stands in for a built road's metas.
class Body extends Object:
	pass


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)

	var feel: Array = TrackPath.SURFACES["shallows"]
	var sand: Array = TrackPath.SURFACES["sand"]
	check(feel[1] > sand[1] and feel[0] == sand[0], "shallows drag more than sand, with the same grip (%.1f)" % feel[1])
	check(TrackBuilder.COLOURS.has("shallows"), "shallows have their own colour")

	# Saved and loaded, and through a share code.
	var course := CourseDesign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit"))))
	course.name = "Shallows test"
	course.pieces[2]["surface"] = "shallows"
	var path := course.save("user://shallows_test.json")
	var back := CourseDesign.load_file(path)
	check(back != null and back.pieces[2].get("surface") == "shallows", "a shallows piece saves and loads")
	check(back != null and back.track().pieces[2].surface == "shallows", "and races as shallows")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var shared := Sharing.read(Sharing.code_for(course.to_dict()))
	check(shared.get("kind") == Sharing.COURSE and shared.data.pieces[2].get("surface") == "shallows", "and goes through a share code")

	# Built, its road carries the grip, drag and spray depth.
	var built := TrackBuilder.new(TrackPath.from_dict({"theme": "gran_canaria", "pieces": [
		{"type": "straight", "length": 2, "surface": "shallows"},
		{"type": "straight", "length": 2},
	]}))
	built.scenery = "none"
	built.sky = false
	built.position = Vector3(400.0, 0.0, 0.0)
	world.add_child(built)
	await frames(2)
	var water := Body.new()
	for child in built.get_children():
		if child is StaticBody3D and child.get_meta("piece", -1) == 0:
			for key in ["grip", "drag", "surface", "wade"]:
				water.set_meta(key, child.get_meta(key, null))
	check(is_equal_approx(water.get_meta("grip", 0.0), feel[0]) and is_equal_approx(water.get_meta("drag", 0.0), feel[1]), "a shallows piece's road has their grip and drag")
	check(water.get_meta("wade", 0.0) > 0.0, "and is deep enough to spray")
	built.queue_free()

	# The same kart on the gas down road, sand and shallows.
	var karts := {}
	var x := 200.0
	for surface in ["asphalt", "sand", "shallows"]:
		var ground := water
		if surface != "shallows":
			ground = Body.new()
			ground.set_meta("grip", TrackPath.SURFACES[surface][0])
			ground.set_meta("drag", TrackPath.SURFACES[surface][1])
			ground.set_meta("surface", surface)
		strip(Vector3(x, 0.04, -50.0), ground)
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.35, 120.0))
		world.add_child(kart)
		kart.linear_velocity = Vector3.FORWARD * 22.0
		kart.controls.throttle = 1.0
		karts[surface] = kart
		x += 20.0
	var planing := 0.0
	var wade := 0.0
	for i in 180:
		await physics_frame
		for w: Kart.Wheel in karts.shallows.wheels:
			planing = maxf(planing, w.planing)
			wade = maxf(wade, w.wade)
	var speeds := {}
	for surface in karts:
		speeds[surface] = karts[surface].forward_speed
	var behind: float = speeds.sand - speeds.shallows
	check(behind > 0.8 and behind < 2.5 and speeds.shallows > speeds.asphalt * 0.7, "on the gas, shallows are 1 to 2 m/s slower than sand and not a trap (road %.1f, sand %.1f, shallows %.1f m/s)" % [speeds.asphalt, speeds.sand, speeds.shallows])
	var guess: Dictionary = RacingLine.TIME_SURFACE
	check(guess.shallows < guess.sand and absf(guess.shallows / guess.sand - speeds.shallows / speeds.sand) < 0.05, "and the AI's split timing knows it (%.2f of sand, measured %.2f)" % [guess.shallows / guess.sand, speeds.shallows / speeds.sand])
	check(wade > 0.0, "its wheels are in the water (%.2f)" % wade)
	check(planing == 0.0, "and never hydroplane")

	water.free()
	print("All shallows checks passed." if failures == 0 else "%d shallows checks failed." % failures)
	quit(1 if failures > 0 else 0)
