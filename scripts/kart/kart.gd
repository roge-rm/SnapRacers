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
const TIRE_FRICTION := 1.25 # grip of a plain tire, as a multiple of its load
const BRAKE_FORCE := 2800.0
const REVERSE_FRACTION := 0.45
const REVERSE_TOP_SPEED := 6.0
const AIR_DENSITY := 1.2
const BODY_DRAG := 0.5
const TIRE_DRAG := 0.9
const ROLL_HELP := 0.6 # lifts the tire forces toward the centre of mass so it doesn't flip in every corner
const DRIVER_MASS := 45.0
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

static var _materials: Dictionary = {}
static var _stud_mesh: CylinderMesh


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
	power = 0.0
	max_force = 0.0
	lift_area = 0.0

	# Centre the kart on its own footprint so its origin sits on the ground
	# right under the middle of it.
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for p in design.parts:
		var def := PartCatalog.get_part(p.id)
		if def.is_empty():
			continue
		var size := Grid.rotated_size(def.size, p.rot)
		lo = lo.min(p.at)
		hi = hi.max(p.at + size)
	var offset := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)

	var total_mass := 0.0
	var weighted := Vector3.ZERO
	var frontal_cells := {}
	var wheel_drag := 0.0

	for p in design.parts:
		var def := PartCatalog.get_part(p.id)
		if def.is_empty():
			push_warning("There's no part called %s, so I left it out." % p.id)
			continue
		var size := Grid.rotated_size(def.size, p.rot)
		var extent := Grid.to_metres(Vector3(size))
		var centre := Grid.to_metres(Vector3(p.at) + Vector3(size) * 0.5 - offset)
		var part_mass: float = def.get("mass", 1.0)
		total_mass += part_mass
		weighted += centre * part_mass

		match def.kind:
			"wheel":
				var w := Wheel.new()
				w.part = def
				w.rest = centre
				w.radius = def.get("radius", 0.3)
				w.width = def.get("width", 0.25)
				w.grip = def.get("grip", 1.0)
				w.rolling = def.get("rolling", 0.015)
				w.visual = _make_wheel_visual(w)
				w.visual.position = centre
				add_child(w.visual)
				wheels.append(w)
				wheel_drag += w.width * w.radius * 2.0 * TIRE_DRAG
				continue
			"engine":
				power += def.get("power", 0.0)
				max_force += def.get("max_force", 0.0)
			"wing":
				lift_area += def.get("lift_area", 0.0)
			"seat":
				var seat_top := centre + Vector3.UP * extent.y * 0.5
				total_mass += DRIVER_MASS
				weighted += (seat_top + Vector3.UP * 0.3) * DRIVER_MASS
				_add_driver(seat_top)

		for x in size.x:
			for y in size.y:
				frontal_cells[Vector2i(p.at.x + x, p.at.y + y)] = true
		_add_block(def, centre, extent, def.kind in ["plate", "brick"])

	drag_area = frontal_cells.size() * Grid.STUD * Grid.PLATE * BODY_DRAG + wheel_drag
	mass = maxf(total_mass, 1.0)
	center_of_mass = weighted / mass

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
		var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		for w in wheels:
			w.spring = share * gravity / SUSPENSION_TRAVEL
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
		var tire := Vector2(f_long, f_lat).limit_length(TIRE_FRICTION * w.grip * load)

		state.apply_force(normal * load, contact - origin)
		var lifted := contact + up * (com - contact).dot(up) * ROLL_HELP
		state.apply_force(heading * tire.x + side * tire.y, lifted - origin)

	# Air: drag from everything facing forward, and downforce from any wings.
	var air := 0.5 * AIR_DENSITY
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


# Visuals. These are placeholders until the real brick models exist, but they
# already show every part where it really is.

