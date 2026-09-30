class_name HairLooks
extends RefCounted

## Hair, in its own colour. Most hair is a dome over the top of the head and a
## band down around the back and sides, like a minifig's hair piece, with
## extras like spikes, buns and tails.
##
## Under a hat that covers the top of the head, only the band below the hat's
## edge and anything like a tail shows, so hair never pokes through a hat.
##
## Long and braided beards hang below the chin, and they're made here too in
## the facial hair's colour. The rest of any facial hair is printed on the face
## (see FacePrint).

## How far out from the head each style's dome is, or -1 for none.
const DOMES := {
	"short": 0.012, "spiky": 0.008, "flat_top": 0.012, "quiff": 0.012,
	"side_part": 0.012, "bob": 0.014, "long": 0.014, "wavy": 0.014,
	"ponytail": 0.014, "pigtails": 0.014, "bun": 0.012, "afro": 0.045,
	"curly": 0.014, "bowl": 0.014, "princess": 0.016, "messy": 0.012,
	"braids": 0.014, "fringe": 0.012,
}
## Under a hat, the band only comes up this far, below the hat's edge.
const UNDER_HAT := 0.06


static func dome_of(style: String) -> float:
	return DOMES.get(style, -1.0)


## How far out from the middle of the head the hair (or the head) is at this
## height, for putting something like a crown or a band around it.
static func radius_at(style: String, height: float) -> float:
	var R := CharacterRig
	var head := R.HEAD_RADIUS
	if height > R.HEAD_HEIGHT * 0.5 - 0.035:
		var over := height - (R.HEAD_HEIGHT * 0.5 - 0.035)
		head = R.HEAD_RADIUS - 0.035 + sqrt(maxf(0.035 * 0.035 - over * over, 0.0))
	var dome := dome_of(style)
	if dome < 0.0:
		return head
	return maxf(head, CharacterRig.shell_radius(dome, height))


## How high the top of the hair is, above the middle of the head.
static func top_of(style: String) -> float:
	var R := CharacterRig
	var dome := dome_of(style)
	if dome < 0.0:
		return R.HEAD_HEIGHT * 0.5 + 0.04
	return R.DOME_BASE + R.dome_height(dome)


