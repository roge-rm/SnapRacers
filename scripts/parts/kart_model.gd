class_name KartModel
extends RefCounted

## A kart's looks without any of its physics, for pictures and for showing it
## off in menus. It's every part where it goes, with the driver in the seat
## holding the steering, and the origin under the middle of the kart like a
## real Kart's.


static func make(design: KartDesign, driver: CharacterDesign = null) -> Node3D:
	var root := Node3D.new()
	var stats := KartStats.compute(design)
	var steering: SteeringVisual = null
	# Everything that doesn't move is drawn as one mesh (see KartMesh).
	var looks: Array[Node3D] = []
	for info in stats.parts:
		var look := PartVisuals.make_turned(info.def, info.extent, info.basis)
		look.position = info.centre
		if look is SteeringVisual or info.def.kind == "wheel":
			root.add_child(look)
			if look is SteeringVisual and steering == null:
				steering = look
		else:
			looks.append(look)
	if not looks.is_empty():
		root.add_child(KartMesh.bake(looks))
		for look in looks:
			look.free()
	if stats.has_seat:
		var rig := CharacterRig.new(driver if driver != null else Kart.default_driver(), true)
		rig.recline = stats.recline
		rig.position = stats.seat_top
		root.add_child(rig)
		if steering != null:
			var grips := steering.grips(0.0)
			var to_rig := rig.transform.affine_inverse() * steering.transform
			rig.grip(to_rig * grips[0], to_rig * grips[1], to_rig.basis * grips[2], to_rig.basis * grips[3])
	return root


## How big the kart is, as a box around its parts in the model's space.
static func bounds(design: KartDesign) -> AABB:
	var stats := KartStats.compute(design)
	var box := AABB()
	var first := true
	for info in stats.parts:
		var part := AABB(info.centre - info.extent * 0.5, info.extent)
		box = part if first else box.merge(part)
		first = false
	if stats.has_seat:
		box = box.expand(stats.seat_top + Vector3.UP * 0.75)
	return box
