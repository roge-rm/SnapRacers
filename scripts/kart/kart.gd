class_name Kart
extends RigidBody3D

## A kart built out of parts from a KartDesign.
##
## The whole kart is one rigid body. Every part adds its own collision box,
## mass and drag, so how it handles comes straight from what it's made of.
## The wheels don't collide at all. Each one casts a ray down to find the
## ground, pushes up like a spring and grips like a tire, which is far steadier
## than real wheel bodies on joints and much easier to keep in sync online.

signal was_reset

const SUSPENSION_TRAVEL := 0.12 # metres either side of where the wheel was built
const SUSPENSION_DAMPING := 0.55 # fraction of critical damping
const MAX_STEER := deg_to_rad(30.0)
const HIGH_SPEED_STEER := 0.35 # steering left at full speed, as a fraction
const STEER_RATE := 4.0 # how fast the wheels turn, in full locks per second
const BRAKE_FORCE := 2800.0
const REVERSE_FRACTION := 0.45
const REVERSE_TOP_SPEED := 6.0
const ROLL_HELP := 0.6 # lifts the tire forces toward the centre of mass so it doesn't flip in every corner
const RESET_LIFT := 1.0
const RESET_SLOWDOWN_TIME := 2.5
const RESET_SLOWDOWN := 0.5

const LAYER_WORLD := 1
const LAYER_KARTS := 2


class Wheel:
	var part: Dictionary
	var rest := Vector3.ZERO # wheel centre as built, in kart space
	var radius := 0.3
	var width := 0.25
	var grip := 1.0
	var rolling := 0.015
	var steered := false
	var driven := false
	var spring := 0.0
	var damper := 0.0
	var length := SUSPENSION_TRAVEL # from the top of its travel down to the wheel centre
	var grounded := false
	var load := 0.0
	var spin := 0.0
	var visual: Node3D


var design: KartDesign
var stats: KartStats
var controls := KartControls.new()
var wheels: Array[Wheel] = []

# What the parts add up to, worked out in build().
var power := 0.0
var max_force := 0.0
var drag_area := 0.0
var lift_area := 0.0

var steer_angle := 0.0
var forward_speed := 0.0
var slowdown_left := 0.0

var _reset_held := false
var _driven_count := 0


func _init() -> void:
	collision_layer = LAYER_KARTS
	collision_mask = LAYER_WORLD | LAYER_KARTS
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	continuous_cd = true
	can_sleep = false
	angular_damp = 0.5


