class_name Kart
extends RigidBody3D

## A kart built out of parts from a KartDesign.
##
## The whole kart is one rigid body. Every part adds its own collision box,
## mass and drag, so how it handles comes straight from what it's made of.
## Each wheel casts a ray down to find the ground, pushes up like a spring and
## grips like a tire, which is far steadier than real wheel bodies on joints
## and much easier to keep in sync online.
##
## Crashes knock parts off. Every hit is traced to the part that took it, and
## a part hit harder than its strength breaks away as a loose piece, along
## with anything that was only held on through it. The kart then drives with
## what's left. Resetting puts it all back together.

signal was_reset
signal parts_lost(indices: Array[int])
signal gadget_used(kind: String)

const SUSPENSION_TRAVEL := 0.12 # metres either side of where the wheel was built
const SUSPENSION_DAMPING := 0.55 # fraction of critical damping
## Past this much of its travel a spring gets much stiffer, like a bump stop,
## so hard landings and loops (where the kart is pressed down at three times
## its weight) don't bottom it out onto its chassis.
const BUMP_START := 1.5
const BUMP_STIFFNESS := 14.0
## The bump stop is damped too, or the kart bounces off it: round a loop the
## wheels went from full load to none and back, driving only half the time.
const BUMP_DAMPING := 3.0
const MAX_STEER := deg_to_rad(30.0)
const HIGH_SPEED_STEER := 0.35 # steering left at full speed, as a fraction
const STEER_RATE := 4.0 # how fast the wheels turn, in full locks per second
const BRAKE_FORCE := 2800.0
const REVERSE_FRACTION := 0.45
const REVERSE_TOP_SPEED := 6.0
const ROLL_HELP := 0.6 # lifts the cornering forces toward the centre of mass so it doesn't flip in every corner
const RESET_LIFT := 1.0
const RESET_SLOWDOWN_TIME := 2.5
const RESET_SLOWDOWN := 0.5

const LAYER_WORLD := 1
const LAYER_KARTS := 2
const LAYER_DEBRIS := 4
## Things karts crash into that aren't the track: fired bricks and dropped
## piles. Wheels don't ride on them.
const LAYER_HAZARD := 8

# Gadgets and studs.
const MOST_STUDS := 10
const TURBO_TIME := 1.6
const TURBO_FORCE := 1500.0
const TURBO_TOP_SPEED := 1.3 # how much further past its usual top speed a turbo can push
const SPRING_SPEED := 5.5 # upward kick from a spring, in m/s
const SHIELD_TIME := 4.0
## How much harder a ram plate hits: a knock from one counts this many times
## over on the kart it hits, and a solid one (more than RAM_HIT) knocks a part
## straight off, since the chassis a ram usually lands on is far too strong to
## break.
const RAM_KNOCK := 2.5
const RAM_HIT := 250.0
const RAM_EVERY := 0.5
const GADGET_COOLDOWN := 0.6

## A part's knocks add up over a few frames, since one crash lands over
## several physics steps, and fade after that.
const IMPACT_FADE := 0.5
## Wheels collide through a cylinder a bit smaller than the tire, so it only
## touches the ground when the suspension is squashed hard, like a bump stop,
## but still catches walls side on.
const WHEEL_BODY := 0.55
## Round loops and up wall rides the road is sticky: with two wheels on it and
## going at least this fast, gravity pulls toward the road instead of down.
## Any slower and you drop off. Hanging upside down (past the wall and on
## toward the top of a loop) takes more speed than riding a wall.
const STICK_SPEED := 5.0
const STICK_SPEED_OVERHEAD := 9.0
## A moment's grace, so a bump that lifts a wheel doesn't drop you.
const STICK_HOLD := 0.4
## While sticking, the kart is steadied to lie flat on the road, the way
## anti-gravity racers do it. Without this a kart up a wall ride would roll a
## little further than the road, lift its wheels and slide off. These are how
## hard it's turned back, and how much its roll is damped.
const STICK_ALIGN := 90.0
const STICK_ALIGN_DAMP := 13.0
const STICK_PITCH_DAMP := 4.0
## A little extra pull onto sticky road, to keep all four wheels planted over
## bumps. Round a loop the kart's own speed presses it on far harder.
const STICK_PULL := 0.1


