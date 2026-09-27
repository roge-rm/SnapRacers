extends SceneTree
class Runner:
	extends Node
	var track: TrackPath
	var kart: Kart
	var ai: AIDriver
	var offset := 2.0
	var tick := 0
	func _ready() -> void:
		track = TrackPath.load_file("res://data/tracks/loopworks.json")
		add_child(TrackBuilder.new(track))
		kart = Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/starter.json"))
		kart.transform = track.place_at(2.0, 0.05)
		kart.reset_to = func(_w): return track.place_at(offset)
		kart.was_reset.connect(func(): print("RESET at %.0f" % offset))
		add_child(kart)
		ai = AIDriver.new()
		ai.kart = kart
		ai.track = track
		kart.controls = ai.controls
		add_child(ai)
	func _physics_process(_d: float) -> void:
		tick += 1
		offset = track.offset_of(kart.global_position, offset, 30.0)
		ai.offset = offset
		if tick % 15 == 0 and offset > 180 and offset < 280 and tick < 60 * 30:
			var mid := track.point_at(offset)
			print("t %.1f off %.0f spd %.1f thr %.1f brk %.1f steer %.2f stick %s grounded %d across %.1f below %.1f contacts %d" % [tick / 60.0, offset, kart.linear_velocity.length(), ai.controls.throttle, ai.controls.brake, ai.controls.steer, kart.sticking, kart.wheels.filter(func(w): return w.grounded).size(), (kart.global_position - mid).dot(track.right_at(offset)), (kart.global_position - mid).dot(track.up_at(offset)), kart.get_contact_count()])
		if tick == 60 * 30:
			get_tree().quit()
func _initialize() -> void:
	root.add_child(Runner.new())
