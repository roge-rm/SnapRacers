extends Node

## Controlled opportunities in a real race, followed by an AI cannon shot.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/ai_gadget_test.tscn

var failures := 0
var race: Race
var ai: AIDriver
var kart: Kart
var target: Kart
var third: Kart
var origin: Vector3
const COURSE := "user://ai_gadget_test.json"


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(count := 2) -> void:
	for i in count:
		await get_tree().physics_frame


func place(body: Kart, ahead: float, side := 0.0, height := 0.0, speed := 0.0, sideways := 0.0) -> void:
	body.global_transform = Transform3D(Basis.IDENTITY, origin + Vector3(side, height, -ahead))
	body.linear_velocity = Vector3(sideways, 0.0, -speed)
	body.angular_velocity = Vector3.ZERO
	body.ghost_left = 0.0
	body.shield_left = 0.0
	body.zapped_left = 0.0
	body.boost_left = 0.0
	body.tow = null
	body.locked = false
	for wheel in body.wheels:
		wheel.grounded = true


func empty() -> void:
	kart.held = ["", ""]
	kart.held_uses = [0, 0]
	kart._gadget_wait = [0.0, 0.0]
	ai.controls.gadget = [false, false]
	ai.controls.throttle = 1.0
	ai.controls.brake = 0.0
	ai._think = 0.0
	ai._stuck = 0.0
	ai._waiting = false
	ai._backing = 0.0
	ai._leaving = 0.0
	place(kart, 0.0, 0.0, 0.0, 15.0)
	place(target, 80.0, 20.0)
	place(third, 80.0, -20.0)


func decide(kind: String, want: bool, label: String, speed := 15.0) -> void:
	check(ai._worth_using(kind, speed) == want, label)