class Wheel:
	var index := 0 # which part of the design this is
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
## While locked (before a race starts) the kart holds its brakes on and
## ignores the throttle.
var locked := false
## Where a reset puts the kart, given where it is now. A race points this at
## the nearest bit of track. Left empty, the kart just rights itself where it
## is.
var reset_to: Callable
var wheels: Array[Wheel] = []
## Parts that have broken off, by their index in the design.
var lost := {}

# What the parts add up to, worked out in build().
var power := 0.0
var max_force := 0.0
var drag_area := 0.0
var lift_area := 0.0

var steer_angle := 0.0
var forward_speed := 0.0
## Whether the kart is stuck to the road round a loop or up a wall right now.
var sticking := false
## Which way is up off the road while it's sticking.
var stick_up := Vector3.UP
var _stick_left := 0.0

## Studs picked up on the track, to spend on gadgets.
var studs := 0
## Every stud picked up this race, spent or not.
var studs_picked := 0
var boost_left := 0.0
var shield_left := 0.0
var _spring_asked := false
var _repair_asked := false
var _gadget_held: Array[bool] = [false, false]
var _gadget_wait: Array[float] = [0.0, 0.0]
var _bubble: MeshInstance3D
var _rammed_wait := 0.0
var slowdown_left := 0.0

var _reset_held := false
var _reset_asked := false
var _repair_pending := false
var _driven_count := 0
var _full: KartStats # the kart as built, before anything broke
var _wheel_setup := {} # part index -> [steered, driven, spring, damper]
var _impact := {} # part index -> recent knocks, in newton seconds
var _breaking: Array[int] = []
var _last_velocity := Vector3.ZERO
var _last_applied := Vector3.ZERO


func _init() -> void:
	collision_layer = LAYER_KARTS
	collision_mask = LAYER_WORLD | LAYER_KARTS | LAYER_HAZARD
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	continuous_cd = true
	can_sleep = false
	angular_damp = 0.5
	contact_monitor = true
	max_contacts_reported = 16
	# Slippery plastic: when the body does scrape the road or a wall it slides
	# rather than grinding to a halt.
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.3


## Builds the kart whole. The wheels' jobs and springs are settled here, from
## the complete kart, and stay the same when parts break off. That's why a kart
## that loses a wheel sags onto that corner instead of balancing on the rest.
func build(new_design: KartDesign) -> void:
	design = new_design
	lost.clear()
	_impact.clear()
	_breaking.clear()
	_full = KartStats.compute(design)
	_wheel_setup.clear()

	var com := _full.center_of_mass
	var steered := []
	var driven := []
	for info in _full.wheels:
		if info.centre.z < com.z - 0.05:
			steered.append(info.index)
		elif info.centre.z > com.z + 0.05:
			driven.append(info.index)
	# Each spring is tuned for the weight its own wheel carries, so the kart
	# sits level with every wheel where it was built, halfway through its
	# travel, however the weight is spread.
	var shares := _weight_shares(_full)
	for n in _full.wheels.size():
		var info: KartStats.PartInfo = _full.wheels[n]
		var share: float = shares[n] * _full.mass
		var spring := share * KartStats.gravity() / SUSPENSION_TRAVEL
		# A kart with only one axle steers and drives with it.
		var steers := steered.is_empty() or steered.has(info.index)
		var drives := driven.is_empty() or driven.has(info.index)
		_wheel_setup[info.index] = [steers, drives, spring, 2.0 * SUSPENSION_DAMPING * sqrt(spring * share)]
	_assemble()


## How much of the kart's weight each wheel carries standing still, as
## fractions that add up to one. The loads have to hold the kart up and
## balance around its centre of mass both ways, and of all the ways to do that
## this is the most even one. Wheels are never left carrying nothing.
static func _weight_shares(full: KartStats) -> Array[float]:
	var n := full.wheels.size()
	var out: Array[float] = []
	if n == 0:
		return out
	var com := full.center_of_mass
	# Rows of the balance: total, then moments along z and along x.
	var rows := [[], [], []]
	for info in full.wheels:
		rows[0].append(1.0)
		rows[1].append(info.centre.z - com.z)
		rows[2].append(info.centre.x - com.x)
	var target := Vector3(1.0, 0.0, 0.0)
	# Minimum-norm answer: loads = Aᵀ (A Aᵀ)⁻¹ b.
	var m := Basis()
	for r in 3:
		for c in 3:
			var dot := 0.0
			for k in n:
				dot += rows[r][k] * rows[c][k]
			m[c][r] = dot
	# Fewer than three wheels (or all in a line) leaves this unsolvable, so
	# fall back to an even split.
	if absf(m.determinant()) < 1e-6:
		for k in n:
			out.append(1.0 / n)
		return out
	var y := m.inverse() * target
	var total := 0.0
	for k in n:
		var share := maxf(rows[0][k] * y.x + rows[1][k] * y.y + rows[2][k] * y.z, 0.05 / n)
		out.append(share)
		total += share
	for k in n:
		out[k] /= total
	return out


