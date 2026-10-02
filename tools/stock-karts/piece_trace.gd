extends Node

## Follows a top AI driver round a course and prints how it goes through one
## piece, ten times a second, from a little before it to well after: how fast,
## how many wheels are down, whether it's stuck to the road, and how far it
## is off the road. Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/piece_trace.tscn -- <course> <piece> [kart]
## <piece> counts from 0 in the course file. With SURVEY=1 it doesn't drive,
## and prints how far the road's surface leans from its up across its width
## instead, every 2 m.

const BEFORE := 30.0
const AFTER := 120.0

var host: Node


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "windmill_ridge"
	var piece := int(args[1]) if args.size() > 1 else 0
	Game.settings.set_value("race", "kart", args[2] if args.size() > 2 else "starter")
	Game.mode = Game.MODE_TIME_TRIAL
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	var path := race.track
	var from := INF
	var to := -INF
	for k in path.points.size():
		if path.piece_of[k] == piece:
			from = minf(from, path.distances[k])
			to = maxf(to, path.distances[k])
	print("piece %d runs %.0f to %.0f m" % [piece, from, to])
	# SURVEY looks at what's under the road across its width, every 2 m.
	if OS.has_environment("SURVEY"):
		await get_tree().physics_frame
		var space := race.get_viewport().world_3d.direct_space_state
		var at := from - 4.0
		while at < to + 10.0:
			var line := "  %4.0f m bank %3.0f:" % [at, rad_to_deg(path.up_at(at).angle_to(Vector3.UP))]
			for across: float in [-6.0, -3.0, 0.0, 3.0, 6.0]:
				var on: Vector3 = path.point_at(at) + path.right_at(at) * across
				var ray := PhysicsRayQueryParameters3D.create(on + path.up_at(at) * 3.0, on - path.up_at(at) * 3.0, Kart.LAYER_WORLD)
				var hit := space.intersect_ray(ray)
				if hit.is_empty():
					line += "   none      "
				else:
					var sticky: bool = hit.collider.get_meta("sticky", false)
					line += "  %4.1f° %+.2f %s %s" % [rad_to_deg(hit.normal.angle_to(path.up_at(at))), (hit.position - on).dot(path.up_at(at)), "S" if sticky else "-", str(hit.collider.name).left(8)]
			print(line)
			at += 2.0
		get_tree().quit()
		return
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = path
	driver.others.assign([race.player.kart])
	driver.skill = 0.99
	race.add_child(driver)
	race.player.ai = driver
	var kart := race.player.kart
	kart.controls = driver.controls
	var passes := 0
	var inside := false
	while passes < 2 and race.time < 300.0:
		await get_tree().physics_frame
		var at := race.player.offset
		var near := at > from - BEFORE and at < to + AFTER
		if near and not inside:
			print("-- pass %d" % (passes + 1))
		if inside and not near:
			passes += 1
		inside = near
		if near and Engine.get_physics_frames() % 6 == 0:
			var down := kart.wheels.filter(func(w): return w.grounded).size()
			var road := path.point_at(at)
			var off := (kart.global_position - road).dot(path.up_at(at))
			var tilt := rad_to_deg(kart.global_basis.y.angle_to(path.up_at(at)))
			var across := (kart.global_position - road).dot(path.right_at(at))
			var bank := rad_to_deg(path.up_at(at).angle_to(Vector3.UP))
			print("  %4.0f m %s %5.1f m/s  up %+5.1f  wheels %d %s  off %+.2f  across %+5.1f  bank %4.0f  tilt %4.1f  height %5.1f  steer %+.2f  ground %4.1f  lie %4.1f" % [at, "in " if at >= from and at <= to else "out", kart.linear_velocity.length(), kart.linear_velocity.dot(path.up_at(at)), down, "stuck" if kart.sticking else "     ", off, across, bank, tilt, kart.global_position.y, kart.controls.steer, rad_to_deg(kart.stick_up.angle_to(path.up_at(at))), rad_to_deg(kart.global_basis.y.angle_to(kart.stick_up))])
	get_tree().quit()
