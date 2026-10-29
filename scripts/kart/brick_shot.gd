class_name BrickShot
extends RigidBody3D

## A cannonball, or a homing brick. A cannonball goes off with a flash and
## smoke, flies fast and nearly flat trailing fire, and the first kart it hits
## loses several parts and is shoved, with a bang. A homing brick knocks one
## part off. It's gone after a couple of seconds either way.

const SPEED := 34.0
const LIFETIME := 2.5
## A homing brick flies a little slower and for longer, turning this fast
## toward its kart, in radians a second.
const HOMING_SPEED := 30.0
const HOMING_LIFETIME := 6.0
const TURN := 3.0
const BALL_RADIUS := 0.4
## Seconds between puffs of the trail behind a cannonball.
const TRAIL_EVERY := 0.05
## Metres of flame streaming behind a cannonball.
const FLAME_LENGTH := 2.6

static var _hots: Dictionary = {}

var shooter: Kart
## The kart a homing brick is after.
var chasing: Kart
var homing := false
var _age := 0.0
var _spent := false
var _trail_wait := 0.0
var _flame: Node3D


static func fire(from: Kart, homing_ := false) -> BrickShot:
	var shot := BrickShot.new()
	shot.shooter = from
	shot.homing = homing_
	if homing_:
		shot.chasing = _kart_ahead(from)
		shot.gravity_scale = 0.0
	shot._dress()
	var forward := -from.global_basis.z
	var up := from.global_basis.y
	shot.transform = Transform3D(from.global_basis, from.global_position + forward * 2.0 + up * 0.7)
	shot.linear_velocity = from.linear_velocity + forward * SPEED
	return shot


func _init() -> void:
	mass = 2.0
	gravity_scale = 0.25
	collision_layer = Kart.LAYER_HAZARD
	collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS | Kart.LAYER_HAZARD
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	body_entered.connect(_on_hit)


## A homing brick is a brick, and anything else a cannonball.
func _dress() -> void:
	var shape := CollisionShape3D.new()
	if homing:
		var size := Vector3(2.0, 3.0, 2.0) * Grid.UNIT
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		add_child(PartVisuals.make({ "kind": "brick", "color": Color("#6b6f76"), "size": Vector3i(2, 3, 2) }, size))
	else:
		mass = 4.0
		var round_ := SphereShape3D.new()
		round_.radius = BALL_RADIUS
		shape.shape = round_
		var ball := MeshInstance3D.new()
		var look := SphereMesh.new()
		look.radius = BALL_RADIUS
		look.height = BALL_RADIUS * 2.0
		ball.mesh = look
		ball.material_override = PartVisuals.shiny(Color("#2b2d31"))
		add_child(ball)
		# A hot glow round it, drawn from the inside so it rims the ball
		# instead of covering it.
		var glow := MeshInstance3D.new()
		var halo := SphereMesh.new()
		halo.radius = BALL_RADIUS * 1.5
		halo.height = BALL_RADIUS * 3.0
		glow.mesh = halo
		glow.material_override = _hot(Color(1.0, 0.5, 0.1, 0.6), true)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
		# A streak of flame behind it, an outer orange one and a yellow core.
		_flame = Node3D.new()
		_flame.top_level = true
		_flame.visible = false
		for layer in [[1.0, 1.0, Color(1.0, 0.42, 0.05, 0.75)], [0.55, 0.6, Color(1.0, 0.88, 0.4, 0.9)]]:
			var streak := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = BALL_RADIUS * 1.1 * layer[0]
			cone.height = FLAME_LENGTH * layer[1]
			cone.radial_segments = 12
			cone.rings = 1
			streak.mesh = cone
			streak.material_override = _hot(layer[2])
			streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# The cone points along its own Y, which is turned to face back.
			streak.basis = Basis(Vector3.RIGHT, -PI * 0.5)
			streak.position = Vector3(0.0, 0.0, cone.height * 0.5)
			_flame.add_child(streak)
		add_child(_flame)
	add_child(shape)


