extends SceneTree

## Prints how each stock kart comes out, and anything stopping it from being
## driven. Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/report.gd

const DIR := "res://data/karts/stock"


func _init() -> void:
	print("%-14s %5s %5s %5s %5s %6s %4s %5s %-7s" % ["kart", "km/h", "pull", "turn", "ctrl", "off", "kg", "drag", "most"])
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".json"):
			continue
		var design := KartDesign.load_file(DIR + "/" + file)
		var stats := KartStats.compute(design)
		print("%-14s %5d %5.2f %5.2f %4d%% %+5d%% %4d %5.2f %-7s" % [file.get_basename(), roundi(stats.top_speed() * 3.6), stats.pull(), stats.cornering(), roundi(stats.control * 100.0), roundi(stats.offroad * 100.0), roundi(stats.mass), stats.drag_area, stats.most_drag()])
		for problem in design.problems():
			print("    ! " + problem)
	quit()
