extends Node

## Deep water: on an island course with a lake put down by hand, a kart
## driven into the lake, or off the road into the sea, splashes, sinks below
## the surface and is put back on the road where it left it. Into painted
## lava or slime it burns the same way, and the kart is told which. One
## driving along shallows road is never reset. Painted mud slows a kart more
## than the grass and ice holds it less, and an online splash says what it
## went into.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . tests/deep_water_test.tscn

const COURSE := "user://deep_water_test.json"

var failures := 0
var host: Node
var race: Race
var human: Race.Racer
var splashes := 0
var splashed_kind := ""
## The middles of the painted lava and slime pools, as x, z.
var pools: Array[Vector2] = []


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
	_painted()
	await _slow_types()
	_net_kinds()
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
	# A lava pool and a slime pool of three by three squares, on the island,
	# clear of the road and the lake.
	pools.clear()
	var plain := TrackBuilder.new(track)
	plain.sky = false
	plain.scenery = "none"
	host.add_child(plain)
	var areas := PaintedAreas.new()
	for type in ["lava", "slime"]:
		for k in range(0, track.points.size(), 7):
			var found := false
			for side in [1.0, -1.0]:
				var p: Vector3 = track.points[k] + track.rights[k] * side * 30.0
				var middle := PaintedAreas.square_at(p.x, p.z)
				var spot := PaintedAreas.middle_of(middle)
				var clear := spot.distance_to(lake) > 70.0
				for other in pools:
					clear = clear and spot.distance_to(other) > 60.0
				for q in track.points:
					clear = clear and Vector2(q.x - spot.x, q.z - spot.y).length() > 26.0
				# Not far below the road, or it counts as fallen off first.
				if not clear or absf(plain.ground_at(spot.x, spot.y) - track.points[k].y) > 1.5:
					continue
				var trial := areas.duplicate_areas()
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						trial.set_square(middle + Vector2i(dx, dz), type)
				data.paint = trial.to_dict()
				if Scenery.paint_of(TrackPath.from_dict(data)).count() == trial.count():
					areas = trial
					pools.append(spot)
					found = true
					break
			if found:
				break
	plain.free()
	data.paint = areas.to_dict()
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
	human.kart.splashed.connect(func(kind: String) -> void:
		splashes += 1
		splashed_kind = kind)
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
		await _drive_in(track.offset_of(lake_at), grass, lake_at, "the lake", "water")

	# Into lava and slime from the grass beside them.
	check(pools.size() == 2, "there's room for a lava pool and a slime pool")
	for n in pools.size():
		var type: String = ["lava", "slime"][n]
		var pool_at := Vector3(pools[n].x, race.builder.ground_at(pools[n].x, pools[n].y), pools[n].y)
		check(water.kind_at(pool_at + Vector3.UP * 0.3) == type, "the middle of the %s pool is %s (%s)" % [type, type, water.kind])
		var shore := _shore(pool_at, 17.0)
		check(shore != Vector3.INF, "there's clear dry grass by the %s" % type)
		if shore != Vector3.INF:
			await _drive_in(track.offset_of(pool_at), shore, pool_at, "the " + type, type)

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
					# Lava or slime on this side is in the way.
					if water.kind != "water":
						break
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
		await _drive_in(sea_from, from, sea_at + track.forward_at(sea_from) * 12.0 + out * 10.0, "the sea", "water")


