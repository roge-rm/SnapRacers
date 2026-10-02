class_name Kart
extends RigidBody3D

## A kart built from the parts in a KartDesign.
##
## The whole kart is one rigid body, and every part adds its own collision box,
## mass and drag. Each wheel casts a ray down to the ground, pushes up like a
## spring and grips like a tire, which is steadier than wheels on joints and
## easier to keep in sync online.
##
## A part hit harder than its strength breaks off as a loose piece, along with
## anything only held on through it, and the kart drives on with what's left. A
## reset puts it all back.

signal was_reset
signal parts_lost(indices: Array[int])
signal gadget_used(kind: String)
## It's thrown a tow rope onto this kart (see TowRope), so others can show it.
signal towed(to: Kart)
## It broke some scenery (see WorldDamage), so other devices can too.
signal broke_scenery(group: int, at: Vector3, velocity: Vector3)
## Its lost parts are back on, after a reset or from a repair kit.
signal repaired

const SUSPENSION_TRAVEL := 0.12 # metres up or down from where the wheel was built
const SUSPENSION_DAMPING := 0.55 # fraction of critical damping
## Past this much of its travel a spring gets much stiffer, like a bump stop,
## so hard landings and loops (where the kart is pressed down at three times
## its weight) don't bottom it out onto its chassis.
const BUMP_START := 1.5
const BUMP_STIFFNESS := 14.0
## The bump stop is damped too, or the kart bounces off it going around a loop.
const BUMP_DAMPING := 3.0
const MAX_STEER := deg_to_rad(30.0)
## How far the front wheels look turned at full lock. At speed they really
## turn only a degree or two, which nobody could see, so they show how much of
## the steering there is instead, the way the steering wheel does.
const SHOWN_LOCK := deg_to_rad(25.0)
const HIGH_SPEED_STEER := 0.35 # how much of the steering is left at full speed
## Full lock turns the front wheels this much past where the tires run out of
## grip, so the whole stick does something.
const SLIDE_MARGIN := 0.95
## A slide smaller than this is just a kart cornering hard (see steer_limit()).
const SMALL_SLIDE := deg_to_rad(3.0)
const STEER_RATE := 4.0 # how fast the wheels turn, in full locks per second
## Stability control (see _steady()). It starts working above this speed, in
## metres a second.
const STEADY_SPEED := 8.0
## How much faster than its front wheels point it the kart can turn before
## stability control steps in, as a share of the turn plus a little, in radians
## a second.
const STEADY_LEEWAY := 0.3
const STEADY_SLACK := 0.15
## How quickly it takes the extra turn away, per second.
const STEADY_RATE := 6.0
const BRAKE_FORCE := 2800.0
const REVERSE_FRACTION := 0.45
## A jet has no push through the wheels to reverse with, so every kart gets
## at least this much push backward, like a little starter motor.
const REVERSE_PUSH := 1000.0
const REVERSE_TOP_SPEED := 6.0
const ROLL_HELP := 0.6 # lifts the cornering forces toward the centre of mass so it doesn't flip in every corner
const RESET_LIFT := 1.0
## A slide starts with a kick: gas and brake together above SLIDE_SPEED while
## steering lock the back wheels, so the tail steps out. Then it's held on the
## gas: as long as you keep the gas on and steer into the bend, the back
## wheels slide with only some of their grip, the engine drives, and the kart
## holds its tail out at a steady angle, more the harder you steer, so it
## won't spin. Straighten up or let go of the gas and it grips again over
## SLIDE_RECOVER seconds.
##
## A held slide keeps its speed, losing slide_scrub a second, and corners up
## to slide_corner times as hard as gripping, so it's quicker round a hairpin
## than braking for it, but the longer it's held the more it loses, so it's
## slower round a gentle bend. These were tuned with
## tools/stock-karts/slide_bench.gd, so they can be changed from there.
const SLIDE_SPEED := 6.0
const SLIDE_REAR_GRIP := 0.2
static var slide_hold_grip := 0.5
const SLIDE_RECOVER := 0.4
## How far the tail's held out, from the least steering into the bend to full.
const SLIDE_ANGLE := [deg_to_rad(15.0), deg_to_rad(32.0)]
## How hard the angle's held, per second.
const SLIDE_HOLD := 7.0
## How long steering straight (or the other way) can last before the slide
## ends, so the thumb can wobble.
const SLIDE_LET_GO := 0.2
## How far into the bend the front wheels point, past the way it's going,
## while a slide's held.
const SLIDE_FRONT := deg_to_rad(8.0)
static var slide_corner := 1.3
static var slide_scrub := 1.0
## How fast a held slide gets back to its speed when the tires drag it down.
const SLIDE_CARRY := 10.0
## Once it's going, a slide keeps going down to this speed.
const SLIDE_KEEP_SPEED := 4.0
static var slide_brake := 1.0
const RESET_SLOWDOWN_TIME := 2.5
const RESET_SLOWDOWN := 0.5

const LAYER_WORLD := 1
const LAYER_KARTS := 2
const LAYER_DEBRIS := 4
## Things karts crash into that aren't the track, like fired bricks and
## dropped piles. Wheels don't ride on them.
const LAYER_HAZARD := 8
## Loose bricks knocked off the scenery (see WorldDamage). Karts push them
## about, and wheels don't ride on them.
const LAYER_RUBBLE := 16
## How fast a kart has to be going into scenery to break it, in metres a
## second, how much of its speed it keeps going through something small it
## broke, and how soon after a break it can break something else.
const BREAK_SPEED := 7.0
const PLOUGH := 0.7
const BREAK_EVERY := 0.25

# Power-ups (see Powerups).
const TURBO_TIME := 1.6
const BIG_TURBO_TIME := 2.8
## Each of a triple turbo's three goes.
const TRIPLE_TURBO_TIME := 1.2
const TURBO_FORCE := 1000.0
const TURBO_TOP_SPEED := 1.3 # how much further past its usual top speed a turbo can push
## A shockwave shoves karts this far away from it, up to this hard (as a
## change in speed, in m/s) nearest, and closer than KNOCK_REACH knocks a
## part loose.
const SHOCK_REACH := 8.0
const SHOCK_SHOVE := 7.0
const SHOCK_KNOCK_REACH := 4.0
const SHIELD_TIME := 4.0
## How long a ghost goes through karts, bricks and oil.
const GHOST_TIME := 3.0
## How long lightning slows the karts it hits, and how much of their push
## they keep meanwhile.
const ZAP_TIME := 2.0
const ZAP_DRIVE := 0.3
## How much harder a ram plate hits. A knock from one counts this many times
## over, and a solid one (more than RAM_HIT) knocks a part straight off, since
## a ram usually lands on the chassis and that's too strong to break.
const RAM_KNOCK := 2.5
const RAM_HIT := 250.0
const RAM_EVERY := 0.5
const GADGET_COOLDOWN := 0.6

