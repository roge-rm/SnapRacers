extends Node

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var picker := KartPicker.new(func() -> void: pass, func() -> void: pass)
	picker._pictures = KartThumbnails.new()
	var entries := [[Game.OWN_KART, Game.design]]
	for key in Game.stock_keys():
		entries.append([key, Game.stock_kart(key)])
	var ranges := KartPicker._ranges(entries.map(func(entry): return KartPicker._measure(entry[1])))
	for entry in entries:
		var card := picker._card(entry[0], entry[1], ranges)
		card.theme = MenuStyle.theme()
		add_child(card)
		for dimensions in [Vector2(330, 410), Vector2(390, 470), Vector2(330, 530)]:
			card.size = dimensions
			for frame in 3:
				await get_tree().process_frame
			var shape := card.get_theme_stylebox("normal") as SlantBox
			var tilt := shape.tilt_for(card.size.y)
			var meters := card.find_children("*", "Control", true, false).filter(func(child): return child is KartPicker.StatBar)
			var fits := meters.size() == KartPicker.BARS.size()
			for meter in meters:
				var transform: Transform2D = card.get_global_transform().affine_inverse() * meter.get_global_transform()
				var rect := Rect2(0, meter.size.y * 0.5 - 5, meter.size.x, 10)
				for corner in UiKit.slant_points(rect):
					var at: Vector2 = transform * corner
					var right := card.size.x - at.y * tilt - shape.edge_width
					fits = fits and at.x <= right - 10.0 and at.x >= 0.0 and at.y <= card.size.y - 10.0
			check(fits, "%s stat bars leave room inside the slanted card at %s" % [entry[0], dimensions])
		card.queue_free()
		await get_tree().process_frame
	picker._pictures.free()
	picker.free()
	print("%d kart picker layout checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
