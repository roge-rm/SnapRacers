extends Node

## Takes a picture of the first row of power-up boxes on a course, from the
## driver's seat a little way back, and a close up. Name the look after the
## course: crate, stud or bag (see PowerupLook). It needs a screen, and saves
## in /tmp/snapracers-build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/box_shots.tscn -- peach_pit crate

const OUT := "/tmp/snapracers-build/shots"


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "peach_pit"
	PowerupField.look = args[1] if args.size() > 1 else "crate"
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.racing_alone = true
	Game.start_practice(Tracks.path_of(course))
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await frames(10)
	await frames(90)
	race.player.hud.visible = false
	var row := race.boxes.spots[1]
	var camera := Camera3D.new()
	race.add_child(camera)
	var back := row.basis.z
	camera.global_position = row.origin + back * 14.0 + row.basis.y * 1.6
	camera.look_at(row.origin, row.basis.y)
	camera.make_current()
	await frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/boxes_%s.png" % [OUT, PowerupField.look])
	camera.global_position = row.origin + back * 3.2 + row.basis.y * 0.6 + row.basis.x * 0.8
	camera.look_at(row.origin, row.basis.y)
	await frames(10)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/boxes_%s_close.png" % [OUT, PowerupField.look])
	print("saved ", PowerupField.look)
	get_tree().quit()
