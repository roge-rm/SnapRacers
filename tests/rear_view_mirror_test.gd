extends Node

## Camera gestures, the single-player mirror and its HUD layout. Pass
## -- --visual to keep native-renderer pictures in the debug folder.

const DEBUG := "/srv/downloads/temp/debug/snapracers/rear-view-mirror"
var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func pad(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func mouse(button: Control, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	get_viewport().push_input(event, true)


func screen_touch(button: Control, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.pressed = down
	event.position = button.get_global_rect().get_center()
	get_viewport().push_input(event, true)


func start(split: String) -> Race:
	var before: Node = Game._screen
	Game.settings.set_value("race", "split", split)
	Game.settings.set_value("race", "kart", "kart_kid")
	Game.start_race(Tracks.path_of("peach_pit"))
	for i in 300:
		await frames(1)
		for child in host.get_children():
			if child is Race and child != before and not child.is_queued_for_deletion() and child.player != null and child.player.hud != null:
				return child
	return null


func layout_clear(mirror: RearViewMirror) -> bool:
	var room := mirror.get_global_rect()
	if not Rect2(Vector2.ZERO, mirror.get_parent().size).encloses(room):
		return false
	for blocker in mirror.blockers:
		if blocker.is_visible_in_tree() and room.intersects(blocker.get_global_rect()):
			return false
	for hole in SafeArea.holes_in(get_viewport()):
		if room.intersects(hole):
			return false
	return true


func capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DEBUG + "/" + name + ".png")


func caption_case(hud: RaceHud, text: String, baseline: Rect2, where: String) -> void:
	hud.flash(text)
	var pill := hud._message.get_parent() as Control
	check(pill.get_parent() == hud and pill.get_global_rect().position.y >= hud.mirror.get_global_rect().end.y + RearViewMirror.GAP - 0.1, "%s puts the new caption below the mirror immediately" % where)
	check(not SafeArea.holes_in(hud.get_viewport()).any(func(hole: Rect2): return pill.get_global_rect().intersects(hole)), "%s keeps the detached caption clear of camera cutouts" % where)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if "--visual" in OS.get_cmdline_user_args() and where.begins_with("top clock at (800, 450)"):
			DirAccess.make_dir_recursive_absolute(DEBUG)
			get_viewport().get_texture().get_image().save_png(DEBUG + ("/first-caption.png" if text == "First person" else "/long-caption.png"))
	var first := pill.get_global_rect()
	check(hud.mirror.get_global_rect().is_equal_approx(baseline) and first.position.y >= baseline.end.y + RearViewMirror.GAP - 0.1, "%s keeps the mirror still on the caption's first draw" % where)
	await frames(3)
	check(hud.mirror.get_global_rect().is_equal_approx(baseline) and pill.get_global_rect().is_equal_approx(first), "%s keeps both rectangles still after container layout" % where)
	hud._message_left = RaceHud.MESSAGE_FADE * 0.5
	hud._process(0.0)
	await frames(2)
	check(pill.visible and pill.modulate.a < 1.0 and hud.mirror.get_global_rect().is_equal_approx(baseline), "%s keeps the mirror still while the caption fades" % where)
	hud._message_left = 0.0
	hud._process(0.0)
	await frames(2)
	check(not pill.visible and hud.mirror.get_global_rect().is_equal_approx(baseline), "%s keeps the mirror still after the caption disappears" % where)


func rounded_frame(camera: RaceCamera) -> void:
	var canvas := SubViewport.new()
	canvas.size = Vector2i(286, 98)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(canvas)
	var frame := RearViewMirror.new()
	frame.camera = camera
	canvas.add_child(frame)
	frame.set_process(false)
	frame.position = Vector2(20, 16)
	frame.size = Vector2(246, 66)
	frame._build_view()
	var solid := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	solid.fill(Color.MAGENTA)
	frame.picture.texture = ImageTexture.create_from_image(solid)
	await frames(3)
	await RenderingServer.frame_post_draw
	var pixels := canvas.get_texture().get_image().get_region(Rect2i(20, 16, 246, 66))
	check(pixels.get_pixel(0, 0).a < 0.05 and pixels.get_pixel(123, 33).r > 0.95 and pixels.get_pixel(123, 33).b > 0.95, "the native rounded frame has clear outside corners and shows its image")
	var clipped := true
	var symmetric := true
	for x in 12:
		for y in 12:
			var pixel := pixels.get_pixel(x, y)
			for other in [pixels.get_pixel(245 - x, y), pixels.get_pixel(x, 65 - y), pixels.get_pixel(245 - x, 65 - y)]:
				if absf(pixel.r - other.r) > 0.06 or absf(pixel.g - other.g) > 0.06 or absf(pixel.b - other.b) > 0.06 or absf(pixel.a - other.a) > 0.06:
					symmetric = false
	for point in [Vector2i(3, 3), Vector2i(242, 3), Vector2i(3, 62), Vector2i(242, 62)]:
		if pixels.get_pixelv(point).r > 0.7:
			clipped = false
	check(clipped, "the rear image is clipped at all four rounded inner corners")
	check(symmetric, "the native frame and image mask have matching corners on every side")
	if "--visual" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(DEBUG)
		pixels.save_png(DEBUG + "/rounded-corners.png")
	canvas.queue_free()
	await frames(1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("camera", "player_1", "chase")
	if Game.settings.has_section_key("camera", "rear_view_mirror"):
		Game.settings.erase_section_key("camera", "rear_view_mirror")
	check(Game.rear_view_mirror(), "the mirror starts on without a saved preference")
	var race := await start(Game.SOLO)
	check(race != null, "a solo race starts")
	if race == null:
		get_tree().quit(1)
		return
	await frames(4)
	var me := race.player
	var camera := me.camera
	var mirror := me.hud.mirror
	check(mirror != null and mirror.viewport == null, "chase starts without a mirror render target")
	for view in ["driver", "hood", "bumper"]:
		camera.set_view(view)
		await frames(3)
		check(mirror.viewport != null and mirror.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "%s shows the live mirror" % view)
	check(mirror.viewport.size == RearViewMirror.RENDER_SIZE and mirror.viewport.world_3d == camera.get_world_3d(), "a small render target shares the existing race world")
	check(mirror.rear_camera.keep_aspect == Camera3D.KEEP_WIDTH and mirror.picture.flip_h, "a fixed horizontal field of view is shown as a mirror")
	check(not mirror.rear_camera.get_cull_mask_value(camera.head_layer), "the mirror leaves out your own head")
	check((-mirror.rear_camera.global_basis.z).dot(me.kart.global_basis.z) > 0.99, "the mirror looks behind the kart")
	var kart_transform := me.kart.global_transform
	me.kart.global_basis = me.kart.global_basis.rotated(me.kart.global_basis.z.normalized(), 0.3)
	mirror._process(0.0)
	check(mirror.rear_camera.global_basis.y.dot(me.kart.global_basis.y.normalized()) > 0.99, "the mirror follows the kart's bank")
	me.kart.global_transform = kart_transform
	mirror._process(0.0)
	check(me.kart.to_local(mirror.rear_camera.global_position).z > me.kart.rear_bumper_point().z, "it starts beyond the tail, clear of large bodywork")
	camera._looking_back = true
	camera.snap()
	mirror._process(0.0)
	check((-mirror.rear_camera.global_basis.z).dot(me.kart.global_basis.z) > 0.99, "look back leaves the mirror facing behind")
	camera._looking_back = false

	for view in ["chase", "far", "overhead", "tv"]:
		camera.set_view(view)
		await frames(2)
		check(mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "%s stops mirror rendering" % view)
	camera.set_view("driver")
	await frames(2)
	mirror.hide()
	await frames(2)
	check(mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hiding the mirror stops rendering")
	mirror.show()
	await frames(2)

	# Both mapped keyboard sets still work on one device.
	for code in [KEY_V, KEY_M]:
		camera.set_view("driver")
		key(code, true)
		await frames(5)
		check(camera.view == "driver", "a short key press waits for release")
		key(code, false)
		await frames(3)
		check(camera.view == "hood", "a short key tap changes view once")
	camera.set_view("driver")
	key(KEY_V, true)
	await frames(40)
	check(camera.view == "driver" and not Game.rear_view_mirror(), "holding the view key turns the mirror off without changing view")
	await frames(45)
	key(KEY_V, false)
	await frames(3)
	check(not Game.rear_view_mirror() and camera.view == "driver" and mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "holding longer and releasing causes no extra action")
	check(Game.settings.get_value("camera", "rear_view_mirror", true) == false, "the mirror preference is saved with the camera settings")

	# The real HUD button follows the same tap and hold rules.
	mouse(me.hud._camera, true)
	await frames(40)
	mouse(me.hud._camera, false)
	await frames(3)
	check(Game.rear_view_mirror() and camera.view == "driver", "holding the HUD camera button toggles without cycling")
	mouse(me.hud._camera, true)
	await frames(3)
	mouse(me.hud._camera, false)
	await frames(3)
	check(camera.view == "hood", "tapping the HUD camera button cycles once")
	camera.set_view("driver")
	screen_touch(me.hud._camera, true)
	await frames(40)
	screen_touch(me.hud._camera, false)
	await frames(3)
	check(not Game.rear_view_mirror() and camera.view == "driver", "holding the touch-screen camera button toggles once")
	screen_touch(me.hud._camera, true)
	await frames(3)
	screen_touch(me.hud._camera, false)
	await frames(3)
	check(camera.view == "hood", "a touch-screen tap changes view once")
	Game.set_rear_view_mirror(true)
	camera.set_view("driver")
	me.input.press_view()
	await frames(2)
	check(camera.view == "hood", "the programmatic view impulse still cycles immediately")

	# A rebound controller button uses the mapped action, including holds.
	Game.controllers.owners[0] = 0
	InputBindings.set_pad(Game.settings, 0, "view", 0, [InputBindings.BUTTON, JOY_BUTTON_RIGHT_STICK, 1])
	camera.set_view("driver")
	pad(JOY_BUTTON_RIGHT_STICK, true)
	await frames(40)
	pad(JOY_BUTTON_RIGHT_STICK, false)
	await frames(3)
	check(not Game.rear_view_mirror() and camera.view == "driver", "a rebound controller hold toggles the mirror")
	pad(JOY_BUTTON_RIGHT_STICK, true)
	await frames(3)
	pad(JOY_BUTTON_RIGHT_STICK, false)
	await frames(3)
	check(camera.view == "hood", "a rebound controller tap still cycles")
	InputBindings.reset(Game.settings, 0)
	camera.set_view("driver")
	pad(JOY_BUTTON_BACK, true)
	await frames(40)
	pad(JOY_BUTTON_BACK, false)
	await frames(3)
	check(Game.rear_view_mirror() and camera.view == "driver" and not race.menu_open(me), "controller Back holds the mirror without opening the race menu")
	Game.controllers.owners.erase(0)

	camera.set_view("driver")
	Game.set_rear_view_mirror(true)
	await frames(3)
	key(KEY_V, true)
	await frames(5)
	race.open_menu(me)
	key(KEY_V, false)
	await frames(3)
	check(mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "pausing stops mirror rendering")
	race.close_menu(me)
	await frames(40)
	check(camera.view == "driver" and Game.rear_view_mirror(), "release during a menu causes no camera or mirror action on resume")
	Game.set_rear_view_mirror(true)
	await frames(3)
	me.input.cancel_camera_press()
	me.hud._camera.button_up.emit()
	me.hud._camera.pressed.emit()
	await frames(3)
	check(camera.view == "driver", "a cancelled touch release causes no phantom tap")
	key(KEY_C, true)
	key(KEY_W, true)
	await frames(3)
	check(me.input.look_back and me.input.controls.throttle > 0.5, "look back and driving controls keep working")
	key(KEY_C, false)
	key(KEY_W, false)

	get_window().mode = Window.MODE_WINDOWED
	me.hud.hide()
	for screen in [Vector2i(1280, 720), Vector2i(800, 450)]:
		get_window().content_scale_size = screen
		get_window().size = screen
		await frames(4)
		for placement in ["right", "top", "corner"]:
			# Rebuild the HUD with each existing clock placement.
			RaceHud.clock_at = placement
			var hud := RaceHud.new()
			hud.race = race
			hud.me = me
			me.hud.get_parent().add_child(hud)
			await frames(2)
			check(hud.size.is_equal_approx(Vector2(screen)), "the HUD uses the requested logical screen size")
			for hole in [Rect2(), Rect2(0, 100, 40, 100), Rect2(screen.x * 0.5 - 30, 0, 60, 28), Rect2(0, 72, 140, 70)]:
				SafeArea.pretend.clear()
				if hole.has_area():
					SafeArea.pretend.append(hole)
				hud._safe.refit()
				await frames(4)
				check(layout_clear(hud.mirror), "%s clock and cutout leave the mirror clear at %s" % [placement, screen])
				var baseline := hud.mirror.get_global_rect()
				for text in ["First person", "Rear-view mirror on, change the view with a short tap"]:
					await caption_case(hud, text, baseline, "%s clock at %s, %s" % [placement, screen, text])
			Game.set_rear_view_mirror(false)
			hud.flash("Rear-view mirror off")
			await frames(3)
			check(hud._message.get_parent().get_parent() == hud._message_row, "turning the mirror off restores the usual top caption row")
			Game.set_rear_view_mirror(true)
			camera.set_view("chase")
			hud.flash("Chase")
			await frames(3)
			check(hud._message.get_parent().get_parent() == hud._message_row, "chase keeps the usual top caption row")
			camera.set_view("driver")
			hud.queue_free()
			await frames(2)
	RaceHud.clock_at = "right"
	SafeArea.pretend.clear()
	me.hud.show()
	if DisplayServer.get_name() != "headless":
		await rounded_frame(camera)

	if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(DEBUG)
		me.kart.freeze = true
		var markers: Array[MeshInstance3D] = []
		for side in [-1.0, 1.0]:
			var marker := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(2.0, 1.0, 0.5)
			marker.mesh = mesh
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color.CYAN if side < 0.0 else Color.HOT_PINK
			marker.material_override = material
			race.add_child(marker)
			markers.append(marker)
			marker.global_position = me.kart.to_global(me.kart.rear_hood_point() + Vector3(side * 3.0, 0.0, 12.0))
		get_window().content_scale_size = Vector2i(1280, 720)
		get_window().size = Vector2i(1280, 720)
		camera.set_view("driver")
		await frames(10)
		await capture("driver-live")
		get_window().content_scale_size = Vector2i(800, 450)
		get_window().size = Vector2i(800, 450)
		SafeArea.pretend.assign([Rect2(370, 0, 60, 28)])
		await frames(10)
		await capture("small-cutout-live")
		await RenderingServer.frame_post_draw
		var rear_before := mirror.viewport.get_texture().get_image()
		rear_before.save_png(DEBUG + "/rear-camera.png")
		markers[0].global_position += me.kart.global_basis.x * 2.0
		await frames(4)
		await RenderingServer.frame_post_draw
		check(rear_before.get_data() != mirror.viewport.get_texture().get_image().get_data(), "the rendered mirror updates when an object behind moves")
		SafeArea.pretend.clear()

	camera.finish()
	await frames(2)
	check(mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "finishing stops the mirror before the camera orbit")
	for split in [Game.SIDE_BY_SIDE, Game.FACE_TO_FACE]:
		race = await start(split)
		await frames(3)
		check(race.humans.size() == 2, "the split race has two local humans")
		for human in race.humans:
			human.camera.set_view("driver")
			await frames(2)
			check(human.hud.mirror == null and not human.camera.mirror_available, "%s never allocates a mirror" % split)
			human.hud.flash("First person")
			check(human.hud._message.get_parent().get_parent() == human.hud._message_row, "%s keeps captions in their usual row" % split)
			human.input.press_view()
			await frames(2)
			check(human.camera.view == "hood", "split-screen camera cycling still works")
	Game.settings.set_value("camera", "player_1", "driver")
	Game.set_rear_view_mirror(true)
	Game.show_drive()
	var drive: TestDrive = null
	for i in 300:
		await frames(1)
		if Game._screen is TestDrive:
			drive = Game._screen
			break
	check(drive != null, "the garage test drive starts")
	if drive != null:
		var drive_mirror: RearViewMirror = null
		for node in drive.find_children("*", "Control", true, false):
			if node is RearViewMirror:
				drive_mirror = node
		check(drive_mirror != null, "the test drive has a single-player mirror")
		if drive_mirror != null:
			for view in ["driver", "hood", "bumper"]:
				drive.camera.set_view(view)
				await frames(3)
				check(drive_mirror.viewport != null and drive_mirror.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS and layout_clear(drive_mirror), "test-drive %s shows the mirror clear of Garage and camera buttons" % view)
			Game.set_rear_view_mirror(false)
			await frames(3)
			check(drive_mirror.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "the race's mirror preference also controls the test drive")
			drive.camera.set_view("driver")
			screen_touch(drive.camera.input._camera_button, true)
			await frames(40)
			screen_touch(drive.camera.input._camera_button, false)
			await frames(3)
			check(Game.rear_view_mirror() and drive.camera.view == "driver", "a test-drive camera hold toggles without cycling")
			screen_touch(drive.camera.input._camera_button, true)
			await frames(3)
			screen_touch(drive.camera.input._camera_button, false)
			await frames(3)
			check(drive.camera.view == "hood", "a test-drive camera tap still cycles")
	print("All rear-view mirror checks passed." if failures == 0 else "%d rear-view mirror checks failed." % failures)
	get_tree().quit(1 if failures else 0)
