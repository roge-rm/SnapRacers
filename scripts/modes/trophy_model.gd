class_name TrophyModel
extends RefCounted

## A cup's trophy, built from bricks. Every one stands on the same plinth, a
## black brick with a plate in the cup's colour and a round stem, and has its
## own top: a two handled cup, a wheel, a gear, an arch, a chequered flag,
## mountains, a lightning bolt, a corkscrew, a palm tree, a cable car, a
## cactus, a stone head from a jungle temple, a traffic light or a hot air
## balloon. The extra tops, which only the cup editor offers, are a steering
## wheel, a tire, a star, a crown, a rocket, a snowflake, a summit with a
## flag, a wrench, a lidded cup with tall handles, a racing helmet, a little
## kart and an anchor.
##
## It comes in plain light grey, for a cup you haven't won yet, or in gold,
## silver or bronze for your best finish. The plinth keeps its colours either
## way, so the cups still tell apart in grey.
##
## A trophy is a little over 1 m across and up to 2 m tall, standing on its own
## origin.

const TOPS := ["cup", "wheel", "gear", "arch", "flag", "peak", "bolt", "spiral", "palm", "cable_car", "cactus", "temple_head", "traffic_light", "balloon"]
## The tops your own cups get picked from. Kept as it is so a cup you made
## keeps its trophy when new cups add tops.
const OWN_TOPS := ["cup", "wheel", "gear", "arch", "flag", "peak", "bolt", "spiral", "palm"]
## Trophies no game cup awards, by the id a cup of your own saves for its
## pick: a name, the top and the plate's colour. "extra:" keeps the ids apart
## from the game cups' ones.
const EXTRAS := {
	"extra:steering_wheel": {"name": "Steering wheel", "top": "steering_wheel", "colour": "#2e3f8f"},
	"extra:tire": {"name": "Gold tire", "top": "tire", "colour": "#6b7a3a"},
	"extra:star": {"name": "Star", "top": "star", "colour": "#f07c5a"},
	"extra:crown": {"name": "Crown", "top": "crown", "colour": "#7a1c3c"},
	"extra:rocket": {"name": "Rocket", "top": "rocket", "colour": "#b8a6e0"},
	"extra:snowflake": {"name": "Snowflake", "top": "snowflake", "colour": "#bfe8ef"},
	"extra:summit": {"name": "Summit", "top": "summit", "colour": "#2f6b4f"},
	"extra:wrench": {"name": "Wrench", "top": "wrench", "colour": "#7d8b99"},
	"extra:loving_cup": {"name": "Tall cup", "top": "loving_cup", "colour": "#d4c39a"},
	"extra:helmet": {"name": "Racing helmet", "top": "helmet", "colour": "#ff8fb0"},
	"extra:kart": {"name": "Little kart", "top": "kart", "colour": "#93c47d"},
	"extra:anchor": {"name": "Anchor", "top": "anchor", "colour": "#004d66"},
}
const FINISHES := ["grey", "gold", "silver", "bronze"]
const GOLD := Color("#f2b632")
const SILVER := Color("#cdd3db")
const BRONZE := Color("#c47a45")
const PLINTH := Color("#1b2a34")
## The dark squares on the flag.
const DARK := Color("#1b2a34")

## Where the top sits, above the plinth and stem.
const TOP_AT := 0.8


## The trophy for a cup in this finish. `spec` is the cup's "trophy" entry,
## like { "top": "gear" }.
static func make(spec: Dictionary, colour: Color, finish := "grey") -> Node3D:
	var root := Node3D.new()
	root.name = "Trophy"
	for piece in pieces(spec, colour, finish):
		var shown := MeshInstance3D.new()
		shown.mesh = piece.mesh
		shown.transform = piece.at
		shown.material_override = piece.material
		root.add_child(shown)
	return root


## The bricks in a trophy, each { mesh, at, material, box }, the box being
## where it is, for checking they all hold together.
static func pieces(spec: Dictionary, colour: Color, finish := "grey") -> Array:
	var out := []
	var metal := _metal(finish)
	var add := func(mesh: Mesh, at: Transform3D, material: Material) -> void:
		out.append({ "mesh": mesh, "at": at, "material": material, "box": at * mesh.get_aabb() })
	# The plinth: a 4 by 4 black brick, a plate in the cup's colour, and a round
	# stem of a brick and a plate.
	add.call(_brick(Vector3(1.0, 0.3, 1.0)), _up(0.15), PartVisuals.material(PLINTH))
	add.call(_brick(Vector3(1.0, 0.1, 1.0)), _up(0.35), PartVisuals.material(colour))
	# The plate's studs, where the stem doesn't cover them.
	for x in [-0.375, -0.125, 0.125, 0.375]:
		for z in [-0.375, -0.125, 0.125, 0.375]:
			if absf(x) > 0.2 or absf(z) > 0.2:
				add.call(_stud(), _up(0.43, x, z), PartVisuals.material(colour))
	add.call(MeshKit.rounded_cylinder(0.24, 0.3, 0.02), _up(0.55), metal)
	add.call(MeshKit.rounded_cylinder(0.3, 0.1, 0.02), _up(0.75), metal)
	var top: String = spec.get("top", "cup")
	match top:
		"wheel":
			_wheel(add, metal)
		"gear":
			_gear(add, metal)
		"arch":
			_arch(add, metal)
		"flag":
			_flag(add, metal, finish)
		"peak":
			_peak(add, metal)
		"bolt":
			_bolt(add, metal)
		"spiral":
			_spiral(add, metal)
		"palm":
			_palm(add, metal)
		"cable_car":
			_cable_car(add, metal)
		"cactus":
			_cactus(add, metal)
		"temple_head":
			_temple_head(add, metal)
		"traffic_light":
			_traffic_light(add, metal)
		"balloon":
			_balloon(add, metal)
		"steering_wheel":
			_steering_wheel(add, metal)
		"tire":
			_tire(add, metal)
		"star":
			_star(add, metal)
		"crown":
			_crown(add, metal)
		"rocket":
			_rocket(add, metal)
		"snowflake":
			_snowflake(add, metal)
		"summit":
			_summit(add, metal)
		"wrench":
			_wrench(add, metal)
		"loving_cup":
			_loving_cup(add, metal)
		"helmet":
			_helmet(add, metal, finish)
		"kart":
			_kart(add, metal)
		"anchor":
			_anchor(add, metal)
		_:
			_cup(add, metal)
	return out


