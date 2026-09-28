class_name ArmLooks
extends RefCounted

## An arm: one piece from the rounded shoulder down to the minifig's fixed
## bend at the elbow and on to the wrist, then the C shaped hand. Sleeves and
## the like are printed on it in their own colours, the way a real minifig's
## are. How long the sleeves
## are, what's on the hands and any extras (cuffs, bracers, pads, a watch)
## come from the arms piece's settings in pieces.json.

const WHITE := Color("#f2f2f2")
const DARK := Color("#3c3f44")


static func build(rig: CharacterRig, arm: Node3D, hand: Node3D, side: int, elbow: Vector3, wrist: Vector3, dir: Vector3) -> void:
	var d := rig.design
	var c := d.color_of("arms")
	var skin := d.skin()
	var R := CharacterRig
	var metal := d.has("arms", "metal")
	var shine := 0.5 if metal else 0.0
	var sleeve: String = d.setting("arms", "sleeve", "long")
	var outward := -1.0 if side == 0 else 1.0

	var upper := c
	var fore := c
	match sleeve:
		"short", "none":
			upper = skin
			fore = skin
		"rolled":
			fore = skin
	if d.has("arms", "two_tone"):
		fore = c.darkened(0.35)
	var hands := skin
	match d.setting("arms", "hands", "skin"):
		"dark":
			hands = DARK
		"white":
			hands = WHITE
		"colour":
			hands = c
		"metal":
			hands = c.lightened(0.15)
	if metal and d.setting("arms", "hands", "") == "":
		hands = c.lightened(0.15)
	if d.setting("arms", "gauntlet", "") == "white":
		fore = WHITE

	# The forearm's own space: +Y back up the arm toward the elbow.
	var y := -dir
	var x := (Vector3.RIGHT - y * Vector3.RIGHT.dot(y)).normalized()
	var fore_basis := Basis(x, y, x.cross(y))
	var along := func(t: float) -> Vector3:
		return elbow + dir * t

	# The arm hangs straight down from the shoulder, with its rounded top
	# tucked against the side of the torso, then bends at the elbow. Each
	# stretch of it in one colour is its own mesh, and they meet exactly.
	var top := Vector3(0.0, 0.045, 0.0)
	var end: Vector3 = wrist + dir * 0.01
	var bend := MeshKit.arm_elbow(top, elbow, end)
	var stretches := [[0.0, bend, upper], [bend, INF, fore]]
	if sleeve == "short":
		# A short sleeve printed over the top of the arm.
		stretches = [[0.0, 0.1, c], [0.1, INF, skin]]
	var from := 0.0
	for i in stretches.size():
		var colour: Color = stretches[i][2]
		var last: bool = i == stretches.size() - 1
		if last or colour != stretches[i + 1][2]:
			rig.add(arm, MeshKit.arm(top, elbow, end, from, stretches[i][1]), colour, Vector3.ZERO, Basis.IDENTITY, shine)
			from = stretches[i][1]
	if sleeve == "rolled":
		rig.add(arm, rig.box(Vector3(0.088, 0.03, 0.093), 0.014), c.darkened(0.15), along.call(0.01), fore_basis)

	# A band around the arm, `at` along the forearm (or up the upper arm when
	# negative), in a colour. The arm's so rounded it's nearly round, so a
	# band is a short round tube around it. A square one stuck out at its
	# corners.
	var band := func(at: float, colour: Color, thick := 0.014, bulk := 0.006) -> void:
		var radius := 0.045 + bulk * 0.5
		if at >= 0.0:
			rig.add(arm, rig.cylinder(radius - 0.002, radius - 0.002, thick, 20), colour, along.call(at), fore_basis, shine)
		else:
			rig.add(arm, rig.cylinder(radius, radius, thick, 20), colour, Vector3(0.0, at, 0.0), Basis.IDENTITY, shine)

	match d.setting("arms", "cuff", ""):
		"colour":
			band.call(R.FOREARM - 0.02, c, 0.03)
		"dark":
			band.call(R.FOREARM - 0.02, DARK, 0.03)
	if d.has("arms", "stripes"):
		for k in 3:
			band.call(-0.035 - k * 0.028, WHITE, 0.012)
			band.call(0.025 + k * 0.035, WHITE, 0.012)
	if d.has("arms", "wraps"):
		for k in 4:
			band.call(0.03 + k * 0.026, WHITE, 0.018, 0.004)
	if d.has("arms", "watch"):
		band.call(R.FOREARM - 0.025, Color("#1b1b1b"), 0.016)
		rig.add(arm, rig.cylinder(0.016, 0.016, 0.01, 14), Color("#c8ccd0"), along.call(R.FOREARM - 0.025) + fore_basis.x * 0.046 * outward, fore_basis * Basis(Vector3.BACK, PI * 0.5), 0.6)
	if d.setting("arms", "bracer", "") == "spikes":
		rig.add(arm, rig.box(Vector3(0.094, 0.075, 0.098), 0.02), Color("#1b1b1b"), along.call(0.06), fore_basis)
		for k in 3:
			var at: Vector3 = along.call(0.035 + k * 0.025) + fore_basis.x * 0.047 * outward
			rig.add(arm, rig.cylinder(0.0, 0.013, 0.035, 8), WHITE, at + fore_basis.x * 0.015 * outward, CharacterRig.pointing(fore_basis.x * outward))
	if d.has("arms", "pads"):
		rig.add(arm, rig.sphere(0.066, 0.07), c.lightened(0.3), Vector3(0.0, -0.005, 0.0), Basis.IDENTITY, 0.6)
	if d.has("arms", "puff"):
		rig.add(arm, rig.sphere(0.064, 0.09), c, Vector3(0.0, -0.025, 0.0))
	if d.has("arms", "fur"):
		var tuft := c.lightened(0.25)
		rig.add(arm, rig.sphere(0.058, 0.05), tuft, Vector3(0.0, -0.005, 0.0))
		rig.add(arm, rig.sphere(0.054, 0.04), tuft, along.call(R.FOREARM - 0.015), fore_basis)
	if d.has("arms", "scales"):
		for k in 3:
			rig.add(arm, rig.box(Vector3(0.006, 0.02, 0.03), 0.003), c.lightened(0.3), Vector3(0.045 * outward, -0.04 - k * 0.035, 0.0))
			rig.add(arm, rig.box(Vector3(0.006, 0.02, 0.03), 0.003), c.lightened(0.3), along.call(0.03 + k * 0.03) + fore_basis.x * 0.042 * outward, fore_basis)
	if d.has("arms", "tattoo"):
		# An anchor on the outside of the upper arm.
		var at := Vector3(0.0452 * outward, -0.07, 0.0)
		var turn := Basis(Vector3.UP, -PI * 0.5 * outward)
		rig.print_on(arm, Vector2(0.006, 0.04), Color("#0d69ab"), at, turn)
		rig.print_on(arm, Vector2(0.03, 0.006), Color("#0d69ab"), at + Vector3(0.0, 0.01, 0.0), turn)
		rig.print_on(arm, Vector2(0.03, 0.006), Color("#0d69ab"), at + Vector3(0.0, -0.018, 0.0), turn)
	if d.setting("arms", "gauntlet", "") == "white":
		band.call(0.005, WHITE, 0.025)

	# The wrist, and the hand on it, which twists to grip.
	var hand_shine := 0.5 if d.setting("arms", "hands", "") == "metal" or metal else 0.0
	rig.add(arm, rig.cylinder(0.022, 0.022, 0.03, 12), hands, wrist + dir * 0.008, fore_basis, hand_shine)
	rig.add(hand, MeshKit.hand(R.HAND_SIZE), hands, Vector3.ZERO, Basis.IDENTITY, hand_shine)
