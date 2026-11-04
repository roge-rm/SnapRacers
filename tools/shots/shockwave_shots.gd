extends Node

## The outgoing shockwave from a still or moving driver's view, and chase.
## DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/shockwave_shots.tscn -- [folder]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "res://build/shots/shockwave"
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	for key in ["kart_kid", "crusher", "quarter_mile"]:
		Game.settings.set_value("race", "kart", key)
		var before := Game._screen
		Game.start_practice(Tracks.path_of("peach_pit"))
		var race: Race
		while race == null:
			await get_tree().process_frame
			for child in host.get_children():
				if child is Race and child != before and not child.is_queued_for_deletion():
					race = child
		for i in 20:
			await get_tree().process_frame
		var kart := race.player.kart
		race.time = 10.0
		race.started = true
		kart.freeze = true
		var camera := race.player.camera
		var start := kart.global_transform
		for view in ["driver", "chase"]:
			camera.set_view(view)
			for speed in [0.0, 25.0, 45.0]:
				kart.global_transform = start
				camera.snap()
				await _save(out, "%s_%s_%d_before" % [key, view, speed])
				race.shockwave_from(kart)
				var ring: ShockRing
				for child in race.get_children():
					if child is ShockRing and not child.is_queued_for_deletion():
						ring = child
				ring.set_process(false)
				ring._age = 0.0
				var age := 0.0
				for time in [0.08, 0.16, 0.3]:
					ring._process(time - age)
					age = time
					kart.global_transform = start
					kart.global_position -= start.basis.z * speed * time
					camera.snap()
					await _save(out, "%s_%s_%d_%03d" % [key, view, speed, time * 1000])
				ring.queue_free()
				await get_tree().process_frame
		print("captured ", key, " eye height ", kart.eye_point().y - kart.global_position.y)
	get_tree().quit()


func _save(out: String, name: String) -> void:
	for i in 2:
		await get_tree().process_frame
	RenderingServer.force_draw.call_deferred()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
