class_name PowerupField
extends Node3D

## The power-up boxes along a track. Every EVERY metres there's a row of three
## right across the road, so wherever you drive you can get one, and driving
## through a box with a free gadget button gives you a power-up (see
## Powerups), better the further back you are.
##
## Every kart collects each box for itself, so the karts ahead can't take them
## all before you get there. What you see is your own set. A box you've taken
## disappears for you and comes back a few seconds later.
##
## In split screen each player's set is drawn on its own render layer (see
## layer_of()), and each player's camera leaves out the other one's.

const EVERY := 400.0 # metres between rows
const FIRST := 150.0 # metres from the start line to the first row
const ACROSS := [-4.0, 0.0, 4.0] # where the three boxes in a row sit
const HEIGHT := 0.9
const REACH := 1.9
const BACK_AFTER := 4.0
const SIZE := 1.1
## The render layer of the first viewer's boxes. The next viewer's is the one
## after it.
const FIRST_LAYER := 11

const BOX_SHADER := """
shader_type spatial;
render_mode cull_disabled;

varying float seed;

void vertex() {
	seed = float(INSTANCE_ID);
	float a = TIME * 1.6 + seed * 0.9;
	mat3 spin = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
	VERTEX = spin * VERTEX + vec3(0.0, sin(TIME * 2.0 + seed) * 0.1, 0.0);
	NORMAL = spin * NORMAL;
}

void fragment() {
	// A colour that shifts slowly through the rainbow.
	float h = fract(TIME * 0.25 + seed * 0.13);
	vec3 rainbow = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0), rainbow, 0.75);
	EMISSION = rainbow * 0.45;
	ROUGHNESS = 0.25;
	ALPHA = 0.8;
}
"""

static var _shader: Shader

var track: TrackPath
## The race, for each kart's place when it picks a box up. It isn't named as
## a Race, since that needs the Game autoload and the -s tests don't have one.
var race: Node
var spots: Array[Transform3D] = []
## Whose boxes are shown, which is the karts the cameras follow. The rest
## collect theirs unseen. Set this before it's added to the scene.
var viewers: Array[Kart] = []
## For each kart (by instance id), when each box comes back for it.
var _back_at := {}
var _time := 0.0
var _rng := RandomNumberGenerator.new()
## One for each viewer.
var _multis: Array[MultiMesh] = []


func _init(path: TrackPath) -> void:
	track = path


func _ready() -> void:
	var d := FIRST
	while d < track.length - 60.0:
		# Never on a loop or a corkscrew, or where the road's open, like a
		# jump's gap.
		var at := d
		while (not track.solid_at(at) or TrackPiece.turns_over(track.piece_type_at(at))) and at < d + EVERY * 0.5:
			at += 8.0
		if track.solid_at(at) and not TrackPiece.turns_over(track.piece_type_at(at)):
			for across in ACROSS:
				var frame := track.frame_at(at)
				frame.origin += frame.basis.y * HEIGHT + frame.basis.x * across
				spots.append(frame)
		d += EVERY

	var box := BoxMesh.new()
	box.size = Vector3.ONE * SIZE
	if _shader == null:
		_shader = TrackBuilder.shader_for(BOX_SHADER)
	var material := ShaderMaterial.new()
	material.shader = _shader
	for v in viewers.size():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = box
		multi.instance_count = spots.size()
		for i in spots.size():
			multi.set_instance_transform(i, spots[i])
		var draw := MultiMeshInstance3D.new()
		draw.multimesh = multi
		draw.material_override = material
		if viewers.size() > 1:
			draw.layers = 1 << (layer_of(v) - 1)
		add_child(draw)
		_multis.append(multi)


## The render layer (counting from 1) that this viewer's boxes are drawn on.
static func layer_of(viewer_index: int) -> int:
	return FIRST_LAYER + viewer_index


## Gives this kart a power-up if it's driving through a box and has a free
## button. Returns the one it got, or "".
func collect(kart: Kart) -> String:
	if kart.full():
		return ""
	var back := _times_for(kart)
	var middle := kart.global_position + kart.global_basis.y * 0.5
	for i in spots.size():
		if back[i] > _time:
			continue
		if spots[i].origin.distance_squared_to(middle) < REACH * REACH:
			back[i] = _time + BACK_AFTER
			var v := viewers.find(kart)
			if v >= 0:
				_multis[v].set_instance_transform(i, spots[i].scaled_local(Vector3.ONE * 0.001))
			var field: int = race.racers.size() if race != null else 1
			var kind := Powerups.pick(_place_of(kart), field, _rng)
			kart.give(kind)
			return kind
	return ""


func _place_of(kart: Kart) -> int:
	if race == null:
		return 1
	for racer in race.racers:
		if racer.kart == kart:
			return int(race.place_of(racer))
	return 1


func _times_for(kart: Kart) -> PackedFloat32Array:
	var id := kart.get_instance_id()
	if not _back_at.has(id):
		var times := PackedFloat32Array()
		times.resize(spots.size())
		_back_at[id] = times
	return _back_at[id]


func _physics_process(delta: float) -> void:
	_time += delta
	for v in viewers.size():
		var back := _times_for(viewers[v])
		for i in spots.size():
			if back[i] > 0.0 and back[i] <= _time:
				back[i] = 0.0
				_multis[v].set_instance_transform(i, spots[i])
