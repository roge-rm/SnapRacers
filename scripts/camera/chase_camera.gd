class_name ChaseCamera
extends Camera3D

## Follows a kart from behind and a little above. It swings round to follow
## the way the kart is actually moving, so a slide looks like a slide.

@export var distance := 5.5
@export var height := 2.2
@export var look_height := 0.9
@export var follow := 6.0

var target: Node3D


func _ready() -> void:
	top_level = true
	fov = 70.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var facing := -target.global_basis.z
	if target is RigidBody3D and target.linear_velocity.length() > 3.0:
		facing = facing.lerp(target.linear_velocity.normalized(), 0.5)
	facing.y = 0.0
	if facing.length() < 0.01:
		facing = Vector3.FORWARD
	facing = facing.normalized()
	var wanted := target.global_position - facing * distance + Vector3.UP * height
	global_position = global_position.lerp(wanted, 1.0 - exp(-follow * delta))
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)


func snap() -> void:
	if target == null:
		return
	var facing := -target.global_basis.z
	facing.y = 0.0
	global_position = target.global_position - facing.normalized() * distance + Vector3.UP * height
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)