## A part's knocks add up over a few frames, because one crash lands over
## several physics steps. After that they fade away.
const IMPACT_FADE := 0.5
## Tire stacks give, so a knock against nothing but them counts this much.
const SOFT_KNOCK := 0.35
## Wheels collide through a cylinder a bit smaller than the tire. It only
## touches the ground when the suspension is squashed hard, like a bump stop,
## but it still catches walls from the side.
const WHEEL_BODY := 0.55
## On loops and wall rides the road is sticky. With two wheels on it and going
## at least this fast, gravity pulls you toward the road instead of down. Any
## slower and you drop off. Hanging upside down near the top of a loop takes
## more speed than riding a wall.
const STICK_SPEED := 5.0
const STICK_SPEED_OVERHEAD := 9.0
## A short grace period, so a bump that lifts a wheel doesn't drop you.
const STICK_HOLD := 0.4
## While it's sticking, the kart is held flat against the road, or on a wall
## ride it rolls past the road and slides off. These set how hard it's turned
## back and how much its roll and pitch are damped.
const STICK_ALIGN := 90.0
const STICK_ALIGN_DAMP := 13.0
const STICK_PITCH_DAMP := 4.0
## On a corkscrew the kart rides the road like a roller coaster on its rails
## (see _ride_rail()). This is how fast it moves in toward the middle of the
## road as it goes, in metres a second, so it doesn't ride round with a wall
## beside it.
const RAIL_CENTRE := 3.0
## A little extra pull onto sticky road to keep all four wheels planted over
## bumps. On a loop the kart's own speed presses it down far harder than this.
const STICK_PULL := 0.1
## Curbs have ridges this far apart. Each ridge a wheel rolls over kicks it up
## by this much for every m/s, more for small wheels than big ones (KERB_WHEEL
## is the size that gets the kick as it is). Slowly they rumble, and at racing
## speed the wheels skip into the air and lose their grip.
## Wheels this close to the middle of the kart from side to side are in a
## line, like a bike's.
const IN_LINE := 0.2
## How hard a trike, with one wheel in the middle, is held upright, against a
## bike.
const TRIKE_HOLD := 0.8
## How strongly a bike is turned back upright, and how much its rolling is
## damped, and how much of that it keeps in the air.
const HOLD_ALIGN := 140.0
const HOLD_DAMP := 24.0
const HOLD_IN_AIR := 1.0
## In the air a bike levels out front to back too, this much as hard as it
## holds its roll, so it lands on its wheels instead of going over the front.
const AIR_PITCH := 0.5
## Rolled over further than this, a bike has crashed, and isn't held up.
const HOLD_LETS_GO := deg_to_rad(65.0)
## How far a bike leans into a bend, at most, and how quickly.
const MOST_LEAN := deg_to_rad(42.0)
const LEAN_RATE := 2.5
const KERB_RIDGE := 0.6
const KERB_KICK := 0.024
const KERB_WHEEL := 0.3
## The sound each power-up makes when it's used (see sound/fx).
const GADGET_SOUNDS := {
	"turbo": "fx/turbo", "big_turbo": "fx/turbo", "triple_turbo": "fx/turbo",
	"tow": "fx/rope", "wall": "fx/wall", "shockwave": "fx/shockwave", "glue": "fx/glue",
	"dropper": "fx/drop", "oil": "fx/drop",
	"cannon": "fx/cannon", "homing": "fx/cannon", "repair": "fx/repair", "shield": "fx/shield",
	"ghost": "fx/ghost", "lightning": "fx/lightning",
}


class Wheel:
	var index := 0 # which part of the design this is
	var part: Dictionary
	var rest := Vector3.ZERO # the wheel's centre as built, in kart space
	var radius := 0.3
	var width := 0.25
	var grip := 1.0
	var rolling := 0.015
	## How much of the grip it loses on grass and dirt it keeps anyway.
	var offroad := 0.0
	var steered := false
	var driven := false
	var spring := 0.0
	var damper := 0.0
	var length := SUSPENSION_TRAVEL # from the top of its travel down to the wheel centre
	var grounded := false
	var load := 0.0
	var spin := 0.0
	## How far it's rolled along curbs, for counting the ridges.
	var kerb_travel := 0.0
	var visual: Node3D


var design: KartDesign
## Who's driving. Their weight goes into the kart, and their model sits in
## the seat holding the steering wheel.
var driver: CharacterDesign
var stats: KartStats
var controls := KartControls.new()
## While locked (before a race starts) the kart holds its brakes on and
## ignores the throttle.
var locked := false
## Where a reset puts the kart, given where it is now. A race points this at
## the nearest bit of track. If it's left empty the kart just flips itself
## upright where it is.
var reset_to: Callable
var wheels: Array[Wheel] = []
## Parts that have broken off, by their index in the design.
var lost := {}

# What the parts add up to, worked out in build().
var power := 0.0
var max_force := 0.0
## Push from jet engines, straight through the middle of the kart.
var thrust := 0.0
var drag_area := 0.0
var lift_area := 0.0

var steer_angle := 0.0
var forward_speed := 0.0
## From the front wheels to the back ones, in metres.
var wheelbase := 1.2
## How hard it's held upright: 1 for a bike, with its wheels in a line, less
## for a trike with one wheel in the middle, and nothing for anything else.
## Bikes and trikes would fall over on their own.
var upright := 0.0
## How far a bike's looks lean into a bend, in radians, right positive. The
## body itself stays upright, so this is only in how it looks, and it's
## worked out from the steering and speed, so remote bikes lean the same.
var lean := 0.0
var _looks: Node3D
## Parts that turn with a steered wheel, like a bike's front fork, as
## [node, its basis going straight].
var _turning := []
var _ground_y := 0.0
## How far the front wheels turn at full lock right now (see steer_limit()).
var full_lock := MAX_STEER
## Whether the kart is stuck to the road on a loop or a wall ride right now.
var sticking := false
## Which way is up off the road while it's sticking.
var stick_up := Vector3.UP
var _stick_left := 0.0
## How fast the sticky road under the kart is turning over, from how its up
## moved last step, so a kart rolling round a corkscrew is only damped
## against the road and not held back from rolling with it.
var _road_spin := Vector3.ZERO
var _last_stick_up := Vector3.ZERO
## How high above a corkscrew's middle line the kart rides, how far across
## it, and how fast it was going, from when it got on. INF when it isn't on
## one.
var _rail_height := INF
var _rail_across := 0.0
var _rail_speed := 0.0
## How far along the corkscrew's line it is, in points, and the start of the
## last line it rode to the end of.
var _rail_at := 0.0
var _rail_done := Vector3.INF

## The power-ups on the two gadget buttons, "" for none, and how many goes
## each has left.
var held: Array[String] = ["", ""]
var held_uses: Array[int] = [0, 0]
## Every power-up picked up this race.
var pickups := 0
var boost_left := 0.0
var ghost_left := 0.0
var zapped_left := 0.0
var shield_left := 0.0
## The tow rope it's on the end of, if any (see TowRope).
var tow: TowRope
## A shove from a shockwave, to be added to its speed next step.
var _shove := Vector3.ZERO
## Whether it's sliding right now (see SLIDE_SPEED), whether that's still the
## kick, which way round (1 right, -1 left), and how far into the slide it
## still is, from 1 while sliding down to 0 once it's gripping again.
var sliding := false
var slide_kick := false
var slide_way := 0.0
var slide_amount := 0.0
var _slide_straight := 0.0
var _slide_speed := 0.0
var _last_flat_velocity := Vector3.ZERO
var _repair_asked := false
var _gadget_held: Array[bool] = [false, false]
var _gadget_wait: Array[float] = [0.0, 0.0]
var _bubble: MeshInstance3D
var _steering: SteeringVisual
var _rig: CharacterRig
## A kart driven on another device, or the host's AI seen on a player's device.
## It isn't simulated here. It's moved to where its updates say (see NetRace),
## and only its looks, sound and wreckage happen here.
var remote := false:
	set(value):
		remote = value
		freeze_mode = FREEZE_MODE_KINEMATIC
		freeze = value