func _add_block(def: Dictionary, centre: Vector3, extent: Vector3, studs: bool) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = extent
	shape.shape = box
	shape.position = centre
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = extent - Vector3.ONE * 0.004 # a hairline gap so parts read as separate bricks
	mesh.mesh = box_mesh
	mesh.material_override = _material(def.color)
	mesh.position = centre
	add_child(mesh)

	if studs:
		var size := Vector3i(roundi(extent.x / Grid.STUD), 0, roundi(extent.z / Grid.STUD))
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _stud()
		multi.instance_count = size.x * size.z
		var top := centre + Vector3(-extent.x * 0.5 + Grid.STUD * 0.5, extent.y * 0.5 + 0.025, -extent.z * 0.5 + Grid.STUD * 0.5)
		var i := 0
		for x in size.x:
			for z in size.z:
				multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, top + Vector3(x * Grid.STUD, 0.0, z * Grid.STUD)))
				i += 1
		var studs_node := MultiMeshInstance3D.new()
		studs_node.multimesh = multi
		studs_node.material_override = _material(def.color)
		add_child(studs_node)


func _make_wheel_visual(w: Wheel) -> Node3D:
	var pivot := Node3D.new()
	var tire := MeshInstance3D.new()
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = w.radius
	tire_mesh.bottom_radius = w.radius
	tire_mesh.height = w.width
	tire_mesh.radial_segments = 20
	tire.mesh = tire_mesh
	tire.material_override = _material(w.part.color)
	tire.rotation.z = PI * 0.5
	pivot.add_child(tire)

	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = w.radius * 0.55
	hub_mesh.bottom_radius = w.radius * 0.55
	hub_mesh.height = w.width + 0.02
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	hub.material_override = _material(Color("#e0e0e0"))
	hub.rotation.z = PI * 0.5
	pivot.add_child(hub)

	# A bar across the hub so you can see the wheel turning.
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(w.width + 0.03, w.radius * 1.1, 0.06)
	bar.mesh = bar_mesh
	bar.material_override = _material(Color("#8a8a8a"))
	pivot.add_child(bar)
	return pivot


func _add_driver(seat_top: Vector3) -> void:
	var driver := Node3D.new()
	driver.position = seat_top
	add_child(driver)
	var pieces := [
		# [size, position, colour]
		[Vector3(0.36, 0.14, 0.42), Vector3(0.0, 0.07, -0.12), "#0d69ab"], # legs, sitting
		[Vector3(0.38, 0.34, 0.2), Vector3(0.0, 0.31, 0.02), "#c4281c"], # torso
		[Vector3(0.1, 0.28, 0.12), Vector3(-0.24, 0.3, -0.06), "#c4281c"], # arms
		[Vector3(0.1, 0.28, 0.12), Vector3(0.24, 0.3, -0.06), "#c4281c"],
	]
	for piece in pieces:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = piece[0]
		mesh.mesh = box
		mesh.position = piece[1]
		mesh.material_override = _material(Color(piece[2]))
		driver.add_child(mesh)
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.12
	head_mesh.bottom_radius = 0.12
	head_mesh.height = 0.22
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.6, 0.02)
	head.material_override = _material(Color("#f2cd37"))
	driver.add_child(head)
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.15
	helmet_mesh.height = 0.2
	helmet_mesh.is_hemisphere = true
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 0.66, 0.02)
	helmet.material_override = _material(Color("#ffffff"))
	driver.add_child(helmet)

	# The driver takes hits too, so a roll-over lands on something.
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.4, 0.7, 0.3)
	shape.shape = box_shape
	shape.position = seat_top + Vector3(0.0, 0.4, 0.0)
	add_child(shape)


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.35
		m.metallic_specular = 0.6
		_materials[key] = m
	return _materials[key]


static func _stud() -> CylinderMesh:
	if _stud_mesh == null:
		_stud_mesh = CylinderMesh.new()
		_stud_mesh.top_radius = 0.075
		_stud_mesh.bottom_radius = 0.075
		_stud_mesh.height = 0.05
		_stud_mesh.radial_segments = 10
		_stud_mesh.rings = 1
	return _stud_mesh
