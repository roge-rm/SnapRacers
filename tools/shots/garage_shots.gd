extends Node

## Takes a picture of the garage with each drawer tab open, for checking how
## the parts look without a phone. Like course_shots, it needs a screen, and
## saves them in build/shots. With "wheel" it takes a trail bike wheel going
## onto a sports bike frame instead, saved where the next argument says.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/garage_shots.tscn
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/garage_shots.tscn -- wheel /some/folder

var OUT := "res://build/shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.show_garage()
	var garage: Garage = null
	while garage == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Garage:
				garage = child
	await get_tree().create_timer(2.0).timeout
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "wheel":
		OUT = args[1]
		DirAccess.make_dir_recursive_absolute(OUT)
		await _wheel(garage)
		get_tree().quit()
		return
	for i in GarageUI.CATEGORIES.size():
		garage.ui._show_category(i)
		# The part pictures are taken a few at a time.
		await get_tree().create_timer(2.0).timeout
		var name: String = GarageUI.CATEGORIES[i][0].to_lower().replace(" ", "_")
		await _save(name)
	# Holding a part, with the dots for where it could go and snapped onto
	# one of them.
	garage.show_view("angle")
	garage.start_placing("p_curve_2x2")
	for spot in garage._spots:
		if spot.at.distance_to(Vector3(150, 24, 230)) < 0.5:
			garage.snap_to(spot)
	await _save("holding")
	garage.cancel()
	# A clip on a bar.
	garage.start_placing("p_plate_handle_1x2", Basis.IDENTITY, null, Vector3i(12, 3, 11))
	garage.place()
	garage.cancel()
	garage.start_placing("p_plate_clip_1x1")
	for spot in garage._spots:
		if spot.type == "bar":
			garage.snap_to(spot)
			garage.slide()
			break
	garage._distance = 3.0
	garage._focus = Grid.to_metres(Vector3(12.5, 4.0, 12.0))
	garage._place_camera()
	await _save("clip")
	# A new kart, empty, with the outline of the build area.
	garage.cancel()
	garage._new_kart()
	await _save("new_kart")
	get_tree().quit()


## A trail bike wheel held by the back of a sports bike frame sitting on the
## floor, then snapped onto its axle from a finger near the dot, then a second
## one that won't go on.
func _wheel(garage: Garage) -> void:
	garage._new_kart()
	garage.start_placing("b_frame_sport", Basis.IDENTITY, null, Vector3i(9, 0, 7))
	garage.place()
	garage.cancel()
	garage.show_view("angle")
	garage._distance = 4.0
	garage._focus = Grid.to_metres(Vector3(10.0, 4.0, 15.0))
	garage._place_camera()
	garage.start_placing("w_moto_trail", Basis.IDENTITY, null, Vector3i(10, 0, 14))
	await _save("wheel_before")
	var axles: Array = garage._spots.filter(func(s): return s.type == "axle")
	var dot := garage._camera.unproject_position(garage._dot_position(axles[2]))
	garage._aim_ghost(dot + Vector2(30.0, 40.0))
	await _save("wheel_snapped")
	garage.place()
	await _save("wheel_on")
	var left: Array = garage._spots.filter(func(s): return s.type == "axle")
	if not left.is_empty():
		garage.snap_to(left[0])
	await _save("wheel_red_note")


func _save(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/garage_%s.png" % [OUT, name])
	print("saved ", name)