## The top for one of your own cups, picked from its name so it stays the
## same, and a colour to go with it.
static func spec_for(cup_name: String) -> Dictionary:
	return { "top": OWN_TOPS[absi(hash(cup_name)) % OWN_TOPS.size()] }


static func colour_for(cup_name: String) -> Color:
	return Color.from_hsv(float(absi(hash(cup_name + " colour")) % 360) / 360.0, 0.6, 0.8)


## An extra trophy's { "trophy": its top, "colour" }, as a game cup has them,
## or nothing for an id that isn't one.
static func extra(id: String) -> Dictionary:
	if not EXTRAS.has(id):
		return {}
	return {"trophy": {"top": EXTRAS[id].top}, "colour": EXTRAS[id].colour}


## The finish for your best place in a cup: 1 is gold, 2 silver, 3 bronze.
static func finish_for(place: int) -> String:
	match place:
		1:
			return "gold"
		2:
			return "silver"
		3:
			return "bronze"
	return "grey"


static func _metal(finish: String) -> StandardMaterial3D:
	match finish:
		"gold":
			return PartVisuals.shiny(GOLD)
		"silver":
			return PartVisuals.shiny(SILVER)
		"bronze":
			return PartVisuals.shiny(BRONZE)
	return PartVisuals.material(Props.LIGHT_GREY)


static func _up(y: float, x := 0.0, z := 0.0) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


## Turned to face the front (-Z), for a top made as a side view.
static func _facing(y: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, y, 0.0))


static func _brick(size: Vector3) -> Mesh:
	return MeshKit.rounded_box(size, 0.015)


## A small brick with fewer steps round its edges, for tops made of many.
static func _small(size: Vector3) -> Mesh:
	return MeshKit.rounded_box(size, 0.015, 1.0, 2)


static func _stud() -> Mesh:
	return MeshKit.rounded_cylinder(0.075, 0.06, 0.012, 16)


## A four sided pyramid standing on its base, with flat faces.
static func _pyramid(half: float, height: float) -> Mesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector3(-half, 0.0, -half), Vector3(half, 0.0, -half), Vector3(half, 0.0, half), Vector3(-half, 0.0, half)]
	var tip := Vector3(0.0, height, 0.0)
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var normal := (b - a).cross(tip - a).normalized()
		if normal.dot((a + b) * 0.5) < 0.0:
			normal = -normal
		for v in [a, tip, b]:
			tool.set_normal(normal)
			tool.add_vertex(v)
	for v in [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]]:
		tool.set_normal(Vector3.DOWN)
		tool.add_vertex(v)
	tool.index()
	var mesh := tool.commit()
	MeshKit.fix_winding(mesh)
	return mesh


## A classic cup with a handle each side.
static func _cup(add: Callable, metal: Material) -> void:
	var bowl := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.16, 0.08), Vector2(0.24, 0.2), Vector2(0.36, 0.38),
		Vector2(0.44, 0.58), Vector2(0.47, 0.78), Vector2(0.48, 0.86), Vector2(0.42, 0.86), Vector2(0.4, 0.78),
		Vector2(0.37, 0.6), Vector2(0.0, 0.6),
	])
	add.call(MeshKit.lathe(bowl, 40), _up(TOP_AT), metal)
	for side in [-1.0, 1.0]:
		var handle := MeshKit.arc_tube(0.2, 0.045, deg_to_rad(-100.0), deg_to_rad(100.0), 16, 10)
		var at := Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(side * 0.36, TOP_AT + 0.55, 0.0))
		add.call(handle, at, metal)


## A kart wheel standing on its edge, with a hub.
static func _wheel(add: Callable, metal: Material) -> void:
	var tyre := PackedVector2Array([
		Vector2(0.24, -0.14), Vector2(0.44, -0.14), Vector2(0.5, -0.1), Vector2(0.52, 0.0),
		Vector2(0.5, 0.1), Vector2(0.44, 0.14), Vector2(0.24, 0.14),
	])
	var turned := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, TOP_AT + 0.52, 0.0))
	add.call(MeshKit.lathe(tyre, 40), turned, metal)
	add.call(MeshKit.rounded_cylinder(0.26, 0.2, 0.03), turned, metal)
	add.call(MeshKit.rounded_cylinder(0.08, 0.34, 0.02), turned, metal)