func _ready() -> void:
	var file := FileAccess.open(COURSE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"name": "Gadget test", "grid": TrackPiece.TILE, "start": [1000, 0, 0, 0], "pieces": [{"type": "straight", "length": 16}]}))
	file.close()
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	Game.mode = Game.MODE_RACE
	Game.show_race(COURSE)
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	race.set_process(false)
	race.set_physics_process(false)
	for racer in race.racers:
		racer.kart.freeze = true
		racer.kart.controls = KartControls.new()
		racer.kart.locked = false
		racer.kart.global_position = Vector3(1600 + race.racers.find(racer) * 20, 20, 0)
		if racer.ai != null:
			racer.ai.set_physics_process(false)
		if racer.input != null:
			racer.input.set_physics_process(false)
	kart = race.player.kart
	target = race.racers[0].kart
	third = race.racers[1].kart
	for body in [kart, target, third]:
		body.build(KartDesign.load_file("res://tests/data/old_starter.json"))
	ai = AIDriver.new()
	ai.kart = kart
	ai.track = race.track
	ai.offset = 100.0
	ai.others = [kart, target, third]
	race.add_child(ai)
	ai.set_physics_process(false)
	ai._rng.seed = 12345
	origin = race.track.point_at(ai.offset) + Vector3.UP * 0.05
	await frames()
	await _opportunities()
	await _boost_boundaries()
	await _inventory()
	await _difficulty()
	await _actual_shot()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COURSE))
	print("All AI gadget checks passed." if failures == 0 else "%d AI gadget checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _opportunities() -> void:
	empty()
	await frames()
	for kind in ["cannon", "homing", "lightning", "dropper", "marbles", "wall", "spikes", "shockwave", "shield", "repair", "ghost"]:
		if kind in ["homing", "lightning"]:
			for racer in race.racers:
				racer.progress.offset = 0.0 if racer.kart != kart else 200.0
		decide(kind, false, "%s waits without a useful opportunity" % kind)
	for kind in ["turbo", "big_turbo", "triple_turbo"]:
		decide(kind, true, "%s uses a clear straight" % kind)
		kart.boost_left = 0.7
		decide(kind, false, "%s preserves a running boost" % kind)
		kart.boost_left = 0.0
		kart.wheels[0].grounded = false
		decide(kind, false, "%s waits while airborne" % kind)
		kart.wheels[0].grounded = true
	decide("tow", true, "a lone tow can use its safe turbo fallback")
	kart.boost_left = 0.5
	decide("tow", false, "tow fallback preserves an active boost")
	kart.boost_left = 0.0
	place(target, 12.0, 0.0, 0.0, 8.0)
	await frames()
	decide("turbo", false, "turbo holds for a slower kart in its duration corridor")
	decide("cannon", true, "cannon finds an intercept with launch velocity")
	target.linear_velocity.x = 15.0
	decide("cannon", false, "cannon holds for a crossing kart that will leave its path")
	place(target, 12.0, 0.0, 8.0)
	await frames()
	decide("cannon", false, "cannon holds for a kart on an upper level")
	place(target, 12.0)
	var wall := BrickWall.drop_behind(kart)
	race.add_child(wall)
	wall.global_position = origin + Vector3(0.0, -0.05, -6.0)
	await frames()
	decide("cannon", false, "cannon holds when a wall blocks its arc")
	wall.queue_free()
	await frames()
	# Standings select the actual homing target, independently of the roster order.
	for racer in race.racers:
		racer.progress.laps = 0
		racer.progress.offset = 0.0
		if racer.kart == kart:
			racer.progress.offset = 100.0
			racer.offset = 100.0
		elif racer.kart == target:
			racer.progress.offset = 112.0
			racer.offset = 112.0
	check(BrickShot._kart_ahead(kart) == target, "fixture uses the real race standings")
	decide("homing", true, "homing uses the actual standings target")
	target.ghost_left = 1.0
	decide("homing", false, "homing holds for its ghost target")
	target.ghost_left = 0.0
	place(target, -80.0, 30.0)
	await frames()
	decide("lightning", true, "lightning hits a standings leader behind and to the side")
	target.shield_left = 1.0
	decide("lightning", false, "lightning waits while all leaders are protected")
	target.shield_left = 0.0
	place(target, 20.0, 0.0, 0.0, 20.0)
	await frames()
	decide("tow", true, "tow catches the real eligible kart when it adds speed")
	kart.linear_velocity.z = -30.0
	decide("tow", false, "tow holds when already faster than the pull")
	kart.linear_velocity.z = -15.0
	for kind in ["wall", "spikes", "marbles", "dropper"]:
		place(target, -18.0, 0.0, 0.0, 20.0)
		await frames()
		decide(kind, true, "%s catches a follower's predicted lane" % kind)
		target.linear_velocity.x = 20.0
		decide(kind, false, "%s holds when the follower will cross another lane" % kind)
		place(target, -18.0, 0.0, 8.0, 20.0)
		await frames()
		decide(kind, false, "%s holds for another level" % kind)
		place(target, -18.0, 0.0, 0.0, 20.0)
		kart.wheels[0].grounded = false
		decide(kind, false, "%s waits for landing" % kind)
		kart.wheels[0].grounded = true
	place(target, 5.0)
	await frames()
	decide("shockwave", true, "shockwave has a reachable kart")
	target.shield_left = 1.0
	decide("shockwave", true, "shockwave can still shove a shield")
	target.ghost_left = 1.0
	decide("shockwave", false, "shockwave waits for ghosts")
	place(target, 1.0, 0.0, 8.0)
	await frames()
	decide("shockwave", false, "shockwave waits for another level inside its radius")
	place(target, 6.0, 0.0, 0.0, 2.0)
	await frames()
	decide("shield", true, "shield reacts to a predicted collision")
	decide("ghost", true, "ghost passes blocked traffic")
	kart.shield_left = 1.0
	decide("shield", false, "shield preserves current protection")
	kart.shield_left = 0.0
	kart.ghost_left = 1.0
	decide("ghost", false, "ghost preserves current protection")
	kart.ghost_left = 0.0
	place(target, 3.0, 4.5, 0.0, 15.0)
	await frames()
	decide("shield", false, "shield holds for safe parallel traffic")
	kart.zapped_left = 2.0
	decide("shield", true, "shield ends an active lightning strike")
	kart.zapped_left = 0.0
	place(target, 30.0, 15.0)
	var shot := BrickShot.fire(target)
	race.add_child(shot)
	shot.global_position = origin + Vector3(0.0, 0.7, -15.0)
	shot.linear_velocity = Vector3(0, 0, 20)
	await frames(1)
	decide("shield", true, "shield sees an incoming projectile")
	shot.queue_free()
	await frames()
	var trap := BrickTrap.drop_behind(kart)
	race.add_child(trap)
	trap.global_position = origin + Vector3(0.0, -0.04, -8.0)
	await frames()
	decide("shield", true, "shield reacts to an upcoming trap")
	decide("ghost", true, "ghost passes an upcoming trap")
	decide("turbo", false, "turbo holds for a trap in its corridor")
	var divider := StaticBody3D.new()
	divider.collision_layer = Kart.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.4)
	shape.shape = box
	divider.add_child(shape)
	race.add_child(divider)
	divider.global_position = origin + Vector3(0.0, 1.0, -4.0)
	await frames()
	decide("shield", false, "shield ignores a trap hidden behind a divider")
	decide("ghost", false, "ghost ignores a trap hidden behind a divider")
	divider.queue_free()
	trap.queue_free()
	await frames()
	var lost: Array[int] = [5, 6]
	kart.lose_parts(lost)
	decide("repair", true, "repair restores meaningful part damage")
	kart.repair_now()
	decide("repair", false, "repair holds on an intact kart")
	var wheel_indices: Array[int] = []
	for i in kart.design.parts.size():
		if KartDesign.is_wheel(kart.design.parts[i].id):
			wheel_indices.append(i)
			break
	kart.lose_parts(wheel_indices)
	check(AIGadgetTactics.score(ai, "repair", 15.0) >= 5.0, "a missing wheel gets urgent repair")
	kart.repair_now()


