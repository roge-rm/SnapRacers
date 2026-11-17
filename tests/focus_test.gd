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


func keyboard() -> PadKeyboard:
	var found := get_tree().root.find_children("*", "PadKeyboard", true, false).filter(func(k): return not k.is_queued_for_deletion())
	return found[0] if not found.is_empty() else null


## Typing with only a controller: A on a typing box brings up a keyboard on
## the screen, A types the key picked out, X deletes, Y is a space, and Start
## or B is done.
func _typing() -> void:
	var was: String = Game.settings.get_value("player", "name", "")
	Game.show_settings()
	await frames(3)
	var box: LineEdit = screen().find_children("*", "LineEdit", true, false)[0]
	box.text = ""
	box.grab_focus()
	await pad(JOY_BUTTON_A)
	check(keyboard() != null and keyboard().visible, "A on a typing box brings up a keyboard")
	await frames(2)
	var key := keyboard().gui_get_focus_owner() if keyboard() != null else null
	check(key is Button and keyboard()._letters.has(key), "with a letter picked out (%s)" % (key.text if key != null else "nothing"))
	await pad(JOY_BUTTON_A)
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_A)
	check(box.text == "Qw", "A types the key picked out, a capital to start (%s)" % box.text)
	await pad(JOY_BUTTON_Y)
	await pad(JOY_BUTTON_A)
	check(box.text == "Qw W", "Y is a space, and the next word starts with a capital (%s)" % box.text)
	await pad(JOY_BUTTON_X)
	await pad(JOY_BUTTON_X)
	check(box.text == "Qw", "X deletes (%s)" % box.text)
	check(Game.settings.get_value("player", "name", "") == "Qw", "and the name's saved as it's typed")
	await pad(JOY_BUTTON_B)
	check(keyboard() == null and screen() is SettingsScreen, "B is done, without leaving the screen")
	check(focused() == box, "and the box is picked out again")
	Game.set_setting("player", "name", was)

	# In a dialog, like naming a kart in the garage, done is the same as
	# pressing Rename.
	Game.show_garage()
	await frames(3)
	var garage: Garage = screen()
	garage.ui._open_rename()
	await frames(2)
	await pad(JOY_BUTTON_A)
	check(keyboard() != null, "naming a kart in the garage brings it up too")
	for i in 40:
		await pad(JOY_BUTTON_X)
	await frames(2)
	await pad(JOY_BUTTON_A)
	await pad(JOY_BUTTON_START)
	await frames(3)
	check(keyboard() == null and not garage.ui._name_dialog.visible and garage.design.name == "Q", "and Start is done, which renames it (%s)" % garage.design.name)


