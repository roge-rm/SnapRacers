extends SceneTree

## Prints every engine alone on a plain kart (130 kg without the engine, 0.7 m²
## drag area, rolling 0.015): top speed, pull and 0 to 100 km/h. Uses KartStats,
## so it matches the garage. Tire grip isn't counted.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/engines.gd


func _init() -> void:
	print("%-16s %5s %8s %6s %8s" % ["engine", "kg", "top km/h", "pull g", "0-100 s"])
	var rows: Array = []
	for id in PartCatalog.ids():
		var def := PartCatalog.get_part(id)
		if def.get("kind", "") != "engine":
			continue
		var stats := KartStats.alone(def)
		rows.append([id, stats.mass, stats.top_speed() * 3.6, stats.pull(), _zero_to_100(stats)])
	rows.sort_custom(func(a, b): return a[3] > b[3])
	for r in rows:
		var t: String = "never" if r[4] < 0.0 else "%.1f" % r[4]
		print("%-16s %5.0f %8.1f %6.2f %8s" % [r[0], r[1], r[2], r[3], t])
	quit()


## Seconds to 100 km/h with the same forces, or -1 if it never gets there.
func _zero_to_100(stats: KartStats) -> float:
	var g := KartStats.gravity()
	var v := 0.0
	var t := 0.0
	var dt := 0.005
	while v < 100.0 / 3.6 and t < 60.0:
		var force := stats.wheel_push(v) + stats.jet_push(v)
		force -= 0.5 * KartStats.AIR_DENSITY * stats.drag_area * v * v + stats.rolling * stats.mass * g
		v += force / stats.mass * dt
		t += dt
	return t if v >= 100.0 / 3.6 else -1.0
