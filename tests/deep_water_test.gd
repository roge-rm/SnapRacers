extends Node

## Deep water: on an island course with a lake put down by hand, a kart
## driven into the lake, or off the road into the sea, splashes, sinks below
## the surface and is put back on the road where it left it. One driving
## along shallows road is never reset.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . tests/deep_water_test.tscn

const COURSE := "user://deep_water_test.json"

var failures := 0
var host: Node
var race: Race
var human: Race.Racer
var splashes := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	var saved := Game.settings.encode_to_text()
	Game.settings.set_value("race", "kart", "kart_kid")
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	await _run()
	Game.settings.clear()
	Game.settings.parse(saved)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COURSE))
	print("All deep water checks passed." if failures == 0 else "%d deep water checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Peach Pit as an island, every piece shallows, with a lake well clear of
## the road. Returns where the lake is.
func _write_course() -> Vector2:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
	data.name = "Deep water test"
	data.theme = "island"
	for piece: Dictionary in data.pieces:
		piece["surface"] = "shallows"
	var track := TrackPath.from_dict(data)
	var lake := Vector2.INF
	for k in range(0, track.points.size(), 10):
		for side in [-1.0, 1.0]:
			var at: Vector3 = track.points[k] + track.rights[k] * side * 42.0
			var clear := true
			for p in track.points:
				clear = clear and Vector2(p.x - at.x, p.z - at.z).length() > 38.0
			if clear:
				lake = Vector2(at.x, at.z)
				break
		if lake != Vector2.INF:
			break
	data.landmarks = [{"prop": "lake", "at": [lake.x, lake.y], "facing": 0}]
	var file := FileAccess.open(COURSE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	return lake


func _run() -> void:
	var lake := _write_course()
	check(lake != Vector2.INF, "there's room for a lake beside the road")
	var previous := Game._screen
	Game.start_race(COURSE)
	for i in 300:
		await get_tree().process_frame
		if Game._screen is Race and Game._screen != previous:
			break
	race = Game._screen as Race
	check(race != null, "the race starts")
	if race == null:
		return
	await frames(5)
	race.started = true
	race.time = 10.0
	race.train_clock.now = race.time
	human = race.humans[0]
	human.input.set_physics_process(false)
	human.kart.splashed.connect(func() -> void: splashes += 1)
	var track := race.track
	var water := race.builder.water
	# Everyone else waits half a lap away, out of the way.
	human.kart.locked = false
	var parked := 0
	for racer in race.racers:
		if racer == human:
			continue
		racer.kart.locked = true
		racer.kart.global_transform = track.place_at(track.length * 0.5 + parked * 8.0)
		racer.offset = track.length * 0.5 + parked * 8.0
		parked += 1

	var lake_at := Vector3(lake.x, race.builder.ground_at(lake.x, lake.y), lake.y)
	check(is_finite(water.level_at(lake_at + Vector3.UP * 0.5)), "the middle of the lake is deep water")
	var dry := true
	for k in range(0, track.points.size(), 5):
		dry = dry and not is_finite(water.level_at(track.points[k] + track.ups[k] * 0.5))
	check(dry, "the shallows road is never deep water")

	# Along the shallows at speed it's never reset.
	var start := track.offset_of(lake_at)
	await _put(start, 0.0, track.forward_at(start) * 15.0)
	human.input.controls.throttle = 1.0
	var reset := false
	var on_water := 0
	human.kart.was_reset.connect(func() -> void: reset = true)
	for i in 180:
		await frames(1)
		for w: Kart.Wheel in human.kart.wheels:
			if w.grounded and w.surface == "shallows":
				on_water += 1
	human.input.controls.throttle = 0.0
	check(on_water > 0 and not reset and splashes == 0 and human.kart.sinking_left <= 0.0, "driving along the shallows it isn't reset (%d wheel steps on them)" % on_water)

	# Into the lake from the grass beside it, inside the room kept clear
	# round it, from somewhere with nothing in the way.
	var space := human.kart.get_world_3d().direct_space_state
	var grass := Vector3.INF
	for n in 16:
		var at := lake_at + Vector3(cos(n * TAU / 16.0), 0.0, sin(n * TAU / 16.0)) * 19.0
		at.y = race.builder.ground_at(at.x, at.z)
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 5.0, Kart.LAYER_WORLD))
		var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, lake_at + Vector3.UP * 0.8, Kart.LAYER_WORLD))
		var near := track.point_at(track.offset_of(at)).distance_to(at) < Race.LOST - 5.0
		if near and not down.is_empty() and absf(down.position.y - at.y) < 0.3 and across.is_empty() and not is_finite(water.level_at(at + Vector3.UP * 0.5)):
			grass = at
			break
	check(grass != Vector3.INF, "there's clear dry grass by the lake")
	if grass != Vector3.INF:
		await _drive_in(track.offset_of(lake_at), grass, lake_at, "the lake")

	# Into the sea, driven off the road, across the sand and on out, from a
	# straight bit with the sea close by and nothing in the way.
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
				if is_finite(water.level_at(at + Vector3.UP * 0.5)):
					var low := track.points[k] + Vector3.UP * 0.8
					var aim := at + track.forwards[k] * 12.0 + Vector3.UP * 0.8
					var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, aim, Kart.LAYER_WORLD)).is_empty()
					if clear and far < nearest:
						nearest = far
						sea_from = track.distances[k]
						sea_at = at
						out = track.rights[k] * side
					break
	check(sea_at != Vector3.INF and nearest < Race.LOST - 10.0, "there's sea close by the road (%.0f m from the middle)" % nearest)
	if sea_at != Vector3.INF:
		var from := track.point_at(sea_from)
		await _drive_in(sea_from, from, sea_at + track.forward_at(sea_from) * 12.0 + out * 10.0, "the sea")


