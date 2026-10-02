class_name LegLooks
extends RefCounted

## The hips and legs. Sitting, the legs stick straight out in front with the
## feet up, like a brick figure sitting down. Standing, they go straight down with
## the feet forward.
##
## Each leg is made of lengths in different colours from the hip down, so
## shorts, boots and socks show where they should. Skirts and gowns go over the
## legs, and prints like pockets and stripes go on the front.

const BOOT := Color("#2a2a2a")
const WHITE := Color("#f2f2f2")


static func build(rig: CharacterRig) -> void:
	var d := rig.design
	var c := d.color_of("legs")
	var skin := d.skin()
	var metal := d.has("legs", "metal")
	var shine := 0.5 if metal else 0.0
	var thin := d.has("legs", "thin")
	var width := 0.13 if thin else 0.17
	var R := CharacterRig
	rig.add(rig, MeshKit.rounded_box(Vector3(0.38, R.HIPS_TOP, R.TORSO_DEPTH), 0.026), c, Vector3(0.0, R.HIPS_TOP * 0.5, 0.0), Basis.IDENTITY, shine)

	# The lengths of each leg, from the hip down, as [share, colour].
	var lengths := [[1.0, c]]
	if d.has("legs", "socks"):
		lengths = [[0.4, c], [0.15, skin], [0.45, WHITE]]
	elif d.has("legs", "bare"):
		lengths = [[0.4, c], [0.6, skin]]
	elif d.has("legs", "boots"):
		lengths = [[0.65, c], [0.35, BOOT]]
	var foot := c
	if d.has("legs", "boots") or d.has("legs", "socks"):
		foot = BOOT
	match d.setting("legs", "shoes", ""):
		"white":
			foot = WHITE
	if d.setting("legs", "feet", "") == "skin":
		foot = skin
	var big_feet := d.has("legs", "boots") or d.has("legs", "claws")
	var foot_size := Vector3(width + (0.02 if big_feet else 0.0), 0.075 if big_feet else 0.065, 0.11 if big_feet else 0.1)
	if d.has("legs", "claws"):
		foot_size = Vector3(width + 0.03, 0.08, 0.13)

	for sign: float in [-1.0, 1.0]:
		var x: float = R.LEG_X * sign
		var start := 0.0
		for k in lengths.size():
			var share: float = lengths[k][0]
			var colour: Color = lengths[k][1]
			var length: float = R.LEG_LENGTH * share
			# Flares get wider toward the bottom.
			var w := width * (1.18 if d.has("legs", "flares") and k == lengths.size() - 1 else 1.0)
			if d.has("legs", "flares") and lengths.size() == 1:
				_segment(rig, x, start, length * 0.6, width, c, shine)
				_segment(rig, x, start + length * 0.6, length * 0.4, width * 1.2, c, shine)
			else:
				_segment(rig, x, start, length + (0.01 if k < lengths.size() - 1 else 0.0), w * (0.97 if k > 0 else 1.0), colour, shine)
			start += length
		# The foot, turned up when sitting and forward when standing.
		var foot_at := Vector3(x, 0.13 + foot_size.z * 0.5 - 0.03, -R.LEG_LENGTH + foot_size.y * 0.5) if rig.seated else Vector3(x, -R.LEG_LENGTH + foot_size.y * 0.5, -0.065 - foot_size.z * 0.5 + 0.03)
		var foot_shape := Vector3(foot_size.x, foot_size.z, foot_size.y) if rig.seated else foot_size
		rig.add(rig, MeshKit.rounded_box(foot_shape, 0.02), foot, foot_at, Basis.IDENTITY, shine)
		if d.has("legs", "claws"):
			for k in 3:
				var cx := x + (k - 1) * 0.045
				var tip := Vector3(cx, foot_at.y + foot_shape.y * 0.5 + 0.01, foot_at.z) if rig.seated else Vector3(cx, foot_at.y - 0.01, foot_at.z - foot_shape.z * 0.5 - 0.012)
				var pointing := Vector3.UP if rig.seated else Vector3.FORWARD
				rig.add(rig, rig.cylinder(0.0, 0.016, 0.04, 8), WHITE, tip, CharacterRig.pointing(pointing))
		_prints(rig, x, width, c, sign)
		if d.has("legs", "pads"):
			var pad := Vector3(x, 0.14, -R.LEG_LENGTH * 0.55) if rig.seated else Vector3(x, -R.LEG_LENGTH * 0.55, -0.075)
			var pad_shape := Vector3(width * 0.8, 0.02, 0.09) if rig.seated else Vector3(width * 0.8, 0.09, 0.02)
			rig.add(rig, rig.box(pad_shape, 0.008), c.lightened(0.3), pad, Basis.IDENTITY, 0.6)
		if metal:
			var bolt := Vector3(x + 0.086 * sign, 0.065, -R.LEG_LENGTH * 0.5) if rig.seated else Vector3(x + 0.086 * sign, -R.LEG_LENGTH * 0.5, 0.0)
			rig.add(rig, rig.cylinder(0.02, 0.02, 0.01, 12), c.lightened(0.4), bolt, Basis(Vector3.BACK, PI * 0.5), 0.7)

	match d.setting("legs", "skirt", ""):
		"long":
			_skirt(rig, c, 0.36 if rig.seated else 0.35, 0.235)
		"short", "kilt":
			_skirt(rig, c, 0.2 if rig.seated else 0.18, 0.215)
			if d.setting("legs", "skirt", "") == "kilt":
				_kilt(rig, c)
	if d.setting("legs", "print", "") == "jeans":
		for sign: float in [-1.0, 1.0]:
			rig.print_on(rig, Vector2(0.05, 0.035), c.lightened(0.25), Vector3(0.11 * sign, R.HIPS_TOP * 0.5, -R.TORSO_DEPTH * 0.5 - 0.002))