## How fast a remote kart is going, from its updates, for its wheels and sound.
var remote_velocity := Vector3.ZERO
## What the kart sounds like. It stays when the kart's rebuilt.
var sound: KartSound
## How much of the kart's weight is on grass or dirt right now, 0 to 1, for
## its rumble.
var rough := 0.0
## A kart the race says is close by, which the driver turns to look at.
var alongside: Kart
var _rammed_wait := 0.0
var slowdown_left := 0.0
## The render layer the driver's head is drawn on (see RaceCamera), or 0.
var head_layer := 0:
	set(value):
		head_layer = value
		if _rig != null:
			_rig.head_layer = value
## How hard the engine pushes compared with usual. The AI's difficulty uses it
## to catch up or ease off (see Difficulty).
var push := 1.0
## Set by the race when a reset is putting the kart back at the run up to a
## loop or a wall ride, so it doesn't get the reset slowdown.
var run_up_reset := false

var _reset_held := false
var _reset_asked := false
var _repair_pending := false
var _driven_count := 0
var _steered_count := 0
var _full: KartStats # the kart as built, before anything broke
var _wheel_setup := {} # part index -> [steered, driven, spring, damper]
var _impact := {} # part index -> recent knocks, in newton seconds
var _breaking: Array[int] = []
var _last_velocity := Vector3.ZERO
var _last_applied := Vector3.ZERO
var _break_wait := 0.0
## The grip the driven wheels had left for driving last step, for each
## newton of weight they carry standing still, taking the one with least.
var _drive_room := INF


func _init() -> void:
	collision_layer = LAYER_KARTS
	collision_mask = LAYER_WORLD | LAYER_KARTS | LAYER_HAZARD | LAYER_RUBBLE
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	continuous_cd = true
	can_sleep = false
	angular_damp = 0.5
	contact_monitor = true
	max_contacts_reported = 16
	# Slippery plastic, so when the body scrapes the road or a wall it slides
	# instead of grinding to a halt.
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.3


## Builds the whole kart. The wheels' jobs and springs are set up from the
## complete kart and stay the same when parts break off, so a kart that loses a
## wheel sags onto that corner.
func build(new_design: KartDesign, who: CharacterDesign = null) -> void:
	driver = who
	design = new_design
	lost.clear()
	_impact.clear()
	_breaking.clear()
	_full = KartStats.compute(design, {}, null, _driver_mass())
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
	upright = 0.0
	var in_line := _full.wheels.filter(func(info: KartStats.PartInfo) -> bool: return absf(info.centre.x - com.x) < IN_LINE).size()
	if _full.wheels.size() >= 2 and in_line == _full.wheels.size():
		upright = 1.0
	elif _full.wheels.size() == 3 and in_line == 1:
		upright = TRIKE_HOLD
	var front := _average_z(_full.wheels, steered)
	var back := _average_z(_full.wheels, driven)
	if not steered.is_empty() and not driven.is_empty() and back - front > 0.2:
		wheelbase = back - front
	_assemble()


static func _average_z(infos: Array, indices: Array) -> float:
	var total := 0.0
	for info in infos:
		if indices.has(info.index):
			total += info.centre.z
	return total / maxf(indices.size(), 1)


## How far the front wheels turn at full lock at this speed, in radians. At low
## speed it's MAX_STEER. Faster, the tires run out of grip at a smaller angle,
## so full lock stops just past that point and the whole stick means something
## at any speed.
##
## `slide` is how far the kart is going sideways from where it's pointing, when
## you're steering into it. Full lock gets that much extra for a real slide, so
## you can catch it, but nothing for the small slide of a hard corner.
func steer_limit(speed: float, slide := 0.0) -> float:
	var limit := MAX_STEER * lerpf(1.0, HIGH_SPEED_STEER, clampf(speed / 28.0, 0.0, 1.0))
	if speed > 1.0 and stats != null:
		var grip := stats.cornering() * KartStats.gravity() * SLIDE_MARGIN
		var catch_slide := maxf(absf(slide) - SMALL_SLIDE, 0.0)
		limit = minf(limit, atan(wheelbase * grip / (speed * speed)) + catch_slide)
	return limit


## How much of the kart's weight each wheel carries standing still, as
## fractions that add up to one. The loads have to hold the kart up and
## balance around its centre of mass both ways, and of all the ways to do
## that this is the most even one. No wheel is ever left carrying nothing.
static func _weight_shares(full: KartStats) -> Array[float]:
	var n := full.wheels.size()
	var out: Array[float] = []
	if n == 0:
		return out
	var com := full.center_of_mass
	# The rows of the balance are the total, then the moments along z and x.
	var rows := [[], [], []]
	for info in full.wheels:
		rows[0].append(1.0)
		rows[1].append(info.centre.z - com.z)
		rows[2].append(info.centre.x - com.x)
	var target := Vector3(1.0, 0.0, 0.0)
	# The minimum norm answer is loads = Aᵀ (A Aᵀ)⁻¹ b.
	var m := Basis()
	for r in 3:
		for c in 3:
			var dot := 0.0
			for k in n:
				dot += rows[r][k] * rows[c][k]
			m[c][r] = dot
	var y := Vector3.ZERO
	if absf(m.determinant()) >= 1e-6:
		y = m.inverse() * target
	else:
		# With the wheels all in a line, like a bike's, only the total and
		# the balance front to back can be met.
		var det := m[0][0] * m[1][1] - m[1][0] * m[0][1]
		if absf(det) < 1e-6:
			for k in n:
				out.append(1.0 / n)
			return out
		y = Vector3(m[1][1], -m[0][1], 0.0) / det
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
	if sound == null:
		sound = KartSound.new(self)
		add_child(sound)
	for child in get_children():
		if child == _bubble or child == sound:
			continue
		remove_child(child)
		child.queue_free()
	wheels.clear()
	_steering = null
	_rig = null
	_turning.clear()
	# Everything you see goes in here, so a bike can lean it.
	_looks = Node3D.new()
	add_child(_looks)

	stats = KartStats.compute(design, lost, _full.origin_cell, _driver_mass())
	power = stats.power
	max_force = stats.max_force
	thrust = stats.thrust
	drag_area = stats.drag_area
	lift_area = stats.lift_area

	# Everything but the wheels and steering is drawn as one mesh.
	var looks: Array[Node3D] = []
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
			w.offroad = info.def.get("offroad", 0.0)
			var setup: Array = _wheel_setup[info.index]
			w.steered = setup[0]
			w.driven = setup[1]
			w.spring = setup[2]
			w.damper = setup[3]
			w.visual = PartVisuals.make_wheel(info.def)
			w.visual.position = info.centre
			_looks.add_child(w.visual)
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
		_add_bodies(info)
		var look := PartVisuals.make_turned(info.def, info.extent, info.basis)
		look.position = info.centre
		if info.def.get("steers", false) and _beside_steered_wheel(info):
			_looks.add_child(look)
			_turning.append([look, look.basis])
		elif look is SteeringVisual:
			_looks.add_child(look)
			if _steering == null:
				_steering = look
		else:
			looks.append(look)
	if not looks.is_empty():
		_looks.add_child(KartMesh.bake(looks))
		for look in looks:
			look.free()

	if stats.has_seat:
		_rig = CharacterRig.new(driver if driver != null else default_driver(), true)
		_rig.recline = stats.recline
		_rig.astride = stats.astride
		_rig.head_layer = head_layer
		_rig.lively = true
		_rig.position = stats.seat_top
		_looks.add_child(_rig)
		# The driver takes hits too, so a rollover lands on something.
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 0.7, 0.3)
		shape.shape = box
		shape.position = stats.seat_top + Vector3(0.0, 0.4, 0.0)
		add_child(shape)

	_ground_y = 0.0
	for w in wheels:
		_ground_y = minf(_ground_y, w.rest.y - w.radius)
	sound.refit(stats)
	mass = maxf(stats.mass, 1.0)
	center_of_mass = stats.center_of_mass
	_driven_count = 0
	_steered_count = 0
	for w in wheels:
		if w.driven:
			_driven_count += 1
		if w.steered:
			_steered_count += 1


