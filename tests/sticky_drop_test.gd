extends SceneTree

## Marbles, spikes and walls dropped on a corkscrew and a loop lie on the
## road, square to it, and stay there, upside down too. A kart driving round
## loses its grip on the marbles and knocks the wall down.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/sticky_drop_test.gd
class Runner:
	extends Node
	var failures := 0
	var track: TrackPath
	var builder: TrackBuilder

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func frames(count: int) -> void:
		for i in count:
			await get_tree().physics_frame

	func build(piece: String) -> void:
		track = TrackPath.from_dict({ "pieces": [
			{ "type": "straight", "length": 5 },
			{ "type": piece, "side": "right" },
			{ "type": "straight", "length": 4 },
		] })
		builder = TrackBuilder.new(track)
		add_child(builder)

	## Offsets along the middle piece: where its road faces most sideways and
	## where it's most upside down.
	func spots() -> Dictionary:
		var side := -1.0
		var top := -1.0
		for k in track.points.size():
			if track.piece_of[k] != 1:
				continue
			var up := track.ups[k]
			if side < 0.0 or absf(up.y) < absf(track.up_at(side).y):
				side = track.distances[k]
			if top < 0.0 or up.y < track.up_at(top).y:
				top = track.distances[k]
		return { "side": side, "top": top }

	func parked_kart(offset: float) -> Kart:
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		kart.transform = track.place_at(offset, 0.4)
		kart.freeze = true
		add_child(kart)
		return kart

	## The road under `at` along `up`, past any traps.
	func road_under(at: Vector3, up: Vector3) -> Dictionary:
		var query := PhysicsRayQueryParameters3D.create(at + up * 0.6, at - up * 0.6, Kart.LAYER_WORLD)
		return BrickTrap.road_hit(get_viewport().world_3d.direct_space_state, query)

	## Checks a trap lies on the road square to it, and its shape and pieces
	## follow the road out to its rim.
	func check_on_road(trap: BrickTrap, what: String) -> void:
		var up := trap.global_basis.y.normalized()
		var road := road_under(trap.global_position, up)
		var gap: float = (trap.global_position - road.position).dot(road.normal) if not road.is_empty() else INF
		var square: float = up.dot(road.normal) if not road.is_empty() else 0.0
		check(absf(gap) < 0.05 and square > 0.99 and not trap._falling, "%s lies on the road (%.3f m off, square %.3f)" % [what, gap, square])
		var worst := 0.0
		var space := get_viewport().world_3d.direct_space_state
		for i in 8:
			# Off the shape's own edges, which a ray can slip between.
			var a := TAU * (i + 0.1) / 8
			var rim := trap.global_transform * Vector3(cos(a) * BrickTrap.KINDS[trap.kind].across * 0.8, 0.0, sin(a) * BrickTrap.KINDS[trap.kind].along * 0.8)
			var query := PhysicsRayQueryParameters3D.create(rim + up * 1.0, rim - up * 1.0, Kart.LAYER_WORLD)
			var top := space.intersect_ray(query)
			var under := road_under(rim, up)
			if top.is_empty() or top.collider != trap or under.is_empty():
				worst = INF
				continue
			worst = maxf(worst, absf((top.position - under.position).dot(under.normal)))
		check(worst < 0.06, "%s keeps to the road out to its rim (%.3f m at most)" % [what, worst])

	func drops_on(piece: String) -> void:
		build(piece)
		await frames(2)
		var at := spots()
		var traps: Array[BrickTrap] = []
		var walls: Array[BrickWall] = []
		for spot in ["side", "top"]:
			# The kart sits a little past the spot, so the marbles land on it,
			# with the spikes before them and the wall after.
			for kind in ["marbles", "spikes", "wall"]:
				var shift: float = {"marbles": 0.0, "spikes": -7.0, "wall": 8.0}[kind]
				var kart := parked_kart(at[spot] + 5.0 + shift)
				await frames(1)
				if kind == "wall":
					var wall := BrickWall.drop_behind(kart)
					add_child(wall)
					walls.append(wall)
				else:
					var trap := BrickTrap.drop_behind(kart, kind)
					add_child(trap)
					traps.append(trap)
				kart.queue_free()
				await frames(1)
				var what := "%s on the %s's %s" % [kind, piece, spot]
				if kind == "wall":
					var wall: BrickWall = walls[-1]
					var road := road_under(wall.global_position, wall.global_basis.y)
					var gap: float = (wall.global_position - road.position).dot(road.normal) if not road.is_empty() else INF
					check(absf(gap) < 0.05 and wall.global_basis.y.dot(road.normal) > 0.99, "%s stands on the road square to it (%.3f m off)" % [what, gap])
				else:
					check_on_road(traps[-1], what)
		var held: Array[Vector3] = []
		for trap in traps:
			held.append(trap.global_position)
		await frames(90)
		var still := true
		for i in traps.size():
			still = still and traps[i].global_position.distance_to(held[i]) < 0.01 and not traps[i]._moving
		check(still, "the patches on the %s stay where they were dropped" % piece)
		check(walls.all(func(wall: BrickWall) -> bool: return wall.bricks().all(func(brick: RigidBody3D) -> bool: return brick.freeze)) and not walls.any(func(wall: BrickWall) -> bool: return wall._falling), "the walls on the %s stay standing" % piece)

		# A shield on the top slides the patch along the road, and it ends up
		# on the road or falls off its side, never hanging in the air.
		var top_trap := traps[2]
		var shield := parked_kart(at.top)
		top_trap.shove_from(shield)
		shield.queue_free()
		await frames(150)
		if top_trap._falling:
			check(true, "the shoved patch on the %s's top fell off its side" % piece)
		else:
			check_on_road(top_trap, "the shoved patch on the %s's top" % piece)
		for thing in traps + walls:
			thing.queue_free()
		builder.queue_free()
		await frames(2)

	## A kart driving round over marbles at the top loses its grip there, and
	## knocks a wall down at the side.
	func drive_over(piece: String) -> void:
		build(piece)
		await frames(2)
		var at := spots()
		var dropper := parked_kart(at.top + 5.0)
		await frames(1)
		var marbles := BrickTrap.drop_behind(dropper, "marbles")
		add_child(marbles)
		dropper.queue_free()
		await frames(1)
		var driver := Kart.new()
		driver.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		driver.transform = track.place_at(2.0, 0.05)
		add_child(driver)
		var ai := AIDriver.new()
		ai.kart = driver
		ai.track = track
		driver.controls = ai.controls
		add_child(ai)
		var offset := 2.0
		var least := 1.0
		var on_patch := false
		for frame in 60 * 12:
			await frames(1)
			offset = track.offset_of(driver.global_position, offset, 30.0)
			ai.offset = offset
			least = minf(least, driver._marble_grip)
			for wheel in driver.wheels:
				on_patch = on_patch or wheel.grounded and driver.global_position.distance_to(marbles.global_position) < 4.0
		check(on_patch and least < 0.5, "a kart driving over marbles on the %s's top loses its grip (%.2f)" % [piece, least])
		ai.queue_free()
		driver.queue_free()
		marbles.queue_free()
		await frames(2)

		var wall_dropper := parked_kart(at.side + 5.0)
		await frames(1)
		var wall := BrickWall.drop_behind(wall_dropper)
		add_child(wall)
		wall_dropper.queue_free()
		driver = Kart.new()
		driver.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		driver.transform = track.place_at(2.0, 0.05)
		add_child(driver)
		ai = AIDriver.new()
		ai.kart = driver
		ai.track = track
		driver.controls = ai.controls
		add_child(ai)
		offset = 2.0
		for frame in 60 * 12:
			await frames(1)
			offset = track.offset_of(driver.global_position, offset, 30.0)
			ai.offset = offset
			if not wall.standing() or wall.bricks().any(func(brick: RigidBody3D) -> bool: return not brick.freeze):
				break
		check(wall.bricks().any(func(brick: RigidBody3D) -> bool: return not brick.freeze), "a kart driving round the %s knocks into the wall on its side" % piece)
		ai.queue_free()
		driver.queue_free()
		wall.queue_free()
		builder.queue_free()
		await frames(2)

	## Bricks dropped upside down start on the open side of the road.
	func bricks_clear(piece: String) -> void:
		build(piece)
		await frames(2)
		var at := spots()
		var kart := parked_kart(at.top + 5.0)
		await frames(1)
		var place := BrickTrap.ground_behind(kart, BrickPile.drop_distance(kart))
		var bricks := BrickPile.drop_behind(kart)
		var space := get_viewport().world_3d.direct_space_state
		var clear: bool = not place.hit.is_empty()
		for brick in bricks:
			var from: Vector3 = place.hit.position + place.hit.normal * 0.05 if clear else Vector3.ZERO
			var query := PhysicsRayQueryParameters3D.create(from, brick.position, Kart.LAYER_WORLD)
			clear = clear and space.intersect_ray(query).is_empty()
			brick.free()
		check(clear, "bricks dropped upside down on the %s start clear of the road" % piece)
		kart.queue_free()
		builder.queue_free()
		await frames(2)

	func _ready() -> void:
		for piece in ["corkscrew", "loop"]:
			await drops_on(piece)
			await bricks_clear(piece)
			await drive_over(piece)
		print("All sticky drop checks passed." if failures == 0 else "%d sticky drop checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)

func _initialize() -> void:
	root.add_child(Runner.new())