## A glowing see-through material, made once for each colour.
static func _hot(colour: Color, inside := false) -> StandardMaterial3D:
	var key := colour.to_html() + (" inside" if inside else "")
	if not _hots.has(key):
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hot.albedo_color = colour
		if inside:
			hot.cull_mode = BaseMaterial3D.CULL_FRONT
		_hots[key] = hot
	return _hots[key]


func _ready() -> void:
	# The parent is still adding this when _ready runs, so the flash goes in
	# just after.
	if not homing:
		CannonFx.muzzle.call_deferred(get_parent(), global_position, linear_velocity.normalized())


func _on_hit(body: Node) -> void:
	if _spent or body == shooter:
		return
	if body is Kart:
		_spent = true
		# The hit arrives in the middle of a physics step, when shapes can't
		# change, so the part comes off just after. A kart driven on another
		# device loses it there instead, when its own copy of the brick hits.
		if not body.remote:
			if homing:
				body.knock_off_a_part.call_deferred()
			else:
				body.struck_by_cannon.call_deferred(linear_velocity)
		if not homing:
			CannonFx.bang.call_deferred(get_parent(), global_position)
		queue_free()
	elif body is BrickPile or body.get_parent() is BrickWall:
		# Dropped bricks and walls get blasted away, which uses the shot up.
		_spent = true
		if homing:
			var push := linear_velocity.normalized() * BrickPile.HOMING_SPEED
			BrickPile.throw.call_deferred(body, push)
		else:
			BrickPile.blast(get_tree(), global_position, BrickPile.CANNON_REACH, BrickPile.CANNON_SPEED)
			CannonFx.bang.call_deferred(get_parent(), global_position)
		queue_free()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > (HOMING_LIFETIME if chasing != null else LIFETIME):
		if not homing:
			get_parent().add_child(CannonFx.puff(global_position, 0.8, Color(0.6, 0.58, 0.55, 0.7), Color(0.5, 0.5, 0.5, 0.0), 0.5))
		queue_free()
		return
	if not homing:
		_trail(delta)
	# A homing brick turns toward the kart it's after, a little at a time.
	if chasing != null and is_instance_valid(chasing):
		var to := chasing.global_position + chasing.global_basis.y * 0.5 - global_position
		var heading := linear_velocity.normalized()
		var wanted := to.normalized()
		var turned := heading.slerp(wanted, minf(TURN * delta / maxf(heading.angle_to(wanted), 0.001), 1.0))
		linear_velocity = turned * HOMING_SPEED


## Fire and smoke left behind a flying cannonball, hot near the ball and
## going grey as it fades.
func _trail(delta: float) -> void:
	var speed := linear_velocity.length()
	# The flame points back the way it came, and shrinks as it slows.
	if speed > 1.0:
		var ahead := linear_velocity / speed
		var up := Vector3.UP if absf(ahead.y) < 0.95 else Vector3.RIGHT
		var stretch := clampf(speed / SPEED, 0.2, 1.0)
		_flame.global_transform = Transform3D(Basis.looking_at(ahead, up) * Basis.from_scale(Vector3(1.0, 1.0, stretch)), global_position)
	_flame.visible = speed > 4.0
	_trail_wait -= delta
	if _trail_wait > 0.0:
		return
	_trail_wait = TRAIL_EVERY
	if speed < 4.0:
		return
	# Smoke off the end of the flame that hangs about.
	var wobble := Vector3(sin(_age * 37.0), cos(_age * 29.0), sin(_age * 23.0)) * 0.12
	var behind := global_position - linear_velocity.normalized() * FLAME_LENGTH * 0.8
	get_parent().add_child(CannonFx.puff(behind + wobble, 0.6, Color(0.42, 0.4, 0.38, 0.7), Color(0.65, 0.65, 0.65, 0.0), 0.8, 1.8, Vector3.UP * 0.5))


## The kart just ahead of this one in the race, or null if it's in front. A
## kart that isn't in a race has nobody to chase.
static func _kart_ahead(from: Kart) -> Kart:
	# The race is asked without naming it, since Race needs the Game autoload
	# and the -s tests load karts without one.
	var race = from.get_parent()
	if race == null or not race.has_method("standings"):
		return null
	var order: Array = race.standings()
	for i in order.size():
		if order[i].kart == from:
			return order[i - 1].kart if i > 0 else null
	return null
