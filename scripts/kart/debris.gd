class_name Debris
extends RigidBody3D

## A part that's broken off a kart. It tumbles about on its own for a few
## seconds, then shrinks away. It bumps into the world and other pieces but
## not into karts, so wreckage can't set off more wreckage.

const LIFETIME := 6.0
const SHRINK_TIME := 0.6
## Phones can't handle hundreds of these, so past this many the oldest go
## first.
const MOST_AT_ONCE := 40

static var _alive: Array[Debris] = []

var _age := 0.0


static func make(def: Dictionary, extent: Vector3, where: Transform3D, rot := 0) -> Debris:
	var piece := Debris.new()
	piece.transform = where
	piece.mass = maxf(def.get("mass", 1.0), 0.2)
	piece.collision_layer = Kart.LAYER_DEBRIS
	piece.collision_mask = Kart.LAYER_WORLD | Kart.LAYER_DEBRIS
	var shape := CollisionShape3D.new()
	if def.get("kind", "") == "wheel":
		var cylinder := CylinderShape3D.new()
		cylinder.radius = def.get("radius", 0.3)
		cylinder.height = def.get("width", 0.25)
		shape.shape = cylinder
		shape.rotation.z = PI * 0.5
	else:
		var box := BoxShape3D.new()
		box.size = extent
		shape.shape = box
	piece.add_child(shape)
	piece.add_child(PartVisuals.make(def, extent, rot))
	return piece


func _ready() -> void:
	_alive.append(self)
	while _alive.size() > MOST_AT_ONCE:
		var oldest: Debris = _alive.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


func _exit_tree() -> void:
	_alive.erase(self)


func _process(delta: float) -> void:
	_age += delta
	var left := LIFETIME - _age
	if left <= 0.0:
		queue_free()
	elif left < SHRINK_TIME:
		for child in get_children():
			if child is Node3D and not child is CollisionShape3D:
				child.scale = Vector3.ONE * (left / SHRINK_TIME)
