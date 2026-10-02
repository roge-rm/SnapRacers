extends Node

## Takes pictures of the crowd and the moving scenery on a course: the fans
## nearest the start as the pack goes by, the same fans a moment later, and
## the first few things that move, twice each a second apart. It needs a
## screen, and saves in /tmp/snapracers-build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/crowd_shots.tscn -- peach_pit

const OUT := "/tmp/snapracers-build/shots"
const AT_REST_SHOT := 0.2

var _course := ""


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/crowd_%s_%s.png" % [OUT, _course, name])
	print("saved ", name)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	_course = args[0] if args.size() > 0 else "peach_pit"
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.racing_alone = true
	Game.show_race(Game.TRACKS + "/" + _course + ".json")
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
	race.add_child(driver)
	race.player.ai = driver
	kart.controls = driver.controls
	race.player.hud.visible = false
	var camera := Camera3D.new()
	camera.far = 800.0
	race.add_child(camera)
	var crowds := race.find_children("*", "", true, false).filter(func(n): return n is Crowd)
	var damage := WorldDamage.in_tree(get_tree())
	var start := race.track.points[0]
	if not crowds.is_empty():
		var crowd: Crowd = crowds[0]
		var nearest: Dictionary = {}
		for bunch in crowd._bunches.values():
			if nearest.is_empty() or bunch.middle.distance_to(start) < nearest.middle.distance_to(start):
				nearest = bunch
		print("fans ", crowd._phases.size(), " in ", crowd._bunches.size(), " bunches")
		var road: Vector3 = race.track.point_at(race.track.offset_of(nearest.middle))
		var toward: Vector3 = nearest.middle - road
		toward.y = 0.0
		camera.global_position = road + toward * 0.35 + Vector3.UP * 3.0 + race.track.forward_at(race.track.offset_of(nearest.middle)) * -6.0
		camera.look_at(nearest.middle + Vector3.UP * 1.5, Vector3.UP)
		camera.make_current()
		while not race.started:
			await frames(5)
		await frames(150)
		await shot("cheer")
		var far_at := camera.global_transform
		camera.global_position = nearest.middle - toward.normalized() * 7.0 + Vector3.UP * 2.0
		camera.look_at(nearest.middle + Vector3.UP * 1.0, Vector3.UP)
		await frames(2)
		await shot("close")
		camera.global_transform = far_at
		var waited := 0
		while nearest.cheer > AT_REST_SHOT and waited < 3000:
			await frames(10)
			waited += 10
		await shot("calm")
	var movers: Array = damage._movers if damage != null else []
	print("movers ", movers.size())
	# One of each way of moving, the spinning ones first.
	var picked: Array = []
	for way in ["spin", "swing", "bob"]:
		for mover in movers:
			if mover[2].has(way) and picked.size() < 4:
				picked.append(mover)
				break
	for i in picked.size():
		var node_at: Vector3 = picked[i][1].origin
		camera.global_position = node_at + Vector3(16.0, 2.0, 16.0)
		camera.look_at(node_at, Vector3.UP)
		await frames(5)
		await shot("mover%d_a" % i)
		await frames(60)
		await shot("mover%d_b" % i)
	get_tree().quit()
