extends Node

## The menus with a controller. The first press picks out the first button,
## the d-pad moves between buttons, A presses one, B goes back and LB and RB
## switch tabs. A touch puts the picked out button away again. In a race,
## Start opens the menu with Resume picked out.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/focus_test.tscn

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func screen() -> Node:
	for i in range(host.get_child_count() - 1, -1, -1):
		var child := host.get_child(i)
		if not child.is_queued_for_deletion():
			return child
	return null


func focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func pad(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await frames(2)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_menu()
	await frames(3)
	check(focused() == null, "nothing's picked out until a controller's used")
	await pad(JOY_BUTTON_DPAD_DOWN)
	var first := focused()
	check(first != null and first.text == "Single player", "the first press picks out the first button (%s)" % (first.text if first != null else "nothing"))
	await pad(JOY_BUTTON_DPAD_DOWN)
	var second := focused()
	check(second != null and second != first, "the d-pad moves down to the next (%s)" % (second.text if second != null else "nothing"))
	await pad(JOY_BUTTON_A)
	check(not screen() is MainMenu, "A presses it (%s)" % screen().get_class())
	check(focused() != null and screen().is_ancestor_of(focused()), "and the next screen has its first button picked out")
	await pad(JOY_BUTTON_B)
	check(screen() is MainMenu, "B goes back")

	Game.show_settings()
	await frames(3)
	var settings: SettingsScreen = screen()
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(settings._pages[1].visible, "RB goes to the next tab")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	check(settings._pages[0].visible, "and LB back again")
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(5, 5)
	touch.pressed = true
	Input.parse_input_event(touch)
	await frames(3)
	check(focused() == null or focused() is LineEdit, "a touch puts the picked out button away")
	# The driver builder's tabs.
	Game.show_driver()
	await frames(3)
	var builder := screen() as DriverBuilder
	var slot: String = builder.ui.slot
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(builder.ui.slot != slot, "RB goes to the driver builder's next tab (%s to %s)" % [slot, builder.ui.slot])
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	check(builder.ui.slot == slot, "and LB back")
	Game.show_menu()
	await frames(3)

	# In a race the controller drives, and Start opens the menu. The pretend
	# controller isn't plugged in, so it's given to player 1.
	Game.controllers.give(0, 0)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.start_race(Game.TRACKS + "/peach_pit.json")
	var race: Race = null
	while race == null:
		await frames(1)
		race = screen() as Race
	while not race.started:
		await frames(10)
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(focused() == null, "while racing the d-pad doesn't pick out a button")
	await pad(JOY_BUTTON_START)
	await frames(3)
	check(race.menu_open(race.player), "Start opens the race's menu")
	check(focused() == race._menus[race.player]._resume, "with Resume picked out")
	await pad(JOY_BUTTON_A)
	await frames(3)
	check(not race.menu_open(race.player) and not get_tree().paused, "and A on it carries on")
	race.leave()
	await frames(3)
	Game.controllers._on_connection(0, false)

	print("All focus checks passed." if failures == 0 else "%d focus checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
