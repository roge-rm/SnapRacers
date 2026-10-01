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


func _physics_process(_delta: float) -> void:
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

	if any_joypad:
		if not Input.get_connected_joypads().has(joypad):
			var pads := Input.get_connected_joypads()
			joypad = pads[0] if not pads.is_empty() else -1
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
