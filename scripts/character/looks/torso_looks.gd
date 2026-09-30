class_name TorsoLooks
extends RefCounted

## The torso, a flat fronted block narrower at the shoulders, in the torso's
## colour, with its style printed on the front the way a real minifig's is.
## Anything raised, like a belt buckle or a control panel, sits on the surface
## and never sinks into it.

const WHITE := Color("#f2f2f2")
const GOLD := Color("#c9a227")
const DENIM := Color("#1f4e8c")


static func build(rig: CharacterRig) -> void:
	var d := rig.design
	var c := d.color_of("torso")
	var style := d.style_of("torso")
	var R := CharacterRig
	var up := rig.upper()
	var shine := 0.35 if style in ["armour", "robot"] else 0.0
	rig.add(up, MeshKit.rounded_box(Vector3(R.TORSO_BOTTOM_WIDTH, R.TORSO_HEIGHT, R.TORSO_DEPTH), 0.026, R.TORSO_TAPER), c, Vector3(0.0, R.TORSO_Y, 0.0), Basis.IDENTITY, shine)
	var light := c.lightened(0.45)
	var dark := c.darkened(0.4)
	var ink := WHITE if c.get_luminance() < 0.5 else Color("#1b1b1b")
	var y := R.TORSO_Y
	var top := R.NECK_Y
	# A print on the front, centred at (x, height), turned `angle` radians.
	# Prints that overlap another go on a higher `layer`, a hair further out,
	# so the two don't flicker.
	var front := func(size: Vector2, colour: Color, x: float, height: float, angle := 0.0, layer := 0) -> void:
		rig.print_on(up, size, colour, Vector3(x, height, -R.TORSO_DEPTH * 0.5 - 0.002 - layer * 0.002), Basis(Vector3.BACK, angle))
	var button := func(colour: Color, x: float, height: float, radius := 0.012) -> void:
		rig.add(up, rig.cylinder(radius, radius, 0.006, 12), colour, Vector3(x, height, -R.TORSO_DEPTH * 0.5 - 0.004), Basis(Vector3.RIGHT, PI * 0.5))
	var belt := func(colour: Color, buckle: Color) -> void:
		front.call(Vector2(0.39, 0.035), colour, 0.0, R.HIPS_TOP + 0.03)
		rig.add(up, rig.box(Vector3(0.045, 0.035, 0.008), 0.004), buckle, Vector3(0.0, R.HIPS_TOP + 0.03, -R.TORSO_DEPTH * 0.5 - 0.006), Basis.IDENTITY, 0.5)
	match style:
		"racing_suit":
			front.call(Vector2(0.06, R.TORSO_HEIGHT * 0.9), WHITE, -0.06, y)
			button.call(WHITE, 0.075, y + 0.07, 0.04)
		"jacket":
			front.call(Vector2(0.012, R.TORSO_HEIGHT * 0.88), dark, 0.0, y - 0.01)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.08, 0.035), dark, 0.045 * s, top - 0.035, 0.55 * s)
		"overalls":
			# A denim bib and straps over a shirt in the torso's colour.
			var bib := DENIM if c.b < 0.5 or c.r > c.b else DENIM.darkened(0.4)
			front.call(Vector2(0.2, 0.15), bib, 0.0, y - 0.07)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.03, 0.2), bib, 0.08 * s, y + 0.07)
				button.call(Color("#f2cd37"), 0.08 * s, y)
		"hoodie":
			rig.add(up, rig.box(Vector3(0.24, 0.08, 0.06), 0.03), c, Vector3(0.0, top - 0.01, 0.09))
			front.call(Vector2(0.2, 0.07), dark, 0.0, y - 0.1)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.008, 0.09), WHITE, 0.03 * s, top - 0.06)
		"armour":
			rig.add(up, MeshKit.rounded_box(Vector3(0.3, 0.18, 0.02), 0.015, 0.85), light, Vector3(0.0, y + 0.04, -R.TORSO_DEPTH * 0.5 - 0.008), Basis.IDENTITY, 0.6)
		"tee":
			front.call(Vector2(0.1, 0.02), dark, 0.0, top - 0.02)
		"tuxedo":
			# A white shirt in a V, with lapels either side and a button.
			front.call(Vector2(0.07, 0.2), WHITE, 0.0, top - 0.11)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.03, 0.2), dark, 0.05 * s, top - 0.1, 0.25 * s, 1)
			button.call(Color("#1b1b1b"), 0.0, y - 0.05, 0.009)
		"gown":
			# A bodice with a lighter front panel, trimmed in gold.
			front.call(Vector2(0.12, 0.22), light, 0.0, y - 0.03)
			front.call(Vector2(0.3, 0.018), GOLD, 0.0, top - 0.04)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.012, 0.22), GOLD, 0.062 * s, y - 0.03, 0.0, 1)
		"vest":
			# A waistcoat open over a white shirt.
			front.call(Vector2(0.1, R.TORSO_HEIGHT * 0.95), WHITE, 0.0, y)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.012, R.TORSO_HEIGHT * 0.9), GOLD, 0.055 * s, y, 0.0, 1)
				for k in 3:
					button.call(GOLD, 0.075 * s, y + 0.07 - k * 0.07, 0.008)
		"tank_top":
			# Bare shoulders and a scooped neck.
			rig.add(up, MeshKit.rounded_box(Vector3(0.15, 0.1, 0.006), 0.04), d.skin(), Vector3(0.0, top - 0.035, -R.TORSO_DEPTH * 0.5 - 0.002))
		"flowery":
			var flowers := [[-0.1, y + 0.08, WHITE], [0.06, y + 0.11, Color("#f2cd37")], [0.1, y - 0.02, WHITE], [-0.04, y - 0.06, Color("#d86cb0")], [0.0, y + 0.02, Color("#f2cd37")], [-0.12, y - 0.1, Color("#d86cb0")], [0.12, y - 0.11, WHITE]]
			for f in flowers:
				for k in 5:
					var a := TAU * k / 5.0
					front.call(Vector2(0.018, 0.018), f[2], f[0] + cos(a) * 0.016, f[1] + sin(a) * 0.016)
				front.call(Vector2(0.012, 0.012), Color("#e36a1a"), f[0], f[1], 0.0, 1)
		"stripes":
			for k in 5:
				front.call(Vector2(0.4 - k * 0.018, 0.022), WHITE, 0.0, R.HIPS_TOP + 0.04 + k * 0.066)
		"plaid":
			for k in 5:
				front.call(Vector2(0.012, R.TORSO_HEIGHT * 0.95), dark, -0.14 + k * 0.07, y)
			for k in 4:
				front.call(Vector2(0.38 - k * 0.02, 0.012), dark, 0.0, R.HIPS_TOP + 0.05 + k * 0.08)
			front.call(Vector2(0.008, R.TORSO_HEIGHT * 0.9), WHITE, 0.0, y, 0.0, 1)
		"lab_coat":
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.03, 0.14), c.darkened(0.15), 0.045 * s, top - 0.08, 0.3 * s)
			front.call(Vector2(0.006, R.TORSO_HEIGHT * 0.7), c.darkened(0.2), 0.0, y - 0.05)
			front.call(Vector2(0.06, 0.05), c.darkened(0.15), -0.1, y + 0.03)
			for k in 2:
				rig.add(up, rig.box(Vector3(0.008, 0.05, 0.008), 0.003), [Color("#0d69ab"), Color("#c4281c")][k], Vector3(-0.115 + k * 0.015, y + 0.06, -R.TORSO_DEPTH * 0.5 - 0.006))
		"tunic":
			var cross := WHITE if c.get_luminance() < 0.6 else Color("#c4281c")
			front.call(Vector2(0.05, 0.22), cross, 0.0, y + 0.01)
			front.call(Vector2(0.18, 0.05), cross, 0.0, y + 0.05)
			belt.call(Color("#6b4430"), GOLD)
		"pirate_coat":
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.04, 0.22), dark, 0.05 * s, top - 0.12, 0.2 * s, 1)
				for k in 3:
					button.call(GOLD, 0.1 * s, y + 0.06 - k * 0.06, 0.01)
			front.call(Vector2(0.06, 0.2), WHITE, 0.0, top - 0.11)
			belt.call(Color("#3b2a1e"), GOLD)
		"leather":
			rig.add(up, rig.box(Vector3(0.008, R.TORSO_HEIGHT * 0.9, 0.006), 0.002), Color("#c8ccd0"), Vector3(-0.02, y, -R.TORSO_DEPTH * 0.5 - 0.004), Basis.IDENTITY, 0.6)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.09, 0.04), dark, 0.06 * s, top - 0.03, 0.4 * s)
			front.call(Vector2(0.06, 0.006), dark, 0.08, y - 0.05)
		"space_suit":
			rig.add(up, rig.box(Vector3(0.14, 0.09, 0.02), 0.008), Color("#9aa0a6"), Vector3(0.0, y + 0.02, -R.TORSO_DEPTH * 0.5 - 0.01), Basis.IDENTITY, 0.4)
			var lights := [Color("#c4281c"), Color("#4fb35f"), Color("#f2cd37"), Color("#3a8dde")]
			for k in 4:
				rig.add(up, rig.cylinder(0.01, 0.01, 0.008, 10), lights[k], Vector3(-0.045 + k * 0.03, y + 0.035, -R.TORSO_DEPTH * 0.5 - 0.022), Basis(Vector3.RIGHT, PI * 0.5))
			rig.print_on(up, Vector2(0.1, 0.012), Color("#1b1b1b"), Vector3(0.0, y + 0.0, -R.TORSO_DEPTH * 0.5 - 0.023))
		"gi":
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.03, 0.26), dark, 0.035 * s, y + 0.03, 0.35 * s)
			front.call(Vector2(0.39, 0.035), Color("#1b1b1b"), 0.0, R.HIPS_TOP + 0.03)
		"robot":
			rig.add(up, rig.box(Vector3(0.18, 0.14, 0.02), 0.01), c.darkened(0.3), Vector3(0.0, y + 0.02, -R.TORSO_DEPTH * 0.5 - 0.01), Basis.IDENTITY, 0.5)
			for k in 3:
				rig.add(up, rig.sphere(0.012), [Color("#c4281c"), Color("#4fb35f"), Color("#3a8dde")][k], Vector3(-0.04 + k * 0.04, y + 0.05, -R.TORSO_DEPTH * 0.5 - 0.02))
			for k in 3:
				rig.print_on(up, Vector2(0.12, 0.006), Color("#1b1b1b"), Vector3(0.0, y - 0.005 - k * 0.02, -R.TORSO_DEPTH * 0.5 - 0.022))
		"jersey":
			# A big number one and a stripe over each shoulder.
			front.call(Vector2(0.03, 0.14), ink, 0.0, y)
			front.call(Vector2(0.04, 0.025), ink, -0.012, y + 0.058, 0.5)
			front.call(Vector2(0.07, 0.022), ink, 0.0, y - 0.06)
			for s: float in [-1.0, 1.0]:
				front.call(Vector2(0.05, 0.03), ink, 0.12 * s, top - 0.03)
		"dino_belly":
			# A pale belly with ridges across it.
			rig.add(up, MeshKit.rounded_box(Vector3(0.2, 0.26, 0.006), 0.07), light.lightened(0.2), Vector3(0.0, y - 0.02, -R.TORSO_DEPTH * 0.5 - 0.002))
			for k in 4:
				front.call(Vector2(0.16 - absf(k - 1.5) * 0.02, 0.008), c.lightened(0.2), 0.0, y - 0.11 + k * 0.06, 0.0, 1)
