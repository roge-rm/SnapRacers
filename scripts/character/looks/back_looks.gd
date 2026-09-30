class_name BackLooks
extends RefCounted

## What's worn on the back, like shells, capes, packs, wings, tails and gear,
## in the back piece's colour. Everything comes out from the flat back of the
## torso, and some pieces have straps over the shoulders.

const WHITE := Color("#f2f2f2")
const DARK := Color("#3c3f44")
const SILVER := Color("#c8ccd0")
const GOLD := Color("#c9a227")


static func build(rig: CharacterRig) -> void:
	var d := rig.design
	var c := d.color_of("back")
	var up := rig.upper()
	var R := CharacterRig
	var back := R.TORSO_DEPTH * 0.5
	var y := R.TORSO_Y
	# Straps over the shoulders and down the front of the chest.
	var straps := func(colour: Color) -> void:
		for s: float in [-1.0, 1.0]:
			rig.add(up, rig.box(Vector3(0.032, 0.012, R.TORSO_DEPTH + 0.01), 0.004), colour, Vector3(0.085 * s, R.HIPS_TOP + R.TORSO_HEIGHT + 0.004, 0.0))
			rig.print_on(up, Vector2(0.032, 0.16), colour, Vector3(0.085 * s, R.HIPS_TOP + R.TORSO_HEIGHT - 0.08, -back - 0.002))
	match d.style_of("back"):
		"spiky_shell", "shell":
			# A domed shell, with a pale rim where it meets the back.
			var middle := Vector3(0.0, y + 0.01, back)
			rig.add(up, rig.sphere(0.18, 0.3), c, middle, Basis.from_scale(Vector3(1.0, 1.0, 0.55)))
			rig.add(up, rig.ring(0.165, 0.195), WHITE.darkened(0.05), middle + Vector3(0.0, 0.0, 0.002), Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.83)))
			if d.style_of("back") == "spiky_shell":
				for k in 7:
					var a := TAU * k / 7.0
					var dir := Vector3(cos(a) * 0.55, sin(a) * 0.75, 0.6).normalized() if k > 0 else Vector3.BACK
					var at := middle + Vector3(cos(a) * 0.09, sin(a) * 0.12, 0.08) if k > 0 else middle + Vector3(0.0, 0.0, 0.1)
					rig.add(up, rig.cylinder(0.0, 0.026, 0.06, 10), WHITE, at + dir * 0.02, CharacterRig.pointing(dir))
			else:
				for k in 3:
					rig.print_on(up, Vector2(0.004, 0.14), c.darkened(0.3), middle + Vector3(-0.05 + k * 0.05, 0.0, 0.1), Basis(Vector3.UP, PI))
		"cape", "short_cape":
			var long := d.style_of("back") == "cape"
			var height := 0.33 if long else 0.2
			var top := R.HIPS_TOP + R.TORSO_HEIGHT
			rig.add(up, rig.box(Vector3(0.37, height, 0.012), 0.005), c, Vector3(0.0, top - height * 0.5, back + 0.014), Basis(Vector3.RIGHT, -0.06))
			rig.add(up, rig.box(Vector3(0.3, 0.02, 0.2), 0.008), c, Vector3(0.0, top + 0.006, 0.0))
			rig.add(up, rig.sphere(0.014), GOLD, Vector3(0.0, top - 0.005, -back - 0.012))
		"backpack":
			rig.add(up, rig.box(Vector3(0.24, 0.24, 0.1), 0.03), c, Vector3(0.0, y + 0.01, back + 0.05))
			rig.add(up, rig.box(Vector3(0.2, 0.08, 0.02), 0.01), c.darkened(0.25), Vector3(0.0, y + 0.1, back + 0.105), Basis(Vector3.RIGHT, 0.15))
			rig.add(up, rig.box(Vector3(0.16, 0.08, 0.02), 0.01), c.lightened(0.15), Vector3(0.0, y - 0.06, back + 0.105))
			straps.call(c.darkened(0.35))
		"jet_pack":
			rig.add(up, rig.box(Vector3(0.2, 0.2, 0.03), 0.01), DARK, Vector3(0.0, y + 0.02, back + 0.015), Basis.IDENTITY, 0.4)
			for s: float in [-1.0, 1.0]:
				rig.add(up, rig.cylinder(0.045, 0.045, 0.22, 16), c, Vector3(0.055 * s, y + 0.02, back + 0.075), Basis.IDENTITY, 0.4)
				rig.add(up, rig.sphere(0.045, 0.05), c, Vector3(0.055 * s, y + 0.13, back + 0.075), Basis.IDENTITY, 0.4)
				rig.add(up, rig.cylinder(0.03, 0.042, 0.04, 16), SILVER, Vector3(0.055 * s, y - 0.11, back + 0.075), Basis.IDENTITY, 0.6)
			straps.call(DARK)
		"angel_wings":
			for s: float in [-1.0, 1.0]:
				for k in 3:
					var reach := 0.24 - k * 0.05
					var feather := rig.add(up, rig.sphere(reach * 0.5, 0.05), [c, c.darkened(0.08), c.darkened(0.16)][k], Vector3(s * (0.07 + reach * 0.4), y + 0.08 - k * 0.04, back + 0.03 + k * 0.004))
					feather.basis = Basis(Vector3.BACK, s * (0.5 + k * 0.25)) * Basis.from_scale(Vector3(1.0, 1.0, 0.3))
		"bat_wings":
			var outline := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.17, 0.13), Vector2(0.28, 0.03), Vector2(0.24, -0.03), Vector2(0.18, 0.015), Vector2(0.14, -0.055), Vector2(0.085, -0.015), Vector2(0.04, -0.07)])
			var wing := BrickShapes.extrude(outline, 0.01)
			for s: float in [-1.0, 1.0]:
				# The outline's drawn across, so turn it to spread out sideways.
				_two_sided(rig.add(up, wing, c, Vector3(0.04 * s, y + 0.06, back + 0.006), Basis(Vector3.UP, PI * 0.5 * s)))
		"fairy_wings":
			var glass := Color(c, 0.55)
			for s: float in [-1.0, 1.0]:
				rig.add(up, rig.sphere(0.09, 0.012), glass, Vector3(0.09 * s, y + 0.1, back + 0.006), Basis(Vector3.BACK, 0.5 * s) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.55)))
				rig.add(up, rig.sphere(0.065, 0.012), glass, Vector3(0.08 * s, y - 0.03, back + 0.006), Basis(Vector3.BACK, -0.4 * s) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.6)))
		"dino_tail":
			var dir := Vector3(0.0, -0.3, 1.0).normalized()
			var root := Vector3(0.0, R.HIPS_TOP + 0.06, back - 0.02)
			rig.add(up, rig.cylinder(0.015, 0.07, 0.34, 16), c, root + dir * 0.17, CharacterRig.pointing(dir))
			for k in 3:
				var at := root + dir * (0.06 + k * 0.09) + Vector3(0.0, 0.065 - k * 0.017, 0.0)
				rig.add(up, rig.cylinder(0.0, 0.02, 0.04, 8), c.darkened(0.3), at, Basis.IDENTITY)
		"flag":
			var pole := Vector3(0.1, y + 0.22, back + 0.012)
			rig.add(up, rig.cylinder(0.01, 0.01, 0.5, 8), SILVER, pole, Basis.IDENTITY, 0.5)
			for i in 5:
				for j in 4:
					rig.add(up, rig.box(Vector3(0.006, 0.042, 0.042), 0.001), c if (i + j) % 2 == 0 else WHITE, pole + Vector3(0.0, 0.2 - j * 0.042, 0.03 + i * 0.042))
		"sword":
			var turn := Basis(Vector3.BACK, 0.6)
			rig.add(up, rig.box(Vector3(0.05, 0.3, 0.03), 0.01), c, Vector3(0.0, y, back + 0.02), turn)
			var hilt := Vector3(-sin(0.6) * 0.18, y + cos(0.6) * 0.18, back + 0.02)
			rig.add(up, rig.box(Vector3(0.1, 0.018, 0.022), 0.006), GOLD, hilt, turn, 0.5)
			rig.add(up, rig.cylinder(0.012, 0.012, 0.06, 8), DARK, hilt + turn.y * 0.035, turn)
		"guitar":
			var turn := Basis(Vector3.BACK, -0.5)
			rig.add(up, rig.sphere(0.1, 0.035), c, Vector3(0.04, y - 0.05, back + 0.018), turn * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 1.25)))
			rig.add(up, rig.box(Vector3(0.025, 0.26, 0.018), 0.005), Color("#6b4430"), Vector3(-0.05, y + 0.11, back + 0.012), turn)
			straps.call(DARK)
		"air_tanks":
			for s: float in [-1.0, 1.0]:
				rig.add(up, rig.cylinder(0.05, 0.05, 0.26, 16), c, Vector3(0.055 * s, y, back + 0.05), Basis.IDENTITY, 0.3)
				rig.add(up, rig.sphere(0.05, 0.06), c, Vector3(0.055 * s, y + 0.13, back + 0.05), Basis.IDENTITY, 0.3)
			rig.add(up, rig.cylinder(0.012, 0.012, 0.03, 8), SILVER, Vector3(0.0, y + 0.17, back + 0.05), Basis.IDENTITY, 0.6)
			straps.call(DARK)
		"parachute":
			rig.add(up, rig.box(Vector3(0.26, 0.24, 0.08), 0.03), c, Vector3(0.0, y + 0.01, back + 0.04))
			rig.print_on(up, Vector2(0.2, 0.006), c.darkened(0.3), Vector3(0.0, y + 0.01, back + 0.081), Basis(Vector3.UP, PI))
			straps.call(c.darkened(0.35))
			rig.add(up, rig.ring(0.012, 0.02), SILVER, Vector3(0.085, R.HIPS_TOP + R.TORSO_HEIGHT - 0.13, -back - 0.008), Basis(Vector3.RIGHT, PI * 0.5), 0.6)
		"quiver":
			var turn := Basis(Vector3.BACK, 0.4)
			rig.add(up, rig.cylinder(0.045, 0.045, 0.28, 14), c, Vector3(0.0, y + 0.02, back + 0.05), turn)
			for k in 3:
				rig.add(up, rig.box(Vector3(0.012, 0.05, 0.03), 0.004), WHITE, Vector3(-sin(0.4) * 0.17 - 0.015 + k * 0.015, y + 0.02 + cos(0.4) * 0.17, back + 0.05), turn)
		"radio":
			rig.add(up, rig.box(Vector3(0.2, 0.22, 0.09), 0.02), c, Vector3(0.0, y, back + 0.045))
			rig.add(up, rig.cylinder(0.005, 0.005, 0.3, 6), DARK, Vector3(0.07, y + 0.26, back + 0.05))
			rig.add(up, rig.cylinder(0.02, 0.02, 0.012, 12), SILVER, Vector3(-0.05, y + 0.05, back + 0.095), Basis(Vector3.RIGHT, PI * 0.5), 0.6)
			straps.call(DARK)
		"fox_tail":
			var dir := Vector3(0.3, 0.5, 1.0).normalized()
			var root := Vector3(0.0, R.HIPS_TOP + 0.05, back)
			for k in 3:
				var size := 0.045 + k * 0.012
				rig.add(up, rig.sphere(size, size * 2.6), c if k < 2 else WHITE, root + dir * (0.05 + k * 0.08), CharacterRig.pointing(dir))
		"shield":
			rig.add(up, rig.cylinder(0.15, 0.15, 0.025, 28), c, Vector3(0.0, y, back + 0.015), Basis(Vector3.RIGHT, PI * 0.5), 0.2)
			rig.add(up, rig.ring(0.14, 0.16), SILVER, Vector3(0.0, y, back + 0.03), Basis(Vector3.RIGHT, PI * 0.5), 0.6)
			rig.add(up, rig.sphere(0.035, 0.04), SILVER, Vector3(0.0, y, back + 0.03), Basis(Vector3.RIGHT, PI * 0.5), 0.6)


static func _two_sided(node: MeshInstance3D) -> void:
	var material := node.material_override.duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
