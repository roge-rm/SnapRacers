extends Node

## Takes pictures of the track editor's landmark drawer, its Trees & plants
## group and Peach Pit with trees put down beside the road. Run it with its
## own XDG_DATA_HOME so the editor's autosave stays out of your profile, once
## per screen size:
##   XDG_DATA_HOME=/tmp/x tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 960x540 res://tools/shots/landmark_shots.tscn

const OUT := "/srv/downloads/temp/debug/snapracers/landmarks"
const TREES := ["broadleaf", "maple", "sakura", "gum_tree", "peach", "lemon", "birch", "pine", "snowy_pine",
	"cypress", "palm", "olive", "stone_pine", "jungle_tree", "jungle_sapling", "cactus", "jungle_bush", "fern",
	"reeds", "bush", "tree_clump", "tree_clump", "hedge_row", "hedge_row"]
## New countryside and trackside landmarks for the course picture.
const NEW := ["house", "windmill", "bridge", "snowy_chalet", "tent", "cows", "hay", "rocks", "red_rocks", "snowman",
	"containers", "tire_pile", "pallets", "parasols", "windsurf", "boats", "grandstand", "pit_building", "billboard",
	"marshal_post", "flag", "lamp_post", "fans", "tire_stack", "barrier_stack"]
const GROUPS := ["Countryside", "Nature", "Industry", "Beach", "Trackside", "Parks"]
var host: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var size := DisplayServer.window_get_size()
	var tag := "%dx%d_m34" % [size.x, size.y]
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
	editor.load_course(Tracks.path_of("peach_pit"))
	await _frames(30)
	var ui := editor.ui
	ui._show_category(TrackEditorUI.CATEGORIES.size())
	ui._choose_landmark_group(0)
	await _frames(90)
	await _save("drawer_%s" % tag)
	for group in GROUPS:
		var found := TrackEditorUI.LANDMARK_GROUPS.map(func(g): return g[0]).find(group)
		ui._choose_landmark_group(found)
		await _frames(150)
		await _save("group_%s_%s" % [group.to_lower(), tag])
		var tall: ScrollContainer = ui._tiles.get_parent()
		if tall.get_v_scroll_bar().max_value > tall.size.y:
			tall.scroll_vertical = int(tall.get_v_scroll_bar().max_value)
			await _frames(60)
			await _save("group_%s_scrolled_%s" % [group.to_lower(), tag])
			tall.scroll_vertical = 0
	var trees := TrackEditorUI.LANDMARK_GROUPS.map(func(g): return g[0]).find("Trees & plants")
	ui._choose_landmark_group(trees)
	await _frames(150)
	await _save("trees_%s" % tag)
	var scroll: ScrollContainer = ui._tiles.get_parent()
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(60)
	await _save("trees_scrolled_%s" % tag)
	# The new landmarks in rings of spots beside the first straight, clear of the road.
	var start: Vector3 = editor.track.points[0]
	var marks: Array = []
	var k := 0
	for ring in [26.0, 38.0, 50.0, 62.0]:
		for step in 16:
			if k >= NEW.size():
				break
			var a := step * TAU / 16.0
			var mark := {"prop": NEW[k], "at": [snappedf(start.x + cos(a) * ring, 0.5), snappedf(start.z + sin(a) * ring, 0.5)], "facing": step % 4}
			if editor._clear_of_road(mark):
				marks.append(mark)
				k += 1
	editor.course.landmarks = marks
	editor._refresh(true)
	ui._show_category(0)
	editor._focus = start
	editor._distance = 130.0
	editor._pitch = deg_to_rad(-30.0)
	editor._yaw = deg_to_rad(30.0)
	editor._place_camera()
	await _frames(90)
	await _save("course_new_%s" % tag)
	print("placed %d of %d" % [marks.size(), NEW.size()])
	host.queue_free()
	await _frames(3)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("saved ", name)