## One length of a leg, `start` from the hip and `length` long.
static func _segment(rig: CharacterRig, x: float, start: float, length: float, width: float, colour: Color, shine: float) -> void:
	if rig.seated:
		rig.add(rig, MeshKit.rounded_box(Vector3(width, 0.13, length), 0.034), colour, Vector3(x, 0.065, -start - length * 0.5), Basis.IDENTITY, shine)
	else:
		# A hairline gap under the hips, like a toy figure's, so the two
		# don't flicker where they meet.
		var gap := 0.004 if start == 0.0 else 0.0
		rig.add(rig, MeshKit.rounded_box(Vector3(width, length - gap, 0.13), 0.034), colour, Vector3(x, -start - length * 0.5 - gap * 0.5, 0.0), Basis.IDENTITY, shine)


## Stripes, turn-ups and the like printed on the front of a leg.
static func _prints(rig: CharacterRig, x: float, width: float, c: Color, sign: float) -> void:
	var R := CharacterRig
	var along := R.LEG_LENGTH
	var front := func(at: float, size: Vector2, colour: Color, sideways := 0.0) -> void:
		# A print `at` down the leg from the hip, on the front (the top, when
		# sitting).
		if rig.seated:
			rig.print_on(rig, size, colour, Vector3(x + sideways, 0.133, -at), Basis(Vector3.RIGHT, -PI * 0.5))
		else:
			rig.print_on(rig, size, colour, Vector3(x + sideways, -at, -0.068))
	match rig.design.setting("legs", "print", ""):
		"jeans":
			front.call(along * 0.5, Vector2(0.006, along * 0.9), c.lightened(0.3), width * 0.3 * sign)
		"stripes":
			front.call(along * 0.5, Vector2(0.02, along * 0.95), LegLooks.WHITE, width * 0.38 * sign)
		"stripe":
			front.call(along * 0.33, Vector2(0.03, along * 0.6), LegLooks.WHITE)
		"chaps":
			front.call(along * 0.35, Vector2(width * 0.9, along * 0.65), Color("#8a5a2b"))
		"turnups":
			front.call(along * 0.93, Vector2(width * 1.02, 0.03), c.lightened(0.25))


## A skirt or gown over the legs, `length` long. Standing it's a bell from the
## hips. Sitting it drapes over the legs out in front.
static func _skirt(rig: CharacterRig, c: Color, length: float, radius: float) -> void:
	var R := CharacterRig
	if rig.seated:
		rig.add(rig, MeshKit.rounded_box(Vector3(0.4, 0.15, length), 0.03), c, Vector3(0.0, 0.07, -length * 0.5 + 0.08))
	else:
		rig.add(rig, rig.cylinder(0.2, radius, length, 28), c, Vector3(0.0, R.HIPS_TOP - length * 0.5, -0.01))


## Pleats and a pouch on a kilt.
static func _kilt(rig: CharacterRig, c: Color) -> void:
	var R := CharacterRig
	if rig.seated:
		for k in 5:
			rig.print_on(rig, Vector2(0.006, 0.12), c.darkened(0.35), Vector3(-0.14 + k * 0.07, 0.148, -0.02), Basis(Vector3.RIGHT, -PI * 0.5))
		rig.add(rig, rig.box(Vector3(0.07, 0.03, 0.08), 0.01), Color("#6b4430"), Vector3(0.0, 0.16, 0.0))
	else:
		for k in 7:
			var a := -0.9 + k * 0.3
			rig.print_on(rig, Vector2(0.006, 0.1), c.darkened(0.35), Vector3(sin(a) * 0.21, R.HIPS_TOP * 0.5 - 0.03, -cos(a) * 0.21), Basis(Vector3.UP, -a))
		rig.add(rig, rig.box(Vector3(0.07, 0.08, 0.03), 0.01), Color("#6b4430"), Vector3(0.0, -0.02, -0.22))
