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
## The item last picked out on each kind of screen (the screen's script path
## to the item's child numbers down from the screen), kept until the game quits.
static var _memory := {}
static var _current: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_current = screen
	get_viewport().gui_focus_changed.connect(_remember)


## A lambda left in a static when the game quits frees memory twice.
func _exit_tree() -> void:
	_current = Callable()


func _input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		using_pad = false
		# A tapped button takes the focus, so let it go again once the finger's
		# up. Letting go any sooner stops the button being pressed.
		if not event.pressed:
			_drop_focus.call_deferred()
		return
	if not _navigating(event):
		return
	using_pad = true
	var current: Node = screen.call() if screen.is_valid() else null
	if current is Race:
		current = _race_part(current, event)
	elif current != null and current.has_method("own_controls") and current.own_controls():
		return
	if current == null:
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B and not current is RaceMenu:
			viewport.set_input_as_handled()
			back.call()
			return
		if event.button_index == JOY_BUTTON_START and current.has_method("on_start"):
			viewport.set_input_as_handled()
			current.on_start()
			return
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER] and current.has_method("next_tab"):
			viewport.set_input_as_handled()
			current.next_tab(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			return
	# In split screen the results are in a half with its own viewport, so its
	# focus is looked for there. Looking only here, every press would pick the
	# first button again and never get through to the half. The halves share
	# one focus, so a player's first press after the other's takes it back.
	var focused := (current as Node).get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree():
		var first: Control = current.refocus() if current.has_method("refocus") else null
		if first == null:
			first = pick(current)
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
## once they're up, or the standings over the podium, or nothing while
## everyone's driving. A controller only works the results of the player
## it belongs to.
static func _race_part(race: Race, event: InputEvent = null) -> Node:
	if race.cup_standings != null:
		return race.cup_standings
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if not race._menus.is_empty():
		if race._can_pause() or not pad:
			return race._menus.values()[0]
		# Online each player has their own menu.
		for racer in race._menus:
			if racer.input == null or racer.input.owns_joypad(event.device):
				return race._menus[racer]
		return null
	for racer in race.humans:
		if pad and racer.input != null and not racer.input.owns_joypad(event.device):
			continue
		if racer.hud != null and racer.hud._results.visible:
			return racer.hud._results
	return null


## Picks out the first button on a screen when it opens, if a controller or
## the keys are being used.
static func focus_first(root: Node) -> void:
	if not using_pad or root == null:
		return
	var first := pick(root)
	if first != null:
		first.grab_focus()


## Forgets which item was picked out on every screen.
static func forget() -> void:
	_memory.clear()


## The screen the control is on, or null.
static func _screen_of(control: Node) -> Node:
	var current: Node = _current.call() if _current.is_valid() else null
	if current != null and is_instance_of(control, Control) and current.is_ancestor_of(control):
		return current
	return null


func _remember(control: Control) -> void:
	var current := _screen_of(control)
	if not using_pad or current == null or current.get_script() == null or not (control is BaseButton or control is Slider):
		return
	var path: Array = []
	var node: Node = control
	while node != current:
		path.push_front(node.get_index())
		node = node.get_parent()
	_memory[_key(current)] = {"id": _id(control, current), "path": path}


## What the remembered items of a screen are filed under: the screen's own
## `focus_key()` if it has one (for screens that show different things), else
## its script.
static func _key(current: Node) -> String:
	if current.has_method("focus_key"):
		return current.focus_key()
	return current.get_script().resource_path


## A name for an item that stays the same when the list around it changes:
## its card's id (cup, course) with the button's words if it's inside the card.
static func _id(control: Control, current: Node) -> String:
	var node: Node = control
	while node != current:
		for key in ["cup", "track", "make", "add", "yours"]:
			if node.has_meta(key):
				var base := "%s:%s" % [key, node.get_meta(key)]
				if node != control and control is Button:
					base += "/" + control.text
				return base
		node = node.get_parent()
	return "text:" + control.text if control is Button and control.text != "" else ""


## What to pick out when `root` opens: the item that was picked out last time
## on this screen if it's still there, else the first one.
static func pick(root: Node) -> Control:
	var current: Node = _current.call() if _current.is_valid() else null
	if current != null and current.get_script() != null and _memory.has(_key(current)) and (root == current or current.is_ancestor_of(root)):
		var saved: Dictionary = _memory[_key(current)]
		if saved.id != "":
			for node in root.find_children("*", "Control", true, false):
				var control := node as Control
				if _usable(control) and _id(control, current) == saved.id:
					return control
		var node: Node = current
		for index in saved.path:
			if index >= node.get_child_count():
				node = null
				break
			node = node.get_child(index)
		var control := node as Control
		if saved.id == "" and control != null and _usable(control) and (root == control or root.is_ancestor_of(control)):
			return control
	return first_button(root)


static func _usable(control: Control) -> bool:
	return control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and control.disabled) and control.is_visible_in_tree() and not control.is_queued_for_deletion() and (control is BaseButton or control is Slider)


## B closes a window that doesn't close on B by itself, like the share and
## add windows and the dialogs, where it's Cancel.
static func close_on_b(window: Window) -> void:
	window.window_input.connect(func(event: InputEvent) -> void:
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
			window.set_input_as_handled()
			window.hide()
			if window is AcceptDialog:
				window.canceled.emit())


## Whether this is a controller or key press that moves around a menu.
func _navigating(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > PUSH and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
	if event is InputEventKey and event.pressed:
		return event.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_TAB]
	return false


## The button nearest the top left that can be picked out, or null. Back,
## Close and the other small buttons only count when nothing else is there.
static func first_button(root: Node) -> Control:
	var best: Control = null
	var best_small := true
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control is LineEdit or not _usable(control):
			continue
		var small := control is Button and control.theme_type_variation == &"SmallButton"
		if best == null or (best_small and not small) or (small == best_small and _before(control, best)):
			best = control
			best_small = small
	return best


static func _before(a: Control, b: Control) -> bool:
	var pa := a.get_global_rect().position
	var pb := b.get_global_rect().position
	if absf(pa.y - pb.y) > 8.0:
		return pa.y < pb.y
	return pa.x < pb.x