## Puts together whatever parts are still on.
func _assemble() -> void:
	for child in get_children():
		if child == _bubble:
			continue
		remove_child(child)
		child.queue_free()
	wheels.clear()

	stats = KartStats.compute(design, lost, _full.origin_cell)
	power = stats.power
	max_force = stats.max_force
	drag_area = stats.drag_area
	lift_area = stats.lift_area

	for info in stats.parts:
		if info.def.kind == "wheel":
			var w := Wheel.new()
			w.index = info.index
			w.part = info.def
			w.rest = info.centre
			w.radius = info.def.get("radius", 0.3)
			w.width = info.def.get("width", 0.25)
			w.grip = info.def.get("grip", 1.0)
			w.rolling = info.def.get("rolling", 0.015)
			var setup: Array = _wheel_setup[info.index]
			w.steered = setup[0]
			w.driven = setup[1]
			w.spring = setup[2]
			w.damper = setup[3]
			w.visual = PartVisuals.make_wheel(info.def)
			w.visual.position = info.centre
			add_child(w.visual)
			wheels.append(w)
			var body := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = w.radius * WHEEL_BODY
			cylinder.height = w.width
			body.shape = cylinder
			body.position = info.centre
			body.rotation.z = PI * 0.5
			add_child(body)
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
	_driven_count = 0
	for w in wheels:
		if w.driven:
			_driven_count += 1


## Resets the kart on the next physics step, just as if the driver had
## pressed reset. The race uses this when a kart falls off the track.
func request_reset() -> void:
	_reset_asked = true


## Knocks these parts off, along with anything that was only held on through
## them. It's its own step so that in a network game the server can decide
## what broke and tell everyone.
func lose_parts(indices: Array[int]) -> void:
	var newly: Array[int] = []
	for i in indices:
		if i < 0 or i >= design.parts.size() or lost.has(i):
			continue
		if PartCatalog.get_part(design.parts[i].id).get("kind", "") == "seat":
			continue
		lost[i] = true
		newly.append(i)
	if newly.is_empty():
		return
	var seat := design.seat_index()
	if seat != -1:
		for i in design.detached_after(lost, seat):
			lost[i] = true
			newly.append(i)

	# Throw the pieces off from where they were, moving the way that bit of
	# the kart was moving.
	var com := global_transform * center_of_mass
	for info in stats.parts:
		if not newly.has(info.index):
			continue
		var at := global_transform * info.centre
		var piece := Debris.make(info.def, info.extent, Transform3D(global_basis, at))
		piece.linear_velocity = linear_velocity + angular_velocity.cross(at - com)
		piece.angular_velocity = angular_velocity
		get_parent().add_child(piece)

	var keep_linear := linear_velocity
	var keep_angular := angular_velocity
	_assemble()
	linear_velocity = keep_linear
	angular_velocity = keep_angular
	parts_lost.emit(newly)


