class_name HeadgearLooks
extends RefCounted

## Hats, helmets and the like, in the headgear's colour. Most of them cover
## the top of the head, and the hair under them keeps only what hangs below
## (see HairLooks). A few (a crown, a tiara, a party hat, horns, a headband)
## sit on top of the hair instead, sized to fit around it.

const WHITE := Color("#f2f2f2")
const GOLD := Color("#c9a227")
const IVORY := Color("#efe6c8")
const JEWEL := Color("#c4281c")


## Whether this headgear covers the top of the head, hiding the top of the
## hair.
static func covers_top(style: String) -> bool:
	return bool(CharacterDesign.piece("headgear", style).get("covers", true))


static func build(rig: CharacterRig) -> void:
	var d := rig.design
	var c := d.color_of("headgear")
	var head := rig.head()
	var R := CharacterRig
	var r := R.HEAD_RADIUS
	var top := R.HEAD_HEIGHT * 0.5
	var hair := d.style_of("hair")
	match d.style_of("headgear"):
		"racing_helmet":
			rig.shell(c, 0.022, deg_to_rad(62.0), deg_to_rad(298.0), -0.075)
			# A strap under the chin, and a clear visor pushed up on the brow.
			rig.add(head, MeshKit.arc_tube(r + 0.004, 0.006, deg_to_rad(205.0), deg_to_rad(335.0)), Color("#1b1b1b"), Vector3(0.0, 0.0, -0.04))
			rig.add(head, MeshKit.rounded_box(Vector3(0.22, 0.035, 0.03), 0.012), Color(Color("#8fd3f4"), 0.65), Vector3(0.0, 0.085, -CharacterRig.shell_radius(0.022, 0.085) - 0.016), Basis(Vector3.RIGHT, -0.3), 0.3)
		"open_helmet":
			rig.shell(c, 0.022, 0.0, 0.0, 0.05)
			rig.goggles(0.07, CharacterRig.shell_radius(0.022, 0.07))
		"cap":
			rig.add(head, rig.sphere(r + 0.008, 0.1), c, Vector3(0.0, top - 0.005, 0.0))
			rig.add(head, MeshKit.rounded_box(Vector3(0.17, 0.012, 0.1), 0.005), c, Vector3(0.0, top - 0.012, -r - 0.03))
			rig.add(head, rig.sphere(0.012), c.darkened(0.3), Vector3(0.0, top + 0.045, 0.0))
			# A blank round badge on the front, for a letter you imagine.
			rig.add(head, rig.cylinder(0.022, 0.022, 0.006, 16), WHITE, Vector3(0.0, top + 0.012, -r + 0.004), Basis(Vector3.RIGHT, PI * 0.5 - 0.5))
		"beanie":
			rig.add(head, rig.sphere(r + 0.01, 0.16), c, Vector3(0.0, top - 0.015, 0.0))
			rig.add(head, rig.ring(r - 0.004, r + 0.026), c.darkened(0.2), Vector3(0.0, top - 0.045, 0.0))
			rig.add(head, rig.sphere(0.035), WHITE, Vector3(0.0, top + 0.08, 0.0))
		"hard_hat":
			rig.add(head, rig.sphere(r + 0.018, 0.14), c, Vector3(0.0, top, 0.0))
			rig.add(head, MeshKit.rounded_cylinder(r + 0.05, 0.014, 0.006, 32), c, Vector3(0.0, top - 0.025, -0.01))
			rig.add(head, MeshKit.rounded_box(Vector3(0.028, 0.04, 0.14), 0.012), c.lightened(0.2), Vector3(0.0, top + 0.06, 0.0))
		"headband":
			var band := HairLooks.radius_at(hair, 0.06) + 0.004
			rig.add(head, rig.ring(band - 0.006, band + 0.012), c, Vector3(0.0, 0.06, 0.0))
			rig.goggles(0.07, band + 0.012)
		"top_hat":
			# It fits down over the top of the head, like a minifig's, with the
			# brim at the brow.
			var brim := top - 0.045
			rig.add(head, MeshKit.rounded_cylinder(r + 0.05, 0.014, 0.006, 32), c, Vector3(0.0, brim, 0.0))
			rig.add(head, MeshKit.rounded_cylinder(r + 0.012, 0.2, 0.01, 32), c, Vector3(0.0, brim + 0.1, 0.0))
			rig.add(head, rig.cylinder(r + 0.014, r + 0.014, 0.03, 32), JEWEL, Vector3(0.0, brim + 0.022, 0.0))
		"crown":
			# A band with points, sitting around the hair (or the head).
			var base := 0.07
			var around := HairLooks.radius_at(hair, base) + 0.004
			var band := PackedVector2Array([Vector2(around, base), Vector2(around + 0.004, base + 0.05)])
			_two_sided(rig.add(head, MeshKit.lathe(band, 36), c, Vector3.ZERO, Basis.IDENTITY, 0.6))
			for k in 5:
				var a := TAU * k / 5.0
				var at := Vector3(sin(a) * (around + 0.002), base + 0.07, -cos(a) * (around + 0.002))
				rig.add(head, rig.cylinder(0.0, 0.022, 0.045, 8), c, at, Basis.IDENTITY, 0.6)
				rig.add(head, rig.sphere(0.011), JEWEL, Vector3(sin(a) * (around + 0.006), base + 0.025, -cos(a) * (around + 0.006)))
		"tiara":
			var base := 0.06
			var around := HairLooks.radius_at(hair, base) + 0.004
			var band := PackedVector2Array([Vector2(around, base), Vector2(around + 0.002, base + 0.022)])
			_two_sided(rig.add(head, MeshKit.lathe(band, 24, deg_to_rad(-70.0), deg_to_rad(70.0)), c, Vector3.ZERO, Basis.IDENTITY, 0.6))
			rig.add(head, rig.cylinder(0.0, 0.02, 0.05, 8), c, Vector3(0.0, base + 0.045, -around - 0.002), Basis.IDENTITY, 0.6)
			rig.add(head, rig.sphere(0.013), Color("#3a8dde"), Vector3(0.0, base + 0.02, -around - 0.008))
			for s: float in [-1.0, 1.0]:
				var a := 0.5 * s
				rig.add(head, rig.cylinder(0.0, 0.012, 0.03, 8), c, Vector3(sin(a) * around, base + 0.035, -cos(a) * around), Basis.IDENTITY, 0.6)
		"mushroom":
			# A big spotted dome. Its edge comes out of the head just above the
			# eyes.
			var middle := Vector3(0.0, 0.13, 0.0)
			rig.add(head, rig.sphere(0.2, 0.2), c, middle)
			var spots := [[0.0, 0.0], [0.9, 0.3], [0.9, 2.4], [0.9, 4.0], [0.95, 5.3], [0.55, 1.2], [0.55, 3.3]]
			for spot in spots:
				var tilt: float = spot[0]
				var around: float = spot[1]
				var normal := Vector3(sin(tilt) * sin(around) / 0.2, cos(tilt) / 0.1, -sin(tilt) * cos(around) / 0.2).normalized()
				var at := middle + Vector3(sin(tilt) * sin(around) * 0.2, cos(tilt) * 0.1, -sin(tilt) * cos(around) * 0.2)
				rig.add(head, rig.sphere(0.042, 0.02), WHITE, at, CharacterRig.pointing(normal))
		"dino_hood":
			rig.shell(c, 0.025, deg_to_rad(50.0), deg_to_rad(310.0), -0.08)
			for k in 3:
				var a := 0.4 + k * 0.45
				var at := Vector3(0.0, 0.045 + 0.13 * cos(a), 0.145 * sin(a))
				rig.add(head, rig.cylinder(0.0, 0.03, 0.06, 8), c.darkened(0.3), at, CharacterRig.pointing(Vector3(0.0, cos(a), sin(a))))
			for s: float in [-1.0, 1.0]:
				var eye := Vector3(0.055 * s, top + 0.045, -0.075)
				rig.add(head, rig.sphere(0.03), WHITE, eye)
				rig.add(head, rig.sphere(0.013), Color("#1b1b1b"), eye + Vector3(0.0, 0.004, -0.022))
		"cowboy":
			rig.add(head, MeshKit.rounded_cylinder(r + 0.09, 0.012, 0.006, 36), c, Vector3(0.0, 0.07, 0.0))
			rig.add(head, MeshKit.rounded_cylinder(r + 0.012, 0.1, 0.02, 32), c, Vector3(0.0, 0.115, 0.0))
			rig.add(head, rig.cylinder(r + 0.014, r + 0.014, 0.02, 32), c.darkened(0.45), Vector3(0.0, 0.088, 0.0))
		"viking":
			rig.add(head, rig.sphere(r + 0.018, 0.14), c, Vector3(0.0, top, 0.0), Basis.IDENTITY, 0.5)
			rig.add(head, rig.ring(r + 0.004, r + 0.03), c.darkened(0.2), Vector3(0.0, top - 0.035, 0.0), Basis.IDENTITY, 0.5)
			for s: float in [-1.0, 1.0]:
				_horn(rig, Vector3((r + 0.005) * s, top + 0.0, 0.0), s, IVORY, 0.03)
		"pirate":
			rig.add(head, MeshKit.rounded_cylinder(r + 0.012, 0.07, 0.012, 32), c, Vector3(0.0, top - 0.005, 0.0))
			for k in 3:
				var a := TAU * k / 3.0
				var flap := rig.add(head, MeshKit.rounded_box(Vector3(0.2, 0.075, 0.014), 0.006), c, Vector3(sin(a) * (r + 0.02), top + 0.01, -cos(a) * (r + 0.02)))
				flap.basis = Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.35)
			rig.add(head, rig.cylinder(0.018, 0.018, 0.006, 14), WHITE, Vector3(0.0, top + 0.015, -r - 0.045), Basis(Vector3.RIGHT, PI * 0.5 - 0.35))
		"wizard":
			rig.add(head, MeshKit.rounded_cylinder(r + 0.07, 0.012, 0.006, 36), c, Vector3(0.0, 0.06, 0.0))
			rig.add(head, rig.cylinder(0.0, r + 0.012, 0.3, 28), c, Vector3(0.0, 0.21, 0.0))
			rig.add(head, rig.cylinder(r + 0.004, r + 0.01, 0.022, 28), GOLD, Vector3(0.0, 0.08, 0.0))
		"bandana":
			rig.shell(c, 0.008, 0.0, TAU, 0.04)
			for s: float in [-1.0, 1.0]:
				rig.add(head, rig.sphere(0.026, 0.06), c, Vector3(0.025 * s, 0.03, r + 0.02), Basis(Vector3.BACK, 0.5 * s))
		"aviator":
			rig.shell(c, 0.018, deg_to_rad(50.0), deg_to_rad(310.0), -0.06)
			for s: float in [-1.0, 1.0]:
				rig.add(head, rig.box(Vector3(0.02, 0.07, 0.06), 0.01), c, Vector3((r + 0.025) * s, -0.05, 0.0))
			rig.goggles(0.085, CharacterRig.shell_radius(0.018, 0.085))
		"propeller":
			rig.add(head, rig.sphere(r + 0.01, 0.16), c, Vector3(0.0, top - 0.015, 0.0))
			rig.add(head, rig.cylinder(0.008, 0.008, 0.04, 8), Color("#9aa0a6"), Vector3(0.0, top + 0.08, 0.0), Basis.IDENTITY, 0.5)
			for s: float in [-1.0, 1.0]:
				rig.add(head, rig.box(Vector3(0.1, 0.006, 0.025), 0.003), [Color("#c4281c"), Color("#f2cd37")][int(s > 0.0)], Vector3(0.05 * s, top + 0.1, 0.0), Basis(Vector3.RIGHT, 0.3 * s))
		"party":
			var base := HairLooks.top_of(hair) - 0.02
			var cone := rig.add(head, rig.cylinder(0.004, 0.06, 0.16, 20), c, Vector3(0.02, base + 0.08, 0.0))
			cone.basis = Basis(Vector3.BACK, -0.15)
			rig.add(head, rig.sphere(0.022), WHITE, Vector3(0.032, base + 0.165, 0.0))
			rig.add(head, rig.cylinder(0.035, 0.045, 0.018, 20), WHITE, Vector3(0.015, base + 0.05, 0.0), Basis(Vector3.BACK, -0.15))
		"beret":
			rig.add(head, rig.sphere(0.14, 0.08), c, Vector3(0.02, top, 0.0), Basis(Vector3.BACK, -0.2))
			rig.add(head, rig.cylinder(0.006, 0.006, 0.025, 8), c.darkened(0.3), Vector3(0.032, top + 0.048, 0.0))
		"horns":
			for s: float in [-1.0, 1.0]:
				var root := Vector3((HairLooks.radius_at(hair, 0.06) - 0.01) * s, 0.06, 0.0)
				_horn(rig, root, s, c, 0.028)


## Shows both sides of a thin band, on its own copy of the material.
static func _two_sided(node: MeshInstance3D) -> void:
	var material := node.material_override.duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material


## A curved horn from `root`, sweeping out to the side (`s` is -1 for left)
## and then up, made of tapering pieces.
static func _horn(rig: CharacterRig, root: Vector3, s: float, colour: Color, thick: float) -> void:
	var at := root
	var directions := [Vector3(s, 0.35, 0.0), Vector3(s * 0.7, 0.8, 0.0), Vector3(s * 0.2, 1.0, 0.0)]
	for k in directions.size():
		var dir: Vector3 = directions[k].normalized()
		var length := 0.045 - k * 0.005
		var top_r := thick * (1.0 - (k + 1) / 3.2)
		var bottom_r := thick * (1.0 - k / 3.2)
		rig.add(rig.head(), rig.cylinder(top_r, bottom_r, length, 10), colour, at + dir * length * 0.5, CharacterRig.pointing(dir))
		at += dir * length * 0.9
