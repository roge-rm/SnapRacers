extends SceneTree

## Checks the cut bend's dirt and scenery clearance in every race layout.

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _bend_centre(track: TrackPath, index: int) -> Vector3:
	var pose := track.piece_starts[index]
	var piece := track.pieces[index]
	var a: Vector3 = pose * piece.point(0.0)
	var b: Vector3 = pose * piece.point(0.5)
	var c: Vector3 = pose * piece.point(1.0)
	var aa := Vector2(a.x, a.z)
	var bb := Vector2(b.x, b.z)
	var cc := Vector2(c.x, c.z)
	var d := 2.0 * (aa.x * (bb.y - cc.y) + bb.x * (cc.y - aa.y) + cc.x * (aa.y - bb.y))
	var x := (aa.length_squared() * (bb.y - cc.y) + bb.length_squared() * (cc.y - aa.y) + cc.length_squared() * (aa.y - bb.y)) / d
	var z := (aa.length_squared() * (cc.x - bb.x) + bb.length_squared() * (aa.x - cc.x) + cc.length_squared() * (bb.x - aa.x)) / d
	return Vector3(x, a.y, z)


func _run() -> void:
	for mirrored in [false, true]:
		for reversed in [false, true]:
			var label := "mirrored=%s reversed=%s" % [mirrored, reversed]
			var track := TrackPath.load_file("res://tests/data/cut_bend_oval.json")
			track.apply_layout(mirrored, reversed)
			check(track.closes, "%s oval closes" % label)
			var index := -1
			for i in track.pieces.size():
				if track.pieces[i].cut:
					index = i
					break
			if index < 0:
				check(false, "%s has a cut bend" % label)
				continue
			var centre := _bend_centre(track, index)
			var builder := TrackBuilder.new(track)
			builder.sky = false
			builder.scenery = "landmarks"
			root.add_child(builder)
			await process_frame
			var dirt: StaticBody3D
			var dressing: Scenery
			for child in builder.get_children():
				if child is StaticBody3D and child.get_meta("surface", "") == "dirt":
					dirt = child
				if child is Scenery:
					dressing = child
			check(dirt != null and dressing != null, "%s builds dirt and scenery" % label)
			if dirt != null and dressing != null:
				var mesh := (dirt.get_child(0) as MeshInstance3D).mesh
				var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var dirt_centre := vertices[0]
				var clear_centre: Vector3 = dressing.keep_clear[0][0]
				check(dirt_centre.distance_to(centre) < 0.05, "%s dirt sits inside driven bend" % label)
				check(clear_centre.distance_to(centre) < 0.05, "%s scenery keeps inside clear" % label)
			builder.queue_free()
			await process_frame
	print("%d cut bend checks passed." % checks if failures == 0 else "%d of %d cut bend checks failed." % [failures, checks])
	quit(1 if failures > 0 else 0)
