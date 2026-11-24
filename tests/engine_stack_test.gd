extends SceneTree
## Engines stack at 1, 1/2, 1/4 and so on, and each one stops pushing at its
## rev_limit. Run with -s tests/engine_stack_test.gd.

var checks := 0
var failures := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## A plain 130 kg kart with the given engines.
func plain(ids: Array) -> KartStats:
	var stats := KartStats.new()
	stats.mass = 130.0
	stats.drag_area = 0.7
	stats.rolling = 0.015
	for id in ids:
		var def := PartCatalog.get_part(id)
		stats.engines.append({
			"power": def.get("power", 0.0) * KartStats.POWER_SCALE,
			"max_force": def.get("max_force", 0.0),
			"thrust": def.get("thrust", 0.0) * KartStats.THRUST_SCALE,
			"rev_limit": def.get("rev_limit", KartStats.DEFAULT_REV_LIMIT),
			"weight": 1.0,
		})
	stats._weigh_engines()
	return stats


func _init() -> void:
	var one := plain(["engine_small"])
	var kmh := one.top_speed() * 3.6
	print("small: %.0f km/h, %.2f g" % [kmh, one.pull()])
	check(kmh > 125.0 and kmh < 150.0, "one small engine tops out near 132 km/h")
	check(absf(one.power - 9000.0 * KartStats.POWER_SCALE) < 0.01, "one engine's totals are its own numbers")
	check(one.wheel_push(10.0) > 0.0 and one.wheel_push(one.engines[0].rev_limit) == 0.0, "push is gone at the rev limit")

	var two := plain(["engine_v8", "engine_v8"])
	var v8 := plain(["engine_v8"])
	check(absf(two.pull() / v8.pull() - 1.5) < 0.01, "two V8s pull 1.5 times one")
	check(two.top_speed() <= PartCatalog.get_part("engine_v8").rev_limit + 0.01, "two V8s stay under the rev limit")
	check(two.top_speed() >= v8.top_speed() - 0.01, "two V8s are no slower than one")

	var jet := plain(["jet"])
	var four := plain(["jet", "jet", "jet", "jet"])
	check(absf(four.thrust / jet.thrust - 1.875) < 0.001, "four jets give 1.875 times the thrust")
	check(four.top_speed() <= PartCatalog.get_part("jet").rev_limit + 0.01, "four jets stay under the jet's rev limit")
	check(four.top_speed() >= jet.top_speed() - 0.01, "four jets are no slower than one")
	check(four.jet_push(50.0) == 0.0, "jets push nothing above the rev limit")

	var both := plain(["engine_small", "jet"])
	check(both.engines[0].thrust > 0.0 or both.engines[1].thrust > 0.0, "engine and jet are both kept")
	var sorted_ok: bool = KartStats._push_at(both.engines[0], 20.0) >= KartStats._push_at(both.engines[1], 20.0)
	check(sorted_ok, "the stronger one is first")
	check(absf(both.engines[1].weight - 0.5) < 0.001, "the second counts half")
	check(both.pull() > one.pull() and both.pull() < one.pull() + jet.pull() + 0.01, "engine and jet pull more than the engine, less than the two summed")
	check(both.top_speed() <= maxf(PartCatalog.get_part("jet").rev_limit, PartCatalog.get_part("engine_small").rev_limit) + 0.01, "engine and jet stay under the highest rev limit")

	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
