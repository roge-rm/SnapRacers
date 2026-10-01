extends Node

## Takes pictures of scenery breaking, for checking how it looks without a
## phone: a kart driven through something small beside the road, with the
## camera behind it, and a hole knocked in a building. It needs a screen,
## and it saves them in /tmp/snapracers-build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/damage_shots.tscn -- peach_pit

const OUT := "/tmp/snapracers-build/shots"


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/damage_%s.png" % [OUT, name])
	print("saved ", name)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var which := "peach_pit"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		which = args[0]
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.start_practice(Tracks.path_of(which))
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await frames(10)
	var scenery := WorldDamage.in_tree(get_tree())
	var kart := race.player.kart
	var names := {}
	for g in scenery.groups:
		names[g.name] = names.get(g.name, 0) + (1 if not g.shapes.is_empty() else 0)
	print("groups with something solid: ", names)

	# Through a billboard, or whatever small thing there is.
	var target := -1
	for wanted in ["billboard", "marshal_post", ""]:
		for g in scenery.groups.size():
			var shapes: Array = scenery.groups[g].shapes
			if scenery.is_small(g) and (wanted == "" or scenery.groups[g].name == wanted) and not shapes.is_empty() and not shapes[0].disabled:
				target = g
				break
		if target >= 0:
			break
	var aim: Vector3 = scenery.groups[target].shapes[0].global_position
	var from := aim + Vector3(-7.0, 0.0, -7.0)
	kart.global_transform = Transform3D(Basis.looking_at((aim - from).normalized()), from + Vector3.UP * 0.4)
	kart.linear_velocity = (aim - from).normalized() * 20.0
	await frames(14)
	await shot("hit")
	await frames(30)
	await shot("after")
	await frames(150)
	await shot("lying")

	# A hole in the nearest building, in the side facing the camera.
	var best := -1
	var best_far := INF
	for g in scenery.groups.size():
		var group: Dictionary = scenery.groups[g]
		if group.name in ["grandstand", "pit_building", "house", "barn", "cottage", "villa"] and not group.shapes.is_empty():
			var far := kart.global_position.distance_to(group.shapes[0].global_position)
			if far < best_far:
				best_far = far
				best = g
	if best >= 0:
		var wall: CollisionShape3D = scenery.groups[best].shapes[0]
		var size: Vector3 = (wall.shape as BoxShape3D).size
		var middle := wall.global_position
		var camera := get_viewport().get_camera_3d().global_position
		var toward := camera - middle
		toward.y = 0.0
		var face := middle + Vector3(clampf(toward.x, -size.x * 0.5, size.x * 0.5), -size.y * 0.5 + 1.0, clampf(toward.z, -size.z * 0.5, size.z * 0.5))
		scenery.break_at(best, face, -toward.normalized() * 26.0)
		await frames(90)
		await shot(scenery.groups[best].name)
	get_tree().quit()