func _physics_process(delta: float) -> void:
	boost_left = maxf(boost_left - delta, 0.0)
	_rammed_wait = maxf(_rammed_wait - delta, 0.0)
	shield_left = maxf(shield_left - delta, 0.0)
	for slot in 2:
		_gadget_wait[slot] = maxf(_gadget_wait[slot] - delta, 0.0)
	for slot in 2:
		var pressed: bool = controls.gadget[slot] if slot < controls.gadget.size() else false
		if pressed and not _gadget_held[slot]:
			use_gadget(slot)
		_gadget_held[slot] = pressed
	if _bubble != null:
		_bubble.visible = shield_left > 0.0

	if _repair_asked:
		# A repair kit: everything back on, and no slowdown.
		_repair_asked = false
		lost.clear()
		_impact.clear()
		_breaking.clear()
		_assemble()
	elif _repair_pending:
		_repair_pending = false
		lost.clear()
		_impact.clear()
		_breaking.clear()
		_assemble()
	elif not _breaking.is_empty():
		var breaking := _breaking.duplicate()
		_breaking.clear()
		lose_parts(breaking)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	var applied := Vector3.ZERO
	if (controls.reset and not _reset_held) or _reset_asked:
		_reset_asked = false
		_reset(state)
	_reset_held = controls.reset
	slowdown_left = maxf(slowdown_left - dt, 0.0)
	if _spring_asked:
		_spring_asked = false
		state.linear_velocity += state.transform.basis.y * SPRING_SPEED

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
	if locked:
		braking = forward_speed > 0.05
	elif controls.throttle > 0.0:
		drive = controls.throttle * minf(max_force, power / maxf(absf(forward_speed), 1.0))
	if controls.brake > 0.0 and not locked:
		if forward_speed > 0.5:
			braking = true
		elif forward_speed > -REVERSE_TOP_SPEED:
			drive -= controls.brake * max_force * REVERSE_FRACTION
	if slowdown_left > 0.0:
		drive *= RESET_SLOWDOWN
	elif boost_left > 0.0 and forward_speed < stats.top_speed() * TURBO_TOP_SPEED:
		drive += TURBO_FORCE
	var drive_per_wheel := drive / maxf(_driven_count, 1)

	var space := state.get_space_state()
	var sticky_up := Vector3.ZERO
	var sticky_wheels := 0
	var share := mass / maxf(wheels.size(), 1)
	for w in wheels:
		var anchor := state.transform * (w.rest + Vector3.UP * SUSPENSION_TRAVEL)
		var reach := SUSPENSION_TRAVEL * 2.0 + w.radius
		# Wheels only look for the track, never other karts, or a kart in
		# traffic would climb up onto the one beside it.
		var query := PhysicsRayQueryParameters3D.create(anchor, anchor - up * reach, LAYER_WORLD, [get_rid()])
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
		var squash := SUSPENSION_TRAVEL * 2.0 - length
		var bump := maxf(squash - SUSPENSION_TRAVEL * BUMP_START, 0.0) * w.spring * BUMP_STIFFNESS
		var damping := w.damper * (BUMP_DAMPING if bump > 0.0 else 1.0)
		var load := maxf(w.spring * squash + bump - damping * stretch_rate, 0.0)
		w.load = load

		var normal: Vector3 = hit.normal
		var ground_body: Object = hit.get("collider")
		if ground_body != null and ground_body.get_meta("sticky", false):
			sticky_up += normal
			sticky_wheels += 1
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
		# Grass and the like grip less and drag more than the road. The
		# ground says how, through its "grip" and "drag" metadata.
		var ground: Object = hit.get("collider")
		var grip_here: float = ground.get_meta("grip", 1.0) if ground != null else 1.0
		var drag_here: float = ground.get_meta("drag", 1.0) if ground != null else 1.0
		var resist := w.rolling * load * drag_here
		if braking:
			resist += BRAKE_FORCE * (1.0 if locked else controls.brake) / wheels.size()
		f_long -= signf(v_long) * minf(resist, absf(v_long) * stop_force)
		var tire := Vector2(f_long, f_lat).limit_length(KartStats.TIRE_FRICTION * w.grip * grip_here * load)

		state.apply_force(normal * load, contact - origin)
		# Cornering forces act a little below the centre of mass, so it leans
		# but doesn't flip. Driving and braking act right at its height, so it
		# doesn't squat onto its tail pulling away or dive when it brakes.
		var height := (com - contact).dot(up)
		state.apply_force(side * tire.y, contact + up * height * ROLL_HELP - origin)
		state.apply_force(heading * tire.x, contact + up * height - origin)
		applied += normal * load + side * tire.y + heading * tire.x

	# Air: drag from everything facing forward, and downforce from any wings.
	# Sticky road. The world pulls everything down already, so this cancels
	# that and pulls toward the road instead.
	var needed := STICK_SPEED if up.y > -0.1 else STICK_SPEED_OVERHEAD
	if sticky_wheels >= 2 and speed > needed:
		stick_up = sticky_up.normalized()
		_stick_left = STICK_HOLD
	else:
		_stick_left = maxf(_stick_left - dt, 0.0)
	sticking = _stick_left > 0.0
	if sticking:
		var g := KartStats.gravity()
		var pull := mass * g * (Vector3.UP - stick_up * (1.0 + STICK_PULL))
		state.apply_central_force(pull)
		applied += pull
		# Turn the kart to lie flat on the road, and damp its roll firmly and
		# its pitch lightly. Round a loop the kart has to keep pitching over,
		# and damping that as hard as roll held it back from the curve; up a
		# wall ride it needs a little, or it bounces off as the road rises.
		var tilt := up.cross(stick_up)
		var forward := -basis.z
		var roll := forward * state.angular_velocity.dot(forward)
		var pitch := basis.x * state.angular_velocity.dot(basis.x)
		var want := tilt * STICK_ALIGN - roll * STICK_ALIGN_DAMP - pitch * STICK_PITCH_DAMP
		state.apply_torque(state.inverse_inertia_tensor.inverse() * want)

	var air := 0.5 * KartStats.AIR_DENSITY
	var drag := -state.linear_velocity * speed * air * drag_area
	var downforce := -up * air * lift_area * forward_speed * forward_speed
	state.apply_central_force(drag)
	state.apply_central_force(downforce)
	applied += drag + downforce

	_feel_knocks(state)
	_last_velocity = state.linear_velocity
	_last_applied = applied


