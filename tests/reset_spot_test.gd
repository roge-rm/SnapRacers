extends Node

## Where a reset puts a kart and how it holds it. Wide on the runoff it's put
## back about where it is. A kart that cuts across the grass is put back where
## it left the road, never further on than where it is, a reset back over the
## line takes the lap off, and a cut over the finish doesn't finish. It sits
## still for the hold with the throttle down, on a slope too, and drives after.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . tests/reset_spot_test.tscn

var failures := 0
var host: Node
var race: Race
var human: Race.Racer


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
	print("All reset spot checks passed." if failures == 0 else "%d reset spot checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _run() -> void:
	var previous := Game._screen
	Game.start_race(Tracks.path_of("peach_pit"))
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
	var track := race.track
	var length := track.length
	# Everyone else waits half a lap away, out of the way.
	human.kart.locked = false
	var parked := 0
	for racer in race.racers:
		if racer == human:
			continue
		racer.kart.locked = true
		racer.kart.global_transform = track.place_at(length * 0.5 + parked * 8.0)
		racer.offset = length * 0.5 + parked * 8.0
		parked += 1

	# Past the runoff, on the infield grass.
	var cut_out := track.width * 0.5 + TrackPath.KERB + Race.RUNOFF + 6.0

	# Running wide onto the runoff it keeps track of where it is, so a reset
	# puts it back about there.
	await _put(200.0, 0.0)
	var wide := await _put(220.0, track.width * 0.5 + TrackPath.KERB + Race.RUNOFF * 0.5)
	check(not human.kart.on_road and absf(human.road_offset - wide) < 3.0, "wide on the runoff it's off the road, and remembers where it is (%.1f m)" % human.road_offset)
	human.kart.request_reset()
	await frames(2)
	var short_of := wrapf(wide - human.offset, -length * 0.5, length * 0.5)
	check(short_of >= -0.5 and short_of < 25.0, "a reset from the runoff puts it back about where it is (%.1f m, it was at %.0f)" % [human.offset, wide])
	await frames(int((Kart.RESET_HOLD + Kart.RESET_SLOWDOWN_TIME) * 60.0))

	# On the road at 300 m, then dropped on the grass 60 m further on.
	var left_at := 300.0
	await _put(left_at, 0.0)
	check(absf(human.road_offset - left_at) < 3.0, "on the road it remembers where (%.1f m)" % human.road_offset)
	var grass := await _put(left_at + 60.0, cut_out)
	check(not human.kart.on_road, "dropped beside the road it's off it")
	check(absf(human.road_offset - left_at) < 3.0, "and still remembers where it left the road (%.1f m)" % human.road_offset)
	var laps := human.progress.laps
	human.kart.request_reset()
	await frames(2)
	var behind := wrapf(left_at - human.offset, -length * 0.5, length * 0.5)
	check(behind >= -0.5 and behind < 25.0, "a reset puts it back where it left the road (%.1f m, it left at %.0f, was at %.0f)" % [human.offset, left_at, grass])
	var across := (human.kart.global_position - track.point_at(human.offset)).dot(track.right_at(human.offset))
	check(track.on_road_across(human.offset, across), "on the road (%.1f m across)" % across)

	# The hold: throttle down the whole time, and it doesn't go anywhere.
	human.input.controls.throttle = 1.0
	check(human.kart.hold_left > 1.0 and human.kart.slowdown_left >= Kart.RESET_SLOWDOWN_TIME - 0.01, "it's held, with the slowdown waiting (%.2f s, %.2f s)" % [human.kart.hold_left, human.kart.slowdown_left])
	check(human.kart.ghost_left > human.kart.hold_left + 0.5, "a ghost for the hold and a bit after (%.2f s)" % human.kart.ghost_left)
	await frames(30)
	var landed := human.kart.global_position
	await frames(45)
	var crept := human.kart.global_position.distance_to(landed)
	check(human.kart.hold_left > 0.0 and crept < 0.3 and absf(human.kart.forward_speed) < 0.5, "with the throttle down it sits still in the hold (moved %.2f m, %.2f m/s)" % [crept, human.kart.forward_speed])
	await frames(int(Kart.RESET_HOLD * 60.0) - 75 + 60)
	check(human.kart.hold_left <= 0.0 and human.kart.slowdown_left > 0.0 and human.kart.slowdown_left < Kart.RESET_SLOWDOWN_TIME, "then the slowdown counts down (%.2f s)" % human.kart.slowdown_left)
	check(human.kart.forward_speed > 1.0, "and it drives off (%.1f m/s)" % human.kart.forward_speed)
	check(human.progress.laps == laps, "no lap gained or lost (%d)" % human.progress.laps)
	human.input.controls.throttle = 0.0

	# Never further on than where it is: with what it remembers ahead, it's
	# put back about where it is.
	await _put(500.0, cut_out)
	human.road_offset = 560.0
	human.kart.request_reset()
	await frames(2)
	behind = wrapf(500.0 - human.offset, -length * 0.5, length * 0.5)
	check(behind >= -0.5 and behind < 25.0, "a reset never moves it on (%.1f m, it was at 500)" % human.offset)

	# Over the line: it left the road just before it, cut across and finished
	# a lap, and the reset takes that lap off. Driving on gives it back.
	human.progress = RaceProgress.new(length, race.laps, length - 30.0)
	human.progress.laps = 0
	human.progress._quarters_seen = {1: true, 2: true, 3: true}
	await _put(length - 25.0, 0.0)
	var done := human.progress.laps
	await _put(20.0, cut_out)
	check(human.progress.laps == done + 1, "cutting over the line counts the lap (%d)" % human.progress.laps)
	human.kart.request_reset()
	await frames(3)
	check(human.offset > length * 0.5 and human.progress.laps == done and human.progress.lap_times.is_empty(), "put back behind the line takes it off (%.0f m, %d laps)" % [human.offset, human.progress.laps])
	human.input.controls.throttle = 1.0
	for i in 60 * 10:
		await frames(1)
		if human.progress.laps > done:
			break
	check(human.progress.laps == done + 1, "and driving over the line gives it back (%d)" % human.progress.laps)
	human.input.controls.throttle = 0.0

	# The last lap: cutting over the finish off the road doesn't finish it
	# yet, the reset puts it back, and driving over the line on the road does.
	await frames(int((Kart.RESET_HOLD + Kart.RESET_SLOWDOWN_TIME) * 60.0))
	human.progress = RaceProgress.new(length, race.laps, length - 30.0)
	human.progress.laps = race.laps - 1
	human.progress._quarters_seen = {1: true, 2: true, 3: true}
	await _put(length - 25.0, 0.0)
	await _put(20.0, cut_out)
	check(not human.progress.finished, "cutting over the finish off the road doesn't finish")
	human.kart.request_reset()
	await frames(3)
	check(human.offset > length * 0.5 and not human.progress.finished, "and a reset puts it back short of the line (%.0f m)" % human.offset)
	human.input.controls.throttle = 1.0
	for i in 60 * 10:
		await frames(1)
		if human.progress.finished:
			break
	check(human.progress.finished, "driving over it on the road finishes")
	human.input.controls.throttle = 0.0
	await _slope()


## A kart held after a reset on a steep slope stays put, and rolls once the
## hold's over.
func _slope() -> void:
	var tilt := deg_to_rad(15.0)
	var body := StaticBody3D.new()
	body.collision_layer = Kart.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 80.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, -400.0, 0.0)
	body.rotation = Vector3(tilt, 0.0, 0.0)
	add_child(body)
	var kart := Kart.new()
	kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
	# Facing down the hill, just above the slope.
	kart.position = body.position + Vector3(0.0, 2.0, 0.0)
	kart.rotation = Vector3(0.0, PI, 0.0)
	add_child(kart)
	await frames(30)
	kart.request_reset()
	# Once it's landed and the springs have settled, it doesn't slide down.
	await frames(50)
	var was := kart.global_position
	await frames(int(Kart.RESET_HOLD * 60.0) - 55)
	var crept := (kart.global_position - was).slide(kart.global_basis.y).length()
	check(kart.hold_left > 0.0 and crept < 0.03, "held on a 15 degree slope it stays put (%.3f m)" % crept)
	was = kart.global_position
	await frames(90)
	var rolled := kart.global_position.distance_to(was)
	check(rolled > 0.5, "and after the hold it rolls down (%.1f m)" % rolled)
	kart.queue_free()
	body.queue_free()


## Puts the kart down at `offset`, `across` metres right of the middle, on
## whatever's there, lets it settle and returns `offset`.
func _put(offset: float, across: float) -> float:
	var track := race.track
	var kart := human.kart
	var spot := track.place_at(offset)
	spot.origin += spot.basis.x * across
	var ray := PhysicsRayQueryParameters3D.create(spot.origin + Vector3.UP * 30.0, spot.origin + Vector3.DOWN * 30.0, Kart.LAYER_WORLD, [kart.get_rid()])
	var hit := kart.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		spot.origin = hit.position + Vector3.UP * 0.6
	kart.global_transform = spot
	kart.linear_velocity = Vector3.ZERO
	kart.angular_velocity = Vector3.ZERO
	human.offset = offset
	await frames(45)
	return offset
