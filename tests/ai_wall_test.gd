extends SceneTree

## An AI driver down a long straight with two brick walls across its line.
## It has to steer round both without knocking a brick, and then, with a
## wheel knocked off, reset to get it back on instead of limping along.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/ai_wall_test.gd

const WALLS := [[120.0, 0.0], [230.0, 2.5]]


class Runner:
	extends Node

	var track: TrackPath
	var kart: Kart
	var ai: AIDriver
	var offset := 2.0
	var tick := 0
	var failures := 0
	var walls: Array[BrickWall] = []
	var lost_at := -1
	var reset_at := -1
	## Where every brick started, to tell whether any were knocked.
	var starts := {}

	func _ready() -> void:
		track = TrackPath.from_dict({ "pieces": [{ "type": "straight", "length": 14 }] })
		add_child(TrackBuilder.new(track))
		for spot in WALLS:
			var wall := BrickWall.new()
			var place := track.place_at(spot[0], 0.0)
			place.origin += place.basis.x * spot[1]
			wall.transform = place
			add_child(wall)
			walls.append(wall)
		kart = Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/stock/starter.json"))
		kart.transform = track.place_at(2.0, 0.05)
		add_child(kart)
		kart.was_reset.connect(func() -> void: reset_at = tick)
		ai = AIDriver.new()
		ai.kart = kart
		ai.track = track
		kart.controls = ai.controls
		add_child(ai)

	## How far the furthest brick of this wall has moved.
	func moved(wall: BrickWall) -> float:
		var most := 0.0
		for brick in wall.get_children():
			if brick is RigidBody3D:
				if not starts.has(brick):
					starts[brick] = brick.global_position
				most = maxf(most, brick.global_position.distance_to(starts[brick]))
		return most

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _physics_process(_delta: float) -> void:
		tick += 1
		if tick == 2:
			for wall in walls:
				moved(wall)
		offset = track.offset_of(kart.global_position, offset, 30.0)
		ai.offset = offset
		if lost_at < 0 and offset > WALLS[-1][0] + 20.0:
			for i in walls.size():
				check(moved(walls[i]) < 0.05, "it gets round the brick wall %.1f m across at %.0f m without knocking a brick (moved %.2f m)" % [WALLS[i][1], WALLS[i][0], moved(walls[i])])
			for i in kart.design.parts.size():
				if KartDesign.is_wheel(kart.design.parts[i].id):
					var wheel: Array[int] = [i]
					kart.lose_parts(wheel)
					break
			lost_at = tick
		if lost_at >= 0 and tick == lost_at + 150:
			check(reset_at > lost_at, "with a wheel knocked off it resets (%.1f s after)" % ((reset_at - lost_at) / 60.0))
			check(kart.lost.is_empty(), "the reset puts the wheel back on")
			finish()
		if tick == 60 * 40:
			check(false, "it gets past both walls in 40 s (it's at %.0f m)" % offset)
			finish()

	func finish() -> void:
		print("All AI wall checks passed." if failures == 0 else "%d AI wall checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
