class_name NeckLooks
extends RefCounted

## What's around the neck, like scarves, ties, necklaces and collars, in the
## neck piece's colour. There's only a little room between the torso and the
## head, so collars are flattened rings and anything bigger hangs on the front
## of the chest.

const WHITE := Color("#f2f2f2")
const GOLD := Color("#c9a227")
const SILVER := Color("#c8ccd0")
const COLLAR_Y := 0.432


static func build(rig: CharacterRig) -> void:
	var d := rig.design
	var c := d.color_of("neck")
	var up := rig.upper()
	var R := CharacterRig
	var chest := -R.TORSO_DEPTH * 0.5
	var flat := Basis.from_scale(Vector3(1.0, 0.5, 1.0))
	# A ring around the neck, sitting on the shoulders.
	var collar := func(inner: float, outer: float, colour: Color, height := COLLAR_Y, metallic := 0.0) -> void:
		rig.add(up, rig.ring(inner, outer), colour, Vector3(0.0, height, 0.0), flat, metallic)
	# A cord from each side of the collar down to a point on the chest.
	var cord := func(bottom: float, colour: Color, width := 0.008) -> void:
		for s: float in [-1.0, 1.0]:
			var from := Vector3(0.06 * s, 0.415, chest - 0.003)
			var to := Vector3(0.0, bottom, chest - 0.003)
			var middle := (from + to) * 0.5
			rig.add(up, rig.box(Vector3(width, from.distance_to(to), 0.005), 0.002), colour, middle, Basis(Vector3.BACK, atan2(to.x - from.x, from.y - to.y)))
	# A string of beads around the neck and down the front in a V.
	var beads := func(colours: Array, size: float, count: int) -> void:
		for k in count:
			var t := float(k) / count
			var a := TAU * t
			var at := Vector3(sin(a) * 0.085, COLLAR_Y, cos(a) * 0.085)
			if cos(a) < -0.2:
				# The front ones hang down the chest.
				var dip := (-0.2 - cos(a)) / 0.8
				at = Vector3(sin(a) * 0.085 * (1.0 - dip * 0.5), COLLAR_Y - 0.015 - dip * 0.06, chest - size * 0.8)
			rig.add(up, rig.sphere(size), colours[k % colours.size()], at)
	match d.style_of("neck"):
		"scarf":
			collar.call(0.05, 0.105, c)
			rig.add(up, rig.box(Vector3(0.05, 0.13, 0.02), 0.01), c, Vector3(0.06, 0.36, chest - 0.012), Basis(Vector3.BACK, 0.12))
			rig.print_on(up, Vector2(0.05, 0.012), c.darkened(0.3), Vector3(0.068, 0.31, chest - 0.023), Basis(Vector3.BACK, 0.12))
		"long_scarf":
			collar.call(0.05, 0.105, c)
			rig.add(up, rig.box(Vector3(0.05, 0.13, 0.02), 0.01), c, Vector3(0.06, 0.36, chest - 0.012), Basis(Vector3.BACK, 0.12))
			rig.add(up, rig.box(Vector3(0.055, 0.26, 0.02), 0.01), c, Vector3(-0.05, 0.34, -chest + 0.06), Basis(Vector3.RIGHT, -0.45))
		"tie":
			rig.add(up, rig.box(Vector3(0.036, 0.028, 0.016), 0.006), c, Vector3(0.0, 0.405, chest - 0.008))
			rig.add(up, rig.box(Vector3(0.042, 0.17, 0.008), 0.004), c, Vector3(0.0, 0.31, chest - 0.004))
			rig.add(up, rig.box(Vector3(0.03, 0.03, 0.008), 0.004), c, Vector3(0.0, 0.228, chest - 0.004), Basis(Vector3.BACK, PI * 0.25))
		"bow_tie":
			for s: float in [-1.0, 1.0]:
				rig.add(up, rig.box(Vector3(0.04, 0.035, 0.016), 0.008), c, Vector3(0.024 * s, 0.405, chest - 0.01), Basis(Vector3.BACK, 0.25 * s))
			rig.add(up, rig.box(Vector3(0.016, 0.02, 0.02), 0.006), c.darkened(0.3), Vector3(0.0, 0.405, chest - 0.012))
		"neckerchief":
			collar.call(0.05, 0.075, c)
			rig.add(up, rig.box(Vector3(0.075, 0.075, 0.008), 0.004), c, Vector3(0.0, 0.37, chest - 0.004), Basis(Vector3.BACK, PI * 0.25))
			rig.add(up, rig.sphere(0.014), c.darkened(0.2), Vector3(0.0, 0.405, chest - 0.012))
		"medal":
			cord.call(0.33, c, 0.016)
			rig.add(up, rig.cylinder(0.03, 0.03, 0.008, 18), GOLD, Vector3(0.0, 0.31, chest - 0.008), Basis(Vector3.RIGHT, PI * 0.5), 0.6)
		"beads":
			beads.call([c, c.lightened(0.4)], 0.013, 18)
		"pearls":
			beads.call([WHITE], 0.01, 22)
		"spiked_collar":
			collar.call(0.05, 0.085, c)
			for k in 8:
				var a := TAU * k / 8.0
				var out := Vector3(sin(a), 0.0, cos(a))
				rig.add(up, rig.cylinder(0.0, 0.012, 0.03, 8), SILVER, Vector3(0.0, COLLAR_Y, 0.0) + out * 0.09, CharacterRig.pointing(out), 0.6)
		"ruff":
			for k in 3:
				collar.call(0.05, 0.1 + k * 0.015, WHITE, COLLAR_Y - 0.004 + k * 0.004)
		"whistle":
			cord.call(0.33, c)
			rig.add(up, rig.cylinder(0.012, 0.012, 0.04, 12), SILVER, Vector3(0.0, 0.31, chest - 0.014), Basis(Vector3.BACK, PI * 0.5), 0.6)
		"pass":
			cord.call(0.34, c)
			rig.add(up, rig.box(Vector3(0.06, 0.08, 0.006), 0.004), WHITE, Vector3(0.0, 0.3, chest - 0.004))
			rig.print_on(up, Vector2(0.06, 0.018), c, Vector3(0.0, 0.325, chest - 0.009))
		"gold_chain":
			collar.call(0.066, 0.078, c, COLLAR_Y, 0.6)
			cord.call(0.35, c, 0.006)
			rig.add(up, rig.sphere(0.018), c, Vector3(0.0, 0.345, chest - 0.012), Basis.IDENTITY, 0.6)
		"brooch":
			rig.add(up, rig.cylinder(0.022, 0.022, 0.008, 16), GOLD, Vector3(0.0, 0.385, chest - 0.006), Basis(Vector3.RIGHT, PI * 0.5), 0.6)
			rig.add(up, rig.sphere(0.015, 0.02), c, Vector3(0.0, 0.385, chest - 0.013))
		"lei":
			var flowers := [c, Color("#f2cd37"), WHITE, Color("#d86cb0")]
			for k in 14:
				var a := TAU * k / 14.0
				var at := Vector3(sin(a) * 0.115, COLLAR_Y - 0.005, cos(a) * 0.115)
				rig.add(up, rig.sphere(0.022, 0.025), flowers[k % flowers.size()], at)
		"headphones":
			rig.add(up, MeshKit.arc_tube(0.075, 0.008, 0.0, PI), Color("#3c3f44"), Vector3(0.0, 0.438, 0.0), Basis(Vector3.RIGHT, PI * 0.5))
			for s: float in [-1.0, 1.0]:
				rig.add(up, rig.cylinder(0.025, 0.025, 0.022, 16), c, Vector3(0.075 * s, 0.438, -0.03), Basis(Vector3.BACK, PI * 0.5))
		"choker":
			collar.call(0.052, 0.064, c, 0.44)
			rig.add(up, rig.sphere(0.01), Color("#3a8dde"), Vector3(0.0, 0.44, -0.062))
		"bell":
			collar.call(0.05, 0.075, c)
			rig.add(up, rig.sphere(0.026), GOLD, Vector3(0.0, 0.405, chest - 0.022), Basis.IDENTITY, 0.6)
		"big_bow":
			for s: float in [-1.0, 1.0]:
				rig.add(up, rig.sphere(0.045, 0.06), c, Vector3(0.045 * s, 0.395, chest - 0.02), Basis.from_scale(Vector3(1.0, 1.0, 0.5)) * Basis(Vector3.BACK, 0.3 * s))
			rig.add(up, rig.sphere(0.02), c.darkened(0.25), Vector3(0.0, 0.395, chest - 0.02))
