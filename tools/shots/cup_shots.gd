extends Node

## Captures the current cup picker, including trophy thumbnails.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/cup_shots.tscn
## After `--`, `size=2400x1080` sets the window (2400 x 1080 is a phone's 1600
## x 720 in UI units), `more=5` adds made-up cups to see a bigger grid, and
## `out=name` names the picture. SNAPRACERS_CUTOUT="x,y,w,h" fakes a camera hole.
func _ready() -> void:
	var window := Vector2i(1280, 720)
	var more := 0
	var out := "cups"
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=")
		if pair.size() != 2:
			continue
		match pair[0]:
			"size":
				var n := pair[1].split("x")
				window = Vector2i(int(n[0]), int(n[1]))
			"more":
				more = int(pair[1])
			"out":
				out = pair[1]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Records.use_file("user://screenshot_records.cfg")
	# Light some reverse / mirrored / both pips so the README shot shows them.
	var n := 0
	for cup in GrandPrix.cups():
		Records.add_cup_place(cup.id, 1 + n % 3, Difficulty.DEFAULT, false)
		Records.add_cup_place(cup.id, 1, Difficulty.DEFAULT, false, "reverse")
		if n % 2 == 0:
			Records.add_cup_place(cup.id, 2, Difficulty.DEFAULT, false, "mirrored")
		if n % 3 == 0:
			Records.add_cup_place(cup.id, 1, Difficulty.DEFAULT, false, "reverse mirrored")
		n += 1
	if more > 0:
		# Made-up cups for the shot only, borrowing the real ones' courses.
		var cups: Array = GrandPrix.cups().duplicate()
		var colours := ["#a0452e", "#a5ca18", "#f5cd2f", "#f2f3f2", "#5ab4e5"]
		for i in more:
			var from: Dictionary = cups[i % cups.size()].duplicate()
			from.id = "made_up_%d" % i
			from.name = "Made Up Cup %d" % (i + 1)
			from.colour = colours[i % colours.size()]
			cups.append(from)
		GrandPrix._cups = cups
	Game.show_cups()
	# Give each batch of trophy thumbnails time to render and reach the cards.
	for i in 90:
		await get_tree().process_frame
		RenderingServer.force_draw.call_deferred()
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/shots")
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % out)
	print("saved ", out, " ", get_viewport().get_visible_rect().size)
	get_tree().quit()