## A gear standing up, with teeth all round and a hole for an axle.
static func _gear(add: Callable, metal: Material) -> void:
	var outline := PackedVector2Array()
	var teeth := 12
	for i in teeth * 4:
		var angle := TAU * i / (teeth * 4)
		var r := 0.48 if (i % 4) in [1, 2] else 0.38
		outline.append(Vector2(cos(angle), sin(angle)) * r + Vector2(0.0, 0.48))
	add.call(BrickShapes.extrude(outline, 0.2), _facing(TOP_AT), metal)
	add.call(MeshKit.rounded_cylinder(0.14, 0.3, 0.03), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, TOP_AT + 0.48, 0.0)), metal)


## A round arch of blocks with a keystone at the top.
static func _arch(add: Callable, metal: Material) -> void:
	var outline := PackedVector2Array()
	for i in 17:
		var angle := PI * i / 16.0
		outline.append(Vector2(cos(angle) * 0.46, sin(angle) * 0.6))
	for i in 17:
		var angle := PI * (16 - i) / 16.0
		outline.append(Vector2(cos(angle) * 0.26, sin(angle) * 0.4))
	add.call(BrickShapes.extrude(outline, 0.24, true), _facing(TOP_AT), metal)
	var key := PackedVector2Array([Vector2(-0.1, 0.36), Vector2(0.1, 0.36), Vector2(0.14, 0.68), Vector2(-0.14, 0.68)])
	add.call(BrickShapes.extrude(key, 0.24), _facing(TOP_AT), metal)


## A chequered flag on a pole.
static func _flag(add: Callable, metal: Material, finish: String) -> void:
	add.call(MeshKit.rounded_cylinder(0.04, 1.2, 0.01, 12), _up(TOP_AT + 0.6, -0.3), metal)
	var dark := PartVisuals.material(DARK) if finish != "grey" else PartVisuals.material(Color("#635f61"))
	var square := 0.14
	for row in 4:
		for column in 4:
			var at := _up(TOP_AT + 0.68 + row * square, -0.3 + 0.04 + square * (column + 0.5))
			add.call(_brick(Vector3(square, square, 0.05)), at, metal if (row + column) % 2 == 0 else dark)


## Mountains, for the rough stuff: a big peak with a smaller one beside it.
static func _peak(add: Callable, metal: Material) -> void:
	add.call(_pyramid(0.36, 0.7), _up(TOP_AT, 0.1, 0.06), metal)
	add.call(_pyramid(0.26, 0.45), _up(TOP_AT, -0.26, -0.08), metal)


## A lightning bolt, for the bright lights indoors.
static func _bolt(add: Callable, metal: Material) -> void:
	var outline := PackedVector2Array([
		Vector2(0.08, 0.0), Vector2(0.4, 0.56), Vector2(0.14, 0.54), Vector2(0.34, 1.04),
		Vector2(-0.22, 0.4), Vector2(0.04, 0.42), Vector2(-0.12, 0.0),
	])
	add.call(BrickShapes.extrude(outline, 0.24), _facing(TOP_AT), metal)


## Round plates climbing around a bar, like a corkscrew.
static func _spiral(add: Callable, metal: Material) -> void:
	add.call(MeshKit.rounded_cylinder(0.06, 1.0, 0.02, 16), _up(TOP_AT + 0.5), metal)
	var steps := 18
	for i in steps:
		var angle := TAU * 1.5 * i / steps
		var y := TOP_AT + 0.04 + 0.9 * i / steps
		var at := _up(y, cos(angle) * 0.22, sin(angle) * 0.22)
		add.call(MeshKit.rounded_cylinder(0.14, 0.08, 0.02, 20), at, metal)


## A palm tree, its trunk leaning a little, with fronds and coconuts.
static func _palm(add: Callable, metal: Material) -> void:
	var top := Vector3.ZERO
	for k in 7:
		var at := Vector3(0.008 * k * k, TOP_AT + 0.08 + k * 0.15, 0.0)
		add.call(MeshKit.rounded_cylinder(0.11 - k * 0.006, 0.16, 0.02, 16), _up(at.y, at.x), metal)
		top = at + Vector3.UP * 0.08
	for k in 7:
		var a := TAU * k / 7.0
		var leaf := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.32)
		var centre := top + Basis(Vector3.UP, a) * Vector3(0.0, -0.05, 0.24)
		add.call(_brick(Vector3(0.15, 0.035, 0.48)), Transform3D(leaf, centre), metal)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		add.call(MeshKit.rounded_cylinder(0.06, 0.1, 0.03, 12), _up(top.y - 0.08, top.x + cos(a) * 0.08, sin(a) * 0.08), metal)


## A cable car hanging from a cable that runs up over a pylon.
static func _cable_car(add: Callable, metal: Material) -> void:
	add.call(MeshKit.rounded_cylinder(0.05, 1.12, 0.01, 12), _up(TOP_AT + 0.56, -0.32), metal)
	add.call(_brick(Vector3(0.1, 0.06, 0.26)), _up(TOP_AT + 1.12, -0.32), metal)
	var tilt := Basis(Vector3.BACK, 0.22)
	add.call(_brick(Vector3(1.2, 0.03, 0.03)), Transform3D(tilt, Vector3(0.0, TOP_AT + 1.16, 0.0)), metal)
	var hang := Vector3(0.22, TOP_AT + 1.16 + 0.22 * tan(0.22), 0.0)
	add.call(_brick(Vector3(0.08, 0.06, 0.08)), _up(hang.y, hang.x), metal)
	add.call(MeshKit.rounded_cylinder(0.02, 0.3, 0.005, 8), _up(hang.y - 0.17, hang.x), metal)
	add.call(_brick(Vector3(0.44, 0.05, 0.34)), _up(hang.y - 0.33, hang.x), metal)
	add.call(_brick(Vector3(0.4, 0.3, 0.3)), _up(hang.y - 0.5, hang.x), metal)
	# Window frames standing out a little on the front and back.
	for z in [-0.155, 0.155]:
		add.call(_brick(Vector3(0.34, 0.03, 0.02)), _up(hang.y - 0.42, hang.x, z), metal)
	add.call(_brick(Vector3(0.42, 0.04, 0.32)), _up(hang.y - 0.67, hang.x), metal)