static func build(rig: CharacterRig, covered: bool) -> void:
	var d := rig.design
	var style := d.style_of("hair")
	if style == "none":
		return
	var c := d.color_of("hair")
	var head := rig.head()
	var R := CharacterRig
	var r := R.HEAD_RADIUS
	var top := R.HEAD_HEIGHT * 0.5
	var up := not covered
	var dome := dome_of(style)
	var band_top := CharacterRig.DOME_BASE if up else UNDER_HAT
	# The dome and the band around the back and sides, from `from` to `to`
	# degrees (0 is the front) down to `bottom`.
	var cap := func(from: float, to: float, bottom: float) -> void:
		rig.shell(c, dome, deg_to_rad(from), deg_to_rad(to), bottom, up, band_top)
	match style:
		"short":
			cap.call(110.0, 250.0, 0.0)
		"spiky":
			cap.call(110.0, 250.0, 0.005)
			if up:
				for i in 9:
					var a := -1.6 + i * 0.4
					var spike := rig.add(head, rig.cylinder(0.0, 0.034, 0.1, 8), c, Vector3(sin(a) * 0.075, top + 0.035, cos(a) * 0.055 + 0.015))
					spike.basis = Basis(Vector3(cos(a), 0.0, -sin(a)), -0.5) * Basis(Vector3.RIGHT, 0.25)
		"flat_top":
			if up:
				rig.add(head, MeshKit.rounded_cylinder(r + 0.012, 0.075, 0.012, 32), c, Vector3(0.0, top - 0.012, 0.0))
			rig.shell(c, dome, deg_to_rad(110.0), deg_to_rad(250.0), -0.01, false, band_top)
		"mohawk":
			if up:
				for i in 7:
					var z := -0.085 + i * 0.03
					var h := 0.05 + sin(PI * i / 6.0) * 0.03
					rig.add(head, rig.box(Vector3(0.03, h + 0.02, 0.034), 0.012), c, Vector3(0.0, top - 0.01 + h * 0.5, z))
		"quiff":
			cap.call(110.0, 250.0, 0.0)
			if up:
				rig.add(head, rig.sphere(0.07, 0.07), c, Vector3(0.0, top + 0.035, -0.06), Basis(Vector3.RIGHT, 0.3))
		"side_part":
			cap.call(110.0, 250.0, 0.0)
			if up:
				rig.add(head, rig.sphere(0.08, 0.055), c, Vector3(-0.035, top + 0.028, -0.025), Basis(Vector3.BACK, 0.25))
		"bob":
			cap.call(60.0, 300.0, -0.06)
		"long", "wavy":
			cap.call(60.0, 300.0, -0.08)
			rig.add(head, rig.box(Vector3(0.21, 0.22, 0.035), 0.015), c, Vector3(0.0, -0.13, r + 0.022))
			if style == "wavy":
				for k in 5:
					rig.add(head, rig.sphere(0.028), c, Vector3(-0.08 + k * 0.04, -0.235, r + 0.022))
				for s: float in [-1.0, 1.0]:
					rig.add(head, rig.sphere(0.03), c, Vector3((r + 0.01) * s, -0.075, 0.03))
		"ponytail":
			cap.call(105.0, 255.0, -0.06)
			var tail := rig.add(head, rig.cylinder(0.02, 0.04, 0.16, 12), c, Vector3(0.0, -0.03, r + 0.05))
			tail.basis = Basis(Vector3.RIGHT, -0.5)
			rig.add(head, rig.ring(0.018, 0.03), c.darkened(0.4), Vector3(0.0, 0.03, r + 0.02), Basis(Vector3.RIGHT, 1.0))
		"pigtails":
			cap.call(90.0, 270.0, -0.02)
			for s: float in [-1.0, 1.0]:
				var root := Vector3((r + 0.01) * s, 0.0, 0.03)
				var tail := rig.add(head, rig.cylinder(0.02, 0.036, 0.13, 12), c, root + Vector3(0.05 * s, -0.05, 0.0))
				tail.basis = Basis(Vector3.BACK, 0.6 * s)
				rig.add(head, rig.ring(0.016, 0.028), c.darkened(0.4), root + Vector3(0.012 * s, 0.0, 0.0), Basis(Vector3.BACK, PI * 0.5 + 0.6 * s))
		"bun":
			cap.call(110.0, 250.0, 0.0)
			if up:
				rig.add(head, rig.sphere(0.048), c, Vector3(0.0, top + 0.07, 0.035))
		"afro":
			if up:
				cap.call(55.0, 305.0, -0.03)
			else:
				rig.shell(c, 0.02, deg_to_rad(55.0), deg_to_rad(305.0), -0.03, false, UNDER_HAT)
		"curly":
			cap.call(100.0, 260.0, -0.02)
			if up:
				for i in 10:
					var a := TAU * i / 10.0
					var at := Vector3(sin(a) * 0.1, top + 0.03 + (i % 2) * 0.02, cos(a) * 0.1)
					if at.z > -0.07:
						rig.add(head, rig.sphere(0.032), c, at)
		"bowl":
			cap.call(35.0, 325.0, 0.0)
		"princess":
			cap.call(60.0, 300.0, -0.08)
			rig.add(head, rig.box(Vector3(0.23, 0.24, 0.035), 0.015), c, Vector3(0.0, -0.14, r + 0.024))
			for s: float in [-1.0, 1.0]:
				rig.add(head, rig.sphere(0.036), c, Vector3((r + 0.018) * s, -0.06, 0.035))
				rig.add(head, rig.sphere(0.032), c, Vector3((r + 0.014) * s, -0.09, 0.075))
		"messy":
			cap.call(110.0, 250.0, 0.0)
			if up:
				var tilts := [[0.04, -0.03, 0.6], [-0.05, 0.02, -0.7], [0.0, 0.06, 0.2], [0.06, 0.05, 0.9], [-0.03, -0.06, -0.4], [-0.07, -0.01, -1.0]]
				for t in tilts:
					var tuft := rig.add(head, rig.cylinder(0.0, 0.028, 0.06, 8), c, Vector3(t[0], top + 0.05, t[1]))
					tuft.basis = Basis(Vector3(cos(t[2]), 0.0, sin(t[2])), 0.6)
		"braids":
			cap.call(90.0, 270.0, -0.02)
			for s: float in [-1.0, 1.0]:
				for k in 5:
					rig.add(head, rig.sphere(0.024), c, Vector3(0.075 * s, -0.04 - k * 0.042, r + 0.015))
				rig.add(head, rig.ring(0.012, 0.022), c.darkened(0.4), Vector3(0.075 * s, -0.228, r + 0.015))
		"fringe":
			cap.call(110.0, 250.0, 0.0)
			if up:
				rig.add(head, rig.box(Vector3(0.19, 0.035, 0.035), 0.015), c, Vector3(0.015, 0.062, -r - 0.004), Basis(Vector3.BACK, -0.22))


## The parts of a long or braided beard that hang below the chin.
static func build_beard(rig: CharacterRig) -> void:
	var d := rig.design
	var c := d.color_of("facial_hair")
	var head := rig.head()
	var R := CharacterRig
	match d.style_of("facial_hair"):
		"long":
			# A flattened point hanging from the chin, in front of the chest.
			rig.add(head, rig.cylinder(0.075, 0.012, 0.15, 20), c, Vector3(0.0, -0.15, -R.HEAD_RADIUS + 0.002), Basis.from_scale(Vector3(1.0, 1.0, 0.3)))
		"braided":
			for k in 3:
				rig.add(head, rig.sphere(0.022), c, Vector3(0.0, -0.115 - k * 0.036, -R.HEAD_RADIUS - 0.004))
			rig.add(head, rig.ring(0.01, 0.02), c.darkened(0.4), Vector3(0.0, -0.21, -R.HEAD_RADIUS - 0.004))