## The part's collision shapes: its box, or for a modelled part with gaps in
## it, like a motorbike's fork, a box for each of its solid bits.
func _add_bodies(info: KartStats.PartInfo) -> void:
	var boxes: Array[AABB] = []
	if info.def.has("solids"):
		var middle := PartCatalog.fine_size(info.def.id) * 0.5
		for solid in info.def.solids:
			var b: AABB = Transform3D(info.basis, Vector3.ZERO) * AABB((solid as AABB).position - middle, (solid as AABB).size)
			boxes.append(AABB(info.centre + b.position * Grid.FINE, b.size * Grid.FINE))
	else:
		boxes.append(AABB(info.centre - info.extent * 0.5, info.extent))
	for b in boxes:
		if b.size.x < 0.01 or b.size.y < 0.01 or b.size.z < 0.01:
			continue
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b.size
		shape.shape = box
		shape.position = b.get_center()
		add_child(shape)


## Whether the wheel nearest this part is one that steers, so a fork turns
## with the wheel in it.
func _beside_steered_wheel(part: KartStats.PartInfo) -> bool:
	var nearest: KartStats.PartInfo = null
	for info in stats.wheels:
		if nearest == null or info.centre.distance_to(part.centre) < nearest.centre.distance_to(part.centre):
			nearest = info
	return nearest != null and _wheel_setup.has(nearest.index) and _wheel_setup[nearest.index][0]


## Where the driver's eyes are, in world space, for a first person camera.
func eye_point() -> Vector3:
	if _rig != null and _rig.is_inside_tree():
		return _rig.eye_point()
	return to_global(stats.seat_top + Vector3.UP * 0.6 if stats != null else Vector3.UP)


## Just in front of the nose of the kart and low down, in the kart's space,
## for a bumper camera.
func bumper_point() -> Vector3:
	var front := 0.0
	if stats != null:
		for info in stats.parts:
			front = minf(front, info.centre.z - info.extent.z * 0.5)
	return Vector3(0.0, 0.3, front - 0.05)


## How wide the kart is, in metres, wheels and all.
func width() -> float:
	var most := 0.0
	if stats != null:
		for info in stats.parts:
			most = maxf(most, absf(info.centre.x) + info.extent.x * 0.5)
	return most * 2.0 if most > 0.0 else 2.0


## How far the back of the kart is behind its middle, in metres, for the chase
## cameras.
func tail_length() -> float:
	var back := 0.0
	if stats != null:
		for info in stats.parts:
			back = maxf(back, info.centre.z + info.extent.z * 0.5)
	return back


## Resets the kart on the next physics step, just as if the driver had
## pressed reset. The race uses this when a kart falls off the track.
func request_reset() -> void:
	_reset_asked = true


## Knocks these parts off, along with anything only held on through them. It's
## its own step so that in a network game the host can decide what broke and
## tell everyone.
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
		var piece := Debris.make(info.def, info.extent, Transform3D(global_basis, at), info.basis)
		piece.linear_velocity = linear_velocity + angular_velocity.cross(at - com)
		piece.angular_velocity = angular_velocity
		get_parent().add_child(piece)

	var keep_linear := linear_velocity
	var keep_angular := angular_velocity
	_assemble()
	linear_velocity = keep_linear
	angular_velocity = keep_angular
	react("surprised", 1.2)
	Sounds.play_at("fx/bricks", sound)
	parts_lost.emit(newly)


