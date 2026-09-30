extends Node

## Takes pictures of a course the way you'd see it racing, for checking how it
## looks without a phone. There's the pack of eight after the start, the whole
## course from above, a kart riding a curb, a kart run wide onto the grass and
## the tire stacks. It needs a screen, so it runs on the computer's own display
## (not headless), and it saves them in /tmp/snapracers-build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/course_shots.tscn -- peach_pit

const OUT := "/tmp/snapracers-build/shots"

var race: Race
var which := "peach_pit"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		which = args[0]
	# After the course, "side" or "face" races two on one phone instead, and
	# only takes the picture of the start.
	var split := args[1] if args.size() > 1 else ""
	if split != "":
		Game.settings.set_value("race", "split", Game.SIDE_BY_SIDE if split == "side" else Game.FACE_TO_FACE)
		Game.start_race(Game.TRACKS + "/" + which + ".json")
	else:
		Game.settings.set_value("race", "split", Game.SOLO)
		Game.show_race(Game.TRACKS + "/" + which + ".json")
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	driver.others.assign(race.racers.map(func(r): return r.kart))
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	while not race.started:
		await get_tree().process_frame
	await seconds(4.0)
	if split != "":
		await shot(split)
		get_tree().quit()
		return
	await shot("pack")
	await overhead()
	await on_grass()
	await on_kerb()
	await tire_stacks()
	get_tree().quit()


## Puts the player's kart here going at `speed`, and tells the race where it
## is now, or it thinks the kart's wandered off and puts it back.
func move_to(where: Transform3D, offset: float, speed: float) -> void:
	var kart := race.player.kart
	# Straight into the physics, so it's there on the next step, and a moment
	# of the reset slowdown so the race doesn't check on it before then.
	kart.slowdown_left = 0.15
	PhysicsServer3D.body_set_state(kart.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, where)
	PhysicsServer3D.body_set_state(kart.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, -where.basis.z * speed)
	PhysicsServer3D.body_set_state(kart.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	race.player.offset = fposmod(offset, race.track.length)
	if race.player.ai != null:
		race.player.ai.offset = race.player.offset


func seconds(time: float) -> void:
	await get_tree().create_timer(time).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [OUT, which, name])
	print("saved ", name)


func with_camera(where: Transform3D, name: String) -> void:
	var camera := Camera3D.new()
	camera.far = 5000.0
	race.add_child(camera)
	camera.global_transform = where
	camera.current = true
	await shot(name)
	camera.queue_free()
	race.camera.make_current()


func overhead() -> void:
	var bounds := AABB(race.track.points[0], Vector3.ZERO)
	for p in race.track.points:
		bounds = bounds.expand(p)
	var centre := bounds.get_center()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 3000.0
	# Turned so the course's long side runs across the picture.
	var across := bounds.size.x >= bounds.size.z
	camera.size = (maxf(bounds.size.x, bounds.size.z) if not across else bounds.size.x * 9.0 / 16.0) + 60.0
	camera.size = maxf(camera.size, minf(bounds.size.x, bounds.size.z) + 60.0)
	race.add_child(camera)
	var up := Vector3.FORWARD if across else Vector3.RIGHT
	camera.global_transform = Transform3D(Basis.IDENTITY, centre + Vector3.UP * 1000.0).looking_at(centre, up)
	camera.current = true
	await shot("overhead")
	camera.queue_free()
	race.camera.make_current()


## The player's kart put a little way off the road on the grass at speed,
## seen from beside it and a little behind, with the road alongside.
func on_grass() -> void:
	var kart := race.player.kart
	var offset := race.player.offset + 60.0
	var frame := race.track.frame_at(offset)
	frame.origin += frame.basis.x * (race.track.width * 0.5 + 5.0) + frame.basis.y * 0.5
	move_to(frame, offset, 20.0)
	await seconds(0.5)
	var at := kart.global_position
	var along := -race.track.frame_at(race.track.offset_of(at)).basis.z
	var right := along.cross(Vector3.UP).normalized()
	var eye := at - along * 9.0 - right * 7.0 + Vector3.UP * 3.0
	await with_camera(Transform3D(Basis.IDENTITY, eye).looking_at(at + along * 6.0, Vector3.UP), "grass")


## The player's kart put on a curb at speed, seen from the grass beyond it.
func on_kerb() -> void:
	var track := race.track
	var best: StaticBody3D
	var best_size := 0.0
	for body in race.find_children("*", "StaticBody3D", true, false):
		if body.get_meta("kerb", false):
			var box: AABB = body.get_child(0).get_aabb()
			if box.size.length() > best_size:
				best_size = box.size.length()
				best = body
	if best == null:
		print("no curbs on this course")
		return
	# A point on the curb itself, from the middle of its mesh.
	var vertices: PackedVector3Array = best.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var middle: Vector3 = vertices[vertices.size() / 2]
	var at := track.offset_of(middle)
	var frame := track.frame_at(at)
	var side := signf((middle - frame.origin).dot(frame.basis.x))
	var start := track.frame_at(at - 8.0)
	var kart := race.player.kart
	var place := start
	place.origin += start.basis.x * side * (track.width * 0.5 + 0.8) + start.basis.y * 0.4
	move_to(place, at - 8.0, 22.0)
	await seconds(0.3)
	var look := kart.global_position
	var eye := look + frame.basis.x * side * 9.0 + Vector3.UP * 1.0 - frame.basis.z * 4.0
	await with_camera(Transform3D(Basis.IDENTITY, eye).looking_at(look, Vector3.UP), "kerb")


## A line of tire stacks, seen from beside the road.
func tire_stacks() -> void:
	for body in race.find_children("*", "StaticBody3D", true, false):
		if body.get_meta("soft", false) and body.get_child_count() > 20:
			var stack: Node3D = body.get_child(body.get_child_count() / 2)
			var target := stack.global_position
			var eye := target + Vector3(14.0, 5.0, 14.0)
			await with_camera(Transform3D(Basis.IDENTITY, eye).looking_at(target, Vector3.UP), "tires")
			return
	print("no tire stacks on this course")