## A saguaro cactus with two arms turned up, and a flower on top.
static func _cactus(add: Callable, metal: Material) -> void:
	add.call(MeshKit.rounded_cylinder(0.14, 0.92, 0.07, 20), _up(TOP_AT + 0.46), metal)
	for arm in [[-1.0, 0.34, 0.4], [1.0, 0.5, 0.3]]:
		var side: float = arm[0]
		var y: float = TOP_AT + arm[1]
		var up: float = arm[2]
		add.call(_brick(Vector3(0.26, 0.15, 0.15)), _up(y, side * 0.2), metal)
		add.call(MeshKit.rounded_cylinder(0.085, up, 0.04, 16), _up(y - 0.06 + up * 0.5, side * 0.31), metal)
	add.call(MeshKit.rounded_cylinder(0.08, 0.06, 0.02, 16), _up(TOP_AT + 0.94), metal)


## A big stone head with a helmet, looking out of the front from under a
## heavy brow, with round plugs in its ears.
static func _temple_head(add: Callable, metal: Material) -> void:
	add.call(_brick(Vector3(0.7, 0.08, 0.6)), _up(TOP_AT + 0.04), metal)
	add.call(_brick(Vector3(0.5, 0.2, 0.48)), _up(TOP_AT + 0.18), metal)
	add.call(_brick(Vector3(0.58, 0.36, 0.52)), _up(TOP_AT + 0.46), metal)
	add.call(_brick(Vector3(0.64, 0.16, 0.58)), _up(TOP_AT + 0.72), metal)
	add.call(_brick(Vector3(0.52, 0.08, 0.46)), _up(TOP_AT + 0.84), metal)
	add.call(_brick(Vector3(0.6, 0.06, 0.04)), _up(TOP_AT + 0.67, 0.0, -0.3), metal)
	for x in [-0.31, 0.31]:
		add.call(MeshKit.rounded_cylinder(0.08, 0.05, 0.01, 16), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, TOP_AT + 0.48, 0.0)), metal)
	# The face is on the front (-Z): brow, eyes, a broad nose and lips.
	add.call(_brick(Vector3(0.46, 0.05, 0.04)), _up(TOP_AT + 0.57, 0.0, -0.27), metal)
	for x in [-0.12, 0.12]:
		add.call(_brick(Vector3(0.12, 0.06, 0.03)), _up(TOP_AT + 0.51, x, -0.27), metal)
	add.call(_brick(Vector3(0.14, 0.14, 0.06)), _up(TOP_AT + 0.42, 0.0, -0.28), metal)
	add.call(_brick(Vector3(0.2, 0.06, 0.07)), _up(TOP_AT + 0.37, 0.0, -0.285), metal)
	add.call(_brick(Vector3(0.24, 0.06, 0.04)), _up(TOP_AT + 0.31, 0.0, -0.27), metal)


## A traffic light on a short post: a tall box with three round lamps down
## the front, each under a little hood.
static func _traffic_light(add: Callable, metal: Material) -> void:
	add.call(MeshKit.rounded_cylinder(0.07, 0.3, 0.02, 16), _up(TOP_AT + 0.15), metal)
	add.call(_brick(Vector3(0.36, 0.06, 0.3)), _up(TOP_AT + 0.31), metal)
	add.call(_brick(Vector3(0.32, 0.78, 0.24)), _up(TOP_AT + 0.73), metal)
	add.call(_brick(Vector3(0.36, 0.05, 0.28)), _up(TOP_AT + 1.13), metal)
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	for k in 3:
		var y := TOP_AT + 0.49 + k * 0.24
		add.call(MeshKit.rounded_cylinder(0.08, 0.05, 0.015, 16), Transform3D(face, Vector3(0.0, y, -0.13)), metal)
		add.call(_brick(Vector3(0.22, 0.03, 0.1)), _up(y + 0.1, 0.0, -0.17), metal)


## A hot air balloon: a basket with ropes at its corners up to a round
## balloon in panels, narrowing to its mouth over the basket, with a cap on
## top.
static func _balloon(add: Callable, metal: Material) -> void:
	add.call(_brick(Vector3(0.28, 0.2, 0.28)), _up(TOP_AT + 0.1), metal)
	add.call(_brick(Vector3(0.32, 0.05, 0.32)), _up(TOP_AT + 0.22), metal)
	for x in [-0.12, 0.12]:
		for z in [-0.12, 0.12]:
			add.call(MeshKit.rounded_cylinder(0.016, 0.22, 0.008, 8), _up(TOP_AT + 0.34, x, z), metal)
	var envelope := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.14, 0.04), Vector2(0.21, 0.16), Vector2(0.3, 0.29),
		Vector2(0.39, 0.43), Vector2(0.45, 0.57), Vector2(0.47, 0.68), Vector2(0.44, 0.79), Vector2(0.35, 0.88),
		Vector2(0.2, 0.94), Vector2(0.0, 0.96),
	])
	# Few sides, so the panels show.
	add.call(MeshKit.lathe(envelope, 10), _up(TOP_AT + 0.42), metal)
	add.call(MeshKit.rounded_cylinder(0.16, 0.05, 0.015, 10), _up(TOP_AT + 0.43), metal)
	add.call(MeshKit.rounded_cylinder(0.12, 0.04, 0.015, 10), _up(TOP_AT + 1.36), metal)


