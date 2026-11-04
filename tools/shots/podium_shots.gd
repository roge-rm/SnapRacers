extends Node

## Pictures of the podium after a cup's last race, in the weather and at the
## time of day asked for: through the show (jumping up, the trophy coming
## down, held up, clapping and confetti), close ups of the winner and the
## field, and with the standings over it. "two" after the size is a cup for
## two ("one" for one), and then where the players finish, like 5 or 2,7.
## An optional stock kart key after the places picks player 1's kart.
## It needs a screen.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/podium_shots.tscn -- baseplate rain night [folder] [WIDTHxHEIGHT] [two] [places]

const OUT := "res://build/shots"
## When to take them, in seconds after the podium goes up.
const AT := [1.6, 4.6, 6.0, 8.0]
## When to take the close ups.
const CLOSE_AT := 8.5

var host: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cup: String = args[0] if args.size() > 0 else "baseplate"
	var weather: String = args[1] if args.size() > 1 else "clear"
	var time: String = args[2] if args.size() > 2 else "day"
	var out: String = args[3] if args.size() > 3 else OUT
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size := Vector2i(1280, 720)
	if args.size() > 4:
		size = Vector2i(int(args[4].get_slice("x", 0)), int(args[4].get_slice("x", 1)))
	DisplayServer.window_set_size(size)
	seed(1)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", weather)
	Game.settings.set_value("race", "time", time)
	var two := args.size() > 5 and args[5] == "two"
	if two:
		var stock := Game.stock_keys()
		Game.settings.set_value("race", "split", Game.SIDE_BY_SIDE)
		Game.settings.set_value("race", "kart", stock[0])
		Game.settings.set_value("race", "player_two", stock[1])
		Game.settings.set_value("player", "name", "Dan")
		Game.settings.set_value("player", "name_two", "Gina")
	if args.size() > 7:
		Game.settings.set_value("race", "kart", args[7])
	Game.start_grand_prix(cup, two)
	# Straight to the last race, before the first one's loaded.
	Game.grand_prix.round = Game.grand_prix.track_ids().size() - 1
	Game.track_path = Game.grand_prix.track_path()
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	print("on ", race.track.name)
	for i in 20:
		await get_tree().process_frame
	var order := race.racers.map(func(r): return r.name)
	order.shuffle()
	# For two, player 2 wins and player 1 comes third, so both are on the steps.
	if two:
		var one := Game.player_one_name()
		var other := Game.player_two_name()
		order = order.filter(func(n): return n != one and n != other)
		order = [other, order[0], one] + order.slice(1)
	var places := ""
	if args.size() > 6:
		places = args[6]
		var people := [Game.player_one_name(), Game.player_two_name()] if two else [Game.player_name()]
		var at := Array(places.split(",")).map(func(p): return int(p))
		people = people.slice(0, at.size())
		order = order.filter(func(n): return not people.has(n))
		# Put in the earliest place first, so the later one lands where asked.
		var by_place := range(people.size())
		by_place.sort_custom(func(a, b): return at[a] < at[b])
		for i in by_place:
			order.insert(at[i] - 1, people[i])
	Game.finish_grand_prix_race(order)
	var podium: Podium = race.podium
	DirAccess.make_dir_recursive_absolute(out)
	var start := Time.get_ticks_msec()
	var named := "%s_%s_%s%s%s_%dx%d" % [cup, weather, time, "_two" if two else "", "_" + places.replace(",", "-") if places != "" else "", size.x, size.y]
	for i in AT.size():
		while podium._time < AT[i]:
			await get_tree().process_frame
		await _save("%s/podium_%s_%d.png" % [out, named, i + 1], size)
	while podium._time < CLOSE_AT:
		await get_tree().process_frame
	# Close up on the winner from the front, and on the end of the row with
	# the sulkers, with the podium's own camera held there for a moment.
	var close := podium.camera
	var was := close.global_transform
	podium.set_process(false)
	var winner: CharacterRig = podium.drivers[0]
	var middle := winner.global_position + Vector3.UP * 0.5
	var front := was.origin - middle
	front.y = 0.0
	front = front.normalized()
	close.global_transform = Transform3D.IDENTITY.translated(middle + front * 2.4 + Vector3.UP * 0.4).looking_at(middle, Vector3.UP)
	await _settle(close)
	await _save("%s/close_winner_%s.png" % [out, named], size)
	var last: CharacterRig = podium.drivers[podium.drivers.size() - 1]
	var near: CharacterRig = podium.drivers[podium.drivers.size() - 3]
	middle = (last.global_position + near.global_position) * 0.5 + Vector3.UP * 0.1
	close.global_transform = Transform3D.IDENTITY.translated(middle + front * 2.8 + Vector3.UP * 0.5).looking_at(middle, Vector3.UP)
	await _settle(close)
	await _save("%s/close_field_%s.png" % [out, named], size)
	close.global_transform = was
	close.reset_physics_interpolation()
	podium.set_process(true)
	podium.finish()
	while not podium.still():
		await get_tree().process_frame
	for i in 10:
		await get_tree().process_frame
	await _save("%s/standings_%s.png" % [out, named], size)
	print("saved podium_%s_%s_%s in %d ms" % [cup, weather, time, Time.get_ticks_msec() - start])
	get_tree().quit()


## Lets the camera jump to where it's been put, rather than glide there.
func _settle(camera: Camera3D) -> void:
	camera.reset_physics_interpolation()
	for i in 2:
		await get_tree().physics_frame


func _save(path: String, size: Vector2i) -> void:
	RenderingServer.force_draw.call_deferred()
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	if picture.get_size() != size:
		picture.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	picture.save_png(path)
