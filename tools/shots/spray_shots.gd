extends Node

## Pictures of the spray from a kart driven straight through the deepest
## puddle on a rainy course once it's full, from behind and to the side,
## low down. It needs a screen, and saves in build/shots, or in OUT_DIR if
## that's set.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/spray_shots.tscn -- peach_pit [name]

const OUT := "res://build/shots"
## How many physics steps apart the pictures are.
const EVERY := 6


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "peach_pit"
	var name: String = args[1] if args.size() > 1 else course
	var out: String = OS.get_environment("OUT_DIR") if OS.has_environment("OUT_DIR") else OUT
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	seed(1)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "rain")
	Game.settings.set_value("race", "time", "day")
	Game.racing_alone = true
	Game.show_race(Game.TRACKS + "/" + course + ".json")
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
	var puddles: Puddles = race.builder.puddles
	# The biggest one on a fairly straight bit of road.
	var best := -1
	for i in puddles.spots.size():
		var o: float = puddles._offset[i]
		if o < 0.0 or absf(puddles._from_middle[i]) > 3.5 or track.forward_at(o - 40.0).dot(track.forward_at(o + 10.0)) < 0.95:
			continue
		if best < 0 or puddles.spots[i][1] > puddles.spots[best][1]:
			best = i
	var at: float = puddles._offset[best] - 40.0
	var across: float = puddles._from_middle[best]
	print("puddle %d at %.0f m, %.1f m right, reaching %.1f m" % [best, puddles._offset[best], across, puddles.spots[best][1]])
	var kart := race.player.kart
	var controls := KartControls.new()
	kart.controls = controls
	race.player.offset = at
	kart.freeze = true
	var ahead := track.forward_at(at)
	kart.global_transform = Transform3D(Basis.looking_at(ahead, track.up_at(at)), track.point_at(at) + track.right_at(at) * across + track.up_at(at) * 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	kart.freeze = false
	for i in 3:
		await get_tree().physics_frame
		kart.linear_velocity = ahead * 22.0
		kart.angular_velocity = Vector3.ZERO
	controls.throttle = 1.0
	var cam := Camera3D.new()
	cam.fov = 55.0
	race.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(out)
	var shot := 0
	var offset := at
	for step in 200:
		# Held on the puddle's line.
		offset = track.offset_of(kart.global_position, offset, 30.0)
		var off := (kart.global_position - track.point_at(offset)).dot(track.right_at(offset)) - across
		var heading := (-kart.global_basis.z).signed_angle_to(track.forward_at(offset + 8.0), track.up_at(offset))
		controls.steer = clampf(-heading * 2.0 - off * 0.15, -1.0, 1.0)
		await get_tree().physics_frame
		var back := kart.global_basis.z
		var side := kart.global_basis.x
		# Every other picture from out to the side, a little ahead.
		if (step / EVERY) % 2 == 0:
			cam.look_at_from_position(kart.global_position + back * 5.0 + side * 2.5 + Vector3.UP * 1.3, kart.global_position + Vector3.UP * 0.3, Vector3.UP)
		else:
			cam.look_at_from_position(kart.global_position - back * 2.0 + side * 6.0 + Vector3.UP * 1.0, kart.global_position + back * 1.5 + Vector3.UP * 0.3, Vector3.UP)
		var wet := kart.wheels.filter(func(w: Kart.Wheel) -> bool: return w.water > 0.0).size()
		if wet > 0 and step % EVERY == 0:
			await RenderingServer.frame_post_draw
			var picture := get_viewport().get_texture().get_image()
			if picture.get_size() != Vector2i(1280, 720):
				picture.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
			shot += 1
			picture.save_png("%s/spray_%s_%02d.png" % [out, name, shot])
			print("  %02d: step %d, %.1f m/s, %d wheels in water (deepest %.2f, planing %.2f), %d drops" % [shot, step, kart.linear_velocity.length(), wet, kart.wheels.map(func(w: Kart.Wheel) -> float: return w.water).max(), kart.wheels.map(func(w: Kart.Wheel) -> float: return w.planing).max(), kart.fx._smoke.count])
	print("saved spray_%s" % name)
	get_tree().quit()
