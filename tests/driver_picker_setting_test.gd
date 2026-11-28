extends Node

## The Settings toggle for the driver picker step: where a race setup lands
## with it on and off, for one player and two, and where Back goes.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/driver_picker_setting_test.tscn

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var saved = Game.settings.get_value("race", "driver_picker", true)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	await frames(5)
	check(Game.driver_picker_step(), "on by default")

	Game.show_settings()
	await frames(3)
	var toggles := Game._screen.find_children("*", "CheckButton", true, false)
	check(toggles.size() >= 1 and toggles[0].button_pressed, "the Settings screen shows it on")
	toggles[0].button_pressed = false
	check(not Game.driver_picker_step(), "the toggle turns it off")
	toggles[0].button_pressed = true
	check(Game.driver_picker_step(), "and on again")

	# On: the driver comes first.
	await _flow(false, true)
	await _flow(true, true)
	Game.set_setting("race", "driver_picker", false)
	await _flow(false, false)
	await _flow(true, false)

	for on in [true, false]:
		Game.set_setting("race", "driver_picker", on)
		await _two_setup(on)

	Game.set_setting("race", "driver_picker", saved)
	print("driver picker setting test: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Two players set up first, then `go` shows the cups, and Back from the cups
## returns to player 2's kart page.
func _two_setup(on: bool) -> void:
	var tag := "setup for two, %s" % ("on" if on else "off")
	var went := [0]
	Game.show_menu()
	await frames(2)
	Game.show_two_setup(func(): went[0] += 1)
	await frames(3)
	var s: Node = Game._screen
	check(s is DriverPicker if on else s is KartPicker, "%s: starts with player 1" % tag)
	for i in 4:
		s = Game._screen
		if went[0] > 0:
			break
		if s is DriverPicker:
			s.grid.marked_card().pressed.emit()
		else:
			s._go.call()
		await frames(3)
	check(went[0] == 1, "%s: after player 2's kart it goes on" % tag)
	check(Game.two_setup_end.is_valid(), "%s: player 2's kart page can be come back to" % tag)
	Game.two_setup_end.call()
	await frames(3)
	check(Game._screen is KartPicker and Game._screen.player == 2 and Game._screen._difficulty_row == null, "%s: it's player 2's kart, with no difficulty" % tag)
	Game._go_back()
	await frames(3)
	check(Game._screen is DriverPicker if on else Game._screen is KartPicker and Game._screen.player == 1, "%s: Back goes a page" % tag)


func _flow(two: bool, on: bool) -> void:
	var tag := "%s, %s" % ["two" if two else "one", "on" if on else "off"]
	var done := [false, false]
	Game.show_menu()
	await frames(2)
	Game.show_race_setup(func(): done[0] = true, func(): done[1] = true, true, two)
	await frames(3)
	var s: Node = Game._screen
	if on:
		check(s is DriverPicker and s.player == (1 if two else 0), "%s: driver first" % tag)
		s.grid.marked_card().pressed.emit()
		await frames(3)
		s = Game._screen
	check(s is KartPicker and s.player == (1 if two else 0), "%s: kart picker for the first player" % tag)
	if two:
		s._go.call()
		await frames(3)
		s = Game._screen
		if on:
			check(s is DriverPicker and s.player == 2, "%s: player 2 driver" % tag)
			s.grid.marked_card().pressed.emit()
			await frames(3)
			s = Game._screen
		check(s is KartPicker and s.player == 2, "%s: kart picker for player 2" % tag)
		Game._go_back()
		await frames(3)
		s = Game._screen
		if on:
			check(s is DriverPicker and s.player == 2, "%s: back from player 2 karts to their driver" % tag)
			Game._go_back()
			await frames(3)
			s = Game._screen
		check(s is KartPicker and s.player == 1, "%s: then player 1 karts" % tag)
	Game._go_back()
	await frames(3)
	s = Game._screen
	if on:
		check(s is DriverPicker, "%s: back from karts to the driver" % tag)
		Game._go_back()
		await frames(3)
	check(done[1] and not done[0], "%s: Back leaves the setup" % tag)
