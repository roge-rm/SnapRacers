extends SceneTree

## Each player's keys and controller buttons (InputBindings), and which
## controller is whose (Controllers). With no real controller plugged in,
## the controller's buttons and sticks are pretend events.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/bindings_test.gd

const PAD := 0

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func button(index: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = PAD
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func stick(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = PAD
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _initialize() -> void:
	var settings := ConfigFile.new()
	var B := InputBindings

	# Out of the box it's the layout there's always been.
	check(B.key(settings, 0, "go") == KEY_W and B.key(settings, 1, "go") == KEY_UP, "player 1 goes with W and player 2 with Up")
	check(B.pad(settings, 0, "go") == [[B.AXIS, JOY_AXIS_TRIGGER_RIGHT, 1], [B.BUTTON, JOY_BUTTON_A, 1]], "and on a controller with RT or A")
	check(B.pad_name(B.pad(settings, 0, "left")[0]) == "Left stick left" and B.pad_name(B.pad(settings, 0, "menu")[0]) == "Start", "and they have names")

	# Buttons, triggers and sticks.
	button(JOY_BUTTON_A, true)
	check(is_equal_approx(B.strength(settings, 0, "go", PAD), 1.0), "A is full throttle")
	button(JOY_BUTTON_A, false)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.5)
	var half := B.strength(settings, 0, "go", PAD)
	check(half > 0.3 and half < 0.6, "half the trigger is about half throttle (%.2f)" % half)
	stick(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	stick(JOY_AXIS_LEFT_X, -0.1)
	check(B.strength(settings, 0, "left", PAD) == 0.0, "a stick just nudged doesn't steer")
	stick(JOY_AXIS_LEFT_X, -1.0)
	check(is_equal_approx(B.strength(settings, 0, "left", PAD), 1.0) and B.strength(settings, 0, "right", PAD) == 0.0, "the stick right over steers all the way, one way only")
	stick(JOY_AXIS_LEFT_X, 0.0)

	# Each player has their own, and changing one leaves the other alone.
	B.set_pad(settings, 1, "reset", 0, [B.BUTTON, JOY_BUTTON_LEFT_STICK, 1])
	B.set_key(settings, 1, "reset", KEY_BACKSPACE)
	check(B.pad(settings, 1, "reset") == [[B.BUTTON, JOY_BUTTON_LEFT_STICK, 1]] and B.key(settings, 1, "reset") == KEY_BACKSPACE, "player 2 can change their reset")
	check(B.pad(settings, 0, "reset") == [[B.BUTTON, JOY_BUTTON_Y, 1]] and B.key(settings, 0, "reset") == KEY_R, "and player 1's stays as it was")
	B.set_pad(settings, 1, "go", 1, [])
	check(B.pad(settings, 1, "go") == [[B.AXIS, JOY_AXIS_TRIGGER_RIGHT, 1]], "a slot can be cleared")
	var saved := ConfigFile.new()
	saved.parse(settings.encode_to_text())
	check(B.key(saved, 1, "reset") == KEY_BACKSPACE and B.pad(saved, 1, "go").size() == 1, "and it all survives being saved")
	B.reset(settings, 1)
	check(B.pad(settings, 1, "reset") == [[B.BUTTON, JOY_BUTTON_Y, 1]] and B.key(settings, 1, "reset") == KEY_ENTER, "Reset puts player 2 back how they were")

	# Picking up a press to rebind to.
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_X
	press.pressed = true
	var push := InputEventJoypadMotion.new()
	push.axis = JOY_AXIS_RIGHT_Y
	push.axis_value = -0.9
	check(B.from_event(press) == [B.BUTTON, JOY_BUTTON_X, 1], "a button press can be picked up to rebind")
	check(B.from_event(push) == [B.AXIS, JOY_AXIS_RIGHT_Y, -1], "and a stick pushed up")

	# Which controller is whose.
	var pads := Controllers.new()
	pads.settings = settings
	pads._on_connection(5, true)
	pads._on_connection(7, true)
	check(pads.device_of(0) == 5 and pads.device_of(1) == 7, "the first controller plugged in is player 1's and the next player 2's")
	pads.give(7, 0)
	check(pads.device_of(0) == 7 and pads.device_of(1) == 5, "giving player 1 the other one swaps them")
	pads._on_connection(7, false)
	check(pads.device_of(0) == -1 and pads.device_of(1) == 5, "unplugging one leaves its player without")
	pads._on_connection(9, true)
	check(pads.device_of(0) == 9, "and a new one goes to them")
	pads.free()

	print("All binding checks passed." if failures == 0 else "%d binding checks failed." % failures)
	quit(1 if failures > 0 else 0)
