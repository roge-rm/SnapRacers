extends Node

## Checks each stock driver's traits load from the roster, a made up driver's
## come from their name the same way every time, and traits only nudge a
## level's settings (see Difficulty.personalise()).
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/driver_traits_test.tscn

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	# Every stock driver has their own, all in range, and online (by name
	# only) gives the same as offline (by roster key).
	var keys: Array[String] = []
	for file in DirAccess.get_files_at(DriverTraits.ROSTER):
		if file.ends_with(".json"):
			keys.append(file.get_basename())
	var seen := {}
	var loaded := 0
	var in_range := true
	var same_online := true
	for key in keys:
		var traits := DriverTraits.for_roster(key)
		if traits == null:
			continue
		loaded += 1
		for value: float in traits.to_dict().values():
			in_range = in_range and value >= -1.0 and value <= 1.0
		seen[JSON.stringify(traits.to_dict())] = true
		var who := CharacterDesign.load_file("%s/%s.json" % [DriverTraits.ROSTER, key])
		same_online = same_online and DriverTraits.for_driver("", who.name).to_dict() == traits.to_dict() and DriverTraits.for_driver(key, who.name).to_dict() == traits.to_dict()
	check(keys.size() == 15 and loaded == 15, "traits load for all fifteen stock drivers (%d of %d)" % [loaded, keys.size()])
	check(seen.size() == 15, "no two stock drivers have the same traits")
	check(in_range, "every stock trait is between -1 and 1")
	check(same_online, "a stock driver gets the same traits by name as by roster key")

	# A made up driver's come from their name, the same every time.
	var a := DriverTraits.for_driver("", "Zed Speedwell")
	var again := DriverTraits.for_driver("", "Zed Speedwell")
	var other := DriverTraits.for_driver("", "Zed Speedwel")
	check(a.to_dict() == again.to_dict(), "a made up driver's traits are the same every time %s" % [a.to_dict()])
	check(a.to_dict() != other.to_dict(), "a different name gives different traits")
	var mild := true
	for i in 50:
		for value: float in DriverTraits.from_name("Driver %d" % i).to_dict().values():
			mild = mild and absf(value) <= DriverTraits.FROM_NAME + 0.001
	check(mild, "traits from a name stay within %.1f either way" % DriverTraits.FROM_NAME)

	# No traits leaves the level as it is, and the strongest traits only move
	# each setting by its share in Difficulty.NUDGE.
	for level in Difficulty.LEVELS:
		var plain := _set_up(level, null)
		var zero := _set_up(level, DriverTraits.new())
		check(_settings(plain) == _settings(zero), "%s: no traits leaves the level's settings alone" % level)
		var within := true
		var moved := false
		var off_stays_off := true
		var corners := [-1.0, 1.0]
		for ag in corners:
			for pa in corners:
				for co in corners:
					for la in corners:
						var t := DriverTraits.from_dict({"aggression": ag, "patience": pa, "consistency": co, "late_braking": la})
						var nudged := _settings(_set_up(level, t))
						var base := _settings(plain)
						for setting: String in base:
							var b: float = base[setting]
							var n: float = nudged[setting]
							var share: float = Difficulty.NUDGE.get(setting, 0.0)
							if b == 0.0:
								off_stays_off = off_stays_off and n == 0.0
							elif absf(n - b) > absf(b) * share + 0.0001:
								within = false
								print("    %s %s %.3f from %.3f" % [level, setting, n, b])
							moved = moved or not is_equal_approx(n, b)
		check(within and moved, "%s: the strongest traits move settings, each by at most its share" % level)
		check(off_stays_off, "%s: settings the level has off stay off" % level)

	# Aggression packs closer, patience costs more to pull out, consistency
	# wanders less and late braking counts on more braking.
	var bold := _set_up("normal", DriverTraits.from_dict({"aggression": 1.0, "patience": 1.0, "consistency": 1.0, "late_braking": 1.0}))
	var meek := _set_up("normal", DriverTraits.from_dict({"aggression": -1.0, "patience": -1.0, "consistency": -1.0, "late_braking": -1.0}))
	check(bold.traffic_clearance < meek.traffic_clearance, "aggression leaves less room")
	check(bold.traffic_move_cost > meek.traffic_move_cost and bold.traffic_hold > meek.traffic_hold, "patience makes pulling out to pass cost more")
	check(bold.line_wander < meek.line_wander, "consistency wanders less")
	check(bold.brake_late > meek.brake_late, "late braking counts on more braking")
	check(bold.traits.aggression == 1.0 and meek.traits.patience == -1.0, "the traits are there on the driver for racecraft")
	# Even the most extreme Normal driver leaves more room than Hard.
	var hard := _set_up("hard", null)
	check(bold.traffic_clearance > hard.traffic_clearance, "an aggressive Normal driver still leaves more room than Hard")
	for ai in _drivers:
		ai.free()

	print("%d failed" % failures if failures > 0 else "all passed")
	get_tree().quit(1 if failures > 0 else 0)


var _drivers: Array[AIDriver] = []


func _set_up(level: String, traits: DriverTraits) -> AIDriver:
	var ai := AIDriver.new()
	_drivers.append(ai)
	Difficulty.apply(ai, level, 3, 7, traits)
	return ai


func _settings(ai: AIDriver) -> Dictionary:
	var out := {}
	for setting in ["traffic_clearance", "traffic_reaction", "traffic_mass_ratio", "traffic_contact_closing", "traffic_contact_cooldown", "traffic_move_cost", "traffic_hold", "pass_wait", "mistakes", "line_wander", "brake_late", "skill", "pace", "line_follow", "line_late"]:
		out[setting] = ai.get(setting)
	return out
