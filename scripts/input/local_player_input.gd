class_name LocalPlayerInput
extends Node

## Reads one local player's controls and writes them into a KartControls.
##
## Each player in split screen gets their own one of these, pointing at their
## own controller or their own half of the touch screen. A player can use
## several at once (keyboard and a controller on a desktop, say) and the
## strongest input wins.

@export var use_keyboard := false
@export var joypad := -1 # device id, or -1 for none
var touch: TouchControls

var controls := KartControls.new()

const STICK_DEADZONE := 0.15


func _physics_process(_delta: float) -> void:
	var throttle := 0.0
	var brake := 0.0
	var steer := 0.0
	var reset := false

	if use_keyboard:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			throttle = 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			brake = 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			steer -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			steer += 1.0
		reset = reset or Input.is_physical_key_pressed(KEY_R)

	if joypad >= 0:
		throttle = maxf(throttle, Input.get_joy_axis(joypad, JOY_AXIS_TRIGGER_RIGHT))
		brake = maxf(brake, Input.get_joy_axis(joypad, JOY_AXIS_TRIGGER_LEFT))
		if Input.is_joy_button_pressed(joypad, JOY_BUTTON_A):
			throttle = 1.0
		if Input.is_joy_button_pressed(joypad, JOY_BUTTON_B):
			brake = 1.0
		var stick := Input.get_joy_axis(joypad, JOY_AXIS_LEFT_X)
		if absf(stick) > STICK_DEADZONE:
			steer += signf(stick) * inverse_lerp(STICK_DEADZONE, 1.0, absf(stick))
		if Input.is_joy_button_pressed(joypad, JOY_BUTTON_DPAD_LEFT):
			steer -= 1.0
		if Input.is_joy_button_pressed(joypad, JOY_BUTTON_DPAD_RIGHT):
			steer += 1.0
		reset = reset or Input.is_joy_button_pressed(joypad, JOY_BUTTON_Y)

	if touch != null and touch.visible:
		throttle = maxf(throttle, touch.throttle)
		brake = maxf(brake, touch.brake)
		steer += touch.steer
		reset = reset or touch.reset

	controls.throttle = throttle
	controls.brake = brake
	controls.steer = clampf(steer, -1.0, 1.0)
	controls.reset = reset