## A front view outline pushed out `depth` deep, standing at `at` and turned
## `tilt` radians in the front plane.
static func _front(outline: PackedVector2Array, depth: float, at: Vector3, tilt := 0.0) -> Array:
	return [BrickShapes.extrude(outline, depth), Transform3D(Basis(Vector3.BACK, tilt) * Basis(Vector3.UP, PI * 0.5), at)]


## Turned so a cylinder's axis points out of the front.
static func _toward_front(at: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at)


## A racing steering wheel facing out, flat along the bottom, with grips,
## three spokes, a hub and a mark at the top, on a post.
static func _steering_wheel(add: Callable, metal: Material) -> void:
	var centre := Vector3(0.0, TOP_AT + 0.6, 0.0)
	var r := 0.38
	add.call(MeshKit.rounded_cylinder(0.07, 0.6, 0.02, 16), _up(TOP_AT + 0.3, 0.0, 0.07), metal)
	add.call(MeshKit.arc_tube(r, 0.055, deg_to_rad(-55.0), deg_to_rad(235.0), 36, 10), Transform3D(Basis.IDENTITY, centre), metal)
	var flat := r * sin(deg_to_rad(55.0))
	add.call(MeshKit.rounded_cylinder(0.055, r * cos(deg_to_rad(55.0)) * 2.0 + 0.04, 0.03, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), centre + Vector3.DOWN * flat), metal)
	for side in [-1.0, 1.0]:
		add.call(MeshKit.rounded_cylinder(0.075, 0.26, 0.035, 12), Transform3D(Basis.IDENTITY, centre + Vector3(side * r, 0.0, 0.0)), metal)
		add.call(_brick(Vector3(0.24, 0.08, 0.05)), Transform3D(Basis.IDENTITY, centre + Vector3(side * 0.2, 0.0, 0.0)), metal)
	add.call(_brick(Vector3(0.1, flat - 0.06, 0.05)), Transform3D(Basis.IDENTITY, centre + Vector3.DOWN * (flat * 0.5 + 0.03)), metal)
	add.call(MeshKit.rounded_cylinder(0.12, 0.1, 0.03, 20), _toward_front(centre), metal)
	add.call(MeshKit.rounded_cylinder(0.06, 0.04, 0.015, 16), _toward_front(centre + Vector3(0.0, 0.0, -0.06)), metal)
	add.call(_brick(Vector3(0.05, 0.13, 0.13)), Transform3D(Basis.IDENTITY, centre + Vector3.UP * r), metal)


## A fat tire with chunky tread, turned to show its face, with a rim and
## wheel nuts, sitting in a cradle.
static func _tire(add: Callable, metal: Material) -> void:
	var centre := Vector3(0.0, TOP_AT + 0.5, 0.0)
	var turn := Basis(Vector3.UP, -0.6)
	var rubber := PackedVector2Array([
		Vector2(0.21, -0.15), Vector2(0.36, -0.15), Vector2(0.4, -0.12), Vector2(0.41, 0.0),
		Vector2(0.4, 0.12), Vector2(0.36, 0.15), Vector2(0.21, 0.15), Vector2(0.21, -0.15),
	])
	add.call(MeshKit.lathe(rubber, 32), Transform3D(turn * Basis(Vector3.RIGHT, PI * 0.5), centre), metal)
	var blocks := 16
	for k in blocks:
		var a := TAU * k / blocks
		var shift := 0.045 if k % 2 == 0 else -0.045
		var block := Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 0.415, sin(a) * 0.415, shift))
		add.call(_small(Vector3(0.06, 0.1, 0.2)), Transform3D(turn, centre) * block, metal)
	add.call(MeshKit.rounded_cylinder(0.215, 0.22, 0.03, 24), Transform3D(turn * Basis(Vector3.RIGHT, PI * 0.5), centre), metal)
	for k in 5:
		var a := TAU * k / 5.0 + PI * 0.5
		var nut := Vector3(cos(a) * 0.11, sin(a) * 0.11, -0.12)
		add.call(MeshKit.rounded_cylinder(0.03, 0.04, 0.01, 6), Transform3D(turn * Basis(Vector3.RIGHT, PI * 0.5), centre + turn * nut), metal)
	add.call(MeshKit.rounded_cylinder(0.05, 0.05, 0.015, 16), Transform3D(turn * Basis(Vector3.RIGHT, PI * 0.5), centre + turn * Vector3(0.0, 0.0, -0.12)), metal)
	add.call(_brick(Vector3(0.44, 0.1, 0.36)), _up(TOP_AT + 0.05), metal)


