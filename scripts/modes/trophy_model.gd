class_name TrophyModel
extends RefCounted

## A cup's trophy, built from bricks. Every one stands on the same plinth, a
## black brick with a plate in the cup's colour and a round stem, and has its
## own top: a two handled cup, a wheel, a gear, an arch, a chequered flag,
## mountains, a lightning bolt, a corkscrew or a palm tree.
##
## It comes in plain light grey, for a cup you haven't won yet, or in gold,
## silver or bronze for your best finish. The plinth keeps its colours either
## way, so the cups still tell apart in grey.
##
## A trophy is a little over 1 m across and up to 2 m tall, standing on its own
## origin.

const TOPS := ["cup", "wheel", "gear", "arch", "flag", "peak", "bolt", "spiral", "palm"]
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
		_:
			_cup(add, metal)
	return out


## The top for one of your own cups, picked from its name so it stays the
## same, and a colour to go with it.
static func spec_for(cup_name: String) -> Dictionary:
	return { "top": TOPS[absi(hash(cup_name)) % TOPS.size()] }


static func colour_for(cup_name: String) -> Color:
	return Color.from_hsv(float(absi(hash(cup_name + " colour")) % 360) / 360.0, 0.6, 0.8)


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
