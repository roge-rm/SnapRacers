extends Node

## Pictures of painted ground in a race, one scene a run, from above and from
## a kart's view. Scenes: atoll (a lagoon with two islands in it on an
## island course), river (water under a bridge), hill_lake (a lake on a
## hillside), lava (a pit and a river of it), slime, and patches (mud,
## gravel, sand and ice beside a corner). Add "night" for night. It needs a
## screen:
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/paint_shots.tscn -- lava night
## They're saved in /srv/downloads/temp/debug/snapracers/0.16/paint/m2 as
## <scene>[_night]_<view>.png.

const OUT := "/srv/downloads/temp/debug/snapracers/0.16/paint/m2"
const COURSE := "user://paint_shots.json"

var race: Race
## Each view: [name, camera position, where it looks], worked out once the
## race is built and the ground is known.
var _views: Array = []
## The middle of what's painted, and a road sample beside it.
var _focus := Vector2.ZERO
var _road := 0


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if not args.is_empty() else "atoll"
	var night := args.has("night")
	var data := _course(scene)
	var file := FileAccess.open(COURSE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "night" if night else "day")
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
	DirAccess.make_dir_recursive_absolute(OUT)
	var track := race.track
	var ground := func(at: Vector2, up: float) -> Vector3:
		return Vector3(at.x, race.builder.ground_at(at.x, at.y) + up, at.y)
	var road := track.points[_road]
	var towards := Vector2(_focus.x - road.x, _focus.y - road.z).normalized()
	var flat_road := Vector2(road.x, road.z)
	# From above, a little off to one side so it's not flat on.
	_views.append(["above", ground.call(_focus - towards * 40.0, 70.0), ground.call(_focus, 0.0)])
	# From a kart on the road beside it, looking across.
	var behind := track.points[(_road - 60 + track.points.size()) % track.points.size()]
	_views.append(["kart", road + Vector3.UP * 1.6, ground.call(_focus, 0.0)])
	_views.append(["kart_along", behind + Vector3.UP * 1.8, road + Vector3(towards.x, 0.0, towards.y) * 12.0])
	_views.append(["low", ground.call(flat_road + towards * 8.0 + Vector2(-towards.y, towards.x) * 30.0, 3.0), ground.call(_focus, 0.0)])
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 2000.0
	race.add_child(cam)
	cam.current = true
	var tag := scene + ("_night" if night else "")
	for view: Array in _views:
		cam.look_at_from_position(view[1], view[2], Vector3.UP)
		for i in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [OUT, tag, view[0]])
		print("saved %s_%s" % [tag, view[0]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COURSE))
	get_tree().quit()


## The course for a scene with its paint, setting _focus and _road.
func _course(scene: String) -> Dictionary:
	var id: String = {"atoll": "peach_pit", "river": "lakeshore_plunge", "hill_lake": "pine_hill_leap",
		"lava": "magma_mile", "slime": "foundry_flats", "patches": "peach_pit"}.get(scene, "peach_pit")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(id)))
	data.name = "Paint shots " + scene
	if scene == "atoll":
		data.theme = "island"
		data.hills = 0.0
	var track := TrackPath.from_dict(data)
	var areas := PaintedAreas.new()
	match scene:
		"atoll":
			_atoll(areas, track)
		"river":
			_river(areas, track)
		"hill_lake":
			_hill_lake(areas, track)
		"lava":
			_lava(areas, track)
		"slime":
			var spot := _beside(track, 0.3, 34.0, 3, 2, "slime")
			_blob(areas, track, spot, 3, 2, "slime")
			_focus = spot
		"patches":
			_patches(areas, track)
	data.paint = areas.to_dict()
	print("%s: %d squares on %s" % [scene, areas.count(), id])
	return data


## Paints w by h squares round a spot, the ones the road allows.
func _blob(areas: PaintedAreas, track: TrackPath, at: Vector2, w: int, h: int, type: String) -> void:
	var first := PaintedAreas.square_at(at.x - (w - 1) * PaintedAreas.CELL * 0.5, at.y - (h - 1) * PaintedAreas.CELL * 0.5)
	for z in h:
		for x in w:
			var square := first + Vector2i(x, z)
			if PaintedAreas.allowed(square, type, track):
				areas.set_square(square, type)


## The first spot from `along` of the way round on, `out` metres to one side
## of the road, where a w by h blob of the type fits whole. Sets _road.
func _beside(track: TrackPath, along: float, out: float, w: int, h: int, type: String) -> Vector2:
	var count := track.points.size()
	for n in range(0, count, 5):
		var k := (int(count * along) + n) % count
		for side in [-1.0, 1.0]:
			var p: Vector3 = track.points[k] + track.rights[k] * side * out
			var test := PaintedAreas.new()
			_blob(test, track, Vector2(p.x, p.z), w, h, type)
			if test.count() == w * h:
				_road = k
				return Vector2(p.x, p.z)
	return Vector2.ZERO


