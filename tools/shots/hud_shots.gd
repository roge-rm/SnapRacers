extends Node

## Takes a picture of the race screen with everything it can show at once: a
## lap time just done, a quick note, and the slowdown after a reset. Name the
## clock's place after the course: top, right or corner (see RaceHud.clock_at).
## It needs a screen, and saves in build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/hud_shots.tscn -- hairpin_hall top
##
## With "slots" it takes the power-up boxes instead: empty, one filled, both
## filled with a count, then side by side and face to face, and a sheet of
## every power-up's picture. Then a name for the end of each file and the
## window's size, and SNAPRACERS_CUTOUT tries a camera hole. An upright
## window only takes face to face. Under xvfb-run the window is the screen.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/hud_shots.tscn -- slots 1280 1280x720
##
## With "screens" it takes the whole race screen with the touch controls up
## and two gadgets held, then the race's menu, then the results, alone, side
## by side and face to face, into a folder at a window size. SNAPRACERS_CUTOUT
## tries a camera hole, drawn in black on the pictures. SNAPRACERS_HELD picks
## the two gadgets held, like "cannon,shield".
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --windowed --path . res://tools/shots/hud_shots.tscn -- screens /srv/downloads/temp/debug/snapracers/ui-looks/m5 1280x800

##
## With "touch" it takes the race screen with the touch controls at each
## size, then Medium at the lowest and highest height, into a folder with a
## name on the end. Run it under xvfb-run with the screen the size to try, and
## SNAPRACERS_DPI for that screen's dots per inch.
##   SNAPRACERS_DPI=206 xvfb-run -s "-screen 0 1920x1200x24" tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/hud_shots.tscn -- touch /srv/downloads/temp/debug/snapracers/touch-size tab

const OUT := "res://build/shots"


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args := OS.get_cmdline_user_args()
	if args.size() > 2 and args[0] == "screens":
		await _screens(args[1], args[2])
		get_tree().quit()
		return
	if args.size() > 2 and args[0] == "touch":
		await _touch_sizes(args[1], args[2])
		get_tree().quit()
		return
	if args.size() > 0 and args[0] == "slots":
		await _slots(args[1] if args.size() > 1 else "", args[2] if args.size() > 2 else "1280x720")
		get_tree().quit()
		return
	var course: String = args[0] if args.size() > 0 else "hairpin_hall"
	RaceHud.clock_at = args[1] if args.size() > 1 else "right"
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.racing_alone = true
	Game.show_race(Game.TRACKS + "/" + course + ".json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await frames(10)
	var kart := race.player.kart
	var driver := AIDriver.new()
	driver.kart = kart
	driver.track = race.track
	race.add_child(driver)
	race.player.ai = driver
	kart.controls = driver.controls
	await frames(600)
	race.player.progress.lap_times.append(58.42)
	kart.slowdown_left = Kart.RESET_SLOWDOWN_TIME * 0.6
	race.player.hud.flash("Chase camera")
	await frames(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/hud_%s.png" % [OUT, RaceHud.clock_at])
	print("saved ", RaceHud.clock_at)
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)


func _start(host: Node, split: String) -> Race:
	Game.settings.set_value("race", "split", split)
	Game.racing_alone = split == Game.SOLO
	for child in host.get_children():
		if child is Race:
			child.queue_free()
	await get_tree().process_frame
	Game.start_race(Game.TRACKS + "/peach_pit.json")
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race and not child.is_queued_for_deletion():
				race = child
	while not race.started:
		await frames(10)
	await frames(200)
	return race


func _slots(tag: String, window_size: String) -> void:
	var end := "_" + tag if tag != "" else ""
	var wh := window_size.split_floats("x")
	var window := Vector2i(int(wh[0]), int(wh[1]))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window)
	await frames(10)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var split_was = Game.settings.get_value("race", "split", Game.SOLO)
	# Face to face is for a phone held upright, so an upright window only
	# takes that.
	var upright := window.y > window.x
	if not upright:
		await _solo(host, end)
	for split in [Game.SIDE_BY_SIDE, Game.FACE_TO_FACE] if not upright else [Game.FACE_TO_FACE]:
		var race := await _start(host, split)
		race.humans[0].kart.held = ["shield", ""]
		race.humans[0].kart.held_uses = [1, 0]
		race.humans[1].kart.held = ["homing", "triple_turbo"]
		race.humans[1].kart.held_uses = [1, 2]
		await frames(30)
		await _save("slots_%s%s" % [split, end])
	Game.settings.set_value("race", "split", split_was)
	for child in host.get_children():
		child.queue_free()
	if upright:
		return
	# Every picture, empty and held, on one sheet.
	var sheet := _Sheet.new()
	add_child(sheet)
	await frames(4)
	await _save("slots_icons" + end)


