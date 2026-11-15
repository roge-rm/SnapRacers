extends Node

## Pictures of a kart driven through a stretch of shallows on a course, from
## behind and to the side, low down. Give it the course file after --, with
## the shallows starting at the piece given after it. It needs a screen and
## saves in /srv/downloads/temp/debug/snapracers/beach as shallows_race_*.png,
## or under the name given third.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/shallows_shots.tscn -- course.json 24 shallows_v2

const OUT := "/srv/downloads/temp/debug/snapracers/beach"
## How many physics steps apart the pictures are.
const EVERY := 20


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var course: String = args[0]
	var first := int(args[1]) if args.size() > 1 else 0
	var title: String = args[2] if args.size() > 2 else "shallows_race"
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	seed(1)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	Game.racing_alone = true
	Game.show_race(course)
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await get_tree().physics_frame
	race.hud.visible = false
	race.build_up = 1.0
	await get_tree().physics_frame
	var track := race.track
	var k := 0
	while track.piece_of[k] != first:
		k += 1
	var at: float = track.distances[k] - 6.0
	print("%s, shallows from %.0f m" % [track.name, track.distances[k]])
	var kart := race.player.kart
	var controls := KartControls.new()
	kart.controls = controls
	race.player.offset = at
	kart.freeze = true
	var ahead := track.forward_at(at)
	kart.global_transform = Transform3D(Basis.looking_at(ahead, track.up_at(at)), track.point_at(at) + track.up_at(at) * 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	kart.freeze = false
	for i in 3:
		await get_tree().physics_frame
		kart.linear_velocity = ahead * 20.0
		kart.angular_velocity = Vector3.ZERO
	controls.throttle = 1.0
	var cam := Camera3D.new()
	cam.fov = 55.0
	race.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(OUT)
	var shot := 0
	var offset := at
	for step in 300:
		offset = track.offset_of(kart.global_position, offset, 30.0)
		var off := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset))
		var heading := (-kart.global_basis.z).signed_angle_to(track.forward_at(offset + 8.0), track.up_at(offset))
		controls.steer = clampf(-heading * 2.0 - off * 0.15, -1.0, 1.0)
		await get_tree().physics_frame
		var back := kart.global_basis.z
		var side := kart.global_basis.x
		if (step / EVERY) % 2 == 0:
			cam.look_at_from_position(kart.global_position + back * 6.0 + side * 2.0 + Vector3.UP * 2.0, kart.global_position + Vector3.UP * 0.3, Vector3.UP)
		else:
			cam.look_at_from_position(kart.global_position - back * 2.0 + side * 7.0 + Vector3.UP * 1.5, kart.global_position + back * 1.5 + Vector3.UP * 0.3, Vector3.UP)
		var wading := kart.wheels.filter(func(w: Kart.Wheel) -> bool: return w.wade > 0.0).size()
		if wading > 0 and step % EVERY == EVERY - 1 and shot < 6:
			await RenderingServer.frame_post_draw
			shot += 1
			get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [OUT, title, shot])
			print("  %02d: %.1f m/s, %d wheels in, planing %.2f, %d drops" % [shot, kart.linear_velocity.length(), wading, kart.wheels.map(func(w: Kart.Wheel) -> float: return w.planing).max(), kart.fx._smoke.count])
	get_tree().quit()
