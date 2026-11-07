class_name LocalPlayerInput
extends Node

## Reads one local player's controls and writes them into a KartControls.
##
## Each player in split screen gets their own one of these, with their own
## keys and controller buttons (InputBindings), their own controller
## (Controllers) and their own half of the touch screen. A player can use
## several at once (like a keyboard and a controller on a desktop), and the
## strongest input wins.

## Start on the controller, for the race's menu.
signal menu_pressed

@export var use_keyboard := false
## Whose keys and controller buttons these are (see InputBindings), 0 for
## player 1.
@export var person := 0
## With one player on their own, both players' keys drive, so the arrows and
## WASD both work.
@export var both_keys := false
@export var joypad := -1 # device id, or -1 for none
## With only one local player, whichever controller is connected is theirs,
## including one plugged in partway through. Otherwise it's the controller
## given to `person` (see Controllers).
@export var any_joypad := false
var touch: TouchControls

var controls := KartControls.new()
## Held down to look behind. It's for the camera, not the kart, so it isn't
## in `controls`.
var look_back := false

var _view_pressed := false
var _view_held := false
var _menu_held := false
const VIEW_HOLD := 0.55
var mirror_hold_enabled := false
var camera_controls_enabled := true:
	set(value):
		camera_controls_enabled = value
		cancel_camera_press()
var _mirror_pressed := false
var _view_time := 0.0
var _view_consumed := false
var _wait_view_release := false
var _touch_view_held := false
var _touch_view_time := 0.0
var _touch_view_consumed := false
var _touch_cancelled := false
var _camera_button: BaseButton


func _physics_process(delta: float) -> void:
	var settings := Game.settings
	var B := InputBindings
	var push := {}
	for action in B.ACTIONS:
		push[action] = 0.0

	if use_keyboard:
		for who in ([0, 1] if both_keys else [person]):
			for action in B.ACTIONS:
				if B.key_down(settings, who, action):
					push[action] = 1.0

	var pads := Controllers.usable_joypads()
	if any_joypad and not pads.is_empty():
		if not pads.has(joypad):
			joypad = pads[0]
	elif Game.controllers != null:
		joypad = Game.controllers.device_of(person)
	if joypad >= 0:
		for action in B.ACTIONS:
			push[action] = maxf(push[action], B.strength(settings, person, action, joypad))

	var throttle: float = push.go
	var brake: float = push.brake
	var steer: float = push.right - push.left
	var reset: bool = push.reset > 0.5
	var gadget: Array[bool] = [push.gadget_1 > 0.5, push.gadget_2 > 0.5]
	var back: bool = push.look_back > 0.5
	var view: bool = push.view > 0.5
	var menu: bool = push.menu > 0.5
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
	_update_camera_button(view, delta)


## True once for each press of the change view key or button (or the camera
## button on the screen, which calls press_view()).
func take_view_press() -> bool:
	var pressed := _view_pressed
	_view_pressed = false
	return pressed


func press_view() -> void:
	if camera_controls_enabled:
		_view_pressed = true


func take_mirror_press() -> bool:
	var pressed := _mirror_pressed
	_mirror_pressed = false
	return pressed


## A tap changes view on release. A hold toggles the mirror once.
func _update_camera_button(down: bool, delta: float) -> void:
	if not camera_controls_enabled:
		cancel_camera_press()
		return
	if _wait_view_release:
		_wait_view_release = down
	else:
		if down:
			_view_time += delta
			if mirror_hold_enabled and _view_time >= VIEW_HOLD and not _view_consumed:
				_mirror_pressed = true
				_view_consumed = true
		elif _view_held:
			if not _view_consumed:
				_view_pressed = true
			_view_time = 0.0
			_view_consumed = false
		_view_held = down
	if _touch_view_held:
		_touch_view_time += delta
		if mirror_hold_enabled and _touch_view_time >= VIEW_HOLD and not _touch_view_consumed:
			_mirror_pressed = true
			_touch_view_consumed = true


func bind_camera_button(button: BaseButton) -> void:
	_camera_button = button
	button.button_down.connect(func() -> void:
		_touch_cancelled = not camera_controls_enabled
		_touch_view_held = camera_controls_enabled
		_touch_view_time = 0.0
		_touch_view_consumed = false)
	button.button_up.connect(func() -> void: _touch_view_held = false)
	button.pressed.connect(func() -> void:
		if not _touch_view_consumed and not _touch_cancelled:
			press_view())
	button.mouse_exited.connect(func() -> void:
		if _touch_view_held:
			_touch_view_held = false
			_touch_cancelled = true)


## Wait for release after a menu, focus loss or cancelled input.
func cancel_camera_press() -> void:
	_view_pressed = false
	_mirror_pressed = false
	_view_held = false
	_view_time = 0.0
	_view_consumed = false
	_wait_view_release = true
	_touch_view_held = false
	_touch_cancelled = true
	_touch_view_consumed = true
	if is_instance_valid(_camera_button):
		_camera_button.set_pressed_no_signal(false)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		cancel_camera_press()


## Whether this controller is this player's. With one player on their own,
## any controller is.
func owns_joypad(device: int) -> bool:
	return any_joypad or device == joypad