func _screens(folder: String, window_size: String) -> void:
	var wh := window_size.split_floats("x")
	get_window().mode = Window.MODE_WINDOWED
	await frames(5)
	get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	await frames(10)
	DirAccess.make_dir_recursive_absolute(folder)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var split_was = Game.settings.get_value("race", "split", Game.SOLO)
	# Face to face is for a phone held upright, so an upright window only
	# takes that.
	var splits := [Game.SOLO, Game.SIDE_BY_SIDE, Game.FACE_TO_FACE] if wh[0] > wh[1] else [Game.FACE_TO_FACE]
	for split in splits:
		var race := await _start(host, split)
		var tag: String = split if split != Game.SOLO else "solo"
		var held := OS.get_environment("SNAPRACERS_HELD").split(",")
		if held.size() != 2:
			held = PackedStringArray(["triple_turbo", "shield"])
		for racer in race.humans:
			racer.kart.held = [held[0], held[1]]
			racer.kart.held_uses = [3 if held[0] == "triple_turbo" else 1, 1]
			racer.hud.touch.visible = true
			# The stick on your own and whatever's set in a split screen, so
			# both kinds get seen.
			if split == Game.SOLO:
				racer.hud.touch.steering = "stick"
			racer.progress.lap_times.append(58.42)
			racer.kart.slowdown_left = Kart.RESET_SLOWDOWN_TIME * 0.6
			racer.hud.flash("Chase camera")
		# Player 1's second gadget waits, to show one that can't be used yet.
		race.humans[0].kart._gadget_wait[1] = 999.0
		await frames(20)
		await _shoot(folder, "race_" + tag)
		race.open_menu(race.humans[0])
		await frames(4)
		await _shoot(folder, "pause_" + tag)
		race.close_menu(race.humans[0])
		await frames(4)
		race.humans[0].progress.finished = true
		race.humans[0].progress.finish_time = race.time
		race._player_finished(race.humans[0])
		await frames(350)
		await _shoot(folder, "results_" + tag)
	Game.settings.set_value("race", "split", split_was)


func _touch_sizes(folder: String, tag: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var race := await _start(host, Game.SOLO)
	var touch: TouchControls = race.player.hud.touch
	race.player.kart.held = ["triple_turbo", "shield"]
	race.player.kart.held_uses = [3, 1]
	touch.visible = true
	touch.steering = "stick"
	for pick in TouchControls.SIZES:
		touch.control_size = pick
		await frames(10)
		await _shoot(folder, "%s_%s" % [tag, pick])
	touch.control_size = "medium"
	for picked in [TouchControls.HEIGHT_LOWEST, TouchControls.HEIGHT_HIGHEST]:
		touch.height = TouchControls.height_for(picked, false)
		await frames(10)
		await _shoot(folder, "%s_medium_height%02d" % [tag, int(picked * 100.0)])
	touch.height = TouchControls.HEIGHT


func _shoot(folder: String, which: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var name := "%s-%dx%d" % [which, picture.get_width(), picture.get_height()]
	if OS.get_environment("SNAPRACERS_CUTOUT") != "":
		name += "-cutout"
		for hole in SafeArea.pretend:
			picture.fill_rect(Rect2i(hole), Color.BLACK)
	picture.save_png("%s/%s.png" % [folder, name])
	print("saved ", name)


func _solo(host: Node, end: String) -> void:
	var race := await _start(host, Game.SOLO)
	var kart := race.player.kart
	await _save("slots_empty" + end)
	kart.held = ["turbo", ""]
	kart.held_uses = [1, 0]
	await frames(4)
	await _save("slots_popping" + end)
	await frames(30)
	await _save("slots_one" + end)
	kart.held = ["turbo", "triple_turbo"]
	kart.held_uses = [1, 3]
	await frames(30)
	await _save("slots_both" + end)


## Every power-up's box in rows, with its name under it.
class _Sheet extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var bg := ColorRect.new()
		bg.color = Color("#3a5a3a")
		bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(bg)
		var i := 0
		for kind in Powerups.ALL:
			var slots := PowerupSlots.new()
			add_child(slots)
			slots.position = Vector2(40 + (i % 5) * 240, 40 + (i / 5) * 200)
			slots.show_held([kind, ""], [Powerups.ALL[kind].uses, 0])
			var big := PowerupSlots.new()
			add_child(big)
			big.scale = Vector2.ONE * 1.6
			big.position = slots.position + Vector2(0, 74)
			big.show_held([kind, ""], [1, 0])
			var label := Label.new()
			label.text = Powerups.name_of(kind)
			label.position = slots.position + Vector2(84, 20)
			add_child(label)
			i += 1
