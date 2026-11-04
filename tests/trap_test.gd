extends SceneTree

## Dropped road patches must miss the dropper's wheels, including long karts.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/trap_test.gd
class Runner:
	extends Node
	var failures := 0

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func frames(count: int) -> void:
		for i in count:
			await get_tree().physics_frame

	func make_kart(key: String, at: Vector3) -> Kart:
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://tests/data/legacy/%s.json" % key))
		kart.position = at
		add_child(kart)
		return kart

	func surface(at: Vector3, size: Vector3, angle := 0.0) -> StaticBody3D:
		var ground := StaticBody3D.new()
		ground.collision_layer = Kart.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		ground.add_child(shape)
		ground.transform = Transform3D(Basis(Vector3.BACK, angle), at)
		ground.position -= ground.basis.y * size.y * 0.5
		add_child(ground)
		return ground

	func moving_trap(kind: String, at: Vector3, normal := Vector3.UP) -> BrickTrap:
		var trap := BrickTrap.new(kind)
		trap.transform = Transform3D(Basis.looking_at(Vector3.FORWARD.slide(normal).normalized(), normal), at)
		add_child(trap)
		var shield := Node3D.new()
		add_child(shield)
		shield.global_position = at - Vector3.RIGHT
		trap.shove_from(shield)
		shield.queue_free()
		return trap

	func _shoved_ground() -> void:
		for kind in ["marbles", "spikes"]:
			var flat := surface(Vector3(200, 0, 0), Vector3(30, 0.5, 30))
			await frames(2)
			var trap := moving_trap(kind, Vector3(197, 0.01, 0))
			await frames(100)
			check(trap.position.x > 200.0 and absf(trap.position.y - 0.01) < 0.03 and not trap._moving, "%s slide along flat ground and stop on it" % kind)
			trap.queue_free()
			flat.queue_free()

			var slope := surface(Vector3(240, 2, 0), Vector3(30, 0.5, 30), 0.2)
			await frames(2)
			var normal := slope.basis.y
			trap = moving_trap(kind, Vector3(237, 2.0 - tan(0.2) * 3.0, 0) + normal * 0.01, normal)
			await frames(100)
			check(absf((trap.position - Vector3(240, 2, 0)).dot(normal) - 0.01) < 0.03 and trap.basis.y.dot(normal) > 0.999, "%s follow the height and normal of a slope" % kind)
			trap.queue_free()
			slope.queue_free()

			var crest := StaticBody3D.new()
			crest.collision_layer = Kart.LAYER_WORLD
			var shape := CollisionShape3D.new()
			var mesh := ConcavePolygonShape3D.new()
			var points := PackedVector3Array()
			for ends in [[Vector2(-10, -1), Vector2(0, 1)], [Vector2(0, 1), Vector2(10, -1)]]:
				var a := Vector3(ends[0].x, ends[0].y, -15)
				var b := Vector3(ends[1].x, ends[1].y, -15)
				var c := Vector3(ends[1].x, ends[1].y, 15)
				var d := Vector3(ends[0].x, ends[0].y, 15)
				points.append_array(PackedVector3Array([a, b, c, a, c, d]))
			mesh.set_faces(points)
			shape.shape = mesh
			crest.add_child(shape)
			crest.position = Vector3(280, 2, 0)
			add_child(crest)
			await frames(2)
			normal = Vector3(-0.2, 1, 0).normalized()
			trap = moving_trap(kind, Vector3(278, 2.6, 0) + normal * 0.01, normal)
			await frames(100)
			var down_normal := Vector3(0.2, 1, 0).normalized()
			check(trap.position.x > 280 and trap.position.y < 3.0 and absf((trap.position - Vector3(280, 3, 0)).dot(down_normal) - 0.01) < 0.03 and trap.basis.y.dot(down_normal) > 0.999, "%s follow a crest onto the downward slope (%s, normal %s)" % [kind, trap.position, trap.basis.y])
			trap.queue_free()
			crest.queue_free()

			var lower := surface(Vector3(320, 0, 0), Vector3(30, 0.5, 30))
			var bridge := surface(Vector3(315, 5, 0), Vector3(10, 0.5, 30))
			await frames(2)
			trap = moving_trap(kind, Vector3(319, 5.01, 0))
			await frames(18)
			check(trap.position.x > 320 and trap.position.y > 2.5 and trap.position.y < 5.0 and trap.collision_layer == 0, "%s fall from a bridge without snapping to the lower road" % kind)
			await frames(100)
			check(absf(trap.position.y - 0.01) < 0.03 and trap.collision_layer == Kart.LAYER_WORLD and not trap._moving, "%s land on the lower road after their slide stops" % kind)
			trap.queue_free()
			lower.queue_free()
			bridge.queue_free()

			trap = moving_trap(kind, Vector3(360, 5, 0))
			await frames(100)
			var fallen := trap.position.y
			await frames(30)
			check(trap._slide == Vector3.ZERO and trap.position.y < fallen - 1.0 and trap.collision_layer == 0, "%s keep falling in a gap after horizontal movement stops" % kind)
			trap.queue_free()

			flat = surface(Vector3(400, 0, 0), Vector3(30, 0.5, 30))
			var other := BrickTrap.new(kind)
			other.position = Vector3(400, 0.12, 0)
			add_child(other)
			await frames(2)
			trap = moving_trap(kind, Vector3(397, 0.01, 0))
			await frames(100)
			check(absf(trap.position.y - 0.01) < 0.03 and absf(other.position.y - 0.12) < 0.001, "%s find the road instead of landing on another trap" % kind)
			trap.queue_free()
			other.queue_free()
			flat.queue_free()

			var suspended := make_kart("starter", Vector3(440, 8, 0))
			suspended.freeze = true
			await frames(2)
			trap = BrickTrap.drop_behind(suspended, kind)
			add_child(trap)
			var dropped_at := trap.position.y
			await frames(30)
			check(trap.position.y < dropped_at - 0.5 and trap.collision_layer == 0, "%s dropped over a gap fall immediately" % kind)
			trap.queue_free()
			suspended.queue_free()
			await frames(2)

	func _ready() -> void:
		var ground := StaticBody3D.new()
		ground.collision_layer = Kart.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(160, 2, 160)
		shape.shape = box
		shape.position.y = -1.0
		ground.add_child(shape)
		add_child(ground)
		for key in ["starter", "rocket", "streamliner"]:
			for kind in ["spikes", "marbles"]:
				var dropper := make_kart(key, Vector3(-20, 0.05, 0))
				var control := make_kart(key, Vector3(20, 0.05, 0))
				await frames(60)
				dropper.give(kind)
				check(dropper.use_gadget(0), "%s drops %s" % [key, kind])
				await frames(2)
				var trap: BrickTrap = get_children().filter(func(n): return n is BrickTrap)[0]
				var wheels_clear := true
				for wheel in dropper.wheels:
					var at := dropper.to_global(wheel.rest)
					var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 2, Kart.LAYER_WORLD, [dropper.get_rid()])
					var hit := dropper.get_world_3d().direct_space_state.intersect_ray(query)
					wheels_clear = wheels_clear and hit.get("collider") == ground
				check(wheels_clear, "%s's wheels are clear of its dropped %s" % [key, kind])
				for kart in [dropper, control]:
					kart.linear_velocity = Vector3(0, 0, -14)
					kart.controls.throttle = 1.0
				await frames(10)
				check(dropper.lost.is_empty(), "%s does not lose parts to its own %s" % [key, kind])
				check(absf(dropper.forward_speed - control.forward_speed) < 0.1, "%s drives away from %s normally (%.2f against %.2f m/s)" % [key, kind, dropper.forward_speed, control.forward_speed])
				trap.queue_free()
				dropper.queue_free()
				control.queue_free()
				await frames(2)
		await _shoved_ground()
		print("All trap checks passed." if failures == 0 else "%d trap checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)

func _initialize() -> void:
	root.add_child(Runner.new())