## A five pointed star on a post, with a smaller raised star on each face.
static func _star(add: Callable, metal: Material) -> void:
	var big := PackedVector2Array()
	var small := PackedVector2Array()
	for i in 10:
		var a := PI * 0.5 + PI * i / 5.0
		var r := 0.46 if i % 2 == 0 else 0.19
		big.append(Vector2(cos(a), sin(a)) * r)
		small.append(Vector2(cos(a), sin(a)) * r * 0.62)
	var middle := TOP_AT + 0.6
	add.call(MeshKit.rounded_cylinder(0.08, 0.42, 0.02, 16), _up(TOP_AT + 0.21), metal)
	var shape: Array = _front(big, 0.16, Vector3(0.0, middle, 0.0))
	add.call(shape[0], shape[1], metal)
	for z in [-0.1, 0.1]:
		shape = _front(small, 0.05, Vector3(0.0, middle, z))
		add.call(shape[0], shape[1], metal)


## A crown on a cushion: a band with jewels, six points with balls on, and
## two arches crossing over the top under a ball.
static func _crown(add: Callable, metal: Material) -> void:
	add.call(MeshKit.rounded_box(Vector3(0.66, 0.16, 0.66), 0.06), _up(TOP_AT + 0.08), metal)
	for x in [-0.3, 0.3]:
		for z in [-0.3, 0.3]:
			add.call(MeshKit.rounded_cylinder(0.04, 0.08, 0.035, 10), _up(TOP_AT + 0.04, x, z), metal)
	var band := PackedVector2Array([
		Vector2(0.24, 0.0), Vector2(0.3, 0.0), Vector2(0.315, 0.03), Vector2(0.3, 0.06),
		Vector2(0.3, 0.2), Vector2(0.315, 0.22), Vector2(0.24, 0.22), Vector2(0.24, 0.0),
	])
	var bottom := TOP_AT + 0.15
	add.call(MeshKit.lathe(band, 32), _up(bottom), metal)
	var point := PackedVector2Array([Vector2(-0.12, 0.0), Vector2(0.12, 0.0), Vector2(0.0, 0.24)])
	for k in 6:
		var a := TAU * k / 6.0
		var out := Vector3(cos(a), 0.0, -sin(a))
		add.call(BrickShapes.extrude(point, 0.05), Transform3D(Basis(Vector3.UP, a), out * 0.27 + Vector3.UP * (bottom + 0.2)), metal)
		add.call(MeshKit.rounded_cylinder(0.045, 0.09, 0.04, 12), Transform3D(Basis.IDENTITY, out * 0.27 + Vector3.UP * (bottom + 0.46)), metal)
		var gem := Vector3(cos(a + PI / 6.0), 0.0, -sin(a + PI / 6.0))
		add.call(MeshKit.rounded_cylinder(0.04, 0.04, 0.015, 12), Transform3D(Basis(Vector3.UP, a + PI / 6.0) * Basis(Vector3.BACK, PI * 0.5), gem * 0.305 + Vector3.UP * (bottom + 0.11)), metal)
	for turn in [0.0, PI * 0.5]:
		add.call(MeshKit.arc_tube(0.26, 0.025, 0.0, PI, 16, 8), Transform3D(Basis(Vector3.UP, turn), Vector3(0.0, bottom + 0.2, 0.0)), metal)
	add.call(MeshKit.rounded_cylinder(0.06, 0.11, 0.05, 12), _up(bottom + 0.52), metal)


## A rocket on a launch pad, standing on four fins, with a porthole and a
## band round its middle.
static func _rocket(add: Callable, metal: Material) -> void:
	add.call(MeshKit.rounded_cylinder(0.36, 0.05, 0.015, 24), _up(TOP_AT + 0.025), metal)
	var body := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.16, 0.06), Vector2(0.17, 0.2), Vector2(0.17, 0.6),
		Vector2(0.15, 0.75), Vector2(0.1, 0.88), Vector2(0.04, 0.96), Vector2(0.0, 0.98),
	])
	var low := TOP_AT + 0.18
	add.call(MeshKit.lathe(body, 24), _up(low), metal)
	var bell := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.09, 0.14), Vector2(0.0, 0.14)])
	add.call(MeshKit.lathe(bell, 16), _up(TOP_AT + 0.05), metal)
	var fin := PackedVector2Array([Vector2(0.12, 0.2), Vector2(0.3, 0.05), Vector2(0.31, 0.1), Vector2(0.27, 0.28), Vector2(0.14, 0.62)])
	for k in 4:
		add.call(BrickShapes.extrude(fin, 0.05), Transform3D(Basis(Vector3.UP, PI * 0.25 + PI * 0.5 * k), Vector3(0.0, TOP_AT, 0.0)), metal)
	add.call(MeshKit.rounded_cylinder(0.185, 0.05, 0.015, 24), _up(low + 0.3), metal)
	add.call(MeshKit.rounded_cylinder(0.075, 0.04, 0.015, 16), _toward_front(Vector3(0.0, low + 0.52, -0.165)), metal)
	add.call(MeshKit.arc_tube(0.075, 0.018, 0.0, TAU, 16, 6), Transform3D(Basis.IDENTITY, Vector3(0.0, low + 0.52, -0.18)), metal)


