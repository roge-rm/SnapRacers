extends Node

## Two players on one phone, side by side and face to face. It checks that
## each player gets their own view, HUD, controls and power-up boxes, that the far half
## is turned around when you're face to face, and that both karts get going.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/split_test.tscn

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


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	var was_name = Game.settings.get_value("player", "name_two", "")
	var was_two = Game.settings.get_value("race", "player_two", "sparky")
	for mode in [Game.SIDE_BY_SIDE, Game.FACE_TO_FACE]:
		print("-- %s" % mode)
		# Set this for the run without saving over what was last picked. Face
		# to face, player 2 has a name and races the garage kart too.
		Game.settings.set_value("race", "split", mode)
		Game.settings.set_value("race", "player_two", "rocket" if mode == Game.SIDE_BY_SIDE else Game.OWN_KART)
		Game.settings.set_value("player", "name_two", "" if mode == Game.SIDE_BY_SIDE else "Gina")
		Game.settings.set_value("race", "kart", Game.OWN_KART)
		var before := race_on_screen()
		Game.start_race(Game.TRACKS + "/peach_pit.json")
		var race: Race = null
		while race == null or race == before:
			await get_tree().process_frame
			race = race_on_screen()
		await frames(2)
		await check_race(race, mode)
	# Races save the settings, so these go back and are saved too.
	Game.set_setting("player", "name_two", was_name)
	Game.set_setting("race", "player_two", was_two)
	print("All split screen checks passed." if failures == 0 else "%d split screen checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


func check_race(race: Race, mode: String) -> void:
	check(race.racers.size() == Race.KARTS, "still %d karts in all (%d)" % [Race.KARTS, race.racers.size()])
	check(race.humans.size() == 2 and race.humans[0] == race.player, "two of them people, player 1 first")
	var second := race.humans[1]
	if mode == Game.SIDE_BY_SIDE:
		check(second.name == "Player 2" and second.kart.design.name == "Rocket", "player 2 drives the kart picked for them (%s)" % second.kart.design.name)
		check(race.racers.filter(func(r): return r.kart.design.name == "Rocket").size() == 1, "and the AI doesn't drive another one")
	else:
		check(second.name == "Gina" and second.kart.design.name == Game.design.name, "player 2 goes by their own name, in the garage kart (%s, %s)" % [second.name, second.kart.design.name])

	var maps := race.find_children("*", "CourseMap", true, false)
	check(maps.size() == 1 and maps[0].shared() and maps[0].players.size() == 2, "there's one map, shared, with a dot for each player (%d)" % maps.size())
	check(race.humans.all(func(h): return h.hud.map == maps[0]), "and both players' menus change it")
	check(maps[0].across > CourseMap.SIZE, "bigger than one player's (%d)" % maps[0].across)
	var views := race.find_children("*", "SubViewport", true, false)
	check(views.size() == 2, "each has a view of their own (%d)" % views.size())
	for i in 2:
		var human := race.humans[i]
		var view: SubViewport = views[i]
		check(view.get_camera_3d() == human.camera and human.camera.target == human.kart, "player %d's view follows their kart" % (i + 1))
		check(human.hud.get_viewport() == view and human.hud.me == human, "with their own HUD in it")
		check(human.hud.touch.get_viewport() == view, "and their own touch controls")
		var own := PowerupField.layer_of(i)
		var theirs := PowerupField.layer_of(1 - i)
		check(human.camera.get_cull_mask_value(own) and not human.camera.get_cull_mask_value(theirs), "their camera shows their power-up boxes and not the other player's")
	check(race.boxes.viewers.size() == 2, "power-up boxes are kept for both")

	var holders: Array = views.map(func(v): return v.get_parent())
	if mode == Game.FACE_TO_FACE:
		check(is_equal_approx(holders[1].rotation, PI) and holders[0].rotation == 0.0, "face to face, player 2's half is turned all the way around")
		check(holders[0].anchor_top == 0.5 and holders[1].anchor_bottom == 0.5, "player 1 has the bottom half, player 2 the top")
	else:
		check(holders[0].rotation == 0.0 and holders[1].rotation == 0.0, "side by side, neither half is turned")
		check(holders[0].anchor_right == 0.5 and holders[1].anchor_left == 0.5, "player 1 has the left half, player 2 the right")

	# A thumb on GO in player 2's half drives player 2 and not player 1.
	for human in race.humans:
		human.hud.touch.visible = true
	var touch := second.hud.touch
	var gas: Vector2 = touch._buttons()["gas"][0]
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = gas
	views[1].push_input(press, true)
	await frames(2)
	check(second.input.controls.throttle == 1.0 and race.player.input.controls.throttle == 0.0, "GO in player 2's half is theirs alone")
	var lift := press.duplicate()
	lift.pressed = false
	views[1].push_input(lift, true)
	await frames(2)
	check(second.input.controls.throttle == 0.0, "and lets go when they do")

	# The steering stick stays put in the corner, and the knob goes where
	# your thumb is.
	var stick: Array = touch._stick()
	var middle: Vector2 = stick[0]
	var travel: float = stick[1] * 0.68
	var steers := []
	for across in [0.5, 1.0, 1.4, -1.0]:
		var hold := InputEventScreenTouch.new()
		hold.index = 1
		hold.pressed = true
		hold.position = middle + Vector2(travel * across, 0.0)
		views[1].push_input(hold, true)
		await frames(2)
		steers.append(second.input.controls.steer)
		var up := hold.duplicate()
		up.pressed = false
		views[1].push_input(up, true)
		await frames(2)
	check(steers[0] > 0.1 and steers[0] < 0.5, "halfway across the stick is a gentle steer (%.2f)" % steers[0])
	check(is_equal_approx(steers[1], 1.0) and is_equal_approx(steers[2], 1.0), "the edge is full lock, and past it too")
	check(is_equal_approx(steers[3], -1.0), "and the other edge is full lock the other way")
	check(second.input.controls.steer == 0.0, "it springs back when you let go")
	var away := InputEventScreenTouch.new()
	away.index = 1
	away.pressed = true
	away.position = Vector2(middle.x + travel, touch.size.y * 0.2)
	views[1].push_input(away, true)
	await frames(2)
	check(second.input.controls.steer == 0.0, "a thumb nowhere near the stick doesn't steer")
	away.pressed = false
	views[1].push_input(away, true)

	# Each player's own keys and controller. Player 2's go key is changed to
	# G, and a pretend controller is given to player 2.
	var settings := Game.settings
	var had: Variant = settings.get_value("bindings", "player_2", null)
	InputBindings.set_key(settings, 1, "go", KEY_G)
	await _key(KEY_G, true)
	check(second.input.controls.throttle == 1.0 and race.player.input.controls.throttle == 0.0, "player 2's own key drives them and not player 1")
	await _key(KEY_G, false)
	await _key(KEY_W, true)
	check(race.player.input.controls.throttle == 1.0 and second.input.controls.throttle == 0.0, "and W is still player 1's")
	await _key(KEY_W, false)
	var pad := 12
	Game.controllers.give(pad, 1)
	await _pad(pad, JOY_BUTTON_A, true)
	check(second.input.controls.throttle == 1.0 and race.player.input.controls.throttle == 0.0, "the controller given to player 2 drives player 2")
	await _pad(pad, JOY_BUTTON_A, false)
	await _pad(pad, JOY_BUTTON_START, true)
	await frames(2)
	check(race.menu_open(second) and not race.menu_open(race.player), "and its Start opens player 2's menu")
	await _pad(pad, JOY_BUTTON_START, false)
	race.close_menu(second)
	Game.controllers._on_connection(pad, false)
	if had == null:
		settings.erase_section_key("bindings", "player_2")
	else:
		settings.set_value("bindings", "player_2", had)

	# Let the AI drive both of them for a bit.
	for human in race.humans:
		var driver := AIDriver.new()
		driver.kart = human.kart
		driver.track = race.track
		driver.others.assign(race.racers.map(func(r): return r.kart))
		race.add_child(driver)
		human.ai = driver
		human.kart.controls = driver.controls
	var from: Array = race.humans.map(func(h): return h.progress.distance())
	await frames(60 * 15)
	for i in 2:
		var went: float = race.humans[i].progress.distance() - from[i]
		check(went > 60.0, "player %d gets going (%.0f m)" % [i + 1, went])
		check(race.humans[i].hud._place.text.begins_with(RaceHud.ordinal(race.place_of(race.humans[i]))), "and their HUD shows their own place (%s)" % race.humans[i].hud._place.text)

	# Finishing shows the results to whoever finished.
	race._player_finished(second)
	check(second.hud._results.visible and not race.player.hud._results.visible, "results come up in the half of whoever finished")


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)


func _pad(device: int, index: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)