## Works out how hard the kart was just knocked and which parts took it.
## Any part hit harder than it can take comes off in the next
## _physics_process, since shapes can't change in the middle of a step.
##
## How hard comes from the kart's change of speed since last step, less what
## its own engine, tires, air and gravity did. The physics engine's own
## contact impulses came out at well under half the real knock, so they're
## only used to share it out between the parts that were touching something.
func _feel_knocks(state: PhysicsDirectBodyState3D) -> void:
	var count := state.get_contact_count()
	for part in _impact.keys():
		_impact[part] *= IMPACT_FADE
		if _impact[part] < 1.0:
			_impact.erase(part)
	if count == 0:
		return
	var gravity := Vector3.DOWN * KartStats.gravity()
	var expected := (_last_applied / mass + gravity) * state.step
	var knock := ((state.linear_velocity - _last_velocity) - expected).length() * mass

	var shares := {}
	var total := 0.0
	var rammed := false
	var to_kart := state.transform.affine_inverse()
	for i in count:
		var part := part_at(to_kart * state.get_contact_local_position(i))
		if part == -1:
			continue
		# Contacts that report nothing still count for a little, so a part
		# can't dodge a crash just because the engine missed it.
		var weight := state.get_contact_impulse(i).length() + 0.01
		# Hit by another kart's ram plate: that counts for a lot more.
		var other: Object = state.get_contact_collider_object(i)
		if other is Kart and other.rammed_with(state.get_contact_collider_position(i)):
			weight *= RAM_KNOCK
			rammed = true
		shares[part] = shares.get(part, 0.0) + weight
		total += weight
	if rammed:
		knock *= RAM_KNOCK
		if knock > RAM_HIT * RAM_KNOCK and _rammed_wait <= 0.0 and shield_left <= 0.0:
			_rammed_wait = RAM_EVERY
			knock_off_a_part.call_deferred()
	# A shield holds everything on, however hard the knock.
	if shield_left > 0.0:
		return
	for part in shares:
		_impact[part] = _impact.get(part, 0.0) + knock * shares[part] / total
		var strength: float = PartCatalog.get_part(design.parts[part].id).get("strength", 0.0)
		if strength > 0.0 and _impact[part] > strength and not _breaking.has(part):
			_breaking.append(part)


# Gadgets.

## The gadgets still on the kart, in the order they were built on, as
## [part index, part].
func gadgets() -> Array:
	var out := []
	if stats == null:
		return out
	for info in stats.parts:
		if info.def.kind == "gadget":
			out.append([info.index, info.def])
	return out


## The gadgets that need a button (the ones that cost studs), at most two.
func buttons() -> Array:
	return gadgets().filter(func(g): return int(g[1].get("cost", 0)) > 0).slice(0, 2)


func has_gadget(kind: String) -> bool:
	return gadgets().any(func(g): return g[1].get("gadget", "") == kind)


