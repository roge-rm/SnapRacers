extends SceneTree

## Says which parts of the stock karts are inside each other and which
## aren't joined to the rest, for working out what's wrong when report.gd
## says so. Name karts after -- to only check those.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/check.gd -- superbike

const DIR := "res://data/karts/stock"


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	for file in DirAccess.get_files_at(DIR):
		var key := file.get_basename()
		if not file.ends_with(".json") or (not only.is_empty() and not only.has(key)):
			continue
		var design := KartDesign.load_file(DIR + "/" + file)
		var p := design.parts
		for i in p.size():
			for j in range(i + 1, p.size()):
				if KartDesign.clash(p[i].id, KartDesign.place_of(p[i]), p[j].id, KartDesign.place_of(p[j])):
					print("%s: %s %s is inside %s %s" % [key, p[i].id, _box(p[i]), p[j].id, _box(p[j])])
		var groups := design.groups()
		if groups.size() > 1:
			groups.sort_custom(func(a, b): return a.size() > b.size())
			for group in groups.slice(1):
				print("%s: not joined: %s" % [key, ", ".join(group.map(func(i): return "%s %s" % [p[i].id, _box(p[i])]))])
	quit()


func _box(entry: Dictionary) -> String:
	var box := KartDesign.fine_box(entry.id, KartDesign.place_of(entry))
	return "(%s to %s)" % [box.position, box.end]