func _physics_process(delta: float) -> void:
	_ghost_tick(delta)
	if remote:
		# Only the shield's bubble shows, from the kart's updates.
		shield_left = maxf(shield_left - delta, 0.0)
		if _bubble != null:
			_bubble.visible = shield_left > 0.0
		return
	zapped_left = maxf(zapped_left - delta, 0.0)
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
		# A repair kit puts everything back on with no slowdown.
		_repair_asked = false
		repair_now()
	elif _repair_pending:
		_repair_pending = false
		repair_now()
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
	if _shove != Vector3.ZERO:
		state.linear_velocity += _shove
		_shove = Vector3.ZERO
	if tow != null and is_instance_valid(tow):
		var pull := tow.pull_on(self)
		state.apply_central_force(pull)
		applied += pull

	var basis := state.transform.basis
	var up := basis.y
	var origin := state.transform.origin
	var com := origin + state.center_of_mass
	var speed := state.linear_velocity.length()
	forward_speed = state.linear_velocity.dot(-basis.z)

	# If the steering wheel has been knocked off there's no steering. The
	# front wheels just follow along until a reset puts it back.
	var slide := 0.0
	var flat_velocity := state.linear_velocity - up * state.linear_velocity.dot(up)
	if flat_velocity.length() > 2.0:
		# Which way it's going, from where it's pointing. Positive is off to
		# the left.
		var toward := (-basis.z).signed_angle_to(flat_velocity, up)
		# Going backwards isn't a slide, and the extra lock only comes when you
		# steer into the slide. Steering the other way, more lock would only
		# make the tail step out further.
		if absf(toward) < PI * 0.5 and controls.steer * toward < 0.0:
			slide = absf(toward)
	_update_slide(dt)
	full_lock = steer_limit(speed, slide)
	# The front wheels turn all the way while the tail's out.
	if slide_amount > 0.0:
		full_lock = lerpf(full_lock, MAX_STEER, slide_amount)
	var wanted_steer := controls.steer * full_lock if stats.steering != null else 0.0
	# Holding a slide, the driver counter-steers, so the front wheels point
	# the way the kart's going and a little into the bend, the way a real
	# drift's held. Pointed into the bend with the nose, they'd only scrub.
	if sliding and not slide_kick and flat_velocity.length() > 2.0:
		var off := (-basis.z).signed_angle_to(flat_velocity, up)
		var into := clampf(controls.steer * slide_way, 0.0, 1.0)
		wanted_steer = clampf(-off + slide_way * SLIDE_FRONT * into, -MAX_STEER, MAX_STEER)
	# A driver who sits awkwardly or has to reach steers more slowly.
	steer_angle = move_toward(steer_angle, wanted_steer, STEER_RATE * stats.control * MAX_STEER * dt)

	# Engine and brakes. Holding the brake once the kart has stopped reverses.
	var drive := 0.0
	var braking := false
	if locked:
		braking = forward_speed > 0.05
	elif controls.throttle > 0.0:
		drive = controls.throttle * minf(max_force, power / maxf(absf(forward_speed), 1.0)) * push
	if slide_kick:
		# The kick locks the back wheels, so nothing drives.
		drive = 0.0
	elif sliding:
		pass
	elif controls.brake > 0.0 and not locked:
		if forward_speed > 0.5:
			braking = true
		elif forward_speed > -REVERSE_TOP_SPEED:
			drive -= controls.brake * maxf(max_force, REVERSE_PUSH) * REVERSE_FRACTION
	if slowdown_left > 0.0:
		drive *= RESET_SLOWDOWN
	if zapped_left > 0.0:
		drive *= ZAP_DRIVE
	var drive_per_wheel := drive / maxf(_driven_count, 1)

	var space := state.get_space_state()
	var sticky_up := Vector3.ZERO
	var sticky_wheels := 0
	# The corkscrew's line, if a wheel is on one.
	var rail := []
	var on_rough := 0
	var on_any := 0
	var room := INF
	var turned := clampf(absf(steer_angle) / maxf(full_lock, 0.001), 0.0, 1.0)
	var share := mass / maxf(wheels.size(), 1)
	var ground_up := Vector3.ZERO
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
		ground_up += normal
		var ground_body: Object = hit.get("collider")
		if ground_body != null and ground_body.get_meta("sticky", false):
			sticky_up += normal
			sticky_wheels += 1
			if ground_body.has_meta("rail"):
				rail = ground_body.get_meta("rail")
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

		# Tire forces. Sideways the tire tries to stop all slip in one step,
		# and along its heading it drives, brakes and rolls. All of that is
		# capped by the grip this tire has under this load.
		var stop_force := share / dt
		var f_lat := -v_lat * stop_force * 0.5
		var f_long := drive_per_wheel if w.driven else 0.0
		# Grass and dirt grip less and drag more than the road. The ground
		# says how much through its "grip" and "drag" metadata.
		var ground: Object = hit.get("collider")
		var grip_here: float = ground.get_meta("grip", 1.0) if ground != null else 1.0
		var drag_here: float = ground.get_meta("drag", 1.0) if ground != null else 1.0
		# A ghost drives over oil as if it isn't there.
		if ghost_left > 0.0 and ground != null and ground.get_meta("oil", false):
			grip_here = 1.0
			drag_here = 1.0
		on_any += 1
		if grip_here < 1.0:
			on_rough += 1
		grip_here = ground_grip(grip_here, w.offroad)
		drag_here = ground_drag(drag_here, w.offroad)
		if ground != null and ground.get_meta("kerb", false):
			var ridge := floori(w.kerb_travel / KERB_RIDGE)
			w.kerb_travel += absf(v_long) * dt
			if floori(w.kerb_travel / KERB_RIDGE) != ridge:
				var kick := KERB_KICK * absf(v_long) * KERB_WHEEL / maxf(w.radius, 0.1)
				state.apply_impulse(normal * share * kick, contact - origin)
		var resist := w.rolling * load * drag_here
		if braking:
			resist += BRAKE_FORCE * (1.0 if locked else controls.brake) / wheels.size()
		elif slide_kick and not w.steered:
			resist += BRAKE_FORCE * slide_brake / maxf(wheels.size() - _steered_count, 1)
		f_long -= signf(v_long) * minf(resist, absf(v_long) * stop_force)
		var most := KartStats.TIRE_FRICTION * w.grip * grip_here * load
		if slide_amount > 0.0 and not w.steered:
			most *= lerpf(1.0, SLIDE_REAR_GRIP if slide_kick else slide_hold_grip, slide_amount)
		# Traction control. Holding the kart in line comes first and the engine
		# only gets the grip that's left over, so full throttle can't use up
		# the grip the back tires need to hold the tail. With the wheels
		# turned the outside one can push harder, which helps the kart around,
		# but with them straight each pushes as much as the weight it carries
		# standing still, or the kart would keep turning after the stick's let
		# go.
		if drive > 0.0 and w.driven:
			f_lat = clampf(f_lat, -most, most)
			var left_over := sqrt(maxf(most * most - f_lat * f_lat, 0.0))
			var standing := w.spring * SUSPENSION_TRAVEL
			room = minf(room, left_over / maxf(standing, 1.0))
			f_long = minf(f_long, lerpf(minf(left_over, _drive_room * standing), left_over, maxf(turned, slide_amount)))
		var tire := Vector2(f_long, f_lat).limit_length(most)

		# A bike's springs push along the bike, through its middle, so they
		# can't tip it over. Balanced on two wheels it would fall over like
		# a pencil on its point, all the faster in the pull of a loop.
		var push := up if upright >= 1.0 else normal
		state.apply_force(push * load, contact - origin)
		# Cornering forces act a little below the centre of mass, so it leans
		# but doesn't flip. Driving and braking act right at its height, so it
		# doesn't squat onto its tail pulling away or dive when it brakes.
		var height := (com - contact).dot(up)
		# A bike's are right at its height, since it doesn't lean on its
		# tires and is held upright instead, and a trike's nearly.
		state.apply_force(side * tire.y, contact + up * height * lerpf(ROLL_HELP, 1.0, upright) - origin)
		state.apply_force(heading * tire.x, contact + up * height - origin)
		applied += push * load + side * tire.y + heading * tire.x

	rough = float(on_rough) / on_any if on_any > 0 else 0.0
	_drive_room = room

	# Sticky road. Gravity already pulls everything down, so this cancels that
	# and pulls toward the road instead.
	var needed := STICK_SPEED if up.y > -0.1 else STICK_SPEED_OVERHEAD
	# A bike only has two wheels, so one on the road is enough.
	if sticky_wheels >= (1 if upright >= 1.0 else 2) and speed > needed:
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
		# Turn the kart to lie flat on the road, damping its roll firmly and
		# its pitch lightly, since on a loop it has to keep pitching over. On a
		# wall ride it needs a little pitch damping, or it bounces off as the
		# road rises.
		if _last_stick_up != Vector3.ZERO:
			_road_spin = _road_spin.lerp(_last_stick_up.cross(stick_up) / dt, 0.3)
		_last_stick_up = stick_up
		var tilt := up.cross(stick_up)
		var forward := -basis.z
		var spin := state.angular_velocity - _road_spin
		var roll := forward * spin.dot(forward)
		var pitch := basis.x * spin.dot(basis.x)
		var want := tilt * STICK_ALIGN - roll * STICK_ALIGN_DAMP - pitch * STICK_PITCH_DAMP
		state.apply_torque(state.inverse_inertia_tensor.inverse() * want)
		if not rail.is_empty():
			_ride_rail(state, rail)
		else:
			_rail_height = INF
			_rail_done = Vector3.INF
	else:
		_road_spin = Vector3.ZERO
		_last_stick_up = Vector3.ZERO
		_rail_height = INF
		_rail_done = Vector3.INF

	# On sticky road too, square to the road, since a bike would fall over on
	# the way into a loop.
	if upright > 0.0:
		_hold_upright(state, ground_up)

	# Air drag from everything facing forward, and downforce from any wings.
	var air := 0.5 * KartStats.AIR_DENSITY
	var drag := -state.linear_velocity * speed * air * drag_area
	var downforce := -up * air * lift_area * forward_speed * forward_speed
	state.apply_central_force(drag)
	state.apply_central_force(downforce)
	applied += drag + downforce

	# The turbo pushes straight through the middle of the kart like a rocket,
	# so it doesn't use up the back tires' grip.
	var on_ground := wheels.any(func(w: Wheel) -> bool: return w.grounded)
	# A jet pushes the same way, whatever the tires are on.
	if thrust > 0.0 and controls.throttle > 0.0 and not locked and on_ground:
		var jet := -basis.z * thrust * controls.throttle * push * (RESET_SLOWDOWN if slowdown_left > 0.0 else 1.0)
		state.apply_central_force(jet)
		applied += jet
	# It cuts out while you brake, so it can't carry you off at a corner.
	if boost_left > 0.0 and slowdown_left <= 0.0 and on_ground and controls.brake <= 0.0 and forward_speed < stats.top_speed() * TURBO_TOP_SPEED:
		var push := -basis.z * TURBO_FORCE
		state.apply_central_force(push)
		applied += push

	if sliding and not slide_kick:
		_hold_slide(state, up)
	elif slide_amount <= 0.0:
		_steady(state, up)
	_last_flat_velocity = state.linear_velocity - up * state.linear_velocity.dot(up)
	_break_scenery(state)
	_feel_knocks(state)
	_last_velocity = state.linear_velocity
	_last_applied = applied


