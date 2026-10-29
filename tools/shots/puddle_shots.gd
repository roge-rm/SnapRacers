extends Node

## Pictures of the puddles on a rainy course at a few points in their
## build-up: from above at two spots along the road where most of them lie,
## straight down on the two that run into each other most, and from low
## down on the road. It needs a screen, and saves in build/shots, or in
## OUT_DIR if that's set.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/puddle_shots.tscn -- peach_pit [name] [build-up ...]

const OUT := "res://build/shots"
const BUILD_UPS := [0.3, 0.6, 1.0]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "peach_pit"
	var name: String = args[1] if args.size() > 1 else course
	var steps: Array = BUILD_UPS if args.size() <= 2 else Array(args.slice(2)).map(func(value): return float(value))
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
	for i in 10:
		await get_tree().process_frame
	var track := race.track
	var puddles: Puddles = race.builder.puddles
	var spots := _spots(track, puddles)
	var pair := _pair(puddles)
	print("%d puddles, the two most run together at %s" % [puddles.spots.size(), pair])
	var cam := Camera3D.new()
	cam.fov = 60.0
	race.add_child(cam)
	# The karts out of the way and the HUD hidden, so the road shows.
	for racer in race.racers:
		racer.kart.freeze = true
		racer.kart.visible = false
	for layer in race.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	DirAccess.make_dir_recursive_absolute(out)
	for step in steps:
		race.build_up = maxf(race.build_up, step)
		for i in 5:
			await get_tree().physics_frame
		var views: Array = []
		for at in spots:
			views.append([track.point_at(at) + track.up_at(at) * 7.0 - track.forward_at(at) * 4.0, track.point_at(at + 22.0)])
		if not pair.is_empty():
			var middle: Vector3 = (puddles.spots[pair[0]][0] + puddles.spots[pair[1]][0]) * 0.5
			var at := track.offset_of(middle)
			views.append([middle + Vector3.UP * 16.0 - track.forward_at(at) * 2.0, middle])
		var low: float = spots[0]
		views.append([track.point_at(low - 4.0) + track.up_at(low) * 1.6, track.point_at(low + 18.0)])
		for n in views.size():
			cam.look_at_from_position(views[n][0], views[n][1], Vector3.UP)
			cam.current = true
			for i in 3:
				await get_tree().process_frame
			RenderingServer.force_draw.call_deferred()
			await RenderingServer.frame_post_draw
			var picture := get_viewport().get_texture().get_image()
			picture.convert(Image.FORMAT_RGB8)
			if picture.get_size() != Vector2i(1280, 720):
				picture.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
			picture.save_png("%s/puddles_%s_%d_%03d.png" % [out, name, n + 1, roundi(step * 100.0)])
	print("saved puddles_%s" % name)
	get_tree().quit()


## Two places along the road, well apart, with the most puddle just ahead
## when they're full.
func _spots(track: TrackPath, puddles: Puddles) -> Array:
	var scores: Array = []
	var o := 0.0
	while o < track.length:
		var count := 0.0
		for i in puddles.spots.size():
			var ahead := fposmod(puddles.spots[i][0].distance_to(track.point_at(o)) if puddles._offset.is_empty() else puddles._offset[i] - o, track.length)
			if ahead > 6.0 and ahead < 30.0:
				count += puddles.spots[i][1] * puddles.spots[i][1]
		if track.forward_at(o).dot(track.forward_at(o + 26.0)) > 0.9:
			scores.append([count, o])
		o += 10.0
	scores.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var picked: Array = []
	for s in scores:
		var far := true
		for p in picked:
			var gap := absf(s[1] - p)
			far = far and minf(gap, track.length - gap) > 150.0
		if far:
			picked.append(s[1])
		if picked.size() == 2:
			break
	return picked


## The biggest two that run into each other when full, side by side:
## water all the way along the line between their middles.
func _pair(puddles: Puddles) -> Array:
	var best := []
	var most := 0.0
	for i in puddles.spots.size():
		for j in range(i + 1, puddles.spots.size()):
			var a: Array = puddles.spots[i]
			var b: Array = puddles.spots[j]
			if a[0].distance_to(b[0]) > a[1] + b[1] or absf(a[0].y - b[0].y) > 1.0 or a[1] + b[1] < most:
				continue
			# Side by side across the road shows the join better than end to
			# end along an edge.
			if absf(puddles._from_middle[i] - puddles._from_middle[j]) < 1.5:
				continue
			var joined := true
			for n in 21:
				var at: Vector3 = a[0].lerp(b[0], n / 20.0)
				joined = joined and maxf(puddles._dip_at(i, at), puddles._dip_at(j, at)) > 0.05
			if joined:
				most = a[1] + b[1]
				best = [i, j]
	return best