## A snowflake standing on a post: six arms, each with a pair of branches and
## a little hexagon on its tip, around a hexagon in the middle.
static func _snowflake(add: Callable, metal: Material) -> void:
	var middle := Vector3(0.0, TOP_AT + 0.58, 0.0)
	add.call(MeshKit.rounded_cylinder(0.06, 0.2, 0.02, 12), _up(TOP_AT + 0.1), metal)
	for k in 6:
		var a := PI * 0.5 + PI * k / 3.0
		var out := Vector3(cos(a), sin(a), 0.0)
		add.call(_small(Vector3(0.44, 0.07, 0.08)), Transform3D(Basis(Vector3.BACK, a), middle + out * 0.22), metal)
		for side in [-1.0, 1.0]:
			var b: float = a + side * deg_to_rad(50.0)
			var branch := middle + out * 0.27 + Vector3(cos(b), sin(b), 0.0) * 0.07
			add.call(_small(Vector3(0.15, 0.05, 0.07)), Transform3D(Basis(Vector3.BACK, b), branch), metal)
		add.call(MeshKit.rounded_cylinder(0.05, 0.09, 0.02, 6), _toward_front(middle + out * 0.44), metal)
	add.call(MeshKit.rounded_cylinder(0.12, 0.12, 0.02, 6), _toward_front(middle), metal)


## A summit built up in steps of bricks, each a little off the one under it,
## with a lower peak beside it and a pennant on a pole at the top.
static func _summit(add: Callable, metal: Material) -> void:
	# Each step is [width, depth, x, z, level].
	var steps := [
		[0.74, 0.6, 0.0, 0.0, 0], [0.58, 0.5, 0.06, 0.03, 1], [0.44, 0.4, 0.1, -0.02, 2], [0.32, 0.3, 0.08, 0.02, 3],
		[0.3, 0.34, -0.2, -0.04, 1],
	]
	for step in steps:
		add.call(_brick(Vector3(step[0], 0.16, step[1])), _up(TOP_AT + 0.08 + step[4] * 0.16, step[2], step[3]), metal)
	add.call(_pyramid(0.15, 0.26), _up(TOP_AT + 0.32, -0.2, -0.04), metal)
	var tip := TOP_AT + 0.64
	add.call(_pyramid(0.16, 0.36), _up(tip, 0.08, 0.02), metal)
	add.call(MeshKit.rounded_cylinder(0.022, 0.32, 0.01, 10), _up(tip + 0.48, 0.08, 0.02), metal)
	var pennant := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.24, 0.07), Vector2(0.0, 0.14)])
	var shape: Array = _front(pennant, 0.03, Vector3(0.09, tip + 0.48, 0.02))
	add.call(shape[0], shape[1], metal)


## An open ended wrench leaning to one side, with a ring at the bottom, held
## in a little stand.
static func _wrench(add: Callable, metal: Material) -> void:
	var lean := Transform3D(Basis(Vector3.BACK, -0.35), Vector3(-0.17, TOP_AT + 0.14, 0.0))
	var ring := PackedVector2Array([Vector2(0.07, -0.045), Vector2(0.15, -0.045), Vector2(0.155, 0.0), Vector2(0.15, 0.045), Vector2(0.07, 0.045), Vector2(0.07, -0.045)])
	add.call(MeshKit.lathe(ring, 20), lean * _toward_front(Vector3.ZERO), metal)
	add.call(_brick(Vector3(0.13, 0.62, 0.07)), lean * _up(0.44), metal)
	var jaw := PackedVector2Array()
	for i in 17:
		var a := deg_to_rad(70.0 - 320.0 * i / 16.0)
		jaw.append(Vector2(cos(a), sin(a)) * 0.19)
	jaw.append(Vector2(-0.065, 0.02))
	jaw.append(Vector2(0.065, 0.02))
	var head: Array = _front(jaw, 0.09, Vector3.ZERO, 0.26)
	add.call(head[0], lean * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.86, 0.0)) * head[1], metal)
	add.call(_brick(Vector3(0.24, 0.06, 0.16)), _up(TOP_AT + 0.03, -0.17), metal)


## A tall cup with a lid and a knob, on a narrow foot, with big handles
## running down its sides.
static func _loving_cup(add: Callable, metal: Material) -> void:
	var urn := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.27, 0.03), Vector2(0.24, 0.06), Vector2(0.12, 0.1),
		Vector2(0.08, 0.18), Vector2(0.08, 0.26), Vector2(0.14, 0.3), Vector2(0.22, 0.4), Vector2(0.28, 0.56),
		Vector2(0.3, 0.72), Vector2(0.3, 0.84), Vector2(0.33, 0.88), Vector2(0.33, 0.92), Vector2(0.0, 0.92),
	])
	add.call(MeshKit.lathe(urn, 32), _up(TOP_AT), metal)
	var lid := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.29, 0.04), Vector2(0.22, 0.1), Vector2(0.1, 0.14), Vector2(0.0, 0.15)])
	add.call(MeshKit.lathe(lid, 32), _up(TOP_AT + 0.92), metal)
	add.call(MeshKit.rounded_cylinder(0.06, 0.1, 0.045, 12), _up(TOP_AT + 1.11), metal)
	var handle := MeshKit.arc_tube(0.24, 0.04, deg_to_rad(-110.0), deg_to_rad(100.0), 20, 10)
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3.UP, 0.0 if side > 0.0 else PI) * Basis.from_scale(Vector3(0.85, 1.2, 1.0))
		add.call(handle, Transform3D(basis, Vector3(side * 0.18, TOP_AT + 0.58, 0.0)), metal)