## Painted water and lava beside Peach Pit, flat and on hills: the middle of
## each is deep at the level it's drawn at, lava says it burns, its edge band
## and the road aren't deep, and on hills the ground dips under the pool.
func _painted() -> void:
	for hills in [0.0, 16.0]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
		data.hills = hills
		var track := TrackPath.from_dict(data)
		# Two pools of three by three squares, 40 m out on each side of a
		# spot a quarter of the way round.
		var k := track.points.size() / 4
		var spots: Array[Vector2] = []
		var areas := PaintedAreas.new()
		for n in 2:
			var p := track.points[k] + track.rights[k] * (40.0 if n == 0 else -40.0)
			var middle := PaintedAreas.square_at(p.x, p.z)
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					areas.set_square(middle + Vector2i(dx, dz), "water" if n == 0 else "lava")
			spots.append(PaintedAreas.middle_of(middle))
		data.paint = areas.to_dict()
		track = TrackPath.from_dict(data)
		var builder := TrackBuilder.new(track)
		builder.sky = false
		host.add_child(builder)
		var water := builder.water
		var what := "on hills" if hills > 0.0 else "on the flat"
		for n in 2:
			var at := spots[n]
			var top := water.paint_top(at.x, at.y)
			var ground := builder.ground_at(at.x, at.y)
			var level := water.level_at(Vector3(at.x, ground + 0.3, at.y))
			check(is_finite(level) and is_equal_approx(level, top) and ground < top, "%s: painted %s is deep in its middle at the level it's drawn (%.2f, ground %.2f)" % [what, ["water", "lava"][n], level, ground])
			check(water.kind == ["water", "lava"][n] and PaintedAreas.effect_of(water.kind) == ["sink", "burn"][n], "and it's %s, which %ss" % [water.kind, PaintedAreas.effect_of(water.kind)])
			# Out in its edge band, 12.8 m from the middle of the pool.
			var band := at + Vector2(12.8, 0.0)
			check(not is_finite(water.level_at(Vector3(band.x, builder.ground_at(band.x, band.y) + 0.3, band.y))), "%s: its edge band isn't deep" % what)
			check(not is_finite(water.level_at(Vector3(at.x, top + 3.0, at.y))), "%s: well above it isn't" % what)
			if hills > 0.0:
				check(ground < top - Terrain.BASIN * 0.5, "the ground dips under it (%.2f below)" % (top - ground))
		var dry := true
		for i in range(0, track.points.size(), 3):
			dry = dry and not is_finite(water.level_at(track.points[i] + track.ups[i] * 0.5))
		check(dry and water.kind == "", "%s: the road is never deep" % what)
		builder.free()
	_most_squares()


## A share code with the most squares a course can have, every other square
## in mixed types for the most edges, comes in and builds, and one more
## square is turned away.
func _most_squares() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
	data.hills = 16.0
	var types := PaintedAreas.TYPES.keys()
	for extra in [1, 0]:
		var runs := []
		for k in PaintedAreas.MOST_SQUARES + extra:
			runs.append([k / 40 - 20, (k % 40) * 2 - 40, 1, types[k % types.size()]])
		data.paint = {"cell": 8.0, "runs": runs}
		var read := Sharing.read(Sharing.code_for(data))
		if extra == 1:
			check(read.has("why"), "a code with %d squares is turned away" % (PaintedAreas.MOST_SQUARES + 1))
			continue
		check(read.get("kind") == Sharing.COURSE, "a code with %d squares comes in" % PaintedAreas.MOST_SQUARES)
		if read.get("kind") != Sharing.COURSE:
			return
		var builder := TrackBuilder.new(TrackPath.from_dict(read.data))
		builder.sky = false
		var start := Time.get_ticks_msec()
		host.add_child(builder)
		var took := Time.get_ticks_msec() - start
		var meshes := builder.find_children("Paint *", "", true, false).size()
		check(builder.track.paint.count() == PaintedAreas.MOST_SQUARES and meshes > 0, "and builds on hills, %d painted meshes in %d ms with the rest of the course" % [meshes, took])
		builder.free()


## Puts the kart on the road at `offset`, so it knows where it left it, then
## drives it from `from` towards `towards` and checks it splashes, drops
## under the water and is put back on the road.
func _drive_in(offset: float, from: Vector3, towards: Vector3, what: String, kind: String) -> void:
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
	check(splashed_kind == kind, "and the kart is told it went into %s (%s)" % [kind, splashed_kind])
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


## A spot on dry, flat ground `radius` metres from `centre`, near enough the
## road and with nothing between it and `centre`, or INF.
func _shore(centre: Vector3, radius: float) -> Vector3:
	var track := race.track
	var water := race.builder.water
	var space := human.kart.get_world_3d().direct_space_state
	for n in 16:
		var at := centre + Vector3(cos(n * TAU / 16.0), 0.0, sin(n * TAU / 16.0)) * radius
		at.y = race.builder.ground_at(at.x, at.z)
		var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 5.0, Kart.LAYER_WORLD))
		var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, centre + Vector3.UP * 0.8, Kart.LAYER_WORLD))
		var near := track.point_at(track.offset_of(at)).distance_to(at) < Race.LOST - 5.0
		if near and not down.is_empty() and absf(down.position.y - at.y) < 0.3 and across.is_empty() and not is_finite(water.level_at(at + Vector3.UP * 0.5)):
			return at
	return Vector3.INF


