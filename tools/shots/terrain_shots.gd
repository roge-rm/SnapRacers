extends Node

## Pictures of tests/data/ground_course.json, a loop on a hand-made ground
## map: the cutting, the embankment, the bridge over the valley, the lake on
## the hillside, the river of pools and the high edge of the ground. Add a
## theme's name to race it there instead of the orchard, like alps_meadow to
## see the far floor at the edge. It needs a screen:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/terrain_shots.tscn -- alps_meadow
## They're saved in /srv/downloads/temp/debug/snapracers/terrain/ as
## <theme>_<view>.png.

const FOLDER := "/srv/downloads/temp/debug/snapracers/terrain"
const SOURCE := "res://tests/data/ground_course.json"
const COURSE := "user://terrain_shots.json"

var race: Race


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var args := OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var theme: String = args[0] if not args.is_empty() else data.theme
	data.theme = theme
	var file := FileAccess.open(COURSE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
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
	for racer in race.racers:
		racer.kart.locked = true
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var at := func(x: float, z: float, up: float) -> Vector3:
		return Vector3(x, race.builder.ground_at(x, z) + up, z)
	var road := func(x: float, z: float, up: float) -> Vector3:
		var k := _nearest(race.track, x, z)
		return race.track.points[k] + Vector3.UP * up
	# Each view: [name, camera, where it looks].
	var views := [
		["cutting", road.call(288.0, -10.0, 2.0), road.call(288.0, -110.0, 1.0)],
		["cutting_above", at.call(240.0, -40.0, 30.0), at.call(310.0, -85.0, 0.0)],
		["embankment", at.call(250.0, -215.0, 6.0), road.call(288.0, -160.0, -3.0)],
		["embankment_road", road.call(288.0, -100.0, 2.0), road.call(288.0, -220.0, 0.0)],
		["bridge", at.call(-60.0, -150.0, 3.0), road.call(0.0, -160.0, 0.0)],
		["bridge_road", road.call(0.0, -40.0, 2.0), road.call(0.0, -170.0, 0.0)],
		["river", at.call(120.0, -120.0, 25.0), at.call(120.0, -164.0, 0.0)],
		["lake", at.call(110.0, -230.0, 20.0), at.call(155.0, -282.0, 0.0)],
		["lake_low", road.call(100.0, -368.0, 2.0), at.call(155.0, -282.0, 0.0)],
		["edge", Vector3(300.0, 70.0, 120.0), Vector3(430.0, -10.0, -120.0)],
		["edge_west", Vector3(-20.0, 50.0, -120.0), Vector3(-140.0, -10.0, -220.0)],
		["overview", Vector3(140.0, 380.0, 260.0), Vector3(140.0, 0.0, -160.0)],
	]
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 3000.0
	race.add_child(cam)
	cam.current = true
	for view: Array in views:
		cam.look_at_from_position(view[1], view[2], Vector3.UP)
		# From far off the near plane goes out too, or the road and the ground
		# just under it flicker into each other.
		cam.near = 5.0 if view[0] in ["overview", "edge", "edge_west"] else 0.05
		for i in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [FOLDER, theme, view[0]])
		print("saved %s_%s" % [theme, view[0]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COURSE))
	get_tree().quit()


func _nearest(track: TrackPath, x: float, z: float) -> int:
	var best := 0
	var gap := INF
	for k in track.points.size():
		var d := Vector2(track.points[k].x - x, track.points[k].z - z).length()
		if d < gap:
			gap = d
			best = k
	return best