func can_use(slot: int) -> bool:
	var list := buttons()
	if slot >= list.size() or _gadget_wait[slot] > 0.0 or locked:
		return false
	return studs >= int(list[slot][1].get("cost", 0))


## Uses the gadget on this button, if there are studs enough. It's its own
## step so that in a network game the server can decide and tell everyone.
func use_gadget(slot: int) -> bool:
	if not can_use(slot):
		return false
	var def: Dictionary = buttons()[slot][1]
	studs -= int(def.get("cost", 0))
	_gadget_wait[slot] = GADGET_COOLDOWN
	match def.get("gadget", ""):
		"turbo":
			boost_left = TURBO_TIME
		"spring":
			_spring_asked = true
		"dropper":
			for brick in BrickPile.drop_behind(self):
				get_parent().add_child(brick)
		"cannon":
			get_parent().add_child(BrickShot.fire(self))
		"repair":
			_repair_asked = true
		"shield":
			shield_left = SHIELD_TIME
			_show_bubble()
	gadget_used.emit(def.get("gadget", ""))
	return true


func add_studs(count: int) -> void:
	studs_picked += maxi(count, 0)
	studs = clampi(studs + count, 0, MOST_STUDS)


## Did this point, in the world, hit the front of this kart where its ram
## plate is? Anything level with the plate or ahead of it counts, since the
## chassis under it is flush with it and takes the hit just as often.
func rammed_with(point: Vector3) -> bool:
	if stats == null:
		return false
	for info in stats.parts:
		if info.def.get("gadget", "") == "ram":
			var local := global_transform.affine_inverse() * point
			return local.z <= info.centre.z + info.extent.z * 0.5 + 0.05
	return false


## Knocked by a fired brick: one part comes off, from the outside in, unless
## a shield is up.
func knock_off_a_part() -> void:
	if shield_left > 0.0 or stats == null:
		return
	var outermost := -1
	var furthest := -1.0
	for info in stats.parts:
		if info.def.kind in ["seat", "plate"]:
			continue
		var reach := (info.centre - center_of_mass).length()
		if reach > furthest:
			furthest = reach
			outermost = info.index
	if outermost != -1:
		var one: Array[int] = [outermost]
		lose_parts(one)


func _show_bubble() -> void:
	if _bubble == null:
		_bubble = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.9
		sphere.height = 3.0
		_bubble.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.35, 0.65, 1.0, 0.25)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_bubble.material_override = material
		_bubble.position = Vector3(0.0, 0.8, 0.0)
	if _bubble.get_parent() == null:
		add_child(_bubble)


## Which part is at this point on the kart, in kart space. It's the part
## whose box is nearest, so a hit on the edge of a brick counts for that brick.
func part_at(point: Vector3) -> int:
	var best := -1
	var best_distance := INF
	for info in stats.parts:
		var box := AABB(info.centre - info.extent * 0.5, info.extent)
		var nearest := point.clamp(box.position, box.end)
		var d := nearest.distance_squared_to(point)
		if d < best_distance:
			best_distance = d
			best = info.index
	return best


## Puts the kart back on its wheels facing the way it was going, with any
## lost parts back on, then holds it back for a moment so resetting is never
## a shortcut.
func _reset(state: PhysicsDirectBodyState3D) -> void:
	var facing := -state.transform.basis.z
	facing.y = 0.0
	if facing.length() < 0.1:
		facing = state.transform.basis.y
		facing.y = 0.0
	if facing.length() < 0.1:
		facing = Vector3.FORWARD
	var place := Transform3D(Basis.looking_at(facing.normalized(), Vector3.UP), state.transform.origin + Vector3.UP * RESET_LIFT)
	if reset_to.is_valid():
		place = reset_to.call(state.transform.origin)
	state.transform = place
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	steer_angle = 0.0
	slowdown_left = RESET_SLOWDOWN_TIME
	_repair_pending = true
	was_reset.emit.call_deferred()


func _process(_delta: float) -> void:
	for w in wheels:
		w.visual.position = w.rest + Vector3.UP * (SUSPENSION_TRAVEL - w.length)
		var turn := Basis(Vector3.UP, -steer_angle) if w.steered else Basis.IDENTITY
		w.visual.basis = turn * Basis(Vector3.RIGHT, -w.spin)
