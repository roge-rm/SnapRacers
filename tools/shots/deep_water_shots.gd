extends Node

## Pictures of a kart driving into deep water, first a lake put down by hand
## and then off the road into the sea, on Peach Pit as an island, from a
## camera beside where it goes in. It needs a screen and saves in
## /srv/downloads/temp/debug/snapracers/beach as deep_lake_v3_*.png and
## deep_sea_v3_*.png.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/deep_water_shots.tscn

const OUT := "/srv/downloads/temp/debug/snapracers/beach"
const COURSE := "user://deep_water_shots.json"
## How many physics steps apart the pictures are.
const EVERY := 6

var race: Race
var controls := KartControls.new()


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	seed(1)
	var lake := _write_course()
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	Game.racing_alone = true
	Game.show_race(COURSE)
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await get_tree().physics_frame
	race.hud.visible = false
	race.player.kart.controls = controls
	DirAccess.make_dir_recursive_absolute(OUT)
	var track := race.track
	var lake_at := Vector3(lake.x, race.builder.ground_at(lake.x, lake.y), lake.y)
	var space := race.player.kart.get_world_3d().direct_space_state
	for n in 16:
		var at := lake_at + Vector3(cos(n * TAU / 16.0), 0.0, sin(n * TAU / 16.0)) * 17.0
		at.y = race.builder.ground_at(at.x, at.z)
		var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, lake_at + Vector3.UP * 0.8, Kart.LAYER_WORLD))
		var near := track.point_at(track.offset_of(at)).distance_to(at) < Race.LOST - 5.0
		if near and across.is_empty() and not is_finite(race.builder.water.level_at(at + Vector3.UP * 0.5)):
			await _drive(at, lake_at, "deep_lake_v3")
			break
	# Off the road into the sea, from a straight bit with the sea close by.
	var sea_from := -1.0
	var sea_at := Vector3.INF
	var out := Vector3.ZERO
	var nearest := INF
	for k in range(0, track.points.size(), 6):
		if absf(track.bend_at(track.distances[k])) > 0.004:
			continue
		for side in [1.0, -1.0]:
			for far in range(10, int(Race.LOST)):
				var at: Vector3 = track.points[k] + track.rights[k] * float(far) * side
				at.y = race.builder.ground_at(at.x, at.z)
				if is_finite(race.builder.water.level_at(at + Vector3.UP * 0.5)):
					var low := track.points[k] + Vector3.UP * 0.8
					var aim := at + track.forwards[k] * 12.0 + Vector3.UP * 0.8
					if space.intersect_ray(PhysicsRayQueryParameters3D.create(low, aim, Kart.LAYER_WORLD)).is_empty() and far < nearest:
						nearest = far
						sea_from = track.distances[k]
						sea_at = at
						out = track.rights[k] * side
					break
	if sea_at != Vector3.INF:
		var from := track.point_at(sea_from)
		var towards := sea_at + track.forward_at(sea_from) * 12.0 + out * 10.0
		# The pictures start a little before it reaches the water.
		var reach := Vector2(towards.x - from.x, towards.z - from.z).length() * nearest / (nearest + 10.0)
		await _drive(from, towards, "deep_sea_v3", int(reach / 11.0 * 60.0) - 20)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COURSE))
	get_tree().quit()


## Peach Pit as an island with a lake well clear of the road. Returns where
## the lake is.
func _write_course() -> Vector2:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
	data.name = "Deep water shots"
	data.theme = "island"
	var track := TrackPath.from_dict(data)
	var lake := Vector2.ZERO
	# Away from the start, where the stands are.
	for k in range(track.points.size() / 4, track.points.size(), 10):
		var at: Vector3 = track.points[k] + track.rights[k] * -42.0
		var clear := true
		for p in track.points:
			clear = clear and Vector2(p.x - at.x, p.z - at.z).length() > 38.0
		if clear:
			lake = Vector2(at.x, at.z)
			break
	data.landmarks = [{"prop": "lake", "at": [lake.x, lake.y], "facing": 0}]
	var file := FileAccess.open(COURSE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return lake


## Drives the kart from `from` towards `towards` until it's been put back,
## with the camera off to one side of the way in, taking pictures after
## `skip` steps.
func _drive(from: Vector3, towards: Vector3, title: String, skip := 25) -> void:
	var kart := race.player.kart
	await _wait(int((Kart.RESET_HOLD + Kart.RESET_SLOWDOWN_TIME) * 60.0))
	# Where it is on the course, so it isn't put back for being far away.
	race.player.offset = race.track.offset_of(from)
	var aim := Vector3(towards.x - from.x, 0.0, towards.z - from.z).normalized()
	kart.global_transform = Transform3D(Basis.looking_at(aim, Vector3.UP), from + Vector3.UP * 0.6)
	kart.linear_velocity = aim * 12.0
	kart.on_road = false
	controls.throttle = 1.0
	var cam := Camera3D.new()
	cam.fov = 55.0
	race.add_child(cam)
	cam.current = true
	var side := aim.cross(Vector3.UP)
	var shot := 0
	var sank := false
	for step in 60 * 5:
		await get_tree().physics_frame
		if kart.sinking_left > 0.0:
			sank = true
		elif sank:
			break
		var at := kart.global_position
		cam.look_at_from_position(Vector3(at.x, from.y, at.z) - aim * 5.0 + side * 6.0 + Vector3.UP * 2.5, Vector3(at.x, from.y, at.z), Vector3.UP)
		if (sank or step > skip) and step % EVERY == 0 and shot < 10:
			await RenderingServer.frame_post_draw
			shot += 1
			get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [OUT, title, shot])
			print("  %s %02d: sinking %.2f s, %.2f m up, %d drops" % [title, shot, kart.sinking_left, at.y, kart.fx._smoke.count])
	controls.throttle = 0.0
	cam.queue_free()


func _wait(steps: int) -> void:
	for i in steps:
		await get_tree().physics_frame
