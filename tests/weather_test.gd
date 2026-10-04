extends SceneTree

## The weather and the time of day: left to chance they suit the course and
## come out the same for the same seed, and picking them sticks.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/weather_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var a := Conditions.resolve("orchard", Conditions.RANDOM, Conditions.RANDOM, 1234)
	var b := Conditions.resolve("orchard", Conditions.RANDOM, Conditions.RANDOM, 1234)
	check(a.to_dict() == b.to_dict(), "the same seed gives the same weather and time (%s)" % a.describe())
	check(Conditions.from_dict(a.to_dict()).to_dict() == a.to_dict(), "and they come through being sent online unchanged")

	var counts := {}
	for theme in ["desert", "frost", "malta", "orchard", "hall_red"]:
		counts[theme] = {}
		for seed in 500:
			var c := Conditions.resolve(theme, Conditions.RANDOM, Conditions.RANDOM, seed)
			counts[theme][c.weather] = counts[theme].get(c.weather, 0) + 1
			if theme == "hall_red":
				counts[theme]["indoor"] = counts[theme].get("indoor", 0) + (1 if c.indoor and not c.dark() else 0)
	check(not counts.desert.has("rain") and not counts.desert.has("snow") and counts.desert.get("dust", 0) > 100, "deserts never rain or snow, and get dust storms %s" % [counts.desert])
	check(counts.frost.get("snow", 0) > 200, "frosty courses snow more often than not %s" % [counts.frost])
	check(counts.malta.get("clear", 0) > 350, "beaches are mostly sunny %s" % [counts.malta])
	check(counts.orchard.size() >= 4, "and anywhere else gets a mix %s" % [counts.orchard])
	check(counts.hall_red.get("indoor", 0) == 500, "halls are always indoors and lit")

	var picked := Conditions.resolve("desert", "snow", "night", 7)
	check(picked.weather == "snow" and picked.time == "night", "a picked weather and time stick, even ones that don't suit the course")
	check(Conditions.picked("rain", "fog") == "rain" and Conditions.picked(Conditions.RANDOM, "fog") == "fog" and Conditions.picked(Conditions.RANDOM, Conditions.RANDOM) == Conditions.RANDOM, "the player's pick comes first, then the course's")
	check(Conditions.resolve("orchard", "clear", "night", 1).dark() and not Conditions.resolve("orchard", "clear", "day", 1).dark() and Conditions.resolve("orchard", "fog", "day", 1).dark(), "it's dark at night and in fog, not on a clear day")

	# A course keeps its own weather and time through saving.
	var course := CourseDesign.starter()
	course.weather = "storm"
	course.time = "dusk"
	var again := CourseDesign.from_dict(course.to_dict())
	var track := TrackPath.from_dict(course.to_dict())
	check(again.weather == "storm" and again.time == "dusk" and track.weather == "storm" and track.time == "dusk", "a course keeps its own weather and time")

	print("All weather checks passed." if failures == 0 else "%d weather checks failed." % failures)
	quit(1 if failures > 0 else 0)