## Painted mud and ice well off the road on flat Peach Pit: coasting across
## mud a kart slows more than across the plain ground beside it, across ice
## it keeps more of its speed, and sliding sideways on ice it holds on less.
func _slow_types() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit")))
	data.hills = 0.0
	var track := TrackPath.from_dict(data)
	# Find three spots 80 m out from the road with 40 m clear all round.
	var spots: Array[Vector2] = []
	for k in range(0, track.points.size(), 4):
		for side in [1.0, -1.0]:
			var p: Vector3 = track.points[k] + track.rights[k] * side * 80.0
			var spot := Vector2(p.x, p.z)
			var clear := true
			for q in track.points:
				clear = clear and Vector2(q.x - spot.x, q.z - spot.y).length() > 45.0
			for other in spots:
				clear = clear and spot.distance_to(other) > 90.0
			if clear and spots.size() < 3:
				spots.append(spot)
	check(spots.size() == 3, "there's room for mud, ice and plain ground off the road (%d)" % spots.size())
	if spots.size() < 3:
		return
	var areas := PaintedAreas.new()
	for n in 2:
		var middle := PaintedAreas.square_at(spots[n].x, spots[n].y)
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				areas.set_square(middle + Vector2i(dx, dz), ["mud", "ice"][n])
	data.paint = areas.to_dict()
	track = TrackPath.from_dict(data)
	var builder := TrackBuilder.new(track)
	builder.sky = false
	builder.scenery = "none"
	host.add_child(builder)
	var kart := Kart.new()
	kart.build(KartDesign.load_file("res://data/karts/stock/kart_kid.json"))
	kart.paint = track.paint
	host.add_child(kart)
	var kept := []
	var driven := []
	var held := []
	var surfaces := []
	for n in 3:
		var spot := spots[n]
		# Coasting along +x at 15 m/s from 12 m short of the middle, once
		# it's settled.
		await _settle(kart, Vector3(spot.x - 12.0, 0.6, spot.y))
		kart.linear_velocity = Vector3.RIGHT * 15.0
		await frames(90)
		kept.append(kart.linear_velocity.length())
		# Flat out along +x from 10 m/s, 20 m short of the middle.
		await _settle(kart, Vector3(spot.x - 20.0, 0.6, spot.y))
		kart.linear_velocity = Vector3.RIGHT * 10.0
		kart.controls.throttle = 1.0
		await frames(90)
		kart.controls.throttle = 0.0
		driven.append(kart.linear_velocity.length())
		surfaces.append(kart.wheels[0].surface)
		# Sliding sideways at 8 m/s, facing +x.
		await _settle(kart, Vector3(spot.x, 0.6, spot.y - 6.0))
		kart.linear_velocity = Vector3.BACK * 8.0
		await frames(20)
		held.append(absf(kart.linear_velocity.z))
	print("  coasting kept %.1f m/s on mud, %.1f on ice, %.1f on plain %s; flat out %.1f, %.1f, %.1f; sideways left %.1f, %.1f, %.1f" % [kept[0], kept[1], kept[2], surfaces[2], driven[0], driven[1], driven[2], held[0], held[1], held[2]])
	check(surfaces[0] == "mud" and surfaces[1] == "ice", "the wheels know they're on mud and ice (%s, %s)" % [surfaces[0], surfaces[1]])
	check(driven[0] < driven[2] * 0.72 and driven[0] > driven[2] * 0.6, "flat out, mud holds a kart to about two thirds of the plain ground (%.1f against %.1f m/s)" % [driven[0], driven[2]])
	check(kept[1] > kept[2] + 0.5, "ice keeps more of its speed (%.1f against %.1f m/s)" % [kept[1], kept[2]])
	check(held[1] > held[2] + 0.5, "and sliding sideways on ice it holds on less (%.1f against %.1f m/s left)" % [held[1], held[2]])
	kart.free()
	builder.free()


## An online "splash" says what the kart went into, and anything else, like
## none from an older copy of the game, is water.
func _net_kinds() -> void:
	var kinds := [NetRace.splash_kind(null), NetRace.splash_kind("lava"), NetRace.splash_kind("slime"), NetRace.splash_kind("water"), NetRace.splash_kind("mud"), NetRace.splash_kind(3)]
	check(kinds == ["water", "lava", "slime", "water", "water", "water"], "an online splash carries lava and slime, and anything else is water (%s)" % [kinds])


## Puts the kart down facing +x at `at`, still, and lets it settle.
func _settle(kart: Kart, at: Vector3) -> void:
	kart.global_transform = Transform3D(Basis.looking_at(Vector3.RIGHT, Vector3.UP), at)
	kart.linear_velocity = Vector3.ZERO
	kart.angular_velocity = Vector3.ZERO
	await frames(40)
