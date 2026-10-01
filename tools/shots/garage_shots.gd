extends Node

## Takes a picture of the garage with each drawer tab open, for checking how
## the parts look without a phone. Like course_shots, it needs a screen, and
## saves them in /tmp/snapracers-build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/garage_shots.tscn

const OUT := "/tmp/snapracers-build/shots"


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
	get_tree().quit()


func _save(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/garage_%s.png" % [OUT, name])
	print("saved ", name)
