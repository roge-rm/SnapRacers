extends SceneTree

## Loose bricks clear the tail and wheels, including long karts.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/brick_pile_test.gd
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

	func kart_at(key: String, at: Vector3) -> Kart:
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/stock/%s.json" % key), Kart.default_driver())
		kart.position = at
		add_child(kart)
		return kart

	func _geometry() -> void:
		for key in ["kart_kid", "crusher", "quarter_mile"]:
			var kart := kart_at(key, Vector3(0, 10, 0))
			kart.freeze = true
			kart.rotation = Vector3(0.15, 0.7, -0.1)
			await frames(2)
			var tail := kart.rear_bumper_point().z
			var clear := true
			var count := true
			for drop in 12:
				kart.grid_slot = 101
				kart.drops = drop
				var pile := BrickPile.drop_behind(kart)
				count = count and pile.size() == BrickPile.COUNT and kart.drops == drop + 1
				for brick in pile:
					var shape: CollisionShape3D = brick.get_child(0)
					var box: BoxShape3D = shape.shape
					for x in [-0.5, 0.5]:
						for y in [-0.5, 0.5]:
							for z in [-0.5, 0.5]:
								var corner := kart.to_local(brick.transform * (box.size * Vector3(x, y, z)))
								clear = clear and corner.z >= tail + 0.05
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = shape.shape
					query.transform = brick.transform
					query.collision_mask = Kart.LAYER_KARTS
					clear = clear and kart.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
					brick.free()
			check(count, "%s keeps the native brick count and drop counter" % key)
			check(clear, "%s's rotated bricks clear its tail in twelve drops" % key)
			kart.queue_free()
			await frames(2)

	func _drive_away() -> void:
		for key in ["kart_kid", "quarter_mile"]:
			for speed in [0.0, 14.0]:
				var kart := kart_at(key, Vector3(-20, 0.05, 0))
				var control := kart_at(key, Vector3(20, 0.05, 0))
				await frames(60)
				for body in [kart, control]:
					body.linear_velocity = Vector3(0, 0, -speed)
					body.controls.throttle = 1.0
				kart.grid_slot = 101
				var pile := BrickPile.drop_behind(kart)
				for brick in pile:
					add_child(brick)
				var contact := false
				var max_speed_difference := 0.0
				for i in 30:
					await frames(1)
					max_speed_difference = maxf(max_speed_difference, absf(kart.forward_speed - control.forward_speed))
					for body in kart.get_colliding_bodies():
						contact = contact or body is BrickPile
				check(not contact and kart.lost.is_empty(), "%s at %.0f m/s stays clear of its own loose bricks for half a second" % [key, speed])
				check(max_speed_difference < 0.1, "%s at %.0f m/s drives away normally (largest speed difference %.3f m/s)" % [key, speed, max_speed_difference])
				for brick in pile:
					brick.queue_free()
				kart.queue_free()
				control.queue_free()
				await frames(2)

	func _prediction() -> void:
		var kart := kart_at("quarter_mile", Vector3(0, 0.05, 0))
		var target := kart_at("kart_kid", Vector3(0, 0.05, 7))
		for body in [kart, target]:
			body.freeze = true
			body.linear_velocity = Vector3(0, 0, -20)
			for wheel in body.wheels:
				wheel.grounded = true
		var ai := AIDriver.new()
		ai.kart = kart
		ai.others = [kart, target]
		await frames(2)
		for body in [kart, target]:
			for wheel in body.wheels:
				wheel.grounded = true
		check(AIGadgetTactics.score(ai, "dropper", 20.0) == 0.0, "a long kart holds bricks when a follower has passed the launch area")
		target.position.z = 18.0
		check(AIGadgetTactics.score(ai, "dropper", 20.0) > 0.0, "a long kart drops bricks for a follower approaching the launch area")
		ai.free()
		kart.queue_free()
		target.queue_free()
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
		await _geometry()
		await _drive_away()
		await _prediction()
		print("All brick pile checks passed." if failures == 0 else "%d brick pile checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)

func _initialize() -> void:
	root.add_child(Runner.new())