func build(new_design: KartDesign) -> void:
	design = new_design
	for child in get_children():
		remove_child(child)
		child.queue_free()
	wheels.clear()

	stats = KartStats.compute(design)
	power = stats.power
	max_force = stats.max_force
	drag_area = stats.drag_area
	lift_area = stats.lift_area

	for info in stats.parts:
		if info.def.kind == "wheel":
			var w := Wheel.new()
			w.part = info.def
			w.rest = info.centre
			w.radius = info.def.get("radius", 0.3)
			w.width = info.def.get("width", 0.25)
			w.grip = info.def.get("grip", 1.0)
			w.rolling = info.def.get("rolling", 0.015)
			w.visual = PartVisuals.make_wheel(info.def)
			w.visual.position = info.centre
			add_child(w.visual)
			wheels.append(w)
			continue
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = info.extent
		shape.shape = box
		shape.position = info.centre
		add_child(shape)
		var look := PartVisuals.make(info.def, info.extent)
		look.position = info.centre
		add_child(look)

	if stats.has_seat:
		var driver := PartVisuals.make_driver()
		driver.position = stats.seat_top
		add_child(driver)
		# The driver takes hits too, so a roll-over lands on something.
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 0.7, 0.3)
		shape.shape = box
		shape.position = stats.seat_top + Vector3(0.0, 0.4, 0.0)
		add_child(shape)

	mass = maxf(stats.mass, 1.0)
	center_of_mass = stats.center_of_mass

	# The wheels ahead of the centre of mass steer and the ones behind it
	# drive. A kart with only one axle does both with it.
	_driven_count = 0
	var any_steered := false
	for w in wheels:
		w.steered = w.rest.z < center_of_mass.z - 0.05
		w.driven = w.rest.z > center_of_mass.z + 0.05
		any_steered = any_steered or w.steered
		if w.driven:
			_driven_count += 1
	for w in wheels:
		if not any_steered:
			w.steered = true
		if _driven_count == 0:
			w.driven = true
	if _driven_count == 0:
		_driven_count = wheels.size()

	# Springs are tuned so that the kart sits with every wheel exactly where
	# it was built, halfway through its travel.
	if not wheels.is_empty():
		var share := mass / wheels.size()
		for w in wheels:
			w.spring = share * KartStats.gravity() / SUSPENSION_TRAVEL
			w.damper = 2.0 * SUSPENSION_DAMPING * sqrt(w.spring * share)
			w.length = SUSPENSION_TRAVEL


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	if controls.reset and not _reset_held:
		_reset(state)
	_reset_held = controls.reset
	slowdown_left = maxf(slowdown_left - dt, 0.0)

	var basis := state.transform.basis
	var up := basis.y
	var origin := state.transform.origin
	var com := origin + state.center_of_mass
	var speed := state.linear_velocity.length()
	forward_speed = state.linear_velocity.dot(-basis.z)

	var steer_limit := MAX_STEER * lerpf(1.0, HIGH_SPEED_STEER, clampf(speed / 28.0, 0.0, 1.0))
	steer_angle = move_toward(steer_angle, controls.steer * steer_limit, STEER_RATE * MAX_STEER * dt)

	# Engine and brakes. Holding the brake once the kart has stopped reverses.
	var drive := 0.0
	var braking := false
	if controls.throttle > 0.0:
		drive = controls.throttle * minf(max_force, power / maxf(absf(forward_speed), 1.0))
	if controls.brake > 0.0:
		if forward_speed > 0.5:
			braking = true
		elif forward_speed > -REVERSE_TOP_SPEED:
			drive -= controls.brake * max_force * REVERSE_FRACTION
	if slowdown_left > 0.0:
		drive *= RESET_SLOWDOWN
	var drive_per_wheel := drive / maxf(_driven_count, 1)

	var space := state.get_space_state()
	var share := mass / maxf(wheels.size(), 1)
	for w in wheels:
		var anchor := state.transform * (w.rest + Vector3.UP * SUSPENSION_TRAVEL)
		var reach := SUSPENSION_TRAVEL * 2.0 + w.radius
		var query := PhysicsRayQueryParameters3D.create(anchor, anchor - up * reach, collision_mask, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			w.grounded = false
			w.load = 0.0
			w.length = move_toward(w.length, SUSPENSION_TRAVEL * 2.0, dt)
			continue

		var length := clampf(anchor.distance_to(hit.position) - w.radius, 0.0, SUSPENSION_TRAVEL * 2.0)
		var stretch_rate := (length - w.length) / dt
		w.length = length
		w.grounded = true
		var load := maxf(w.spring * (SUSPENSION_TRAVEL * 2.0 - length) - w.damper * stretch_rate, 0.0)
		w.load = load

		var normal: Vector3 = hit.normal
		var contact: Vector3 = hit.position
		var heading := -basis.z
		var side := basis.x
		if w.steered:
			heading = heading.rotated(up, -steer_angle)
			side = side.rotated(up, -steer_angle)
		heading = (heading - normal * heading.dot(normal)).normalized()
		side = (side - normal * side.dot(normal)).normalized()

		var v := state.linear_velocity + state.angular_velocity.cross(contact - com)
		var v_long := v.dot(heading)
		var v_lat := v.dot(side)
		w.spin += v_long / w.radius * dt

		# Tire forces. Sideways the tire tries to stop all slip in one step;
		# along its heading it drives, brakes and rolls. Then the lot is
		# capped by how much grip this tire has under this load, which is
		# where wide tires earn their extra drag.
		var stop_force := share / dt
		var f_lat := -v_lat * stop_force * 0.5
		var f_long := drive_per_wheel if w.driven else 0.0
		var resist := w.rolling * load
		if braking:
			resist += BRAKE_FORCE * controls.brake / wheels.size()
		f_long -= signf(v_long) * minf(resist, absf(v_long) * stop_force)
		var tire := Vector2(f_long, f_lat).limit_length(KartStats.TIRE_FRICTION * w.grip * load)

		state.apply_force(normal * load, contact - origin)
		var lifted := contact + up * (com - contact).dot(up) * ROLL_HELP
		state.apply_force(heading * tire.x + side * tire.y, lifted - origin)

	# Air: drag from everything facing forward, and downforce from any wings.
	var air := 0.5 * KartStats.AIR_DENSITY
	state.apply_central_force(-state.linear_velocity * speed * air * drag_area)
	state.apply_central_force(-up * air * lift_area * forward_speed * forward_speed)


## Puts the kart back on its wheels facing the way it was going, then holds
## it back for a moment so resetting is never a shortcut.
func _reset(state: PhysicsDirectBodyState3D) -> void:
	var facing := -state.transform.basis.z
	facing.y = 0.0
	if facing.length() < 0.1:
		facing = state.transform.basis.y
		facing.y = 0.0
	if facing.length() < 0.1:
		facing = Vector3.FORWARD
	var place := Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), state.transform.origin + Vector3.UP * RESET_LIFT)
	state.transform = place
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	steer_angle = 0.0
	slowdown_left = RESET_SLOWDOWN_TIME
	was_reset.emit.call_deferred()


func _process(_delta: float) -> void:
	for w in wheels:
		w.visual.position = w.rest + Vector3.UP * (SUSPENSION_TRAVEL - w.length)
		var turn := Basis(Vector3.UP, -steer_angle) if w.steered else Basis.IDENTITY
		w.visual.basis = turn * Basis(Vector3.RIGHT, -w.spin)
