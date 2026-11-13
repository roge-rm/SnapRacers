extends Node

## Pictures of a course from above with its racing line drawn on the road in
## pink (see RacingLine), the whole course and the stretch where it bends
## most. It needs a screen, so it runs on the computer's own display.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/racing_line_shots.tscn -- peach_pit
## Add "mirrored" or "reversed" (or both) after the course for those layouts.
## They're saved in /srv/downloads/temp/debug/snapracers/racing-line.

const OUT := "/srv/downloads/temp/debug/snapracers/racing-line"

var race: Race
var which := "peach_pit"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		which = args[0]
	var path := which if which.contains("/") else Game.TRACKS + "/" + which + ".json"
	which = which.get_file().get_basename()
	Game.settings.set_value("race", "weather", "clear")
	Game.settings.set_value("race", "time", "day")
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "mirrored", args.has("mirrored"))
	Game.settings.set_value("race", "reversed", args.has("reversed"))
	if args.has("mirrored"):
		which += "_mirrored"
	if args.has("reversed"):
		which += "_reversed"
	Game.show_race(path)
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var line := race.track.racing_line()
	print("racing line took %.1f ms" % (line.build_usec / 1000.0))
	_draw_line()
	await _overhead(_bounds(0, race.track.points.size()), "overhead")
	await _overhead(_bendiest(), "bend")
	get_tree().quit()


## The racing line as a pink strip on the road, and the middle as a thin
## white one.
func _draw_line() -> void:
	var t := race.track
	var mesh := ImmediateMesh.new()
	for strip in [[t.racing_line().offsets, 1.0, Color(1.0, 0.1, 0.7)], [PackedFloat32Array(), 0.3, Color.WHITE]]:
		var offsets: PackedFloat32Array = strip[0]
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		mesh.surface_set_color(strip[2])
		for n in t.points.size() + 1:
			var k := n % t.points.size()
			var across := offsets[k] if not offsets.is_empty() else 0.0
			var middle := t.points[k] + t.rights[k] * across + t.ups[k] * 0.4
			mesh.surface_add_vertex(middle - t.rights[k] * strip[1])
			mesh.surface_add_vertex(middle + t.rights[k] * strip[1])
		mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	race.add_child(instance)


func _bounds(from: int, count: int) -> AABB:
	var t := race.track
	var bounds := AABB(t.points[from], Vector3.ZERO)
	for n in count:
		bounds = bounds.expand(t.points[(from + n) % t.points.size()])
	return bounds


## About 200 m of road around the sharpest stretch of the lap.
func _bendiest() -> AABB:
	var t := race.track
	var best := 0
	var best_bend := -1.0
	for k in t.points.size():
		var bend := t.bend_at(t.distances[k])
		if bend > best_bend and t.pieces[t.piece_of[k]].type in ["curve", "arc"]:
			best_bend = bend
			best = k
	var from := t._index_before(t.distances[best] - 100.0)
	return _bounds(from, t._index_before(t.distances[best] + 100.0) - from + (t.points.size() if t.distances[best] + 100.0 > t.length else 0))


func _overhead(bounds: AABB, name_: String) -> void:
	var centre := bounds.get_center()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 3000.0
	var across := bounds.size.x >= bounds.size.z
	camera.size = (maxf(bounds.size.x, bounds.size.z) if not across else bounds.size.x * 9.0 / 16.0) + 40.0
	camera.size = maxf(camera.size, minf(bounds.size.x, bounds.size.z) + 40.0)
	race.add_child(camera)
	var up := Vector3.FORWARD if across else Vector3.RIGHT
	camera.global_transform = Transform3D(Basis.IDENTITY, centre + Vector3.UP * 1000.0).looking_at(centre, up)
	camera.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [OUT, which, name_])
	print("saved ", which, "_", name_)
	camera.queue_free()
	race.camera.make_current()
