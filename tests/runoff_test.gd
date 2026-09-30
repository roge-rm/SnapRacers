extends SceneTree

## The edges of the road, with bumpy curbs on the corners that throw you into
## the air at speed, grass that slows you down without stopping you dead, and
## soft tire stacks you bounce off. It builds a little course of hairpins and
## straights and drives the Starter over each.
##
## Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/runoff_test.gd

var failures := 0
var world: Node3D
var builder: TrackBuilder
var track: TrackPath


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func kart_at(where: Transform3D, speed: float) -> Kart:
	var kart := Kart.new()
	kart.build(KartDesign.load_file("res://data/karts/stock/starter.json"))
	kart.transform = where
	world.add_child(kart)
	kart.linear_velocity = -where.basis.z * speed
	return kart


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	# A long rectangle: two straights joined by hairpins at each end.
	track = TrackPath.from_dict({"theme": "orchard", "pieces": [
		{"type": "straight", "length": 3},
		{"type": "curve", "turn": "right", "size": 1},
		{"type": "curve", "turn": "right", "size": 1},
		{"type": "straight", "length": 3},
		{"type": "curve", "turn": "right", "size": 1},
		{"type": "curve", "turn": "right", "size": 1},
	]})
	check(track.closes, "the test course closes")
	builder = TrackBuilder.new(track)
	builder.scenery = "none"
	builder.sky = false
	world.add_child(builder)
	await frames(2)

	var walls := 0
	var kerbs: Array[StaticBody3D] = []
	for child in builder.get_children():
		if child is StaticBody3D and child.get_meta("kerb", false):
			kerbs.append(child)
	check(kerbs.size() >= 4, "the hairpins have curbs, inside and out (%d)" % kerbs.size())
	# Nothing sticks up beside the road at ground level: a ray just above the
	# road, out across the edge, hits nothing.
	var space := world.get_world_3d().direct_space_state
	for offset: float in [20.0, 60.0]:
		var frame := track.frame_at(offset)
		for side: float in [-1.0, 1.0]:
			var from: Vector3 = frame.origin + frame.basis.y * 0.4 + frame.basis.x * side * (track.width * 0.5 - 1.0)
			var query := PhysicsRayQueryParameters3D.create(from, from + frame.basis.x * side * 6.0)
			if not space.intersect_ray(query).is_empty():
				walls += 1
	check(walls == 0, "there are no walls beside the road at ground level (%d)" % walls)

	# Riding a curb, fast and then slowly. It's a long straight one out on the
	# grass, with the kart's right hand wheels on it and nothing steering.
	var strip := StaticBody3D.new()
	strip.collision_layer = Kart.LAYER_WORLD
	strip.set_meta("kerb", true)
	strip.set_meta("grip", TrackBuilder.KERB_GRIP)
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	box.shape.size = Vector3(1.5, TrackBuilder.KERB_HEIGHT * 2.0, 400.0)
	strip.add_child(box)
	strip.position = Vector3(-80.0, 0.0, -50.0)
	world.add_child(strip)
	for speed: float in [22.0, 3.0]:
		var airborne := await ride_kerb(Vector3(-80.75, 0.35, 60.0), speed)
		if speed > 10.0:
			check(airborne > 0.1, "riding a curb at %d m/s throws the wheels into the air (%.2f of the time)" % [speed, airborne])
		else:
			check(airborne < 0.03, "at %d m/s a curb only rumbles (%.2f of the time in the air)" % [speed, airborne])

	# Running wide onto the grass at speed, and coasting.
	var off := track.frame_at(40.0)
	off.origin += off.basis.x * (track.width * 0.5 + 6.0) + Vector3.UP * 0.3
	var kart := kart_at(off, 24.0)
	await frames(30)
	var after_half := kart.forward_speed
	check(after_half > 24.0 * 0.6, "running onto the grass doesn't stop you dead (%.1f m/s after half a second)" % after_half)
	await frames(180)
	check(kart.forward_speed < 24.0 * 0.55, "but coasting on it slows you right down (%.1f m/s after 3.5 s)" % kart.forward_speed)
	check(kart.global_basis.y.y > 0.8, "and you stay on your wheels (up.y %.2f)" % kart.global_basis.y.y)
	kart.queue_free()

	# A line of tire stacks, out on the grass, and a kart driving into it.
	var kit := SceneryKit.new()
	var line_at := Vector3(-60.0, 0.0, 70.0)
	for i in 20:
		Props.barrier_stack(kit, line_at + Vector3(-8.0 + i * 0.8, 0.0, 0.0), Props.RED)
	var holder := Node3D.new()
	world.add_child(holder)
	kit.build(holder)
	kart = kart_at(Transform3D(Basis.IDENTITY, line_at + Vector3(0.0, 0.3, 20.0)), 15.0)
	await frames(120)
	check(kart.global_position.z > line_at.z + 0.5, "a kart doesn't go through the tire stacks (%.1f m in front)" % (kart.global_position.z - line_at.z))
	check(kart.linear_velocity.z > 0.5, "it bounces back off them (%.1f m/s)" % kart.linear_velocity.z)
	check(kart.global_basis.y.y > 0.7, "and it's still upright (up.y %.2f)" % kart.global_basis.y.y)

	print("All runoff checks passed." if failures == 0 else "%d runoff checks failed." % failures)
	quit(1 if failures > 0 else 0)


## Puts a kart at `at` going at `speed` with its throttle held (so it keeps
## going), for two seconds, and says how much of the time its wheels were off
## the ground.
func ride_kerb(at: Vector3, speed: float) -> float:
	var kart := kart_at(Transform3D(Basis.IDENTITY, at), speed)
	kart.controls.throttle = 1.0 if speed > 10.0 else 0.15
	await frames(20)
	var off := 0
	var total := 0
	for i in 120:
		await physics_frame
		for w in kart.wheels:
			total += 1
			if not w.grounded:
				off += 1
	kart.queue_free()
	await frames(2)
	return float(off) / maxf(total, 1)