## Puts the kart on the road at `offset`, so it knows where it left it, then
## drives it from `from` towards `towards` and checks it splashes, drops
## under the water and is put back on the road.
func _drive_in(offset: float, from: Vector3, towards: Vector3, what: String) -> void:
	var track := race.track
	var kart := human.kart
	await frames(int(Kart.RESET_SLOWDOWN_TIME * 60.0))
	await _put(offset, 0.0, Vector3.ZERO)
	var left := human.road_offset
	var had := splashes
	var aim := Vector3(towards.x - from.x, 0.0, towards.z - from.z).normalized()
	kart.global_transform = Transform3D(Basis.looking_at(aim, Vector3.UP), from + Vector3.UP * 0.6)
	kart.linear_velocity = aim * 14.0
	kart.on_road = false
	human.input.controls.throttle = 1.0
	var lowest := INF
	var level := NAN
	var sank := false
	for i in 60 * 6:
		await frames(1)
		if kart.sinking_left > 0.0:
			sank = true
			var here := race.builder.water.level_at(Vector3(kart.global_position.x, level if is_finite(level) else kart.global_position.y, kart.global_position.z))
			if is_finite(here):
				level = here
			lowest = minf(lowest, kart.global_position.y)
		elif sank:
			break
	human.input.controls.throttle = 0.0
	check(splashes == had + 1, "into %s it splashes once (%d)" % [what, splashes - had])
	check(sank and is_finite(level) and lowest < level - 0.5, "and drops under the surface (%.2f m below)" % (level - lowest))
	await frames(3)
	var across := (kart.global_position - track.point_at(human.offset)).dot(track.right_at(human.offset))
	var back := wrapf(human.offset - left, -track.length * 0.5, track.length * 0.5)
	check(track.on_road_across(human.offset, across) and absf(back) < 30.0, "then it's put back on the road where it left it (%.0f m from %.0f, %.1f m across)" % [back, left, across])
	check(kart.slowdown_left > 0.0 and kart.collision_mask & Kart.LAYER_WORLD != 0, "slowed, and on the ground again (%.2f s)" % kart.slowdown_left)


## Puts the kart down at `offset`, `across` metres right of the middle,
## going at `velocity`, and lets it settle.
func _put(offset: float, across: float, velocity: Vector3) -> void:
	var track := race.track
	var kart := human.kart
	var spot := track.place_at(offset)
	spot.origin += spot.basis.x * across + spot.basis.y * 0.6
	kart.global_transform = spot
	kart.linear_velocity = velocity
	kart.angular_velocity = Vector3.ZERO
	human.offset = offset
	await frames(30 if velocity == Vector3.ZERO else 2)
