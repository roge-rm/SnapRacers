extends SceneTree

## Checks racing hulls in Jolt, including the empty space under slopes and
## beside wedges, then drives a kart built with all four shapes.

class Runner:
	extends Node3D

	const PARTS := ["p_wedge_2x4_left", "p_wedge_2x4_right", "p_inverted_slope_1x2", "p_inverted_slope_1x3"]
	var failures := 0
	var samples: Array[Dictionary] = []

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _ready() -> void:
		_run()

	func _run() -> void:
		for id in PARTS:
			var bounded := true
			var bounds_match := true
			for turn in Grid.turns():
				var design := KartDesign.new()
				design.parts.append(KartDesign.placed_entry(id, Transform3D(turn, Vector3(40, 80, 120))))
				var stats := KartStats.compute(design)
				var info := stats.parts[0]
				var kart := Kart.new()
				kart._add_bodies(info)
				var shapes := kart.get_children()
				bounded = bounded and shapes.size() == 1 and shapes[0].shape is ConvexPolygonShape3D
				if shapes.size() != 1 or not shapes[0].shape is ConvexPolygonShape3D:
					kart.free()
					continue
				var shape: CollisionShape3D = shapes[0]
				var lo := Vector3.ONE * INF
				var hi := -lo
				for point in shape.shape.points:
					var p: Vector3 = shape.transform * point
					lo = lo.min(p)
					hi = hi.max(p)
				bounds_match = bounds_match and lo.is_equal_approx(info.centre - info.extent * 0.5) and hi.is_equal_approx(info.centre + info.extent * 0.5)
				var body := StaticBody3D.new()
				body.collision_layer = Kart.LAYER_KARTS
				body.position = Vector3(samples.size() % 12 * 5.0, 0, floori(samples.size() / 12.0) * 5.0)
				kart.remove_child(shape)
				body.add_child(shape)
				kart.free()
				add_child(body)
				# This maps the design's corner directly, independently of the
				# collision shape's centred local coordinates.
				var mapping := Transform3D(turn, info.place.origin - stats.origin_cell * Grid.UNIT_FINE)
				samples.append({"id": id, "body": body, "mapping": mapping})
			check(bounded, "%s uses one convex racing shape in all 24 turns" % id)
			check(bounds_match, "%s racing bounds match the turned part in metres" % id)
		_stock_boxes()
		await get_tree().physics_frame
		await get_tree().physics_frame
		for id in PARTS:
			var solid_spheres := true
			var clear_spheres := true
			var solid_rays := true
			var clear_rays := true
			for sample in samples:
				if sample.id != id:
					continue
				var wedge: bool = id.begins_with("p_wedge")
				var solid := Vector3(10, 21, 5)
				var clear := Vector3(10, 4, 5)
				var ray_axis := Vector3.RIGHT * 24
				if wedge:
					solid = Vector3(30 if id.ends_with("left") else 10, 4, 5)
					clear = Vector3(4 if id.ends_with("left") else 36, 4, 5)
					ray_axis = Vector3.UP * 12
				solid_spheres = solid_spheres and _sphere_hits(sample, solid)
				clear_spheres = clear_spheres and not _sphere_hits(sample, clear)
				solid_rays = solid_rays and _ray_hits(sample, solid - ray_axis, solid + ray_axis)
				clear_rays = clear_rays and not _ray_hits(sample, clear - ray_axis, clear + ray_axis)
			check(solid_spheres and solid_rays, "%s has a solid body for sphere and ray queries in all 24 turns" % id)
			check(clear_spheres and clear_rays, "%s leaves its cutaway clear for sphere and ray queries in all 24 turns" % id)
		for sample in samples:
			sample.body.queue_free()
		await get_tree().physics_frame
		await _drive()
		print("All kart collision checks passed." if failures == 0 else "%d kart collision checks failed." % failures)
		get_tree().quit(1 if failures else 0)

	func _point(sample: Dictionary, fine: Vector3) -> Vector3:
		return sample.body.position + (sample.mapping * fine) * Grid.FINE

	func _sphere_hits(sample: Dictionary, point: Vector3) -> bool:
		var sphere := SphereShape3D.new()
		sphere.radius = 0.008
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.collision_mask = Kart.LAYER_KARTS
		query.transform.origin = _point(sample, point)
		var hits := get_world_3d().direct_space_state.intersect_shape(query)
		return hits.any(func(hit): return hit.collider == sample.body)

	func _ray_hits(sample: Dictionary, from: Vector3, to: Vector3) -> bool:
		var query := PhysicsRayQueryParameters3D.create(_point(sample, from), _point(sample, to), Kart.LAYER_KARTS)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		return not hit.is_empty() and hit.collider == sample.body

	func _stock_boxes() -> void:
		for entry in [["p_plate_2x4", 1], ["p_inverted_bracket_1x2", 2], ["p_technic_brick_1x2", 4], ["p_axle_hole_brick_1x1", 8]]:
			var design := KartDesign.new()
			design.parts.append(KartDesign.placed_entry(entry[0], Transform3D.IDENTITY))
			var kart := Kart.new()
			kart._add_bodies(KartStats.compute(design).parts[0])
			var shapes := kart.get_children()
			check(shapes.size() == entry[1] and shapes.all(func(shape): return shape.shape is BoxShape3D), "%s keeps its %d box colliders" % entry)
			kart.free()

	func _drive() -> void:
		var track := TestTrack.new()
		add_child(track)
		var design := KartDesign.load_file("res://tests/data/legacy/starter.json")
		design.parts = design.parts.filter(func(part): return PartCatalog.get_part(part.id).kind in ["wheel", "seat", "engine", "steering"] or part.id in ["p_plate_6x10", "p_kart_axle_plate", "steering_wheel"])
		for i in 8:
			var id: String = PARTS[i % 4]
			var layer_height := 8 if i % 4 < 2 else 24
			var at := Vector3(140 if i % 2 == 0 else 220, 36 + floori(i / 4.0) * layer_height, 140 if i % 4 < 2 else 240)
			design.parts.append(KartDesign.placed_entry(id, Transform3D(Basis.IDENTITY, at)))
		check(design.problems().is_empty(), "the assembled kart is connected and clear of overlaps %s" % [design.problems()])
		var kart := Kart.new()
		kart.build(design)
		kart.position = Vector3(80, 0.05, 100)
		add_child(kart)
		var convex := kart.get_children().filter(func(child): return child is CollisionShape3D and child.shape is ConvexPolygonShape3D).size()
		check(convex == 8, "an assembled kart uses eight convex colliders for eight shaped parts")
		for tick in 360:
			await get_tree().physics_frame
			if tick == 59:
				check(kart.wheels.all(func(wheel): return wheel.grounded), "the assembled kart settles on all four wheels")
				kart.controls.throttle = 1.0
		check(kart.forward_speed > 12 and kart.global_position.y > -0.5 and kart.global_basis.y.y > 0.95, "the assembled kart drives on the ground upright (%.1f m/s, y %.2f)" % [kart.forward_speed, kart.global_position.y])
		kart.queue_free()
		track.queue_free()


func _initialize() -> void:
	root.add_child(Runner.new())
