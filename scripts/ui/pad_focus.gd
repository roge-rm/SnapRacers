class_name PadFocus
extends Node

## Makes the menus work with a controller or the keys. The first time a
## controller button or an arrow key is pressed, the first button on the
## screen is picked out, and from there the d-pad, the stick and the arrows
## move between buttons, A or Enter presses one, and B goes back. LB and RB
## switch tabs on a screen that has them (one with a `next_tab(by)`).
##
## A touch or a click puts the picked out button away again, so the outline
## only shows while you're using a controller or the keys.
##
## In a race the driving controls have the buttons, so this keeps out of the
## way unless the race's menu or the results are up. Screens with their own
## way of using a controller and keys, like the garage, say so with
## `own_controls()`.

## How far a stick has to be pushed to count as moving.
const PUSH := 0.6

## The screen it's working on, and going back from it, from Game.
var screen: Callable
var back: Callable
## Whether a controller or the keys were used last, rather than a touch or
## the mouse.
static var using_pad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		using_pad = false
		# A tapped button takes the focus, so let it go again afterwards.
		_drop_focus.call_deferred()
		return
	if not _navigating(event):
		return
	using_pad = true
	var current: Node = screen.call() if screen.is_valid() else null
	if current is Race:
		current = _race_part(current)
	elif current != null and current.has_method("own_controls") and current.own_controls():
		return
	if current == null:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B and not current is RaceMenu:
			viewport.set_input_as_handled()
			back.call()
			return
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER] and current.has_method("next_tab"):
			viewport.set_input_as_handled()
			current.next_tab(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			return
	if viewport.gui_get_focus_owner() == null or not viewport.gui_get_focus_owner().is_visible_in_tree():
		var first := first_button(current)
		if first != null:
			first.grab_focus()
			viewport.set_input_as_handled()


func _drop_focus() -> void:
	if using_pad:
		return
	var focused := get_viewport().gui_get_focus_owner()
	# Typing boxes keep their focus, so the keyboard stays up.
	if focused != null and not focused is LineEdit:
		focused.release_focus()


## The part of a race that's a menu now: someone's open menu, or the results
## once they're up, or nothing while everyone's driving.
static func _race_part(race: Race) -> Node:
	if not race._menus.is_empty():
		return race._menus.values()[0]
	for racer in race.humans:
		if racer.hud != null and racer.hud._results.visible:
			return racer.hud._results
	return null


## Picks out the first button on a screen when it opens, if a controller or
## the keys are being used.
static func focus_first(root: Node) -> void:
	if not using_pad or root == null:
		return
	var first := first_button(root)
	if first != null:
		first.grab_focus()


## Whether this is a controller or key press that moves around a menu.
func _navigating(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > PUSH and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
	if event is InputEventKey and event.pressed:
		return event.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB]
	return false


## The button nearest the top left that can be picked out, or null.
static func first_button(root: Node) -> Control:
	var best: Control = null
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree() or control is LineEdit:
			continue
		if not (control is BaseButton or control is Slider):
			continue
		if best == null or _before(control, best):
			best = control
	return best


static func _before(a: Control, b: Control) -> bool:
	var pa := a.get_global_rect().position
	var pb := b.get_global_rect().position
	if absf(pa.y - pb.y) > 8.0:
		return pa.y < pb.y
	return pa.x < pb.x