## Starts, holds and ends a slide (see SLIDE_SPEED) from the controls.
func _update_slide(dt: float) -> void:
	var can := not locked and stats.steering != null and forward_speed > (SLIDE_KEEP_SPEED if sliding else SLIDE_SPEED) and not sticking
	var into := controls.steer * slide_way
	if not sliding:
		if can and controls.throttle > 0.5 and controls.brake > 0.5 and absf(controls.steer) > 0.2:
			sliding = true
			slide_way = signf(controls.steer)
			_slide_straight = 0.0
			_slide_speed = forward_speed
	elif not can or controls.throttle < 0.5:
		sliding = false
	else:
		_slide_straight = _slide_straight + dt if into < 0.15 else 0.0
		if _slide_straight > SLIDE_LET_GO:
			sliding = false
	slide_kick = sliding and controls.brake > 0.5
	# The kick loses speed, which the held slide starts from.
	if slide_kick:
		_slide_speed = forward_speed
	slide_amount = 1.0 if sliding else move_toward(slide_amount, 0.0, dt / SLIDE_RECOVER)


## A held slide: the tail's kept out at its angle, and the kart keeps its
## speed, losing only slide_scrub a second, and goes round the line the
## steering asks for, up to slide_corner times as hard as its tires could.
func _hold_slide(state: PhysicsDirectBodyState3D, up: Vector3) -> void:
	var flat := state.linear_velocity - up * state.linear_velocity.dot(up)
	var speed := flat.length()
	if speed < 1.0:
		return
	var dt := state.step
	var heading := -state.transform.basis.z
	# Positive is the velocity off to the left of where it's pointing, which
	# going round to the right is the tail out.
	var off := heading.signed_angle_to(flat, up)
	var into := clampf(controls.steer * slide_way, 0.0, 1.0)
	var want := lerpf(SLIDE_ANGLE[0], SLIDE_ANGLE[1], into)
	# How fast the way it's going is turning, and how fast it should, going
	# right negative.
	var turning := 0.0
	if _last_flat_velocity.length() > 1.0:
		turning = _last_flat_velocity.signed_angle_to(flat, up) / dt
	var should := -slide_way * into * stats.cornering() * KartStats.gravity() * slide_corner / speed
	var fix := clampf((should - turning) * dt * 0.8, -0.05, 0.05)
	var vertical := state.linear_velocity - flat
	# It keeps its speed, losing only the scrub, whatever the tires did.
	_slide_speed = minf(_slide_speed - slide_scrub * dt, speed + SLIDE_CARRY * dt)
	var keep := maxf(speed, _slide_speed)
	state.linear_velocity = (flat / speed).rotated(up, fix) * keep + vertical
	# The nose turns with it, and a bit more or less to hold the angle.
	var spin := turning + (off - slide_way * want) * SLIDE_HOLD
	var now := state.angular_velocity.dot(up)
	state.angular_velocity += up * (spin - now) * minf(1.0, 12.0 * dt)


## Keeps a bike or trike from falling over, by turning it back upright about
## the way it's pointing. On the ground that's square to the ground, and in
## the air it levels out both ways, so it lands on its wheels. One that's gone right over has crashed,
## and is left to fall.
func _hold_upright(state: PhysicsDirectBodyState3D, ground_up: Vector3) -> void:
	var basis := state.transform.basis
	var strength := upright
	var toward := ground_up.normalized()
	var flying := ground_up == Vector3.ZERO
	if flying:
		toward = Vector3.UP
		strength *= HOLD_IN_AIR
	if basis.y.angle_to(toward) > HOLD_LETS_GO:
		return
	var forward := -basis.z
	var tilt := basis.y.cross(toward).dot(forward)
	var roll := state.angular_velocity.dot(forward)
	var want := forward * (tilt * HOLD_ALIGN - roll * HOLD_DAMP) * strength
	if flying:
		var side := basis.x
		var pitch := basis.y.cross(toward).dot(side)
		want += side * (pitch * HOLD_ALIGN - state.angular_velocity.dot(side) * HOLD_DAMP) * AIR_PITCH * upright
	state.apply_torque(state.inverse_inertia_tensor.inverse() * want)


## The parts that turn with the steering, like a bike's fork. Tests use it.
func turning_parts() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for turning in _turning:
		out.append(turning[0])
	return out


## The looks, which lean with a bike. Tests use it.
func looks() -> Node3D:
	return _looks


## On a corkscrew, once it's going fast enough to stay on, the kart rides the
## road like a roller coaster car on its rails. It's carried along the road
## at least as fast as it got on, at its height above the road, moving in to
## the middle, and turns over with it. A kart can't roll over as fast as a
## corkscrew turns by itself, and it would bounce off. At the end it's let go,
## and it doesn't get back on that corkscrew until it's left it.
func _ride_rail(state: PhysicsDirectBodyState3D, rail: Array) -> void:
	var line: PackedVector3Array = rail[0]
	if line.size() < 3 or (_rail_done == line[0] and _rail_height == INF):
		return
	var at := state.transform.origin
	if _rail_height == INF:
		var near := 1
		for k in range(1, line.size() - 1):
			if line[k].distance_squared_to(at) < line[near].distance_squared_to(at):
				near = k
		var road := _rail_frame(rail, near, 0.0)
		var along := state.linear_velocity.dot(-road.z)
		# It only gets on going forward, fast enough to stay on.
		if along < STICK_SPEED_OVERHEAD:
			return
		_rail_height = (at - line[near]).dot(road.y)
		_rail_across = (at - line[near]).dot(road.x)
		_rail_speed = along
		_rail_at = float(near)
	var along := maxf(state.linear_velocity.dot(-state.transform.basis.z), _rail_speed)
	_rail_across = move_toward(_rail_across, 0.0, RAIL_CENTRE * state.step)
	# Move on along the line by how far it goes this step.
	var k := int(_rail_at)
	var step_length := maxf(line[k].distance_to(line[mini(k + 1, line.size() - 1)]), 0.01)
	_rail_at += along * state.step / step_length
	if _rail_at >= line.size() - 1.5:
		# Off the end, carrying on the way the road goes.
		_rail_done = line[0]
		_rail_height = INF
		state.linear_velocity = -_rail_frame(rail, line.size() - 2, 0.0).z * along
		return
	k = int(_rail_at)
	var f := _rail_at - k
	var road := _rail_frame(rail, k, f)
	var spot := line[k].lerp(line[k + 1], f) + road.x * _rail_across + road.y * _rail_height
	state.transform = Transform3D(road, spot)
	state.linear_velocity = -road.z * along
	var turning := Quaternion(_rail_frame(rail, k + 1, 0.0) * _rail_frame(rail, k, 0.0).inverse())
	state.angular_velocity = turning.get_axis() * turning.get_angle() / step_length * along if turning.get_angle() > 0.0001 else Vector3.ZERO


## Which way the road faces `f` of the way from point k to the next on a
## corkscrew's line, as right, up and back.
func _rail_frame(rail: Array, k: int, f: float) -> Basis:
	var count: int = rail[0].size()
	var frames: Array[Basis] = []
	for i in [k, mini(k + 1, count - 1)]:
		var ahead: Vector3 = rail[1][i]
		var across: Vector3 = rail[2][i]
		frames.append(Basis(across, across.cross(ahead), -ahead).orthonormalized())
	return frames[0].slerp(frames[1], f)


