extends Node

## Takes a picture of the garage with each drawer tab open, for checking how
## the parts look without a phone. Like course_shots, it needs a screen, and
## saves them in build/shots. With "wheel" it takes a trail bike wheel going
## onto a sports bike frame instead, saved where the next argument says, and
## with "mirror" wheels put on with Mirror on and by hand.
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
	if args.size() >= 2 and args[0] == "suspension":
		OUT = args[1]
		DirAccess.make_dir_recursive_absolute(OUT)
		garage.design = KartDesign.load_file("res://tests/data/old_starter.json")
		garage._rebuild()
		garage.show_view("angle")
		var wheel: int = range(garage.design.parts.size()).filter(func(i): return KartDesign.is_wheel(garage.design.parts[i].id))[0]
		garage.select(wheel)
		await _save("suspension_medium")
		garage.set_suspension("soft")
		await _save("suspension_soft")
		garage.set_suspension("hard")
		await _save("suspension_hard")
		garage.select(0)
		await _save("suspension_other_part")
		get_tree().quit()
		return
	if args.size() >= 2 and args[0] == "mirror":
		OUT = args[1]
		DirAccess.make_dir_recursive_absolute(OUT)
		await _mirror(garage)
		get_tree().quit()
		return
	if args.size() >= 2 and args[0] == "engines":
		OUT = args[1]
		DirAccess.make_dir_recursive_absolute(OUT)
		garage.ui._show_category(5)
		await get_tree().create_timer(3.0).timeout
		await _save("engine_tiles")
		garage.start_placing("engine_small", Basis.IDENTITY, null, Vector3i(0, 0, 0))
		garage.place()
		garage.start_placing("engine_small", Basis.IDENTITY, null, Vector3i(10, 0, 0))
		garage.place()
		garage.cancel()
		await _save("engine_note")
		get_tree().quit()
		return
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


## The red stock kart as it was built, then with its right wheels taken off
## and put back with Mirror on from the left ones, then put back by hand.
## Then a wheel on the end of an axle and its twin. Each from the front and
## close up from each side.
func _mirror(garage: Garage) -> void:
	var stock := KartDesign.load_file("res://data/karts/stock/redline.json")
	garage.design = stock
	garage._rebuild()
	await _mirror_views(garage, "stock")
	var middle := stock.middle()
	var right := func(p: Dictionary) -> bool: return KartDesign.is_wheel(p.id) and KartDesign.fine_box(p.id, KartDesign.place_of(p)).get_center().x > middle
	var lefts := stock.parts.filter(func(p): return KartDesign.is_wheel(p.id) and not right.call(p))
	var bare := stock.duplicate_design()
	bare.parts = bare.parts.filter(func(p): return not KartDesign.is_wheel(p.id))
	# Mirror on, the left wheels put back on their pins.
	garage.design = bare.duplicate_design()
	garage._rebuild()
	garage.set_mirror(true)
	for p in lefts:
		_snap_wheel(garage, p.id, KartDesign.fine_box(p.id, KartDesign.place_of(p)).get_center())
	_print_wheels(garage, "mirrored")
	await _mirror_views(garage, "mirrored")
	# Mirror off, all four put on by hand.
	garage.set_mirror(false)
	garage.design = bare.duplicate_design()
	garage._rebuild()
	for p in stock.parts.filter(func(p): return KartDesign.is_wheel(p.id)):
		_snap_wheel(garage, p.id, KartDesign.fine_box(p.id, KartDesign.place_of(p)).get_center())
	_print_wheels(garage, "by hand")
	await _mirror_views(garage, "by_hand")
	# An axle across the middle and a wheel on its left end, with Mirror on.
	garage._new_kart()
	garage.set_mirror(true)
	garage.start_placing("p_axle_8", Basis.IDENTITY, null, Vector3i(6, 2, 10))
	garage.place()
	garage.cancel()
	_snap_wheel(garage, "w_kart_wide", Vector3(110.0, 24.0, 210.0))
	_print_wheels(garage, "axle")
	await _mirror_views(garage, "axle")


## Puts a wheel on the hub spot nearest `near`, in the fine unit.
func _snap_wheel(garage: Garage, id: String, near: Vector3) -> void:
	garage.start_placing(id)
	var spots: Array = garage._spots.filter(func(s): return s.type in ["pin", "axle"])
	spots.sort_custom(func(a, b): return a.at.distance_to(near) < b.at.distance_to(near))
	for spot in spots:
		if garage.snap_to(spot) and garage._ghost_ok:
			garage.place()
			break
	garage.cancel()


func _print_wheels(garage: Garage, what: String) -> void:
	for p in garage.design.parts:
		if KartDesign.is_wheel(p.id) or p.id.begins_with("p_axle"):
			print(what, " ", p.id, " ", KartDesign.place_of(p))


func _mirror_views(garage: Garage, name: String) -> void:
	garage.show_view("front")
	await _save("mirror_%s_front" % name)
	var wheels: Array = garage.design.parts.filter(func(p): return KartDesign.is_wheel(p.id))
	wheels.sort_custom(func(a, b): return KartDesign.place_of(a).origin.z < KartDesign.place_of(b).origin.z)
	for side in [["left", 270.0], ["right", 90.0]]:
		for p in wheels:
			var centre := KartDesign.fine_box(p.id, KartDesign.place_of(p)).get_center()
			if (centre.x < garage.design.middle()) == (side[0] == "left"):
				garage._focus = Grid.to_metres(centre / Grid.UNIT_FINE)
				break
		garage._yaw = deg_to_rad(side[1] - 25.0 if side[0] == "left" else side[1] + 25.0)
		garage._pitch = deg_to_rad(-12.0)
		garage._distance = 1.6
		garage._place_camera()
		await _save("mirror_%s_%s" % [name, side[0]])


func _save(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/garage_%s.png" % [OUT, name])
	print("saved ", name)
