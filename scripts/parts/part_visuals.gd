class_name PartVisuals
extends RefCounted

## Makes the meshes for parts. The kart on the track and the garage both use
## these, so a part always looks the same wherever you see it. Bricks and
## plates are boxes with studs, the shaped bodywork comes from BrickShapes,
## and engines and wheels each have their own look.

const STUD_RADIUS := 0.075
const STUD_HEIGHT := 0.05

static var _materials: Dictionary = {}
static var _stud_mesh: CylinderMesh


## A part centred on its own origin, turned `rot` quarter turns. `extent` is
## its size once turned. Wheels come out with their axle along X.
static func make(def: Dictionary, extent: Vector3, rot := 0) -> Node3D:
	var kind: String = def.get("kind", "")
	if kind == "wheel":
		return make_wheel(def)
	if kind == "steering":
		return SteeringVisual.new(def, extent)
	var root := Node3D.new()
	# Shaped parts are made facing forward and then turned, so they need
	# their size before the turn.
	var own := extent
	if posmod(rot, 2) == 1:
		own = Vector3(extent.z, extent.y, extent.x)
	var holder := Node3D.new()
	holder.rotation.y = -rot * PI * 0.5
	root.add_child(holder)
	if kind == "engine":
		_engine(holder, def, own)
		return root
	var shape: String = def.get("shape", "")
	var mesh := MeshInstance3D.new()
	var shaped := BrickShapes.mesh(shape, own - Vector3.ONE * 0.004) if shape != "" else null
	if shaped != null:
		mesh.mesh = shaped
	else:
		var box := BoxMesh.new()
		box.size = own - Vector3.ONE * 0.004 # a hairline gap so parts read as separate bricks
		mesh.mesh = box
	mesh.material_override = glass(def.color) if shape == "screen" else material(def.color)
	holder.add_child(mesh)
	if kind in ["plate", "brick"] or shape != "":
		var cells := Vector2i(roundi(own.x / Grid.STUD), roundi(own.z / Grid.STUD))
		var studs := BrickShapes.studs(shape, cells)
		if not studs.is_empty():
			holder.add_child(make_studs(own, def.color, studs))
	return root


## Studs on top of a part. `cells` picks which ones, as (x, z) stud cells from
## the front left corner. Leave it empty for all of them.
static func make_studs(extent: Vector3, color: Color, cells: Array[Vector2i] = []) -> MultiMeshInstance3D:
	var across := roundi(extent.x / Grid.STUD)
	var along := roundi(extent.z / Grid.STUD)
	if cells.is_empty():
		cells = []
		for x in across:
			for z in along:
				cells.append(Vector2i(x, z))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _stud()
	multi.instance_count = cells.size()
	var corner := Vector3(-extent.x * 0.5 + Grid.STUD * 0.5, extent.y * 0.5 + STUD_HEIGHT * 0.5, -extent.z * 0.5 + Grid.STUD * 0.5)
	for i in cells.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, corner + Vector3(cells[i].x * Grid.STUD, 0.0, cells[i].y * Grid.STUD)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material(color)
	return node


