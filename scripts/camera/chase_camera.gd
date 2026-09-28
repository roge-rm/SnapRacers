class_name ChaseCamera
extends Camera3D

## Follows a kart from behind and a little above. It swings around to follow
## the way the kart is actually moving, so a slide looks like a slide.

@export var distance := 5.5
@export var height := 2.2
@export var look_height := 0.9
@export var follow := 6.0

var target: Node3D
## Which way is up for the camera. It follows the kart around loops and up
## walls, and settles back to straight up afterwards.
var _up := Vector3.UP


func _ready() -> void:
	top_level = true
	fov = 70.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var wanted_up := Vector3.UP
	if target is Kart and target.sticking:
		wanted_up = target.global_basis.y.normalized()
	# I lerp this instead of using slerp. Slerp between two almost equal
	# directions works out a rotation axis from almost nothing, and Godot
	# complains that it isn't normalised.
	var blended := _up.lerp(wanted_up, 1.0 - exp(-4.0 * delta))
	if blended.length_squared() > 0.0001:
		_up = blended.normalized()
	var facing := -target.global_basis.z
	if target is RigidBody3D and target.linear_velocity.length() > 3.0:
		facing = facing.lerp(target.linear_velocity.normalized(), 0.5)
	facing -= _up * facing.dot(_up)
	if facing.length() < 0.01:
		facing = Vector3.FORWARD
	facing = facing.normalized()
	var wanted := target.global_position - facing * distance + _up * height
	global_position = global_position.lerp(wanted, 1.0 - exp(-follow * delta))
	look_at(target.global_position + _up * look_height, _up)


func snap() -> void:
	if target == null:
		return
	var facing := -target.global_basis.z
	facing.y = 0.0
	global_position = target.global_position - facing.normalized() * distance + Vector3.UP * height
	look_at(target.global_position + Vector3.UP * look_height, Vector3.UP)