## Everything inside the loop of road on an island, but two islands of four
## squares each.
func _atoll(areas: PaintedAreas, track: TrackPath) -> void:
	var loop := PackedVector2Array()
	for p in track.points:
		loop.append(Vector2(p.x, p.z))
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in loop:
		lo = lo.min(p)
		hi = hi.max(p)
	var middles: Array[Vector2] = []
	for z in range(floori(lo.y / PaintedAreas.CELL), ceili(hi.y / PaintedAreas.CELL)):
		for x in range(floori(lo.x / PaintedAreas.CELL), ceili(hi.x / PaintedAreas.CELL)):
			var square := Vector2i(x, z)
			var middle := PaintedAreas.middle_of(square)
			if Scenery.inside(loop, middle) and PaintedAreas.allowed(square, "water", track):
				areas.set_square(square, "water")
				middles.append(middle)
	var sum := Vector2.ZERO
	for m in middles:
		sum += m
	_focus = sum / maxf(middles.size(), 1.0)
	# Two islands, either side of the middle.
	var keys := areas.squares.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return PaintedAreas.middle_of(a).distance_to(_focus) < PaintedAreas.middle_of(b).distance_to(_focus))
	for pick in [keys.size() / 6, keys.size() / 3]:
		var corner: Vector2i = keys[pick]
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			areas.set_square(corner + d, "")
	_road = _nearest(track, _focus)


## A river two squares wide straight across under the highest raised road.
func _river(areas: PaintedAreas, track: TrackPath) -> void:
	var best := 0
	for k in track.points.size():
		var lift := track.points[k].y - track.grounds[k]
		if track.ups[k].y > 0.95 and lift > 4.0 and lift < 9.0 and absf(track.bend_at(track.distances[k])) < 0.01:
			best = k
			break
	var p := track.points[best]
	var across := Vector2(track.rights[best].x, track.rights[best].z)
	var along := Vector2(track.forwards[best].x, track.forwards[best].z)
	for d in range(-120, 121, 4):
		for w in [-3.0, 3.0]:
			var at: Vector2 = Vector2(p.x, p.z) + across * d + along * w
			var square := PaintedAreas.square_at(at.x, at.y)
			if PaintedAreas.allowed(square, "water", track):
				areas.set_square(square, "water")
	_focus = Vector2(p.x, p.z) + across * 30.0
	# The kart's view comes from the road just before the bridge.
	_road = (best - 20 + track.points.size()) % track.points.size()


## A lake of five by four squares on the steepest bit of hillside near the
## road.
func _hill_lake(areas: PaintedAreas, track: TrackPath) -> void:
	var best := Vector2.ZERO
	var steepest := -1.0
	for k in range(0, track.points.size(), 15):
		for side in [-1.0, 1.0]:
			var p: Vector3 = track.points[k] + track.rights[k] * side * 55.0
			var slope := absf(track.ground_height(p.x + 16.0, p.z) - track.ground_height(p.x - 16.0, p.z)) + absf(track.ground_height(p.x, p.z + 16.0) - track.ground_height(p.x, p.z - 16.0))
			var test := PaintedAreas.new()
			_blob(test, track, Vector2(p.x, p.z), 5, 4, "water")
			if test.count() >= 18 and slope > steepest:
				steepest = slope
				best = Vector2(p.x, p.z)
				_road = k
	_blob(areas, track, best, 5, 4, "water")
	_focus = best


## A pit of three by three squares and a river of lava a square wide along
## the road further on.
func _lava(areas: PaintedAreas, track: TrackPath) -> void:
	var pit := _beside(track, 0.55, 36.0, 3, 3, "lava")
	_blob(areas, track, pit, 3, 3, "lava")
	_focus = pit
	var from := int(track.points.size() * 0.6)
	for k in range(from, from + 120, 4):
		var p := track.points[k % track.points.size()] + track.rights[k % track.points.size()] * 30.0
		var square := PaintedAreas.square_at(p.x, p.z)
		if PaintedAreas.allowed(square, "lava", track):
			areas.set_square(square, "lava")


## Two by two of each slow type along the outside of the sharpest corner,
## right up to the kerb.
func _patches(areas: PaintedAreas, track: TrackPath) -> void:
	var count := track.points.size()
	var turn := func(k: int) -> float: return track.forwards[(k - 4 + count) % count].cross(track.forwards[(k + 4) % count]).y
	var sharpest := 0
	for k in count:
		if absf(turn.call(k)) > absf(turn.call(sharpest)):
			sharpest = k
	# The outside of a left turn is on the right (see Scenery._trackside()).
	var outside := signf(turn.call(sharpest))
	var types := ["mud", "gravel", "sand", "ice"]
	var sum := Vector2.ZERO
	for n in types.size():
		var k := (sharpest + (n - 2) * 18 + track.points.size()) % track.points.size()
		var p := track.points[k] + track.rights[k] * outside * (track.width * 0.5 + TrackPath.KERB + 8.0)
		_blob(areas, track, Vector2(p.x, p.z), 2, 2, types[n])
		sum += Vector2(p.x, p.z)
	_focus = sum / types.size()
	_road = (sharpest - 40 + track.points.size()) % track.points.size()


func _nearest(track: TrackPath, at: Vector2) -> int:
	var best := 0
	for k in track.points.size():
		if Vector2(track.points[k].x, track.points[k].z).distance_to(at) < Vector2(track.points[best].x, track.points[best].z).distance_to(at):
			best = k
	return best