static func make_wheel(def: Dictionary) -> Node3D:
	var radius: float = def.get("radius", 0.3)
	var width: float = def.get("width", 0.25)
	var tread: String = def.get("tread", "road")
	var pivot := Node3D.new()
	var tire := MeshInstance3D.new()
	# Knobbly tires have their lugs standing out past a smaller tire.
	var lug := 0.04 if tread == "knobbly" else 0.0
	if tread == "skinny":
		# Just a ring, so the spokes show through.
		var ring := TorusMesh.new()
		ring.inner_radius = radius - width * 0.6
		ring.outer_radius = radius
		ring.rings = 32
		ring.ring_segments = 10
		tire.mesh = ring
	else:
		var tire_mesh := CylinderMesh.new()
		tire_mesh.top_radius = radius - lug
		tire_mesh.bottom_radius = radius - lug
		tire_mesh.height = width
		tire_mesh.radial_segments = 24 if radius > 0.35 else 20
		tire.mesh = tire_mesh
	tire.material_override = material(def.color)
	tire.rotation.z = PI * 0.5
	pivot.add_child(tire)
	if lug > 0.0:
		var lugs := MeshInstance3D.new()
		lugs.mesh = _lugs(radius, width, lug)
		lugs.material_override = material(def.color)
		pivot.add_child(lugs)

	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	var hub_size := 0.25 if tread == "skinny" else 0.55
	hub_mesh.top_radius = radius * hub_size
	hub_mesh.bottom_radius = radius * hub_size
	hub_mesh.height = width + 0.02
	hub_mesh.radial_segments = 12
	hub.mesh = hub_mesh
	# Slicks have racing yellow hubs, so you can tell them apart.
	hub.material_override = material(Color("#f2cd37") if tread == "slick" else Color("#e0e0e0"))
	hub.rotation.z = PI * 0.5
	pivot.add_child(hub)

	if tread == "skinny":
		# Spokes, like a bicycle wheel.
		var spokes := MeshInstance3D.new()
		spokes.mesh = _spokes(radius, width)
		spokes.material_override = shiny(Color("#c8ccd0"))
		pivot.add_child(spokes)
	else:
		# A bar across the hub so you can see the wheel turning.
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(width + 0.03, radius * 1.1, 0.06)
		bar.mesh = bar_mesh
		bar.material_override = material(Color("#8a8a8a"))
		pivot.add_child(bar)
	return pivot


static var _shared: Dictionary = {}

## Chunky blocks all around a knobbly tire, in one mesh.
static func _lugs(radius: float, width: float, depth: float) -> Mesh:
	var key := "lugs %s %s %s" % [radius, width, depth]
	if not _shared.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := maxi(roundi(TAU * radius / 0.09), 10)
		var block := BoxMesh.new()
		block.size = Vector3(width * 0.92, depth * 2.0, TAU * radius / count * 0.55)
		for i in count:
			var a := TAU * i / count
			# Every other one is set in a little, like real tread.
			var sideways := 0.0 if i % 2 == 0 else width * 0.04
			var turn := Basis(Vector3.RIGHT, a)
			tool.append_from(block, 0, Transform3D(turn, turn * Vector3(sideways, radius - depth, 0.0)))
		_shared[key] = tool.commit()
	return _shared[key]


## Thin spokes from the hub to the rim, in one mesh.
static func _spokes(radius: float, width: float) -> Mesh:
	var key := "spokes %s %s" % [radius, width]
	if not _shared.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.012, radius * 0.9, 0.012)
		for i in 10:
			var turn := Basis(Vector3.RIGHT, TAU * i / 10.0)
			for side in [-1.0, 1.0]:
				tool.append_from(spoke, 0, Transform3D(turn, turn * Vector3(side * width * 0.3, radius * 0.5, 0.0)))
		_shared[key] = tool.commit()
	return _shared[key]


