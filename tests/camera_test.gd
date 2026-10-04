extends Node

## Checks every camera view in a practice session on Peach Pit, with the AI
## driving. Each view has to be where it should be and look the right way,
## looking back has to turn it around, your own head has to be hidden only in
## first person, the camera button has to go through the views (and be
## remembered), and finishing has to circle the kart and then cut to the TV
## cameras.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/camera_test.tscn

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "kart", "starter")
	var was_view := Game.camera_view(0)
	Game.settings.set_value("camera", "player_1", "chase")
	Game.start_practice(Tracks.path_of("peach_pit"))
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	var kart := race.player.kart
	var driver := AIDriver.new()
	driver.kart = kart
	driver.track = race.track
	driver.others.assign([kart])
	race.add_child(driver)
	race.player.ai = driver
	kart.controls = driver.controls
	var camera := race.player.camera
	check(camera is RaceCamera and camera.view == "chase", "the race starts in the view you used last")
	# Get going first.
	await physics_frames(360)

	# The map in the corner, which a tap moves on to its next mode, kept for
	# next time.
	var map: CourseMap = race.player.hud.map
	var was_map := Game.map_view(0)
	check(map != null and map.mode == was_map and map.track == race.track, "there's a map of the course in the corner (%s)" % was_map)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	map._gui_input(tap)
	var next: String = CourseMap.MODES[(CourseMap.MODES.find(was_map) + 1) % CourseMap.MODES.size()]
	check(map.mode == next and Game.map_view(0) == next, "tapping it goes on to the next kind of map, and it's kept (%s)" % map.mode)
	Game.set_map_view(0, was_map)
	map.mode = was_map

	var ahead := func() -> Vector3: return -kart.global_basis.z
	var looking := func() -> Vector3: return -camera.global_basis.z
	var gap := func() -> Vector3: return camera.global_position - kart.global_position

	camera.set_view("chase")
	await physics_frames(30)
	var near: float = gap.call().length()
	check(gap.call().dot(ahead.call()) < -2.0 and looking.call().dot(ahead.call()) > 0.7, "chase is behind the kart, looking the way it's going")
	camera.set_view("far")
	await physics_frames(30)
	check(gap.call().length() > near + 2.5, "far chase is further back (%.1f m against %.1f m)" % [gap.call().length(), near])

	camera.set_view("driver")
	await physics_frames(2)
	# It's placed each time the screen's drawn, after the physics step. This
	# is between the two, so place it now, as drawing the screen would.
	camera._process(0.0)
	check(camera.global_position.distance_to(kart.eye_point()) < 0.05 and looking.call().dot(ahead.call()) > 0.95, "first person is at the driver's eyes, looking ahead (%.2f m off, facing %.2f)" % [camera.global_position.distance_to(kart.eye_point()), looking.call().dot(ahead.call())])
	check(not camera.get_cull_mask_value(camera.head_layer), "and leaves out their own head")
	var head_layers := kart.find_children("*", "VisualInstance3D", true, false).filter(func(n): return n.layers == 1 << (camera.head_layer - 1))
	check(not head_layers.is_empty(), "which is on its own layer (%d pieces)" % head_layers.size())

	camera.set_view("bumper")
	await physics_frames(2)
	check(gap.call().dot(ahead.call()) > 0.8 and gap.call().dot(kart.global_basis.y) < 0.6, "bumper is low down on the nose")
	check(camera.get_cull_mask_value(camera.head_layer), "and shows the driver's head again")

	camera.set_view("overhead")
	await physics_frames(60)
	check(gap.call().y > RaceCamera.OVERHEAD_HEIGHT * 0.8 and looking.call().y < -0.95, "overhead is high up, looking straight down")
	check(camera.global_basis.y.dot(ahead.call()) > 0.7, "turned so the kart points up the screen")

	camera.set_view("tv")
	await physics_frames(2)
	var first_spot := camera.global_position
	check(gap.call().length() > 3.0 and looking.call().dot(-gap.call().normalized()) > 0.95, "a TV camera stands off to the side, watching the kart")
	await physics_frames(240)
	check(camera.global_position != first_spot, "and it cuts to the next one as the kart goes by")

	# Looking back. The controls would put it straight back, so this sets it
	# directly.
	camera.input = null
	camera.set_view("chase")
	camera._looking_back = true
	camera.snap()
	check(gap.call().dot(ahead.call()) > 2.0 and looking.call().dot(ahead.call()) < -0.7, "looking back, chase is in front of the kart looking back at it")
	camera.set_view("driver")
	camera._looking_back = true
	camera.snap()
	check(looking.call().dot(ahead.call()) < -0.95, "and first person turns around")
	camera.set_view("bumper")
	camera._looking_back = true
	camera.snap()
	check(gap.call().dot(ahead.call()) < -0.8 and looking.call().dot(ahead.call()) < -0.95, "and bumper moves to the back bumper, looking back (%.1f m behind)" % -gap.call().dot(ahead.call()))
	camera._looking_back = false
	camera.input = race.player.input

	# The camera button on the screen goes through the views, and the one you
	# end up on is kept for next time.
	camera.set_view("chase")
	race.player.hud._camera.pressed.emit()
	await physics_frames(2)
	check(camera.view == "far" and Game.camera_view(0) == "far", "the camera button moves on to the next view, and it's remembered")
	var seen := [camera.view]
	for i in RaceCamera.VIEWS.size() - 1:
		camera.next_view()
		seen.append(camera.view)
	camera.next_view()
	check(seen.size() == RaceCamera.VIEWS.size() and camera.view == "far", "and it goes through them all and around again %s" % [seen])

	camera.finish()
	await physics_frames(30)
	check(gap.call().length() > 4.0 and camera.get_cull_mask_value(camera.head_layer), "crossing the line, the camera circles the kart")
	await physics_frames(int(RaceCamera.ORBIT_TIME * 60.0))
	check(camera.view == "tv", "and then goes to the TV cameras")

	Game.set_camera_view(0, was_view)
	print("All camera checks passed." if failures == 0 else "%d camera checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
