class_name LocalPlayerInput
extends Node

## Reads one local player's controls and writes them into a KartControls.
##
## Each player in split screen gets their own one of these, pointing at their
## own controller or their own half of the touch screen. A player can use
## several at once (like a keyboard and a controller on a desktop), and the
## strongest input wins.

## Start on the controller, for the race's menu.
signal menu_pressed

@export var use_keyboard := false
## Which keys a player uses when two share a keyboard. It's ALL_KEYS for one
## player on their own, LEFT_KEYS (WASD, Q, E and R, with C to look back and V
## to change the view), or RIGHT_KEYS (the arrows, period, slash and Enter,
## with comma to look back and M to change the view).
@export var keys := ALL_KEYS
@export var joypad := -1 # device id, or -1 for none
## With only one local player, whichever controller is connected is theirs,
## including one plugged in partway through.
@export var any_joypad := false
## With two, the first controller connected is player 1's and the second is
## player 2's. -1 leaves `joypad` alone.
@export var pad_slot := -1
var touch: TouchControls

var controls := KartControls.new()
## Held down to look behind. It's for the camera, not the kart, so it isn't
## in `controls`.
var look_back := false

var _view_pressed := false
var _view_held := false
var _menu_held := false

const STICK_DEADZONE := 0.15
const ALL_KEYS := 0
const LEFT_KEYS := 1
const RIGHT_KEYS := 2


func _physics_process(_delta: float) -> void:
	var throttle := 0.0
	var brake := 0.0
	var steer := 0.0
	var reset := false
	var gadget: Array[bool] = [false, false]
	var back := false
	var view := false

	if use_keyboard:
		# Go, brake, left, right, reset, gadget 1, gadget 2, look back, view.
		var left := [KEY_W, KEY_S, KEY_A, KEY_D, KEY_R, KEY_Q, KEY_E, KEY_C, KEY_V]
		var right := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_PERIOD, KEY_SLASH, KEY_COMMA, KEY_M]
		var sets := []
		if keys != RIGHT_KEYS:
			sets.append(left)
		if keys != LEFT_KEYS:
			sets.append(right)
		for set in sets:
			var down := func(i: int) -> bool: return Input.is_physical_key_pressed(set[i])
			if down.call(0):
				throttle = 1.0
			if down.call(1):
				brake = 1.0
			if down.call(2):
				steer -= 1.0
			if down.call(3):
				steer += 1.0
			reset = reset or down.call(4)
			gadget[0] = gadget[0] or down.call(5)
			gadget[1] = gadget[1] or down.call(6)
			back = back or down.call(7)
			view = view or down.call(8)

	if any_joypad and not Input.get_connected_joypads().has(joypad):
		var pads := Input.get_connected_joypads()
		joypad = pads[0] if not pads.is_empty() else -1
	if pad_slot >= 0:
		var pads := Input.get_connected_joypads()
		joypad = pads[pad_slot] if pad_slot < pads.size() else -1

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
		gadget[0] = gadget[0] or Input.is_joy_button_pressed(joypad, JOY_BUTTON_X)
		gadget[1] = gadget[1] or Input.is_joy_button_pressed(joypad, JOY_BUTTON_RIGHT_SHOULDER)
		back = back or Input.is_joy_button_pressed(joypad, JOY_BUTTON_LEFT_SHOULDER)
		view = view or Input.is_joy_button_pressed(joypad, JOY_BUTTON_BACK)
		var menu := Input.is_joy_button_pressed(joypad, JOY_BUTTON_START)
		if menu and not _menu_held:
			menu_pressed.emit()
		_menu_held = menu

	if touch != null and touch.visible:
		throttle = maxf(throttle, touch.throttle)
		brake = maxf(brake, touch.brake)
		steer += touch.steer
		reset = reset or touch.reset or touch.take_reset_tap()
		for slot in 2:
			gadget[slot] = gadget[slot] or touch.take_gadget_tap(slot)
		back = back or touch.look_back

	controls.throttle = throttle
	controls.brake = brake
	controls.steer = clampf(steer, -1.0, 1.0)
	controls.reset = reset
	controls.gadget = gadget
	look_back = back
	# The view changes once each time the key or button goes down.
	if view and not _view_held:
		_view_pressed = true
	_view_held = view


## True once for each press of the change view key or button (or the camera
## button on the screen, which calls press_view()).
func take_view_press() -> bool:
	var pressed := _view_pressed
	_view_pressed = false
	return pressed


func press_view() -> void:
	_view_pressed = true


## Whether this controller is this player's. With one player on their own,
## any controller is.
func owns_joypad(device: int) -> bool:
	return any_joypad or device == joypad
