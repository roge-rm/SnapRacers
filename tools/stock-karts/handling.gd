extends SceneTree

## Checks how steady each stock kart is at speed. On a big flat stretch of
## road it gets each one up to most of its top speed, then with the throttle
## still down it steers hard one way (the way the steering buttons do), and
## then flicks left and right like a lane change. For both it prints the
## biggest slide, which is how far the kart ends up going sideways from where
## it's pointing, and whether it spun.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tools/stock-karts/handling.gd
##
## Name karts after -- to only do those, and set TRACE=1 to see the hard turn
## a tenth of a second at a time, with how much each wheel carries.

const STOCK := "res://data/karts/stock"
## Going sideways more than this is a spin, not a slide.
const SPUN := deg_to_rad(40.0)
const HOW_FAST := 0.8 # of its top speed, before it starts steering
const GIVE_UP := 40.0 # seconds to get up to speed


class Runner:
	extends Node

	var keys: Array[String] = []
	var kart: Kart
	var phase := ""
	var time := 0.0
	var target := 0.0
	var worst := {}
	var results := []

	func _ready() -> void:
		# Road everywhere, so it's the tires and not the grass.
		var ground := StaticBody3D.new()
		ground.collision_layer = Kart.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4000.0, 1.0, 4000.0)
		shape.shape = box
		shape.position.y = -0.5
		ground.add_child(shape)
		add_child(ground)
		print("kart           speed   hard turn          lane change")
		_next()

	func _next() -> void:
		if kart != null:
			kart.queue_free()
			kart = null
		if keys.is_empty():
			var spins := results.filter(func(r): return r).size()
			print("%d of %d runs spun." % [spins, results.size()])
			get_tree().quit()
			return
		var key: String = keys.pop_front()
		kart = Kart.new()
		kart.name = key
		kart.build(KartDesign.load_file("%s/%s.json" % [STOCK, key]))
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.3, 1500.0))
		add_child(kart)
		target = kart.stats.top_speed() * HOW_FAST
		phase = "settle"
		time = 0.0
		worst = {"turn": 0.0, "lane": 0.0}

	func _slide() -> float:
		var up := kart.global_basis.y
		var v := kart.linear_velocity - up * kart.linear_velocity.dot(up)
		if v.length() < 3.0:
			return 0.0
		return (-kart.global_basis.z).angle_to(v)

	func _physics_process(delta: float) -> void:
		if kart == null:
			return
		time += delta
		var c := kart.controls
		match phase:
			"settle":
				if time > 1.0:
					phase = "speed"
					time = 0.0
					c.throttle = 1.0
			"speed":
				if kart.forward_speed >= target or time > GIVE_UP:
					phase = "turn"
					time = 0.0
					target = kart.forward_speed
					c.steer = 1.0
			"turn":
				worst.turn = maxf(worst.turn, _slide())
				if OS.has_environment("TRACE") and Engine.get_physics_frames() % 6 == 0:
					print("  %.1f s: %.1f m/s, slide %.1f°, yaw %.2f, lock %.1f°, wheels %s" % [time, kart.linear_velocity.length(), rad_to_deg(_slide()), kart.angular_velocity.y, rad_to_deg(kart.steer_angle), kart.wheels.map(func(w): return "%s%s%.0f" % ["D" if w.driven else "", "S" if w.steered else "", w.load])])
				if time > 1.5:
					# Straighten up and get back to speed for the lane change.
					c.steer = 0.0
					phase = "straighten"
					time = 0.0
			"straighten":
				if time > 3.0:
					phase = "lane"
					time = 0.0
			"lane":
				worst.lane = maxf(worst.lane, _slide())
				c.steer = 1.0 if time < 0.4 else (-1.0 if time < 0.8 else 0.0)
				if time > 2.5:
					_report()
					_next()

	func _report() -> void:
		var spun_turn: bool = worst.turn > SPUN
		var spun_lane: bool = worst.lane > SPUN
		results.append(spun_turn)
		results.append(spun_lane)
		print("%-14s %4.0f   %5.1f° %-8s   %5.1f° %s" % [kart.name, target * 3.6, rad_to_deg(worst.turn), "SPUN" if spun_turn else "", rad_to_deg(worst.lane), "SPUN" if spun_lane else ""])


func _init() -> void:
	var runner := Runner.new()
	var asked := Array(OS.get_cmdline_user_args())
	for file in DirAccess.get_files_at(STOCK):
		if file.ends_with(".json") and (asked.is_empty() or asked.has(file.get_basename())):
			runner.keys.append(file.get_basename())
	runner.keys.sort()
	root.add_child.call_deferred(runner)