## An engine, built to fill its box with the look of its type (see "style" in
## parts.json). Made facing forward, on `holder`.
static func _engine(holder: Node3D, def: Dictionary, extent: Vector3) -> void:
	var colour: Color = def.color
	var h := extent * 0.5
	var metal := shiny(Color("#c8ccd0"))
	var add := func(mesh: Mesh, where: Vector3, look: Material, turn := Basis.IDENTITY) -> void:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = look
		node.transform = Transform3D(turn, where)
		holder.add_child(node)
	var box := func(size: Vector3) -> BoxMesh:
		var b := BoxMesh.new()
		b.size = size
		return b
	var tube := func(radius: float, length: float) -> CylinderMesh:
		var c := CylinderMesh.new()
		c.top_radius = radius
		c.bottom_radius = radius
		c.height = length
		c.radial_segments = 14
		return c
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	var across := Basis(Vector3.BACK, PI * 0.5)
	match def.get("style", "block"):
		"pedals":
			# No engine at all, just a low frame with a chainring on it and a
			# crank arm each side with a pedal on the end.
			var dark := material(Color("#3c3f44"))
			add.call(box.call(Vector3(extent.x * 0.5, extent.y * 0.25, extent.z * 0.9)), Vector3(0.0, -h.y + extent.y * 0.125, 0.0), material(colour))
			var middle := Vector3(0.0, -h.y + extent.y * 0.55, 0.0)
			var ring := minf(h.y, h.z) * 0.8
			add.call(tube.call(ring, 0.02), middle + Vector3(h.x * 0.3, 0.0, 0.0), metal, across)
			add.call(tube.call(0.02, extent.x * 0.9), middle, metal, across)
			for side in [-1.0, 1.0]:
				var arm := Vector3(side * h.x * 0.75, 0.0, 0.0)
				var tip := arm + Vector3(0.0, side * ring * 0.8, side * ring * 0.4)
				add.call(box.call(Vector3(0.02, ring * 0.9, 0.03)), middle + (arm + tip) * 0.5, metal, Basis(Vector3.RIGHT, side * 0.46))
				add.call(box.call(Vector3(h.x * 0.35, 0.02, 0.05)), middle + tip + Vector3(side * h.x * 0.15, 0.0, 0.0), dark)
		"electric", "jet":
			# A round can lying along the kart.
			var r := minf(h.x, h.y) * 0.95
			add.call(tube.call(r, extent.z * 0.85), Vector3(0.0, -h.y + r, 0.0), material(colour), along_z)
			if def.style == "electric":
				for i in 4:
					add.call(tube.call(r * 1.05, 0.03), Vector3(0.0, -h.y + r, lerpf(-h.z * 0.6, h.z * 0.6, i / 3.0)), metal, along_z)
				add.call(tube.call(r * 0.4, extent.z), Vector3(0.0, -h.y + r, 0.0), metal, along_z)
			else:
				# An intake ring at the front and a nozzle out of the back.
				add.call(tube.call(r * 1.08, 0.06), Vector3(0.0, -h.y + r, -h.z * 0.85), metal, along_z)
				var nozzle := CylinderMesh.new()
				nozzle.top_radius = r * 0.55
				nozzle.bottom_radius = r * 0.9
				nozzle.height = extent.z * 0.2
				nozzle.radial_segments = 14
				add.call(nozzle, Vector3(0.0, -h.y + r, h.z * 0.88), shiny(Color("#5a5d62")), along_z)
				add.call(tube.call(r * 0.5, 0.02), Vector3(0.0, -h.y + r, h.z * 0.99), material(Color("#ff8c1a")), along_z)
		_:
			var body_height := extent.y * (0.7 if def.style in ["twin", "v8"] else 0.82)
			add.call(box.call(Vector3(extent.x, body_height, extent.z) - Vector3.ONE * 0.004), Vector3(0.0, -h.y + body_height * 0.5, 0.0), material(colour))
			var top := -h.y + body_height
			var rest := extent.y - body_height
			match def.style:
				"twin":
					# Two finned cylinders in a V.
					for side in [-1.0, 1.0]:
						var tilt := Basis(Vector3.BACK, side * 0.45)
						add.call(tube.call(minf(h.x, h.z) * 0.45, rest * 1.3), Vector3(side * h.x * 0.35, top + rest * 0.45, 0.0), metal, tilt)
				"v8":
					# Two rows of four, with the intake between them.
					for side in [-1.0, 1.0]:
						for i in 4:
							add.call(tube.call(0.045, rest * 0.8), Vector3(side * h.x * 0.55, top + rest * 0.4, lerpf(-h.z * 0.7, h.z * 0.7, i / 3.0)), metal)
					add.call(box.call(Vector3(extent.x * 0.3, rest * 0.9, extent.z * 0.6)), Vector3(0.0, top + rest * 0.45, 0.0), shiny(Color("#f2f3f2")))
				_:
					# A cylinder head or two on top.
					var heads := 1 if def.style == "micro" else 2
					for i in heads:
						var z := 0.0 if heads == 1 else lerpf(-h.z * 0.4, h.z * 0.4, i)
						add.call(tube.call(minf(h.x, h.z) * 0.35, rest), Vector3(0.0, top + rest * 0.5, z), metal)
			# An exhaust out of the back, and a tall stack for the diesel.
			if def.style == "diesel":
				add.call(tube.call(0.035, extent.y * 0.9), Vector3(h.x * 0.7, extent.y * 0.1, h.z * 0.75), shiny(Color("#3c3f44")))
			else:
				add.call(tube.call(0.03, extent.z * 0.4), Vector3(h.x * 0.5, -h.y + body_height * 0.6, h.z), metal, along_z)