func _boost_boundaries() -> void:
	empty()
	var old_track := ai.track
	var old_offset := ai.offset
	# A bend 64 m ahead leaves room for a short burst, but not a big turbo.
	ai.track = TrackPath.from_dict({"grid": TrackPiece.TILE, "start": [origin.x, 0, origin.z + 32.0, 0], "pieces": [{"type": "straight", "length": 3}, {"type": "curve", "turn": "right", "size": 2}]})
	ai.offset = 32.0
	await frames()
	decide("triple_turbo", true, "a short triple burst fits before the bend")
	decide("big_turbo", false, "big turbo plans for its full 2.8 seconds before a bend")
	ai.track = old_track
	ai.offset = old_offset
	kart.global_basis = Basis(Vector3.UP, 0.4)
	decide("turbo", false, "turbo waits until aligned with the road")
	place(kart, 0.0, 0.0, 0.0, 15.0)
	var old_throttle := ai.controls.throttle
	ai.controls.throttle = 0.0
	decide("turbo", false, "turbo holds while lifting off")
	ai.controls.throttle = old_throttle
	ai._waiting = true
	decide("tow", false, "tow fallback holds while waiting at a crossing")
	ai._waiting = false
	ai._stuck = 1.0
	decide("ghost", true, "ghost can free a grounded stuck kart")
	ai._stuck = 0.0
	var lone_brick: Array[int] = []
	var steering: Array[int] = []
	var engines: Array[int] = []
	for i in kart.design.parts.size():
		var part := PartCatalog.get_part(kart.design.parts[i].id)
		if part.kind == "brick" and lone_brick.is_empty():
			lone_brick.append(i)
		elif part.kind == "steering":
			steering.append(i)
		if part.get("power", 0.0) > 0.0 or part.get("thrust", 0.0) > 0.0:
			engines.append(i)
	kart.lose_parts(lone_brick)
	decide("repair", false, "repair saves itself for more than one plain brick")
	kart.repair_now()
	kart.lose_parts(steering)
	check(AIGadgetTactics.score(ai, "repair", 15.0) >= 5.0, "lost steering gets urgent repair")
	kart.repair_now()
	kart.lose_parts(engines)
	check(AIGadgetTactics.score(ai, "repair", 15.0) >= 5.0, "lost drive power gets urgent repair")
	kart.repair_now()


func prime() -> void:
	ai._use_gadgets(0.01, 15.0)
	ai._held_for = [3.0, 3.0]
	ai._think = 0.0
	ai.controls.gadget = [false, false]


