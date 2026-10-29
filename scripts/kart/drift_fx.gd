class_name DriftFx
extends Node3D

## A kart's tire smoke, drift sparks and boost flames. Smoke comes off the
## driven wheels while it slides, tinted by what they're on: grey on tarmac,
## brown on dirt and mud, white spray on snow. Once a slide's charged a
## boost, sparks fly off the back wheels in the level's colour (blue,
## orange, purple), and a boost blows short flames out of the back in the
## same colour, bigger for a longer boost, with a burst as it starts.
## Wheels going through a puddle throw up spray, in the same batch as the
## smoke, so Low graphics leaves it out too.
##
## It's only looks, worked out here from the kart's state each frame, and it
## never touches the physics. The smoke and the glowing bits are each one
## batch of soft dots, moved by the processor and drawn in one call, kept small for slow phones. Low
## graphics leaves the smoke out and has fewer of the rest (see Graphics).
## A remote kart's slides and boosts aren't sent, so it only smokes when
## its updates show it going sideways.

## The most dots of each at High. A remote kart throws up no spray, so it
## has fewer smoke dots.
const SMOKE_MOST := 40
const SMOKE_REMOTE := 24
const GLOW_MOST := 32
## Dots a second: smoke from each driven wheel, sparks, and flames. Smoke
## from all the driven wheels together stays under SMOKE_ALL, so with puffs
## living up to 0.8 s there are never more than SMOKE_REMOTE and it comes
## steady on four driven wheels too.
const SMOKE_RATE := 14.0
const SMOKE_ALL := 26.0
const SPARK_RATE := 22.0
const FLAME_RATE := 30.0
const BURST := 8
## Spray drops a second from each wheel in water at least half as deep as
## it gets, going SPRAY_SPEED m/s or more, fewer in shallower water and
## slower, and none under SPRAY_LEAST m/s.
const SPRAY_RATE := 26.0
const SPRAY_SPEED := 20.0
const SPRAY_LEAST := 4.0
const SPRAY := Color(0.93, 0.96, 1.0, 0.8)

const LEVEL_COLOURS := [Color(0.35, 0.65, 1.0), Color(1.0, 0.55, 0.12), Color(0.78, 0.32, 1.0)]

## Smoke by the "surface" a wheel is on.
const SMOKE := {
	"grey": Color(0.8, 0.8, 0.78, 0.6),
	"brown": Color(0.52, 0.4, 0.26, 0.65),
	"sand": Color(0.86, 0.77, 0.56, 0.6),
	"white": Color(0.97, 0.98, 1.0, 0.8),
}
const SURFACE_SMOKE := {
	"dirt": "brown", "gravel": "brown", "mud": "brown", "grass": "brown",
	"sand": "sand", "snow": "white", "ice": "white",
}

## One shader for every kind, so there's only the one to compile. Smoke has
## soft edges; sparks and flames ("hot") have a white middle.
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix, skip_vertex_transform, fog_disabled;
uniform float edge = 0.2;
uniform float hot = 0.0;
varying vec4 tint;

