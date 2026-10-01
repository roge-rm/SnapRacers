extends Node

## The menu in a race. In a single player race it pauses everything, its
## settings work straight away, Resume carries on and Quit leaves. Esc opens
## and closes it. In split screen each player opens their own, and the race
## carries on.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/pause_test.tscn

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func race_on_screen() -> Race:
	for child in host.get_children():
		if child is Race and not child.is_queued_for_deletion():
			return child
	return null


func start(split: String) -> Race:
	# Set this for the run without saving over what was last picked.
	Game.settings.set_value("race", "split", split)
	Game.settings.set_value("race", "kart", Game.OWN_KART)
	var before := race_on_screen()
	Game.start_race(Game.TRACKS + "/peach_pit.json")
	var race: Race = null
	while race == null or race == before:
		await get_tree().process_frame
		race = race_on_screen()
	while not race.started:
		await frames(10)
	await frames(60)
	return race


func _ready() -> void:
	# This keeps going while the race is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	var map_was := Game.map_view(0)
	var camera_was := Game.camera_view(0)
	var split_was := Game.split()

	var race := await start(Game.SOLO)
	var me := race.humans[0]
	var hud: RaceHud = me.hud
	var menu_button: IconButton = hud._menu
	check(menu_button.visible and menu_button.picture == "pause", "there's a menu button at the top")
	menu_button.pressed.emit()
	await frames(2)
	check(race.menu_open(me) and get_tree().paused, "it opens the menu and pauses the race")
	var time := race.time
	var at := me.kart.global_position
	await frames(60)
	check(race.time == time and me.kart.global_position.is_equal_approx(at), "nothing moves while it's paused (%.2f s, %.2f m)" % [race.time - time, me.kart.global_position.distance_to(at)])
	var menu: RaceMenu = race._menus[me]
	check(menu.can_restart and menu.find_children("*", "Button", true, false).any(func(b): return b.text == "QUIT THE RACE"), "with Restart and Quit in it")
	var mode := hud.map.mode
	menu._next_map()
	check(hud.map.mode != mode and Game.map_view(0) == hud.map.mode, "changing the map there changes it straight away")
	var view: String = me.camera.view
	menu._camera_button.pressed.emit()
	check(me.camera.view != view, "and the camera too")
	menu.resume_pressed.emit()
	await frames(30)
	check(not race.menu_open(me) and not get_tree().paused and race.time > time, "Resume carries on")

	race.go_back()
	await frames(2)
	check(race.menu_open(me) and get_tree().paused, "Esc opens it")
	race.go_back()
	await frames(2)
	check(not race.menu_open(me) and not get_tree().paused, "and closes it again")

	race.open_menu(me)
	await frames(2)
	race._menus[me].quit_pressed.emit()
	await frames(5)
	check(race_on_screen() == null and not get_tree().paused, "Quit leaves the race, and nothing's paused after")

	race = await start(Game.SIDE_BY_SIDE)
	var second := race.humans[1]
	race.open_menu(second)
	await frames(2)
	time = race.time
	await frames(30)
	check(race.menu_open(second) and not race.menu_open(race.humans[0]), "in split screen player 2 opens their own menu")
	check(not get_tree().paused and race.time > time, "and the race carries on")
	check(race._menus[second].get_viewport() == second.hud.get_viewport() and not race._menus[second].can_restart == false, "in their own half")
	race.go_back()
	race.leave()
	await frames(5)

	# The split goes back first, since putting the views back saves.
	Game.settings.set_value("race", "split", split_was)
	Game.set_map_view(0, map_was)
	Game.set_camera_view(0, camera_was)
	print("All pause checks passed." if failures == 0 else "%d pause checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