## A racing helmet on a stand, with a dark visor across the front, a pivot
## each side and a little spoiler at the back.
static func _helmet(add: Callable, metal: Material, finish: String) -> void:
	add.call(MeshKit.rounded_cylinder(0.13, 0.2, 0.02, 20), _up(TOP_AT + 0.1), metal)
	var low := TOP_AT + 0.16
	var shell := PackedVector2Array([
		Vector2(0.0, 0.02), Vector2(0.3, 0.02), Vector2(0.34, 0.06), Vector2(0.37, 0.18), Vector2(0.38, 0.3),
		Vector2(0.36, 0.44), Vector2(0.3, 0.56), Vector2(0.2, 0.64), Vector2(0.08, 0.68), Vector2(0.0, 0.69),
	])
	add.call(MeshKit.lathe(shell, 28), _up(low), metal)
	# A tinted visor, like the flag's dark squares.
	var tint := PartVisuals.material(DARK) if finish != "grey" else PartVisuals.material(Color("#635f61"))
	var visor := PackedVector2Array([Vector2(0.35, 0.13), Vector2(0.4, 0.13), Vector2(0.415, 0.25), Vector2(0.4, 0.38), Vector2(0.35, 0.38), Vector2(0.35, 0.13)])
	add.call(MeshKit.lathe(visor, 28, -PI * 0.5, PI * 0.5), _up(low), tint)
	for x in [-0.405, 0.405]:
		add.call(MeshKit.rounded_cylinder(0.065, 0.05, 0.015, 16), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, low + 0.255, 0.0)), metal)
	add.call(_brick(Vector3(0.3, 0.04, 0.14)), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.0, low + 0.56, 0.25)), metal)


## A little kart on a stand, side on and pointing right: wheels, side pods,
## a bumper each end, a seat, an engine, a steering wheel and a driver in a
## helmet.
static func _kart(add: Callable, metal: Material) -> void:
	add.call(_brick(Vector3(0.36, 0.2, 0.3)), _up(TOP_AT + 0.1), metal)
	var deck := TOP_AT + 0.2
	add.call(_brick(Vector3(0.96, 0.05, 0.62)), _up(deck + 0.025), metal)
	var axle := deck + 0.05
	for x in [-0.28, 0.28]:
		var r := 0.12 if x < 0.0 else 0.1
		for z in [-0.22, 0.22]:
			add.call(MeshKit.rounded_cylinder(r, 0.11, 0.03, 16), _toward_front(Vector3(x, axle + r, z)), metal)
	add.call(_small(Vector3(0.74, 0.04, 0.32)), _up(axle + 0.09), metal)
	for z in [-0.19, 0.19]:
		add.call(_small(Vector3(0.3, 0.08, 0.06)), _up(axle + 0.13, 0.0, z), metal)
	add.call(_small(Vector3(0.12, 0.08, 0.44)), _up(axle + 0.1, 0.43), metal)
	add.call(_small(Vector3(0.06, 0.07, 0.56)), _up(axle + 0.1, -0.43), metal)
	add.call(_small(Vector3(0.14, 0.05, 0.18)), _up(axle + 0.135, -0.08), metal)
	add.call(_small(Vector3(0.05, 0.2, 0.18)), Transform3D(Basis(Vector3.BACK, 0.2), Vector3(-0.17, axle + 0.23, 0.0)), metal)
	add.call(_small(Vector3(0.14, 0.14, 0.12)), _up(axle + 0.18, -0.29, 0.1), metal)
	add.call(MeshKit.rounded_cylinder(0.025, 0.2, 0.01, 10), Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0.18, axle + 0.2, 0.0)), metal)
	add.call(MeshKit.arc_tube(0.07, 0.015, 0.0, TAU, 16, 6), Transform3D(Basis(Vector3.BACK, 0.6) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.12, axle + 0.29, 0.0)), metal)
	add.call(_small(Vector3(0.1, 0.16, 0.16)), _up(axle + 0.24, -0.08), metal)
	add.call(MeshKit.rounded_cylinder(0.08, 0.12, 0.04, 16), _up(axle + 0.38, -0.07), metal)


## An anchor: a shank with a ring on top and a crossbar under it, and curved
## arms at the bottom ending in flukes.
static func _anchor(add: Callable, metal: Material) -> void:
	add.call(MeshKit.rounded_cylinder(0.05, 1.0, 0.02, 12), _up(TOP_AT + 0.5), metal)
	add.call(MeshKit.arc_tube(0.09, 0.03, 0.0, TAU, 20, 8), Transform3D(Basis.IDENTITY, Vector3(0.0, TOP_AT + 1.08, 0.0)), metal)
	add.call(MeshKit.rounded_cylinder(0.045, 0.56, 0.02, 12), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, TOP_AT + 0.82, 0.0)), metal)
	for x in [-0.28, 0.28]:
		add.call(MeshKit.rounded_cylinder(0.06, 0.08, 0.04, 12), _up(TOP_AT + 0.82, x), metal)
	var bend := Vector3(0.0, TOP_AT + 0.42, 0.0)
	add.call(MeshKit.arc_tube(0.34, 0.05, deg_to_rad(200.0), deg_to_rad(340.0), 18, 10), Transform3D(Basis.IDENTITY, bend), metal)
	var fluke := PackedVector2Array([Vector2(-0.1, -0.02), Vector2(0.1, -0.02), Vector2(0.0, 0.18)])
	for side in [-1.0, 1.0]:
		var a := deg_to_rad(270.0 + side * 70.0)
		var shape: Array = _front(fluke, 0.08, bend + Vector3(cos(a), sin(a), 0.0) * 0.34, -side * deg_to_rad(20.0))
		add.call(shape[0], shape[1], metal)
	add.call(MeshKit.rounded_cylinder(0.08, 0.1, 0.03, 16), _up(TOP_AT + 0.1), metal)
