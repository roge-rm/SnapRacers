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
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		var name: String = GarageUI.CATEGORIES[i][0].to_lower()
		get_viewport().get_texture().get_image().save_png("%s/garage_%s.png" % [OUT, name])
		print("saved ", name)
	get_tree().quit()
