extends Node

## Takes pictures of marbles, spikes and a brick wall dropped on a corkscrew
## or loop, where its road faces sideways and where it's upside down, from a
## way off and close up. It needs a screen, and saves in build/shots, or the
## folder after --, then the piece.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/sticky_drop_shots.tscn -- /some/folder corkscrew

var out := "res://build/shots"


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func shot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	var piece: String = args[1] if args.size() > 1 else "corkscrew"
	DirAccess.make_dir_recursive_absolute(out)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#9cc8e8")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.6, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var track := TrackPath.from_dict({ "pieces": [
		{ "type": "straight", "length": 5 },
		{ "type": piece, "side": "right" },
		{ "type": "straight", "length": 4 },
	] })
	add_child(TrackBuilder.new(track))
	await frames(2)
	var side := -1.0
	var top := -1.0
	for k in track.points.size():
		if track.piece_of[k] != 1:
			continue
		if side < 0.0 or absf(track.ups[k].y) < absf(track.up_at(side).y):
			side = track.distances[k]
		if top < 0.0 or track.ups[k].y < track.up_at(top).y:
			top = track.distances[k]
	var camera := Camera3D.new()
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	for spot in [["side", side], ["top", top]]:
		var things: Array[Node3D] = []
		for kind in ["spikes", "marbles", "wall"]:
			var shift: float = {"spikes": -7.0, "marbles": 0.0, "wall": 8.0}[kind]
			var kart := Kart.new()
			kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
			kart.transform = track.place_at(spot[1] + 5.0 + shift, 0.4)
			kart.freeze = true
			add_child(kart)
			await frames(1)
			var thing: Node3D = BrickWall.drop_behind(kart) if kind == "wall" else BrickTrap.drop_behind(kart, kind)
			add_child(thing)
			things.append(thing)
			kart.queue_free()
		await frames(30)
		# Well back along the road, then side-on close to each.
		var middle := track.frame_at(spot[1])
		camera.global_position = track.point_at(spot[1] - 22.0) + track.up_at(spot[1] - 22.0) * 5.0
		camera.look_at(middle.origin, middle.basis.y)
		await shot("%s_%s" % [piece, spot[0]])
		for thing in things:
			var name: String = thing.kind if thing is BrickTrap else "wall"
			var up := thing.global_basis.y
			var across := thing.global_basis.x
			camera.global_position = thing.global_position + across * 7.0 + up * 1.2
			camera.look_at(thing.global_position, up)
			await shot("%s_%s_%s" % [piece, spot[0], name])
		for thing in things:
			thing.queue_free()
		await frames(2)
	print("saved ", piece)
	get_tree().quit()