func _inventory() -> void:
	empty()
	Difficulty.apply(ai, "expert", 0, 7)
	ai.gadget_sense = 1.0
	await frames()
	kart.give("shockwave")
	prime()
	ai._held_for[0] = 100.0
	ai._use_gadgets(0.3, 15.0)
	check(not ai.controls.gadget.has(true), "an old shockwave still waits for a target")
	kart.held[0] = "cannon"
	ai._think = 0.0
	ai._use_gadgets(0.3, 15.0)
	check(ai._held_for[0] == 0.0 and not ai.controls.gadget.has(true), "a different kind loses the old item's age")
	empty()
	kart.give("shield")
	prime()
	kart.zapped_left = 2.0
	ai._use_gadgets(0.2, 15.0)
	check(ai.controls.gadget[0] and ai._held_for[0] == 0.0, "issuing a use resets that button's age")
	check(kart.use_gadget(0), "the issued shield is usable")
	kart.give("shield")
	kart._gadget_wait[0] = 0.0
	kart.zapped_left = 2.0
	ai.controls.gadget = [false, false]
	ai._think = 0.0
	ai._held_for[0] = 50.0
	ai._use_gadgets(0.01, 15.0)
	check(ai._held_for[0] == 0.0 and not ai.controls.gadget[0], "same-kind replacement before an empty tick starts fresh")
	empty()
	kart.give("turbo")
	kart.give("shield")
	kart._gadget_wait[0] = 1.0
	kart.zapped_left = 2.0
	prime()
	ai._use_gadgets(0.2, 15.0)
	check(not ai.controls.gadget[0] and ai.controls.gadget[1], "a cooling-down first button leaves the second usable")
	empty()
	kart.give("turbo")
	kart.give("repair")
	var indices: Array[int] = []
	for i in kart.design.parts.size():
		if KartDesign.is_wheel(kart.design.parts[i].id):
			indices.append(i)
			break
	kart.lose_parts(indices)
	prime()
	ai._use_gadgets(0.2, 15.0)
	check(ai.controls.gadget[1], "urgent repair wins over the first button's turbo")
	kart.repair_now()
	empty()
	kart.give("triple_turbo")
	prime()
	ai._use_gadgets(0.2, 15.0)
	check(ai.controls.gadget[0] and kart.use_gadget(0), "triple turbo starts its first burst")
	var duration := kart.boost_left
	ai.controls.gadget = [false, false]
	kart._gadget_wait[0] = 0.0
	ai._think = 0.0
	ai._use_gadgets(0.6, 15.0)
	ai._held_for[0] = 10.0
	ai._think = 0.0
	ai._use_gadgets(0.3, 15.0)
	check(not ai.controls.gadget[0] and kart.held_uses[0] == 2 and kart.boost_left == duration, "remaining triple bursts preserve the current 1.2 seconds")
	kart.boost_left = 0.0
	ai._think = 0.0
	ai._use_gadgets(0.3, 15.0)
	check(ai.controls.gadget[0], "triple turbo can fire again after the burst ends")


func _difficulty() -> void:
	var reactions: Array[float] = []
	var planning: Array[float] = []
	var confidence: Array[float] = []
	for level in Difficulty.LEVELS:
		empty()
		Difficulty.apply(ai, level, 0, 7)
		planning.append(ai.gadget_planning)
		confidence.append(ai.gadget_confidence)
		# Keep noticing deterministic here to measure reaction separately.
		ai.gadget_sense = 1.0
		kart.give("shield")
		kart.zapped_left = 2.0
		var elapsed := 0.0
		while elapsed < 2.0 and not ai.controls.gadget[0]:
			ai._use_gadgets(0.05, 15.0)
			elapsed += 0.05
		reactions.append(elapsed)
		check(ai.controls.gadget[0] and elapsed >= ai.gadget_reaction, "%s waits for its configured reaction (%.2f s)" % [level, elapsed])
	check(reactions[0] > reactions[1] and reactions[1] > reactions[2] and reactions[2] > reactions[3], "each difficulty reacts sooner, including Hard and Expert")
	check(planning[0] < planning[1] and planning[1] < planning[2] and planning[2] < planning[3], "each difficulty judges farther ahead")
	check(confidence[0] > confidence[1] and confidence[1] > confidence[2] and confidence[2] > confidence[3], "each difficulty accepts more demanding fixed shots")
	empty()
	place(target, 20.0, 0.0, 0.0, 5.0)
	await frames()
	Difficulty.apply(ai, "hard", 0, 7)
	decide("shield", false, "Hard holds before a collision enters its planning horizon")
	Difficulty.apply(ai, "expert", 0, 7)
	decide("shield", true, "Expert recognises that collision earlier")


func _actual_shot() -> void:
	empty()
	Difficulty.apply(ai, "expert", 0, 7)
	ai.gadget_sense = 1.0
	place(kart, 0.0)
	place(target, 12.0)
	await frames()
	kart.give("cannon")
	prime()
	ai._use_gadgets(0.2, 0.0)
	check(ai.controls.gadget[0], "AI requests a real cannon shot down a clear corridor")
	if ai.controls.gadget[0]:
		kart.use_gadget(0)
	await frames(45)
	check(target.lost.size() >= Kart.CANNON_PARTS, "the fixed cannon projectile reaches the chosen kart (%d lost)" % target.lost.size())
