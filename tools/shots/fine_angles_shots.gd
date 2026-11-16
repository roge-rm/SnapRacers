extends Node

## Pictures of the 15 and 75 degree bends: the Bends drawer at its top and
## further down, a course built from them in the editor, then a race on it
## with the AI driving every kart. Run it with its own XDG_DATA_HOME so the
## editor's autosave stays out of your profile:
##   XDG_DATA_HOME=build/creations/shots DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 1600x720 res://tools/shots/fine_angles_shots.tscn
## They're saved in /srv/downloads/temp/debug/snapracers/0.16/angles.

const OUT := "/srv/downloads/temp/debug/snapracers/0.16/angles"
const FineAngles := preload("res://tests/fine_angles_test.gd")
## When to take the race pictures, in seconds of race time.
const AT := [6.0, 16.0, 30.0, 45.0]
var host: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	seed(1)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_track_editor()
	var editor: TrackEditor = null
	while editor == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is TrackEditor:
				editor = child
	var course := FineAngles.loop_course()
	course.name = "Fine angles"
	course.theme = "orchard"
	var path := course.save()
	editor.load_course(path)
	editor.ui._show_category(TrackEditorUI.CATEGORIES.map(func(c): return c[0]).find("Bends"))
	editor.fit_view()
	await get_tree().create_timer(TrackEditor.IDLE_BUILD + 0.5).timeout
	await _shot("drawer_15")
	# The 75 degree rows sit after the 60 degree ones.
	var scroll: ScrollContainer = editor.ui._tiles.get_parent()
	var row: Control = editor.ui._tiles.get_child(32)
	scroll.scroll_vertical = int(row.position.y)
	await _shot("drawer_75")
	editor._select(3)
	await _shot("course_75_picked")
	editor._select(1)
	await _shot("course_15_picked")
	editor._select(-1)
	path = editor.save()

	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	Game.settings.set_value("controls", "player_1", "buttons")
	Game.start_course(Game.MODE_RACE, path, true)
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	var driver := AIDriver.new()
	driver.kart = race.player.kart
	driver.track = race.track
	race.add_child(driver)
	race.player.ai = driver
	race.player.kart.controls = driver.controls
	for i in AT.size():
		while race.time < AT[i]:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/race_%d.png" % [OUT, i + 1])
		print("saved race_%d at %.0f m, %d karts" % [i + 1, race.player.kart.global_position.length(), race.find_children("*", "Kart", true, false).size()])
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TrackEditor.CURRENT)
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