## Stability control. When the kart turns much faster than its front wheels
## point it, because the tail is stepping out, this turns it back the way
## braking one wheel would. It leaves it alone in the air, on sticky road and
## at low speed.
func _steady(state: PhysicsDirectBodyState3D, up: Vector3) -> void:
	if sticking or forward_speed < STEADY_SPEED:
		return
	if wheels.any(func(w: Wheel) -> bool: return not w.grounded):
		return
	var turning := state.angular_velocity.dot(up)
	# How fast the front wheels would turn it if nothing slid. Steering right
	# turns it clockwise seen from above, which is negative about up.
	var meant := -forward_speed * tan(steer_angle) / maxf(wheelbase, 0.5)
	var extra := turning - meant
	# Only the part past a little leeway, and only when it's turning the same
	# way as that extra, so it's the tail coming around and not the kart
	# straightening up.
	var leeway := absf(meant) * STEADY_LEEWAY + STEADY_SLACK
	if absf(extra) <= leeway or signf(extra) != signf(turning):
		return
	extra -= signf(extra) * leeway
	var inertia := (state.inverse_inertia_tensor.inverse() * up).dot(up)
	state.apply_torque(-up * extra * inertia * STEADY_RATE)


## How much a tire grips on this ground, as a multiple of its grip on the
## road. Off-road tires keep some of what they'd lose on grass and dirt, and
## slicks lose even more (see "offroad" in parts.json).
static func ground_grip(ground: float, offroad: float) -> float:
	return 1.0 - (1.0 - ground) * (1.0 - offroad) if ground < 1.0 else ground


## The same for how much the ground drags on a tire.
static func ground_drag(ground: float, offroad: float) -> float:
	return 1.0 + (ground - 1.0) * (1.0 - offroad) if ground > 1.0 else ground


## Works out how hard the kart was just knocked and which parts took it. A part
## hit harder than it can take comes off in the next _physics_process, since
## shapes can't change in the middle of a step.
##
## The knock is the kart's change of speed since the last step, minus what its
## engine, tires, air and gravity did. The physics engine's contact impulses
## come out well under the real knock, so they only share it out between the
## parts that were touching something.
## Breaks scenery the kart's gone into hard enough (see WorldDamage). Only
## the kart's own device decides, and tells the others. Going through
## something small only slows it down a bit.
func _break_scenery(state: PhysicsDirectBodyState3D) -> void:
	_break_wait = maxf(_break_wait - state.step, 0.0)
	if remote or _break_wait > 0.0 or ghost_left > 0.0:
		return
	for i in state.get_contact_count():
		var hit: Object = state.get_contact_collider_object(i)
		if hit == null or not hit.has_meta("breakable"):
			continue
		var group := WorldDamage.group_of(hit, state.get_contact_collider_shape(i))
		if group < 0:
			continue
		var at := state.get_contact_collider_position(i)
		var toward := at - state.transform.origin
		toward.y = 0.0
		if toward.length() < 0.01 or _last_velocity.dot(toward.normalized()) < BREAK_SPEED:
			continue
		_break_wait = BREAK_EVERY
		var damage: WorldDamage = hit.get_meta("breakable")
		damage.break_at.call_deferred(group, at, _last_velocity)
		broke_scenery.emit.call_deferred(group, at, _last_velocity)
		if damage.is_small(group):
			state.linear_velocity = _last_velocity * PLOUGH
		return


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
	var all_soft := true
	var to_kart := state.transform.affine_inverse()
	for i in count:
		var hit: Object = state.get_contact_collider_object(i)
		if hit == null or not hit.get_meta("soft", false):
			all_soft = false
		var part := part_at(to_kart * state.get_contact_local_position(i))
		if part == -1:
			continue
		# Contacts that report nothing still count for a little, so a part
		# can't dodge a crash just because the engine missed it.
		var weight := state.get_contact_impulse(i).length() + 0.01
		# A hit from another kart's ram plate counts for a lot more.
		var other: Object = state.get_contact_collider_object(i)
		if other is Kart and other.rammed_with(state.get_contact_collider_position(i)):
			weight *= RAM_KNOCK
			rammed = true
		shares[part] = shares.get(part, 0.0) + weight
		total += weight
	if all_soft:
		knock *= SOFT_KNOCK
	if sound != null:
		sound.knocked(knock)
	if rammed:
		knock *= RAM_KNOCK
		if knock > RAM_HIT * RAM_KNOCK and _rammed_wait <= 0.0 and shield_left <= 0.0:
			_rammed_wait = RAM_EVERY
			Sounds.play_at.call_deferred("fx/ram", sound)
			knock_off_a_part.call_deferred()
	# A shield holds everything on, however hard the knock, and a ghost
	# isn't really there.
	if shield_left > 0.0 or ghost_left > 0.0:
		return
	for part in shares:
		_impact[part] = _impact.get(part, 0.0) + knock * shares[part] / total
		var strength: float = PartCatalog.get_part(design.parts[part].id).get("strength", 0.0)
		if strength > 0.0 and _impact[part] > strength and not _breaking.has(part):
			_breaking.append(part)


# The driver.

func _driver_mass() -> float:
	return driver.mass() if driver != null else KartStats.DRIVER_MASS


static var _default_driver: CharacterDesign

## Who drives when nobody's been picked. It's the same plain racer every time.
static func default_driver() -> CharacterDesign:
	if _default_driver == null:
		_default_driver = CharacterDesign.load_file("res://data/characters/roster/racer.json")
	return _default_driver


## Turns the steering wheel to match the front wheels and puts the driver's
## hands on it. It only uses steer_angle and speed, which are part of the
## kart's state, so everyone watching sees the same. The wheel shows how much
## of the steering there is at this speed, so at full lock it's turned all the
## way even when the front wheels have only turned a few degrees.
func _pose_driver() -> void:
	if _rig == null:
		return
	var amount := clampf(steer_angle / full_lock, -1.0, 1.0)
	_rig.look(amount)
	# A motorbike's bars turn as far as the front wheel looks turned, along
	# with the fork.
	var turn := shown_steer() / SteeringVisual.BIKE_TURN if _steering != null and _steering.style == "bikebars" else amount
	if alongside != null and is_instance_valid(alongside):
		_rig.glance(_rig.global_transform.affine_inverse() * alongside.global_position)
	else:
		_rig.glance(Vector3.ZERO)
	if _rig.busy_hands():
		if _steering != null:
			_steering.steer(turn)
		return
	if _steering == null:
		_rig.rest_hands()
		return
	_steering.steer(turn)
	var grips := _steering.grips(turn)
	# From the steering wheel's space into the driver's.
	var to_rig := _rig.transform.affine_inverse() * _steering.transform
	_rig.grip(to_rig * grips[0], to_rig * grips[1], to_rig.basis * grips[2], to_rig.basis * grips[3])


## The driver pulls a face for a while (one of FacePrint.MOODS). It's only
## for show.
func react(mood: String, seconds := 1.5) -> void:
	if _rig != null:
		_rig.feel(mood, seconds)


## The driver throws their arms up and bounces in the seat.
func cheer() -> void:
	if _rig != null:
		_rig.cheer()


# Gadgets and power-ups.

## Whether the kart has a part with this always-on gadget, like "ram".
func has_gadget(kind: String) -> bool:
	if stats == null:
		return false
	return stats.parts.any(func(info): return info.def.kind == "gadget" and info.def.get("gadget", "") == kind)


## Puts a power-up on the first free gadget button. Returns false when both
## are full.
func give(kind: String) -> bool:
	for slot in Powerups.HOLD:
		if held[slot] == "":
			held[slot] = kind
			held_uses[slot] = int(Powerups.ALL.get(kind, {}).get("uses", 1))
			pickups += 1
			Sounds.play_at("fx/powerup", sound, -2.0)
			return true
	return false


