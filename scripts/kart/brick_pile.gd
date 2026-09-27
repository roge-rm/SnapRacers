class_name BrickPile
extends RigidBody3D

## One of the loose bricks a brick dropper leaves behind. Karts hit them like
## anything else, so running into a pile at speed can knock your parts off.
## They clear away after a while.

const LIFETIME := 15.0

var _age := 0.0


static func drop_behind(from: Kart) -> Array[BrickPile]:
	var out: Array[BrickPile] = []
	var back := from.global_basis.z
	var right := from.global_basis.x
	var up := from.global_basis.y
	for i in 3:
		var brick := BrickPile.new()
		var at := from.global_position + back * 2.4 + right * (i - 1) * 0.7 + up * (0.6 + i * 0.2)
		brick.transform = Transform3D(from.global_basis.rotated(up, i * 0.7), at)
		brick.linear_velocity = from.linear_velocity * 0.3
		out.append(brick)
	return out


func _init() -> void:
	mass = 6.0
	collision_layer = Kart.LAYER_HAZARD
	collision_mask = Kart.LAYER_WORLD | Kart.LAYER_KARTS | Kart.LAYER_HAZARD
	var size := Vector3(2.0, 3.0, 4.0) * Grid.UNIT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	add_child(PartVisuals.make({ "kind": "brick", "color": Color("#8a5a2b") }, size))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