void vertex() {
	// Each dot's place and size come in its transform, and it always faces
	// the camera.
	vec3 centre = MODELVIEW_MATRIX[3].xyz;
	VERTEX = centre + vec3(VERTEX.xy * length(MODEL_MATRIX[0].xyz), 0.0);
	tint = COLOR;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.98, 0.9), hot * (1.0 - smoothstep(0.0, 0.55, d)));
	ALPHA = tint.a * (1.0 - smoothstep(edge, 1.0, d));
}
"""

static var _shader: Shader

## Whether snow lies on the road, so any wheel on it throws up white spray.
var snow_lies := false

var _kart: Kart
var _smoke: Dots
var _glow: Dots
var _smoke_due := 0.0
var _spark_due := 0.0
var _flame_due := 0.0
var _spray_due := 0.0
var _boosts_seen := 0
var _exhaust := Vector3.ZERO
var _exhaust_for: KartStats
var _rng := RandomNumberGenerator.new()


## One batch of dots that fly, grow and fade.
class Dots:
	extends MultiMeshInstance3D

	var most := 0
	var count := 0
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var age := PackedFloat32Array()
	var life := PackedFloat32Array()
	var size_from := PackedFloat32Array()
	var size_to := PackedFloat32Array()
	var fall := PackedFloat32Array()
	var from := PackedColorArray()
	var to := PackedColorArray()
	## The multimesh's buffer, 16 floats a dot: a 3x4 transform by rows, then
	## the colour. Only the size, place and colour change, so the rest stays 0.
	var buffer := PackedFloat32Array()
	var shown := -1

	func _init(most_: int, shader: Shader, edge: float, hot: float) -> void:
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = QuadMesh.new()
		multimesh = multi
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("edge", edge)
		material.set_shader_parameter("hot", hot)
		material_override = material
		make_room(most_)

	## Makes room for this many dots, keeping the ones there are.
	func make_room(most_: int) -> void:
		most = most_
		multimesh.instance_count = most
		multimesh.visible_instance_count = 0
		shown = -1
		var had := buffer.size()
		buffer.resize(most * 16)
		for n in range(had, buffer.size()):
			buffer[n] = 0.0
		multimesh.buffer = buffer
		for array in [pos, vel]:
			array.resize(most)
		for array in [age, life, size_from, size_to, fall]:
			array.resize(most)
		from.resize(most)
		to.resize(most)

	## Adds a dot, unless there are already as many as there can be.
	func add(at: Vector3, speed: Vector3, time: float, grow_from: float, grow_to: float, colour_from: Color, colour_to: Color, gravity := 0.0) -> void:
		if count >= most:
			return
		var i := count
		count += 1
		pos[i] = at
		vel[i] = speed
		age[i] = 0.0
		life[i] = time
		size_from[i] = grow_from
		size_to[i] = grow_to
		fall[i] = gravity
		from[i] = colour_from
		to[i] = colour_to

	## Ages and moves the dots.
	func step(delta: float) -> void:
		var i := 0
		while i < count:
			age[i] += delta
			if age[i] >= life[i]:
				count -= 1
				pos[i] = pos[count]
				vel[i] = vel[count]
				age[i] = age[count]
				life[i] = life[count]
				size_from[i] = size_from[count]
				size_to[i] = size_to[count]
				fall[i] = fall[count]
				from[i] = from[count]
				to[i] = to[count]
				continue
			vel[i] = vel[i] * (1.0 - minf(delta * 2.5, 1.0)) + Vector3.DOWN * fall[i] * delta
			pos[i] += vel[i] * delta
			i += 1

	## Puts the dots on the screen, around a kart. With none it's hidden and
	## left alone.
	func show_around(around: Vector3) -> void:
		if count == 0:
			if shown != 0:
				shown = 0
				multimesh.visible_instance_count = 0
				visible = false
			return
		for n in count:
			var t := age[n] / life[n]
			var size := lerpf(size_from[n], size_to[n], t)
			var at := pos[n]
			var colour := from[n].lerp(to[n], t)
			var o := n * 16
			buffer[o] = size
			buffer[o + 3] = at.x
			buffer[o + 5] = size
			buffer[o + 7] = at.y
			buffer[o + 10] = size
			buffer[o + 11] = at.z
			buffer[o + 12] = colour.r
			buffer[o + 13] = colour.g
			buffer[o + 14] = colour.b
			buffer[o + 15] = colour.a
		multimesh.buffer = buffer
		if count != shown:
			shown = count
			multimesh.visible_instance_count = count
			visible = true
		# It sits at the world's origin, so its bounds go around the kart.
		custom_aabb = AABB(around - Vector3.ONE * 12.0, Vector3.ONE * 24.0)


func _init(kart: Kart) -> void:
	_kart = kart
	_rng.seed = hash(kart.get_instance_id())
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_smoke = Dots.new(SMOKE_REMOTE, _shader, 0.15, 0.0)
	_glow = Dots.new(GLOW_MOST, _shader, 0.45, 1.0)
	add_child(_smoke)
	add_child(_glow)


## Puts a few of each kind of dot behind the kart, so the splash screen gets
## their shaders compiled (see SplashScreen).
func show_sample() -> void:
	var back := _kart.to_global(_exhaust_point())
	for i in 3:
		_smoke.add(back + Vector3(i - 1.0, 0.0, 0.5), Vector3.ZERO, 2.0, 0.6, 0.8, SMOKE.grey, SMOKE.grey)
		_glow.add(back + Vector3(i - 1.0, 0.3, 0.3), Vector3.ZERO, 2.0, 0.3, 0.3, LEVEL_COLOURS[i], LEVEL_COLOURS[i])


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	# Moved first, so new ones start right where the kart is now.
	_smoke.step(delta)
	_glow.step(delta)
	var share: float = Graphics.value("drift_fx")
	var smoke_on: bool = Graphics.value("drift_smoke")
	var going := _kart.remote_velocity if _kart.remote else _kart.linear_velocity
	var speed := going.length()
	if not _kart.remote and _smoke.most < SMOKE_MOST:
		_smoke.make_room(SMOKE_MOST)
	if smoke_on and speed > 4.0:
		_tire_smoke(delta, going, share)
	if not _kart.remote:
		if smoke_on and speed > SPRAY_LEAST:
			_spray(delta, going, speed, share)
		if _kart.sliding and _kart.slide_level > 0:
			_sparks(delta, going, share)
		else:
			_spark_due = 0.0
		if _kart.boost_count != _boosts_seen:
			_boosts_seen = _kart.boost_count
			_burst(going, share)
		if _kart.boost_left > 0.0:
			_flames(delta, going, share)
		else:
			_flame_due = 0.0
	var around := _kart.global_position
	_smoke.show_around(around)
	_glow.show_around(around)


func _tire_smoke(delta: float, going: Vector3, share: float) -> void:
	var sideways := absf(going.dot(_kart.global_basis.x))
	var slipping := (sideways > 3.0) if _kart.remote else _kart.sliding
	if not slipping:
		_smoke_due = 0.0
		return
	var hard := clampf(sideways / 8.0, 0.3, 1.0)
	var driven := 0
	for w: Kart.Wheel in _kart.wheels:
		if w.driven:
			driven += 1
	_smoke_due += minf(SMOKE_RATE, SMOKE_ALL / maxi(driven, 1)) * share * hard * delta
	while _smoke_due >= 1.0:
		_smoke_due -= 1.0
		for w: Kart.Wheel in _kart.wheels:
			if not w.driven:
				continue
			var at: Vector3
			var colour: Color
			if _kart.remote:
				at = w.visual.global_position - _kart.global_basis.y * w.radius * 0.8
				colour = SMOKE.white if snow_lies else SMOKE.grey
			elif w.grounded:
				at = w.contact
				colour = _smoke_for(w)
			else:
				continue
			var puff := going * 0.25 + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.4, 1.0), _rng.randf_range(-0.6, 0.6))
			var size := w.radius * _rng.randf_range(1.6, 2.2)
			var clear := Color(colour, 0.0)
			_smoke.add(at + Vector3.UP * w.radius * 0.5, puff, _rng.randf_range(0.5, 0.8), size, size * 2.6, colour, clear)


func _smoke_for(w: Kart.Wheel) -> Color:
	if w.snow > 0.05 or (snow_lies and not SURFACE_SMOKE.has(w.surface)):
		return SMOKE.white
	return SMOKE[SURFACE_SMOKE.get(w.surface, "grey")]


## Spray thrown up and out from the wheels in water, more the deeper it is
## and the faster the kart's going.
func _spray(delta: float, going: Vector3, speed: float, share: float) -> void:
	var wet := 0.0
	for w: Kart.Wheel in _kart.wheels:
		if w.grounded:
			wet += minf(w.water * 2.0, 1.0)
	if wet <= 0.0:
		_spray_due = 0.0
		return
	var fast := minf(speed / SPRAY_SPEED, 1.0)
	_spray_due += SPRAY_RATE * share * fast * wet * delta
	var middle := _kart.global_position
	var up := _kart.global_basis.y
	while _spray_due >= 1.0:
		_spray_due -= 1.0
		# A wheel in water, picked by how deep it is.
		var pick := _rng.randf() * wet
		for w: Kart.Wheel in _kart.wheels:
			if not w.grounded or w.water <= 0.0:
				continue
			pick -= minf(w.water * 2.0, 1.0)
			if pick > 0.0:
				continue
			var out := w.contact - middle
			out -= up * out.dot(up)
			out = out.normalized() if out.length() > 0.01 else _kart.global_basis.x
			var deep := minf(w.water * 2.0, 1.0)
			# Mostly along with the kart, fanned out sideways and up.
			var fling := going * _rng.randf_range(0.7, 0.9) + out * _rng.randf_range(2.0, 4.5) * fast + up * _rng.randf_range(3.0, 6.0) * (0.5 + 0.5 * deep) * fast
			var size := w.radius * _rng.randf_range(0.9, 1.3) * (0.6 + 0.4 * deep)
			_smoke.add(w.contact + up * w.radius * 0.8 + out * w.radius * 0.6, fling, _rng.randf_range(0.3, 0.45), size, size * 1.7, SPRAY, Color(SPRAY, 0.0), 9.0)
			break


## Sparks off the back wheels in the colour of the level charged.
func _sparks(delta: float, going: Vector3, share: float) -> void:
	var colour: Color = LEVEL_COLOURS[_kart.slide_level - 1]
	_spark_due += SPARK_RATE * share * (0.7 + 0.3 * _kart.slide_level) * delta
	var back := 0
	for w: Kart.Wheel in _kart.wheels:
		if not w.steered and w.grounded:
			back += 1
	if back == 0:
		_spark_due = 0.0
		return
	while _spark_due >= 1.0:
		_spark_due -= 1.0
		var w := _back_wheel(_rng.randi() % back)
		var out := going * 0.6 + _kart.global_basis.z * 2.0 + Vector3(_rng.randf_range(-2.0, 2.0), _rng.randf_range(1.5, 3.5), _rng.randf_range(-2.0, 2.0))
		_glow.add(w.contact + Vector3.UP * 0.08, out, _rng.randf_range(0.2, 0.32), 0.22, 0.08, colour, Color(colour, 0.2), 9.0)


## The nth back wheel on the ground.
func _back_wheel(n: int) -> Kart.Wheel:
	for w: Kart.Wheel in _kart.wheels:
		if not w.steered and w.grounded:
			if n == 0:
				return w
			n -= 1
	return _kart.wheels[0]


## Short flames out of the back for as long as the boost lasts, longer for a
## longer boost.
func _flames(delta: float, going: Vector3, share: float) -> void:
	var colour: Color = LEVEL_COLOURS[clampi(_kart.boost_level, 1, 3) - 1]
	var big := clampf(_kart.boost_given / 1.5, 0.5, 1.6)
	_flame_due += FLAME_RATE * share * delta
	var back := _kart.global_basis.z
	var at := _kart.to_global(_exhaust_point())
	while _flame_due >= 1.0:
		_flame_due -= 1.0
		var out := going + back * _rng.randf_range(2.5, 4.0) * big + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.0, 0.4), _rng.randf_range(-0.3, 0.3))
		var size := 0.32 * big * _rng.randf_range(0.8, 1.2)
		# Spread along the trail, so a slow frame doesn't heap them up.
		_glow.add(at + back * _rng.randf_range(0.0, 0.35) * big, out, _rng.randf_range(0.12, 0.2) * big, size, size * 0.35, colour, Color(colour, 0.0))


## A quick puff of flame as a boost starts.
func _burst(going: Vector3, share: float) -> void:
	var colour: Color = LEVEL_COLOURS[clampi(_kart.boost_level, 1, 3) - 1]
	var at := _kart.to_global(_exhaust_point())
	var back := _kart.global_basis.z
	for i in maxi(roundi(BURST * share), 2):
		var out := going + back * 3.0 + Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(0.0, 1.5), _rng.randf_range(-1.5, 1.5))
		_glow.add(at, out, _rng.randf_range(0.2, 0.3), 0.7, 0.2, colour, Color(colour, 0.0))


## Where the flames come out, just behind the kart and low on its body, in
## its own space.
func _exhaust_point() -> Vector3:
	if _kart.stats != _exhaust_for:
		_exhaust_for = _kart.stats
		_exhaust = _kart.rear_bumper_point() + Vector3.BACK * 0.1
		var low := INF
		var high := -INF
		for info: KartStats.PartInfo in _kart.stats.parts:
			if info.def.kind != "wheel":
				low = minf(low, info.centre.y - info.extent.y * 0.5)
				high = maxf(high, info.centre.y + info.extent.y * 0.5)
		if low < high:
			_exhaust.y = minf(low + 0.25, lerpf(low, high, 0.35))
	return _exhaust
