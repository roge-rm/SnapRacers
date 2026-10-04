extends Node

## Races eight AI karts the whole way round a course and says how it went:
## each kart's resets and finishing time, any kart that stopped getting
## anywhere, and how long the race took. tools/soak/soak.sh runs it on every
## course in a mix of weather and times of day. With "why" it also says what
## a kart that's made no headway for a while is doing and what it's touching.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/soak/soak.tscn -- peach_pit weather=rain time=night seed=1 [why]

## Gives up on a race after this long.
const MOST_TIME := 600.0
## A kart that gets no further than this in this long has stalled.
const STALL_TIME := 20.0
const STALL_DISTANCE := 5.0

var host: Node


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	var args := OS.get_cmdline_user_args()
	var course: String = args[0] if args.size() > 0 else "peach_pit"
	Game.racing_alone = true
	# seed= deals the same karts and drivers again.
	for arg in args:
		if arg.begins_with("seed="):
			seed(int(arg.split("=")[1]))
		if arg.begins_with("weather=") or arg.begins_with("time=") or arg.begins_with("difficulty="):
			var parts: PackedStringArray = arg.split("=")
			Game.settings.set_value("race", parts[0], parts[1])
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	var resets := {}
	for racer in race.racers:
		resets[racer] = 0
		racer.kart.was_reset.connect(func() -> void:
			resets[racer] += 1
			print("RESET %s: %s at %.0f m, %.0f s" % [course, racer.name, fposmod(racer.progress.distance(), race.track.length), race.time]))
	while not race.started:
		await get_tree().process_frame
	print("SOAK %s in %s at %s, %s" % [course, race.conditions.weather, race.conditions.time, ", ".join(race.racers.map(func(r: Race.Racer) -> String: return "%s in %s" % [r.name, r.kart.design.name]))])
	var last := {}
	var since := {}
	var stalls := {}
	for racer in race.racers:
		last[racer] = racer.progress.distance()
		since[racer] = race.time
		stalls[racer] = 0
	while race.time < MOST_TIME and not race.racers.all(func(r: Race.Racer) -> bool: return r.progress.finished):
		await get_tree().physics_frame
		for racer in race.racers:
			if racer.progress.finished:
				continue
			var now: float = racer.progress.distance()
			if absf(now - last[racer]) > STALL_DISTANCE:
				last[racer] = now
				since[racer] = race.time
			elif race.time - since[racer] > STALL_TIME * 0.5 and race.time - since[racer] < STALL_TIME * 0.5 + 0.02 and OS.get_cmdline_user_args().has("why"):
				var k: Kart = racer.kart
				print("WHY %s %s: v %.2f throttle %.2f brake %.2f steer %.2f locked %s held %s weather %.2f/%.2f wheels %s" % [racer.name, k.design.name, k.linear_velocity.length(), k.controls.throttle, k.controls.brake, k.controls.steer, k.locked, k.held, k.weather_grip, k.weather_drag,
					k.wheels.map(func(w) -> String: return "%s%s load %.0f grip %.2f off %.2f" % ["D" if w.driven else "-", "G" if w.grounded else "a", w.load, w.grip, w.offroad])])
				var ball := SphereShape3D.new()
				ball.radius = 2.5
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = ball
				query.transform = Transform3D(Basis.IDENTITY, k.global_position - k.global_basis.z * 1.5)
				query.exclude = [k.get_rid()]
				var touching := []
				for hit in k.get_world_3d().direct_space_state.intersect_shape(query, 16):
					var thing: Object = hit.collider
					touching.append("%s %s%s" % [thing.get_class(), thing.name, " " + str(thing.get_meta_list()) if thing.get_meta_list().size() > 0 else ""])
				print("    near it: %d things; sliding %s kick %s amount %.2f; boost %.1f ghost %.1f zapped %.1f shield %.1f slowdown %.1f tow %s; power %.0f force %.0f mass %.0f; puddle %.2f" % [touching.size(), k.sliding, k.slide_kick, k.slide_amount, k.boost_left, k.ghost_left, k.zapped_left, k.shield_left, k.slowdown_left, k.tow != null, k.power, k.max_force, k.mass, k.puddles.factor_at(k.global_position) if k.puddles != null else -1.0])
			elif race.time - since[racer] > STALL_TIME:
				stalls[racer] += 1
				print("STALL %s: %s stuck near %.0f m at %.0f s" % [course, racer.name, fposmod(now, race.track.length), race.time])
				since[racer] = race.time
	var lines: Array[String] = []
	var finished := 0
	for racer in race.racers:
		var kart: String = racer.kart.design.name
		if racer.progress.finished:
			finished += 1
			lines.append("  %-14s %-14s %6.1f s  %d resets" % [racer.name, kart, racer.progress.finish_time, resets[racer]])
		else:
			lines.append("  %-14s %-14s    DNF  %d resets, lap %d" % [racer.name, kart, resets[racer], racer.progress.current_lap()])
	print("\n".join(lines))
	var total_resets: int = resets.values().reduce(func(a, b): return a + b, 0)
	var total_stalls: int = stalls.values().reduce(func(a, b): return a + b, 0)
	print("RESULT %s %s %s: %d of %d finished, %d resets, %d stalls, %.0f s" % [course, race.conditions.weather, race.conditions.time, finished, race.racers.size(), total_resets, total_stalls, race.time])
	get_tree().quit()