## First visit picks out the top left item, not Back, and coming back to a
## screen picks out what was picked out when leaving.
func _memory() -> void:
	PadFocus.forget()
	var cups := GrandPrix.cups()
	Game.show_cups()
	await frames(3)
	var start := focused()
	check(start != null and start.get_meta("cup", "") == cups[0].id, "a first visit picks out the top left cup, not Back")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_DPAD_RIGHT)
	check(focused().get_meta("cup", "") == cups[2].id, "moved to the third cup")
	await pad(JOY_BUTTON_A)
	await frames(3)
	check(not screen() is CupGrid, "opening it leaves the grid (%s)" % screen().get_class())
	await pad(JOY_BUTTON_B)
	await frames(3)
	check(screen() is CupGrid and focused() != null and focused().get_meta("cup", "") == cups[2].id, "coming back picks out the third cup again")
	# A cup's course page has its own memory, and so has each cup.
	Game.show_course_grid(Game.MODE_RACE, false, cups[1].id)
	await frames(3)
	var courses := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("track"))
	check(focused() == courses[0], "a course page starts at its top left course")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	var second_track: String = focused().get_meta("track", "")
	check(second_track == courses[1].get_meta("track"), "moved to the second course")
	Game.show_menu()
	await frames(3)
	Game.show_course_grid(Game.MODE_RACE, false, cups[1].id)
	await frames(3)
	check(focused() != null and focused().get_meta("track", "") == second_track, "back on the course page picks out the second course again")
	Game.show_course_grid(Game.MODE_RACE, false, cups[2].id)
	await frames(3)
	var other := screen().find_children("*", "Button", true, false).filter(func(b): return b.has_meta("track"))
	check(focused() == other[0], "another cup's course page starts top left")
	# Your cups is kept apart from the Grand Prix cups.
	Game.show_your_cups()
	await frames(3)
	check(focused() != null and not focused().has_meta("cup") or focused().get_meta("cup") != cups[2].id, "Your cups doesn't take the Grand Prix pick")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	var mine := focused()
	var mine_id: String = str(mine.get_meta("cup", mine.get_meta("make", mine.get_meta("add", "?"))))
	Game.show_menu()
	await frames(3)
	Game.show_your_cups()
	await frames(3)
	var again := focused()
	check(again != null and str(again.get_meta("cup", again.get_meta("make", again.get_meta("add", "?")))) == mine_id, "back in Your cups picks out the same one")
	PadFocus.forget()
	Game.show_menu()
	await frames(3)


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
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(5, 5)
		touch.pressed = down
		Input.parse_input_event(touch)
		await frames(3)
	check(focused() == null or focused() is LineEdit, "a touch puts the picked out button away")
	# A button keeps its focus while a finger's held down on it, since losing it
	# would stop the press, and lets go once the finger's up.
	Game.show_single_player()
	await frames(3)
	var held: Button = screen().find_children("*", "Button", true, false)[0]
	var watcher: PadFocus = Game.get_children().filter(func(n): return n is PadFocus)[0]
	held.grab_focus()
	for down in [true, false]:
		var finger := InputEventScreenTouch.new()
		finger.pressed = down
		watcher._input(finger)
		await frames(3)
		if down:
			check(focused() == held, "a button keeps its focus while it's held down")
	check(focused() == null, "and lets it go once the finger's up")
	# Start on the kart picker goes on, like the Race button.
	var went := [0]
	Game.show_kart_picker(func(): went[0] += 1, Game.show_menu)
	await frames(3)
	await pad(JOY_BUTTON_START)
	check(went[0] == 1, "Start on the kart picker does what Race does")
	await _memory()
	# The driver builder's tabs.
	Game.show_driver()
	await frames(3)
	var builder := screen() as DriverBuilder
	var slot: String = builder.ui.slot
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(builder.ui.slot != slot, "RB goes to the driver builder's next tab (%s to %s)" % [slot, builder.ui.slot])
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	check(builder.ui.slot == slot, "and LB back")
	# The colours drawer puts away and comes back with the focus on it.
	var colours: ColourDrawer = builder.ui._colours
	colours._shut.grab_focus()
	colours._shut.pressed.emit()
	await frames(2)
	check(not colours.visible and focused() == colours.handle, "the colours drawer puts away, and the focus goes to its handle")
	await pad(JOY_BUTTON_A)
	await frames(2)
	check(colours.visible and focused() == colours._shut, "and A on the handle brings it back")
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(focused() != null and colours.is_ancestor_of(focused()), "the d-pad goes down into its colours (%s)" % focused())
	await _typing()
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

	# With the Switch layout everything after the window sees A and B, and X
	# and Y, swapped, going by what's printed on the controller.
	Controllers.swapped[0] = true
	var seen := []
	var listen := func(event: InputEvent) -> void:
		if event is InputEventJoypadButton and event.pressed:
			seen.append(event.button_index)
	get_tree().root.window_input.connect(listen)
	await pad(JOY_BUTTON_Y)
	await pad(JOY_BUTTON_B)
	check(seen == [JOY_BUTTON_X, JOY_BUTTON_A], "with the Switch layout Y comes through as X and B as A (%s)" % [seen])
	get_tree().root.window_input.disconnect(listen)
	Controllers.swapped.clear()

	print("All focus checks passed." if failures == 0 else "%d focus checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