## The driver, sitting with their bottom at the origin and facing forward.
static func make_driver() -> Node3D:
	var driver := Node3D.new()
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
		mesh.material_override = material(Color(piece[2]))
		driver.add_child(mesh)
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.12
	head_mesh.bottom_radius = 0.12
	head_mesh.height = 0.22
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.6, 0.02)
	head.material_override = material(Color("#f2cd37"))
	driver.add_child(head)
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.15
	helmet_mesh.height = 0.2
	helmet_mesh.is_hemisphere = true
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 0.66, 0.02)
	helmet.material_override = material(Color("#ffffff"))
	driver.add_child(helmet)
	return driver


## Makes a part see-through, and red when it can't go where it is. It swaps the
## materials, since a tint drawn on top doesn't show on the phone.
static func set_ghost(node: Node, fits: bool) -> void:
	_tint(node, func(base: StandardMaterial3D) -> StandardMaterial3D:
		return _variant(base.albedo_color if fits else Color("#ff2a1a"), 0.55))


## Lightens a part to show it's the one picked out.
static func set_highlight(node: Node, on: bool) -> void:
	if not on:
		_tint(node, Callable())
		return
	_tint(node, func(base: StandardMaterial3D) -> StandardMaterial3D:
		return _variant(base.albedo_color.lightened(0.45), 1.0))


## Runs every mesh in a part through `change`, starting from the material it
## was made with each time. An empty Callable puts the originals back.
static func _tint(node: Node, change: Callable) -> void:
	for child in node.get_children():
		if child is GeometryInstance3D and child.material_override is StandardMaterial3D:
			if not child.has_meta("base_material"):
				child.set_meta("base_material", child.material_override)
			var base: StandardMaterial3D = child.get_meta("base_material")
			child.material_override = base if change.is_null() else change.call(base)
		_tint(child, change)


static var _variants: Dictionary = {}

static func _variant(color: Color, alpha: float) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), alpha]
	if not _variants.has(key):
		var m := material(color).duplicate() as StandardMaterial3D
		m.albedo_color = Color(color, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_variants[key] = m
	return _variants[key]


## A metal finish, for exhausts, spokes and the like.
static func shiny(color: Color) -> StandardMaterial3D:
	var key := "shiny " + color.to_html()
	if not _materials.has(key):
		var m := material(color).duplicate() as StandardMaterial3D
		m.metallic = 0.7
		m.roughness = 0.3
		_materials[key] = m
	return _materials[key]


## See-through tinted plastic, for windscreens.
static func glass(color: Color) -> StandardMaterial3D:
	var key := "glass " + color.to_html()
	if not _materials.has(key):
		var m := material(color).duplicate() as StandardMaterial3D
		m.albedo_color = Color(color, 0.4)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = m
	return _materials[key]


static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		# Plastic has a soft sheen, since glossier flat tops look pale blue
		# under the sky.
		m.roughness = 0.55
		m.metallic_specular = 0.35
		_materials[key] = m
	return _materials[key]


static func _stud() -> CylinderMesh:
	if _stud_mesh == null:
		_stud_mesh = CylinderMesh.new()
		_stud_mesh.top_radius = STUD_RADIUS
		_stud_mesh.bottom_radius = STUD_RADIUS
		_stud_mesh.height = STUD_HEIGHT
		_stud_mesh.radial_segments = 10
		_stud_mesh.rings = 1
	return _stud_mesh
