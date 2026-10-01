class_name InputBindings
extends RefCounted

## Which keys and controller buttons do what, for each player. Each player has
## their own, kept in the settings, so two people can like different layouts.
##
## Every action has a key and up to two things on a controller, each a button
## or a stick or trigger pushed one way. With one player on their own, both
## players' keys work, so the arrows and WASD both drive.
##
## The menu is Start on a controller. On a keyboard it's always Esc, which is
## Back everywhere else too.

const ACTIONS := ["go", "brake", "left", "right", "reset", "gadget_1", "gadget_2", "look_back", "view", "menu"]
const NAMES := {
	"go": "Go", "brake": "Brake", "left": "Steer left", "right": "Steer right", "reset": "Reset",
	"gadget_1": "Power-up 1", "gadget_2": "Power-up 2", "look_back": "Look back", "view": "Change view", "menu": "Menu",
}
## How far a stick has to be pushed before it counts.
const DEADZONE := 0.15
## How many things on a controller one action can have.
const PAD_SLOTS := 2

const BUTTON := "button"
const AXIS := "axis"

## The keys for player 1 and player 2, by action.
const DEFAULT_KEYS := [
	{ "go": KEY_W, "brake": KEY_S, "left": KEY_A, "right": KEY_D, "reset": KEY_R, "gadget_1": KEY_Q, "gadget_2": KEY_E, "look_back": KEY_C, "view": KEY_V },
	{ "go": KEY_UP, "brake": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "reset": KEY_ENTER, "gadget_1": KEY_PERIOD, "gadget_2": KEY_SLASH, "look_back": KEY_COMMA, "view": KEY_M },
]
## The controller, the same for both to start with, as [kind, index, way].
const DEFAULT_PAD := {
	"go": [[AXIS, JOY_AXIS_TRIGGER_RIGHT, 1], [BUTTON, JOY_BUTTON_A, 1]],
	"brake": [[AXIS, JOY_AXIS_TRIGGER_LEFT, 1], [BUTTON, JOY_BUTTON_B, 1]],
	"left": [[AXIS, JOY_AXIS_LEFT_X, -1], [BUTTON, JOY_BUTTON_DPAD_LEFT, 1]],
	"right": [[AXIS, JOY_AXIS_LEFT_X, 1], [BUTTON, JOY_BUTTON_DPAD_RIGHT, 1]],
	"reset": [[BUTTON, JOY_BUTTON_Y, 1]],
	"gadget_1": [[BUTTON, JOY_BUTTON_X, 1]],
	"gadget_2": [[BUTTON, JOY_BUTTON_RIGHT_SHOULDER, 1]],
	"look_back": [[BUTTON, JOY_BUTTON_LEFT_SHOULDER, 1]],
	"view": [[BUTTON, JOY_BUTTON_BACK, 1]],
	"menu": [[BUTTON, JOY_BUTTON_START, 1]],
}

const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Home",
	JOY_BUTTON_LEFT_STICK: "Left stick in", JOY_BUTTON_RIGHT_STICK: "Right stick in",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const AXIS_NAMES := {
	JOY_AXIS_LEFT_X: ["Left stick left", "Left stick right"], JOY_AXIS_LEFT_Y: ["Left stick up", "Left stick down"],
	JOY_AXIS_RIGHT_X: ["Right stick left", "Right stick right"], JOY_AXIS_RIGHT_Y: ["Right stick up", "Right stick down"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"], JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}


## The player's key for an action, or KEY_NONE.
static func key(settings: ConfigFile, person: int, action: String) -> Key:
	var saved: Dictionary = settings.get_value("bindings", _section(person), {})
	if saved.has(action) and saved[action].has("key"):
		return saved[action].key
	return DEFAULT_KEYS[mini(person, 1)].get(action, KEY_NONE)


## The things on a controller for an action, as [kind, index, way].
static func pad(settings: ConfigFile, person: int, action: String) -> Array:
	var saved: Dictionary = settings.get_value("bindings", _section(person), {})
	if saved.has(action) and saved[action].has("pad"):
		return saved[action].pad
	return DEFAULT_PAD.get(action, [])


static func set_key(settings: ConfigFile, person: int, action: String, code: Key) -> void:
	_change(settings, person, action, "key", code)


## Puts a button, stick or trigger in one of an action's slots. An empty
## array clears the slot.
static func set_pad(settings: ConfigFile, person: int, action: String, slot: int, input: Array) -> void:
	var list := pad(settings, person, action).duplicate(true)
	while list.size() <= slot:
		list.append([])
	list[slot] = input
	list = list.filter(func(i: Array) -> bool: return not i.is_empty())
	_change(settings, person, action, "pad", list)


static func reset(settings: ConfigFile, person: int) -> void:
	if settings.has_section_key("bindings", _section(person)):
		settings.erase_section_key("bindings", _section(person))


static func _change(settings: ConfigFile, person: int, action: String, what: String, value: Variant) -> void:
	var saved: Dictionary = settings.get_value("bindings", _section(person), {}).duplicate(true)
	if not saved.has(action):
		saved[action] = {}
	saved[action][what] = value
	settings.set_value("bindings", _section(person), saved)


static func _section(person: int) -> String:
	return "player_%d" % (person + 1)


## How hard an action is pushed on this controller, from 0 to 1. Buttons are
## 0 or 1, and sticks and triggers in between.
static func strength(settings: ConfigFile, person: int, action: String, joypad: int) -> float:
	if joypad < 0:
		return 0.0
	var most := 0.0
	for input in pad(settings, person, action):
		most = maxf(most, input_strength(input, joypad))
	return most


static func input_strength(input: Array, joypad: int) -> float:
	if input.size() < 3:
		return 0.0
	if input[0] == BUTTON:
		return 1.0 if Input.is_joy_button_pressed(joypad, input[1]) else 0.0
	var value := Input.get_joy_axis(joypad, input[1]) * float(input[2])
	if value <= DEADZONE:
		return 0.0
	return inverse_lerp(DEADZONE, 1.0, minf(value, 1.0))


## Whether the player's key for an action is down.
static func key_down(settings: ConfigFile, person: int, action: String) -> bool:
	var code := key(settings, person, action)
	return code != KEY_NONE and Input.is_physical_key_pressed(code)


## The thing on a controller an event is, as [kind, index, way], for
## rebinding, or an empty array if it isn't one (or a stick only nudged).
static func from_event(event: InputEvent) -> Array:
	if event is InputEventJoypadButton and event.pressed:
		return [BUTTON, event.button_index, 1]
	if event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		return [AXIS, event.axis, 1 if event.axis_value > 0.0 else -1]
	return []


## What to call a key, for the settings.
static func key_name(code: Key) -> String:
	if code == KEY_NONE:
		return "None"
	# What the key says on this keyboard's layout, where there's a keyboard
	# to ask.
	if DisplayServer.get_name() != "headless":
		var local := DisplayServer.keyboard_get_keycode_from_physical(code)
		if local != KEY_NONE:
			return OS.get_keycode_string(local)
	return OS.get_keycode_string(code)


## What to call a button, stick or trigger, for the settings.
static func pad_name(input: Array) -> String:
	if input.size() < 3:
		return "None"
	if input[0] == BUTTON:
		return BUTTON_NAMES.get(input[1], "Button %d" % input[1])
	var names: Array = AXIS_NAMES.get(input[1], ["Axis %d -" % input[1], "Axis %d +" % input[1]])
	return names[1 if input[2] > 0 else 0]
