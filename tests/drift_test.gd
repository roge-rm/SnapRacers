extends SceneTree

## Sliding around a corner. Starter karts go into a hard right turn at the
## same speed, one just steering and one with the gas and the brake held
## together for a moment. A third kicks the tail out the same way and then
## holds the slide on the gas, around and around without spinning. The sliding one swings its tail out and turns
## further, and once it's let go and the steering's straightened it grips
## and runs straight again. Plain braking still stops straight. And a thumb
## slid from GO onto the brake holds both, and onto look back looks behind
## with the gas still on.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/drift_test.gd

const SPEED := 18.0


class Runner:
	extends Node

	var failures := 0
	var tick := 0
	var steerer: Kart
	var slider: Kart
	var braker: Kart
	var holder: Kart
	var held_tail := []
	var held_slowest := INF
	var start_yaw := {}
	var most_tail := 0.0

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func kart_at(x: float) -> Kart:
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/stock/starter.json"))
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(x, 0.05, 110.0))
		add_child(kart)
		return kart

	## How far the kart's going off from where it's pointing, in degrees.
	static func tail_out(kart: Kart) -> float:
		var v := kart.linear_velocity
		v.y = 0.0
		if v.length() < 2.0:
			return 0.0
		return rad_to_deg(absf((-kart.global_basis.z).signed_angle_to(v, Vector3.UP)))

	func _ready() -> void:
		add_child(TestTrack.new())
		steerer = kart_at(-60.0)
		slider = kart_at(0.0)
		braker = kart_at(60.0)
		holder = kart_at(-110.0)

	func _physics_process(_delta: float) -> void:
		tick += 1
		if tick > 70 and tick < 170:
			held_tail.append(tail_out(holder))
			held_slowest = minf(held_slowest, holder.linear_velocity.length())
		match tick:
			40:
				for kart in [steerer, slider, braker, holder]:
					kart.linear_velocity = Vector3(0.0, 0.0, -SPEED)
					kart.controls.throttle = 1.0
					start_yaw[kart] = kart.global_rotation.y
			45:
				steerer.controls.steer = 1.0
				slider.controls.steer = 1.0
				slider.controls.brake = 1.0
				braker.controls.throttle = 0.0
				braker.controls.brake = 1.0
				holder.controls.steer = 1.0
				holder.controls.brake = 1.0
			54:
				# The kick's done, and it's held on the gas.
				holder.controls.brake = 0.0
			46:
				check(slider.sliding and not steerer.sliding, "gas and brake together at speed slide the kart")
			53, 60, 70:
				most_tail = maxf(most_tail, tail_out(slider))
			80:
				# Let go of the brake, and straighten up to catch it.
				slider.controls.brake = 0.0
				slider.controls.steer = -0.4
				steerer.controls.steer = 0.0
				var turned_slide := rad_to_deg(absf(angle_difference(start_yaw[slider], slider.global_rotation.y)))
				var turned_steer := rad_to_deg(absf(angle_difference(start_yaw[steerer], steerer.global_rotation.y)))
				check(turned_slide > turned_steer * 1.5 + 5.0, "it turns much further than just steering (%.0f against %.0f degrees)" % [turned_slide, turned_steer])
				check(most_tail > 12.0, "with the tail out (%.0f degrees)" % most_tail)
				var braked := rad_to_deg(absf(angle_difference(start_yaw[braker], braker.global_rotation.y)))
				check(braked < 3.0 and not braker.sliding, "plain braking still stops straight (%.1f degrees)" % braked)
			100:
				slider.controls.steer = 0.0
			170:
				var tail: float = held_tail.reduce(func(a, b): return a + b, 0.0) / maxf(held_tail.size(), 1)
				var turned := rad_to_deg(absf(angle_difference(start_yaw[holder], holder.global_rotation.y)))
				check(holder.sliding and not holder.slide_kick, "a slide kicked off and then held on the gas keeps going")
				check(tail > 12.0 and held_tail.max() < 50.0, "with the tail held out steadily, not spun (%.0f degrees on average, %.0f at most)" % [tail, held_tail.max()])
				check(turned > 90.0 and held_slowest > 7.0, "round the bend without stalling (%.0f degrees, never under %.1f m/s)" % [turned, held_slowest])
				holder.controls.steer = 0.0
			200:
				check(not holder.sliding, "straightening up ends it")
				check(tail_out(slider) < 8.0, "let go and steered straight, it grips again (%.0f degrees)" % tail_out(slider))
				check(slider.global_basis.y.y > 0.9, "the right way up")
				_touch()
				print("All drift checks passed." if failures == 0 else "%d drift checks failed." % failures)
				get_tree().quit(1 if failures > 0 else 0)

	## A thumb slid from GO down onto the brake holds both, and back up onto
	## GO it's just the gas again.
	func _touch() -> void:
		var touch := TouchControls.new()
		touch.size = Vector2(2340, 1080)
		add_child(touch)
		touch.visible = true
		var buttons := touch._buttons()
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = buttons.gas[0]
		touch._input(press)
		check(touch.throttle == 1.0 and touch.brake == 0.0, "a thumb on GO is the gas")
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = buttons.brake[0]
		touch._input(drag)
		check(touch.throttle == 1.0 and touch.brake == 1.0, "slid down onto the brake it holds both")
		drag.position = buttons.gas[0]
		touch._input(drag)
		check(touch.throttle == 1.0 and touch.brake == 0.0, "and back up onto GO it's just the gas")
		drag.position = buttons.look[0]
		touch._input(drag)
		check(touch.throttle == 1.0 and touch.look_back, "slid up onto look back it looks behind and keeps the gas on")
		drag.position = (buttons.look[0] + buttons.gas[0]) * 0.5
		touch._input(drag)
		check(touch.throttle == 1.0 and not touch.look_back, "sliding back off it looks forward again")
		drag.position = buttons.gas[0]
		touch._input(drag)
		check(touch.throttle == 1.0 and not touch.look_back and touch.brake == 0.0, "and back on GO it's just the gas")
		var fresh := InputEventScreenTouch.new()
		fresh.index = 1
		fresh.pressed = true
		fresh.position = buttons.brake[0]
		press.pressed = false
		touch._input(press)
		touch._input(fresh)
		check(touch.throttle == 0.0 and touch.brake == 1.0, "a thumb put straight on the brake is just the brake")


func _initialize() -> void:
	root.add_child(Runner.new())
