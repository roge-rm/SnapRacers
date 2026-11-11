extends Node

var checks := 0
var failures := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func bundle(id: String, count := 1) -> Vector3:
	var part := PartCatalog.get_part(id)
	return Vector3(part.mass, part.power, part.max_force) * count


func one_engine(design: KartDesign) -> KartDesign:
	var single := design.duplicate_design()
	for i in range(single.parts.size() - 1, -1, -1):
		if single.parts[i].id == "engine_micro":
			single.parts.remove_at(i)
			break
	return single


func ground() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000, 2, 1000)
	shape.shape = box
	shape.position.y = -1
	body.add_child(shape)
	add_child(body)
	return body


func launch(design: KartDesign) -> Dictionary:
	var kart := Kart.new()
	kart.build(design)
	kart.position = Vector3(0, 0.05, 100)
	add_child(kart)
	for frame in 60:
		await get_tree().physics_frame
	var grounded := kart.wheels.filter(func(w): return w.grounded).size()
	var result := {"grounded": grounded, "mass": kart.mass}
	kart.controls.throttle = 1.0
	for frame in 300:
		await get_tree().physics_frame
		if frame == 29:
			result.half_second = kart.forward_speed
		if frame == 119:
			result.two_seconds = kart.forward_speed
	result.five_seconds = kart.forward_speed
	result.upright = kart.global_basis.y.y
	kart.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	return result


func _ready() -> void:
	Game.start(self, false)
	var micros := bundle("engine_micro", 2)
	var twin := bundle("engine_twin")
	check(twin.x < micros.x and twin.y > micros.y and twin.z >= micros.z, "a twin trades its larger footprint for less weight and more power than two micros")
	var triple := bundle("engine_micro", 3)
	var big := bundle("engine_big")
	check(triple.x > big.x and triple.y > big.y and triple.z > big.z, "three micros buy extra power and pull with extra weight over a big engine")
	var rotaries := bundle("engine_rotary", 2)
	var v8 := bundle("engine_v8")
	check(rotaries.x > v8.x and rotaries.y > v8.y and rotaries.z < v8.z, "two rotaries trade more weight and less launch force for more top-end power than a V8")
	var electric := bundle("electric_motor", 2)
	check(electric.y < v8.y and electric.z > v8.z, "electric motors keep their launch-force niche at the cost of V8 top-end power")
	var large_electric := bundle("electric_big", 2)
	check(large_electric.x > v8.x and large_electric.y > v8.y and large_electric.z > v8.z, "two big electric motors buy extra power and force with extra weight over a V8")
	var pedals := bundle("pedals")
	var micro := bundle("engine_micro")
	check(pedals.x < micro.x and pedals.y < micro.y and pedals.z < micro.z and pedals.y / pedals.x < micro.y / micro.x, "pedals are lighter but cannot supply micro-engine power and pull for almost no weight")
	var design := KartDesign.load_file("res://tests/data/engine_tradeoff_kart.json")
	check(design.problems().is_empty(), "the shared two-engine build is still valid")
	var single := one_engine(design)
	check(single.problems().is_empty(), "the same build works with one micro engine")
	var one := KartStats.compute(single)
	var two := KartStats.compute(design)
	check(one.top_speed() > 25.0 and one.pull() > 0.7, "one micro still powers a driveable kart")
	check(two.mass > one.mass and two.top_speed() > one.top_speed() and two.pull() > one.pull(), "a second micro still adds performance and weight")
	var net := NetSession.new()
	check(NetSession.VERSION == 18 and net._check({"version": 17}).contains("different version") and net._check({"version": 18, "players": []}) == "Nobody to race.", "online peers cannot mix the old and new engine physics")
	net.free()
	var floor := ground()
	var one_launch: Dictionary = await launch(single)
	var two_launch: Dictionary = await launch(design)
	check(one_launch.grounded == 4 and two_launch.grounded == 4, "both engine configurations settle on all four wheels")
	check(one_launch.half_second > 2.0 and two_launch.half_second > 2.0, "single and twin micro builds both pull away under real wheel physics")
	check(one_launch.five_seconds > 12.0 and two_launch.five_seconds > one_launch.five_seconds, "the second engine retains a measurable straight-line advantage")
	check(one_launch.upright > 0.95 and two_launch.upright > 0.95, "both builds remain upright through the launch")
	print("ENGINE_LAUNCH " + JSON.stringify({"one": one_launch, "two": two_launch}))
	floor.queue_free()
	print("%d engine tradeoff checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