## Whether both gadget buttons are full.
func full() -> bool:
	return not held.has("")


func can_use(slot: int) -> bool:
	return slot < held.size() and held[slot] != "" and _gadget_wait[slot] <= 0.0 and not locked


## Uses the power-up on this button. It's its own step so that in a network
## game each kart's own device decides, and tells everyone.
func use_gadget(slot: int) -> bool:
	if not can_use(slot):
		return false
	var kind := held[slot]
	held_uses[slot] -= 1
	if held_uses[slot] <= 0:
		held[slot] = ""
	_gadget_wait[slot] = GADGET_COOLDOWN
	match kind:
		"turbo":
			boost_left = TURBO_TIME
		"big_turbo":
			boost_left = BIG_TURBO_TIME
		"triple_turbo":
			boost_left = TRIPLE_TURBO_TIME
		"tow":
			var rope := TowRope.throw(self, BrickShot._kart_ahead(self))
			if rope != null:
				get_parent().add_child(rope)
				towed.emit(rope.to)
			else:
				# With nobody in reach it's a turbo.
				boost_left = TURBO_TIME
		"wall":
			get_parent().add_child(BrickWall.drop_behind(self))
		"glue":
			get_parent().add_child(OilSlick.drop_behind(self, "glue"))
		"oil":
			get_parent().add_child(OilSlick.drop_behind(self))
		"dropper":
			for brick in BrickPile.drop_behind(self):
				get_parent().add_child(brick)
		"cannon":
			get_parent().add_child(BrickShot.fire(self))
		"homing":
			get_parent().add_child(BrickShot.fire(self, true))
		"repair":
			_repair_asked = true
		"shield":
			shield_left = SHIELD_TIME
			_show_bubble()
		"ghost":
			start_ghost()
	var noise: String = GADGET_SOUNDS.get(kind, "")
	if noise != "":
		Sounds.play_at(noise, sound)
	# Lightning and shockwaves are the race's to hand out (see Race), to every
	# kart they reach.
	gadget_used.emit(kind)
	return true


## Goes through karts, bricks and oil for a while, see-through.
func start_ghost() -> void:
	ghost_left = GHOST_TIME
	_set_ghostly(true)


## Shoved by a shockwave from `from`, harder the closer it is, and knocked
## about if it's very close.
func shoved_from(from: Vector3) -> void:
	if ghost_left > 0.0:
		return
	var away := global_position - from
	away.y = 0.0
	var far := away.length()
	if far > SHOCK_REACH:
		return
	var push := SHOCK_SHOVE * (1.0 - far / SHOCK_REACH * 0.6)
	_shove += (away.normalized() if far > 0.1 else -global_basis.x) * push + Vector3.UP * 1.0
	if far < SHOCK_KNOCK_REACH and shield_left <= 0.0:
		knock_off_a_part.call_deferred()


## Slows the kart right down for a moment, from lightning.
func zap() -> void:
	if shield_left > 0.0:
		return
	zapped_left = ZAP_TIME
	Sounds.play_at("fx/lightning", sound, -4.0)


func _ghost_tick(delta: float) -> void:
	if ghost_left <= 0.0:
		return
	ghost_left = maxf(ghost_left - delta, 0.0)
	if ghost_left <= 0.0:
		_set_ghostly(false)


func _set_ghostly(on: bool) -> void:
	collision_layer = 0 if on else LAYER_KARTS
	collision_mask = LAYER_WORLD if on else LAYER_WORLD | LAYER_KARTS | LAYER_HAZARD | LAYER_RUBBLE
	for mesh in find_children("*", "GeometryInstance3D", true, false):
		mesh.transparency = 0.6 if on else 0.0


## Whether this point in the world hit the front of this kart where its ram
## plate is. Anything level with the plate or ahead of it counts, since the
## chassis under it is flush with it.
func rammed_with(point: Vector3) -> bool:
	if stats == null:
		return false
	for info in stats.parts:
		if info.def.get("gadget", "") == "ram":
			var local := global_transform.affine_inverse() * point
			return local.z <= info.centre.z + info.extent.z * 0.5 + 0.05
	return false


## When a fired brick hits, one part comes off, working from the outside in,
## unless a shield is up.
func knock_off_a_part() -> void:
	if shield_left > 0.0 or stats == null:
		return
	Sounds.play_at("fx/hit", sound)
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


## Puts the kart back on its wheels facing the way it was going, with its lost
## parts back on, then holds it back for a moment so a reset is never a
## shortcut.
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
	# A kart put back before a loop has already lost time by starting further
	# back, so it gets no slowdown.
	slowdown_left = 0.0 if run_up_reset else RESET_SLOWDOWN_TIME
	run_up_reset = false
	_repair_pending = true
	Sounds.play_at.call_deferred("fx/reset", sound)
	was_reset.emit.call_deferred()


## Puts every lost part back on.
func repair_now() -> void:
	var had_lost := not lost.is_empty()
	lost.clear()
	_impact.clear()
	_breaking.clear()
	_assemble()
	if had_lost:
		repaired.emit()


## Where this kart is and what it's doing, to send to the other devices. That's
## its position, facing, velocity, steering and shield.
func net_state() -> PackedFloat32Array:
	var q := global_basis.get_rotation_quaternion()
	var p := global_position
	var v := linear_velocity
	return PackedFloat32Array([p.x, p.y, p.z, q.x, q.y, q.z, q.w, v.x, v.y, v.z, steer_angle, shield_left])


## Shows a remote kart as its update says, already smoothed (see NetRace).
func show_net_state(where: Transform3D, velocity: Vector3, steer: float, shield: float) -> void:
	global_transform = where
	remote_velocity = velocity
	forward_speed = velocity.dot(-where.basis.z)
	steer_angle = steer
	if shield > 0.0 and shield_left <= 0.0:
		_show_bubble()
	shield_left = shield


func _process(delta: float) -> void:
	if remote:
		for w in wheels:
			w.spin += forward_speed / w.radius * delta
	_pose_driver()
	_lean_looks(delta)
	if remote:
		full_lock = steer_limit(remote_velocity.length())
	var steered := Basis(Vector3.UP, -shown_steer())
	for turning in _turning:
		turning[0].basis = steered * turning[1]
	for w in wheels:
		w.visual.position = w.rest + Vector3.UP * (SUSPENSION_TRAVEL - w.length)
		var turn := steered if w.steered else Basis.IDENTITY
		w.visual.basis = turn * Basis(Vector3.RIGHT, -w.spin)


## How far the front wheels look turned (see SHOWN_LOCK), right negative like
## steer_angle.
func shown_steer() -> float:
	return clampf(steer_angle / maxf(full_lock, 0.001), -1.0, 1.0) * SHOWN_LOCK


## Leans a bike's looks into the bend, as far as it would have to lean to go
## round it at this speed, about where its wheels touch the ground.
func _lean_looks(delta: float) -> void:
	if _looks == null:
		return
	var want := 0.0
	if upright >= 1.0:
		var bend := tan(steer_angle) / maxf(wheelbase, 0.5)
		want = clampf(atan(forward_speed * absf(forward_speed) * bend / KartStats.gravity()), -MOST_LEAN, MOST_LEAN)
	lean = move_toward(lean, want, LEAN_RATE * delta)
	var pivot := Vector3(0.0, _ground_y, 0.0)
	var tip := Basis(Vector3.FORWARD, lean)
	_looks.transform = Transform3D(tip, pivot - tip * pivot)
