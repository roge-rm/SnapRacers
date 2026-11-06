extends SceneTree

## Sharing courses, cups, racers and karts. A design goes to a share code and
## back the same, the code's found in a chat message even split over lines,
## a file's JSON works as well, and nonsense or a course that's been tampered
## with is turned away. Adding one puts it with your own, never twice, and a
## different one with the same name gets a number. A cup brings its own
## courses with it, the game's courses in it are raced from the game, and one
## sent online can be kept the same way.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/sharing_test.gd

var failures := 0
var made: Array[String] = []
var before := {}
var checks := 0
var tag := str(Time.get_ticks_usec())


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## Whether two courses or cups are the same once they've been through JSON,
## which reads every number back as a float.
static func same(a, b) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))


func _initialize() -> void:
	for kind in Sharing.KINDS:
		for path in Sharing.saved_paths(kind):
			before[path] = true
	var course := CourseDesign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit"))))
	course.name = "Sharing test course " + tag
	course.made_by = "Tester " + tag
	course.theme = "sakura"
	var data := course.to_dict()

	print("-- Codes")
	var code := Sharing.code_for(data)
	check(code.begins_with(Sharing.CODE_START) and code.length() < 1000, "a course's code is short (%d characters)" % code.length())
	var back := Sharing.read(code)
	check(back.get("kind") == Sharing.COURSE and same(back.data, data), "and reads back as the same course")
	var message := Sharing.message_for(data)
	check(message.contains("Sharing test course") and message.contains("by Tester"), "the message says what it is and who made it")
	var cut := message.find(Sharing.CODE_START) + Sharing.CODE_START.length() + 40
	var wrapped := "Try this one!\n" + message.substr(0, cut) + "\n" + message.substr(cut, 50) + " \n" + message.substr(cut + 50) + "\nsee you"
	check(same(Sharing.read(wrapped).get("data"), data), "a code's found in a chat message, even split over lines")
	check(same(Sharing.read(Sharing.file_for(data)).get("data"), data), "and the file's JSON works too")
	check(Sharing.read("hello there").has("why"), "nonsense is turned away")
	check(Sharing.read(code.substr(0, code.length() / 2)).has("why"), "and so is half a code")
	var huge := data.duplicate(true)
	huge.pieces[0]["length"] = 100000
	check(Sharing.read(Sharing.code_for(huge)).has("why"), "and a course with a piece the editor couldn't make")
	var odd := data.duplicate(true)
	odd.pieces[0]["type"] = "teleporter"
	check(Sharing.read(Sharing.code_for(odd)).has("why"), "or a piece that doesn't exist")
	var game_course = JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("lemon_lake")))
	check(Sharing.game_path_of(game_course) == Tracks.path_of("lemon_lake"), "one of the game's courses is known for what it is")
	var unbuildable: Array = Tracks.all().filter(func(id): return not Sharing.buildable(CourseDesign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of(id))))))
	check(unbuildable.is_empty(), "every one of the game's courses passes the check a host's course gets online %s" % str(unbuildable))

	print("-- Adding")
	var first := Sharing.add(back)
	made.append(first.path)
	check(first.path.begins_with(CourseDesign.FOLDER) and FileAccess.file_exists(first.path), "a course is added to yours (%s)" % first.said)
	var again := Sharing.add(Sharing.read(code))
	check(again.path == first.path and again.said.begins_with("You've already got"), "adding it again doesn't make a second one")
	var other := data.duplicate(true)
	other.theme = "orchard"
	var second := Sharing.add(Sharing.read(Sharing.code_for(other)))
	made.append(second.path)
	check(second.path != first.path and CourseDesign.load_file(second.path).name == course.name + " 2", "a different one with the same name gets a number (%s)" % CourseDesign.load_file(second.path).name)
	check(Sharing.add(Sharing.read(Sharing.code_for(game_course))).said.contains("one of the game's"), "one of the game's courses isn't added")

	print("-- Cups")
	var cup := CupDesign.new()
	cup.name = "Sharing test cup " + tag
	cup.made_by = "Tester " + tag
	cup.add(Tracks.path_of("lemon_lake"))
	cup.races.append({"from": "user://courses/somewhere_else.json", "course": other})
	var cup_code := Sharing.code_for(cup.to_dict())
	var cup_back := Sharing.read(cup_code)
	check(cup_back.get("kind") == Sharing.CUP, "a cup reads back as a cup (%d characters)" % cup_code.length())
	check(cup_back.data.races[0].from == Tracks.path_of("lemon_lake") and cup_back.data.races[1].from == "", "the game's course in it is raced from the game, and the other from the cup")
	var sneaky := cup.to_dict()
	sneaky.races[1].from = "res://data/tracks/../../project.godot"
	check(Sharing.read(Sharing.code_for(sneaky)).data.races[1].from == "", "a race can't say it's from somewhere it isn't")
	# The course in the cup is one of yours already, so only the cup is new.
	var kept := Sharing.add(cup_back)
	made.append(kept.path)
	check(kept.path.begins_with(CupDesign.FOLDER) and CupDesign.load_file(kept.path).races.size() == 2, "a cup is added to yours (%s)" % kept.said)
	check(CourseDesign.saved().filter(func(p): return CourseDesign.load_file(p).name.begins_with(course.name)).size() == 2, "and a course in it you've already got isn't added twice")
	var fresh := data.duplicate(true)
	fresh.name = "Sharing test cup course " + tag
	fresh.theme = "windmill"
	var cup_two := CupDesign.new()
	cup_two.name = "Sharing test cup two " + tag
	cup_two.add(Tracks.path_of("peach_pit"))
	cup_two.races.append({"from": "", "course": fresh})
	var added_two := Sharing.add(Sharing.read(Sharing.code_for(cup_two.to_dict())))
	made.append(added_two.path)
	var brought := CourseDesign.saved().filter(func(p): return CourseDesign.load_file(p).name == "Sharing test cup course " + tag)
	made.append_array(brought)
	check(brought.size() == 1, "a cup brings a course of its own with it, to race on its own")

	print("-- Online")
	var online := {"name": "Sharing test online", "made_by": "Host", "courses": [game_course, fresh]}
	var from_online := Sharing.read(JSON.stringify(Sharing.cup_from_online(online)))
	check(from_online.get("kind") == Sharing.CUP and from_online.data.races[0].from == Tracks.path_of("lemon_lake") and from_online.data.made_by == "Host", "a cup sent online can be kept, crediting whoever made it")

	_more_designs(data, game_course)
	_bad_inputs(data)
	_atomic_save(data)
	for path in made:
		if path != "" and not before.has(path):
			DirAccess.remove_absolute(path)
	print("All %d sharing checks passed." % checks if failures == 0 else "%d of %d sharing checks failed." % [failures, checks])
	quit(1 if failures > 0 else 0)


func _keep(found: Dictionary) -> Dictionary:
	var result := Sharing.add(found)
	if result.get("path", "") != "":
		made.append(result.path)
	return result


func _library() -> Array[String]:
	var paths: Array[String] = []
	for kind in Sharing.KINDS:
		paths.append_array(Sharing.saved_paths(kind))
	return paths


func _more_designs(course: Dictionary, stock: Dictionary) -> void:
	print("-- Racers and karts")
	var driver := CharacterDesign.from_dict({}).to_dict()
	driver.name = "Sharing racer " + tag
	driver.head.color = "#%06x" % (hash(tag) & 0xffffff)
	for slot in CharacterDesign.SLOTS:
		driver[slot].style = CharacterDesign.styles(slot).back()
	var driver_file := Sharing.file_for(driver)
	var wrapped = JSON.parse_string(driver_file)
	check(wrapped.format == Sharing.FORMAT and wrapped.version == Sharing.VERSION and wrapped.kind == Sharing.DRIVER, "racer files have a version and explicit kind")
	check(same(Sharing.read(driver_file).get("data"), driver), "all nine racer styles and colours survive file sharing")
	check(same(Sharing.read(Sharing.code_for(driver)).get("data"), driver), "racers survive a share code")
	check(same(Sharing.read(JSON.stringify(driver)).get("data"), driver), "raw saved racer JSON is accepted")
	check(Sharing.message_for(driver).contains("racer") and Sharing.file_name_for(driver).ends_with(".json"), "racer messages and file names say what they share")
	var explicit := Sharing.envelope_for(Sharing.DRIVER, driver)
	check(Sharing.kind_of(explicit) == Sharing.DRIVER and Sharing.data_of(explicit).name == driver.name and same(Sharing.read(Sharing.code_for(explicit)).get("data"), driver), "explicit envelopes use the same dictionary sharing API")
	var saved := _keep(Sharing.read(driver_file))
	check(saved.path.begins_with(CharacterDesign.SAVE_DIR) and FileAccess.file_exists(saved.path), "racers go into the driver library")
	var renamed := driver.duplicate(true)
	renamed.name += " renamed"
	check(Sharing.add(Sharing.read(JSON.stringify(renamed))).path == saved.path, "a racer under another name is kept once")
	var changed := driver.duplicate(true)
	changed.head.color = "#010203" if driver.head.color != "#010203" else "#040506"
	var second := _keep(Sharing.read(JSON.stringify(changed)))
	check(second.path != saved.path and CharacterDesign.load_file(saved.path).to_dict().head.color == driver.head.color, "different racers with the same name keep both files")
	for alias in CharacterDesign.HAIR_THAT_WAS_HEADGEAR:
		var old := driver.duplicate(true)
		old.erase("hair")
		old.headgear = {"style": alias, "color": "#aabbcc"}
		var retired := Sharing.read(JSON.stringify(old))
		check(retired.get("kind") == Sharing.DRIVER and retired.data.hair.style == CharacterDesign.HAIR_THAT_WAS_HEADGEAR[alias] and retired.data.hair.color == "#aabbcc", "retired headgear %s migrates to hair" % alias)

	var kart := {"name": "Sharing kart " + tag, "about": "Draft " + tag, "parts": []}
	for path in DirAccess.get_files_at("res://data/karts/stock"):
		if path.ends_with(".json"):
			var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/karts/stock/" + path))
			if raw is Dictionary and not raw.get("parts", []).is_empty():
				kart.parts = KartDesign.from_dict(raw).to_dict().parts
				break
	check(not kart.parts.is_empty(), "the kart fixture comes from the part catalogue")
	kart.parts[0].color = "#a1b2c3"
	for part in kart.parts:
		if KartDesign.is_wheel(part.id):
			part.suspension = "hard"
	var stock_failures: Array[String] = []
	for path in DirAccess.get_files_at("res://data/karts/stock"):
		if path.ends_with(".json") and Sharing.read(FileAccess.get_file_as_string("res://data/karts/stock/" + path)).has("why"):
			stock_failures.append(path)
	check(stock_failures.is_empty(), "every stock kart passes import validation %s" % str(stock_failures))
	var kart_file := Sharing.file_for(kart)
	check(JSON.parse_string(kart_file).kind == Sharing.KART, "kart files have an explicit kind")
	check(same(Sharing.read(kart_file).get("data"), kart), "kart parts, turns, paint, suspension and description survive sharing")
	check(same(Sharing.read(Sharing.code_for(kart)).get("data"), kart) and same(Sharing.read(JSON.stringify(kart)).get("data"), kart), "kart codes and raw saved JSON work")
	check(Sharing.message_for(kart).contains("kart") and Sharing.file_name_for(kart).ends_with(".json"), "kart messages and file names work")
	var kept := _keep(Sharing.read(kart_file))
	check(kept.path.begins_with(KartDesign.SAVE_DIR) and FileAccess.file_exists(kept.path), "karts go into the kart library")
	var renamed_kart := kart.duplicate(true)
	renamed_kart.name += " another name"
	check(Sharing.add(Sharing.read(JSON.stringify(renamed_kart))).path == kept.path, "a kart under another name is kept once")
	var legacy := {"name": "Legacy kart " + tag, "parts": [{"id": kart.parts[0].id, "at": [2, 3, 4], "rot": 3, "color": "#abcdef"}]}
	var legacy_back := Sharing.read(JSON.stringify(legacy))
	check(legacy_back.get("kind") == Sharing.KART and same(legacy_back.data, KartDesign.from_dict(legacy).to_dict()), "old at/rot kart saves keep placement and paint")
	var empty := {"name": "Unfinished " + tag, "about": "Empty " + tag, "parts": []}
	var draft := _keep(Sharing.read(Sharing.code_for(empty)))
	check(draft.path != "" and KartDesign.load_file(draft.path).parts.is_empty(), "an unfinished empty kart can be shared and kept")
	var one := _keep(legacy_back)
	check(one.path != "" and KartDesign.load_file(one.path).parts.size() == 1, "a disconnected or undriveable draft is allowed")
	var collide := empty.duplicate(true)
	collide.name = "Sharing / collision " + tag
	collide.about = "First " + tag
	var collision_a := _keep(Sharing.read(JSON.stringify(collide)))
	collide.name = "Sharing ? collision " + tag
	collide.about = "Second " + tag
	var collision_b := _keep(Sharing.read(JSON.stringify(collide)))
	check(collision_a.path != collision_b.path and KartDesign.load_file(collision_a.path).about == "First " + tag, "names that sanitise to one kart filename never overwrite")
	var hostile_name := empty.duplicate(true)
	hostile_name.name = "../../Sharing escape " + tag
	hostile_name.about = "Path " + tag
	var safe := _keep(Sharing.read(JSON.stringify(hostile_name)))
	check(safe.path.begins_with(KartDesign.SAVE_DIR + "/") and not safe.path.trim_prefix(KartDesign.SAVE_DIR + "/").contains("/"), "a name cannot escape its library folder")

	print("-- Cup snapshots")
	var custom := course.duplicate(true)
	custom.name = "Sharing repeated course " + tag
	custom.made_by = "Snapshot " + tag
	custom.laps = 7
	custom.weather = "rain"
	custom.time = "night"
	custom.fixed_time = true
	custom.hills = 0
	var cup := {"name": "Sharing mixed cup " + tag, "made_by": "Cup " + tag, "races": [
		{"from": Tracks.path_of("lemon_lake"), "course": stock},
		{"from": "/home/sender/private/track.json", "course": custom},
		{"from": "user://courses/private.json", "course": custom},
		{"from": Tracks.path_of("lemon_lake"), "course": custom}]}
	var cup_file := Sharing.file_for(cup)
	var cup_code := Sharing.code_for(cup)
	check(not cup_file.contains("/home/sender") and not cup_file.contains("user://"), "cup files strip sender library and absolute paths")
	var cup_back := Sharing.read(cup_code)
	check(cup_back.get("kind") == Sharing.CUP and cup_back.data.races.size() == 4, "mixed stock and custom cups retain repeated races")
	check(cup_back.data.races[0].from == Tracks.path_of("lemon_lake") and cup_back.data.races[3].from == "" and same(cup_back.data.races[3].course, custom), "a forged stock path uses its actual inline snapshot")
	check(cup_back.data.races[1].course.laps == 7 and cup_back.data.races[1].course.weather == "rain" and cup_back.data.races[1].course.time == "night" and cup_back.data.races[1].course.fixed_time, "cup snapshots retain laps, weather and time")
	var legacy_code := Sharing.CODE_START + Marshalls.raw_to_base64(JSON.stringify(cup).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)) + "."
	check(same(Sharing.read(legacy_code).get("data"), cup_back.data), "old unwrapped cup codes with sender paths import safely")
	var old_cup := Sharing.read(JSON.stringify(cup))
	check(same(old_cup.data, cup_back.data), "old cup files with sender paths import safely")
	var kept_cup := _keep(cup_back)
	var brought: Array[String] = CourseDesign.saved().filter(func(p): return not before.has(p) and CourseDesign.load_file(p).name.begins_with(custom.name))
	made.append_array(brought)
	check(kept_cup.path != "" and brought.size() == 1 and same(CupDesign.load_file(kept_cup.path).races, cup_back.data.races), "a whole cup is kept in order and repeated dependencies are saved once")
	var renamed_cup := cup.duplicate(true)
	renamed_cup.name += " renamed"
	for race in renamed_cup.races:
		race.from = "user://other/sender.json"
	check(Sharing.add(Sharing.read(JSON.stringify(renamed_cup))).path == kept_cup.path, "cup duplicates ignore display names and sender paths")


func _bad_inputs(course: Dictionary) -> void:
	print("-- Invalid input")
	var paths := _library()
	var driver := CharacterDesign.from_dict({}).to_dict()
	var invalid: Array = [
		Sharing.envelope_for("spaceship", driver),
		{"format": Sharing.FORMAT, "version": 2, "kind": Sharing.DRIVER, "data": driver},
		{"format": "Other", "version": 1, "kind": Sharing.COURSE, "data": course, "pieces": course.pieces},
		Sharing.envelope_for(Sharing.DRIVER, {}),
		{"name": "Ambiguous", "parts": [], "pieces": course.pieces},
		{"name": [], "parts": []},
		{"name": "Long", "about": "a".repeat(Sharing.MOST_ABOUT + 1), "parts": []},
	]
	var wrong := driver.duplicate(true)
	wrong.head.style = "res://malicious.tres"
	invalid.append(wrong)
	wrong = driver.duplicate(true)
	wrong.torso = []
	invalid.append(wrong)
	wrong = driver.duplicate(true)
	wrong.head.color = "not a colour"
	invalid.append(wrong)
	wrong = driver.duplicate(true)
	wrong.hair = {"style": "unknown", "color": "#123456"}
	invalid.append(wrong)
	var id := ""
	for path in DirAccess.get_files_at("res://data/karts/stock"):
		if path.ends_with(".json"):
			var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/karts/stock/" + path))
			if raw is Dictionary and not raw.get("parts", []).is_empty():
				id = raw.parts[0].id
				break
	for bad_part in [
		{"id": "res://project.godot", "pos": [0, 0, 0]},
		{"id": id, "pos": [0, 0]}, {"id": id, "pos": [0, 0, 0, 0]},
		{"id": id, "pos": ["0", 0, 0]}, {"id": id, "pos": [1000000, 0, 0]},
		{"id": id, "pos": [-401, 0, 0]}, {"id": id, "pos": [0, 0, 0], "turn": 24},
		{"id": id, "pos": [0, 0, 0], "turn": 0.5}, {"id": id, "at": [0, 0, 0], "rot": -1},
		{"id": id, "at": [0, 0.5, 0]}, {"id": id, "at": []},
		{"id": id, "pos": [0, 0, 0], "color": []},
		{"id": id, "pos": [0, 0, 0], "suspension": "extreme"}, [],
	]:
		invalid.append({"name": "Bad kart", "parts": [bad_part]})
	for key in ["pieces", "landmarks", "start"]:
		var bad_course := course.duplicate(true)
		bad_course[key] = {}
		invalid.append(bad_course)
	for key in ["length", "size", "rise"]:
		var bad_course := course.duplicate(true)
		bad_course.pieces[0][key] = []
		invalid.append(bad_course)
	var bad_grid := course.duplicate(true)
	bad_grid.grid = 0
	invalid.append(bad_grid)
	var bad_cup := {"name": "Bad cup", "races": [{"course": course}, {"course": {"pieces": []}}]}
	invalid.append(bad_cup)
	for i in invalid.size():
		var back := Sharing.read(JSON.stringify(invalid[i]))
		check(back.has("why"), "invalid shape %d returns a clear error" % i)
	check(Sharing.read(" ".repeat(Sharing.MOST_BYTES + 1)).has("why"), "oversized raw input is rejected")
	check(Sharing.read(Sharing.CODE_START + "A".repeat(Sharing.MOST_BYTES) + ".").has("why"), "oversized encoded input is rejected")
	var too_many_parts := {"name": "Too many parts", "parts": []}
	for i in Sharing.MOST_PARTS + 1:
		too_many_parts.parts.append({"id": id, "pos": [0, 0, 0]})
	check(Sharing.read(JSON.stringify(too_many_parts)).has("why"), "oversized kart models are rejected before opening the editor")
	check(Sharing.add({"kind": Sharing.KART, "data": too_many_parts}).has("why"), "oversized kart models cannot be saved by bypassing read")
	var crowded := {"name": "Overlapping connections", "parts": []}
	for i in 28:
		crowded.parts.append({"id": "p_plate_6x12", "pos": [0, 0, 0]})
	check(Sharing.read(JSON.stringify(crowded)).has("why"), "small files cannot request excessive connector comparisons")
	var rounded_crowd := {"name": "Rounded connections", "parts": []}
	for x in [0.499, 0.501]:
		for y in [0.499, 0.501]:
			for z in [0.499, 0.501]:
				for i in 28:
					rounded_crowd.parts.append({"id": "p_plate_2x4", "pos": [x, y, z]})
	check(Sharing.read(JSON.stringify(rounded_crowd)).has("why"), "connection budgets use the positions that will be saved and loaded")
	var bomb := Sharing.CODE_START + Marshalls.raw_to_base64(" ".repeat(Sharing.MOST_BYTES + 1).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)) + "."
	var printed_errors := Engine.print_error_messages
	Engine.print_error_messages = false
	var too_large := Sharing.read(bomb)
	var infinite := Sharing.read('{"name":"Infinite","parts":[{"id":"%s","pos":[1e999,0,0]}]}' % id)
	Engine.print_error_messages = printed_errors
	check(too_large.has("why"), "decompressed data cannot exceed the size limit")
	check(infinite.has("why"), "non-finite JSON coordinates are rejected")
	var bad_add := Sharing.add({"kind": Sharing.KART, "data": {"parts": [{"id": id, "pos": []}]}})
	check(bad_add.has("why") and bad_add.path == "", "add revalidates data and reports a save failure without writing")
	check(Sharing.add({"why": "bad input"}).has("why"), "add accepts a failed read without an exception")
	check(_library() == paths, "invalid input leaves every library unchanged")


func _atomic_save(course: Dictionary) -> void:
	print("-- Save rollback")
	var base := CourseDesign.FOLDER + "/sharing_atomic_" + tag
	var dependency := base + "_dependency.json"
	var blocker := base + "_blocker"
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("Keep this fixture unchanged")
	file.close()
	var plan: Array[Dictionary] = [{"path": dependency, "data": course}, {"path": blocker + "/cup.json", "data": {"name": "Cup"}}]
	check(not Sharing._write_plan(plan) and not FileAccess.file_exists(dependency), "a later save failure removes earlier new dependencies")
	check(FileAccess.get_file_as_string(blocker) == "Keep this fixture unchanged", "save rollback leaves pre-existing files untouched")
	plan = [{"path": blocker, "data": course}]
	check(not Sharing._write_plan(plan) and FileAccess.get_file_as_string(blocker) == "Keep this fixture unchanged", "a planned write refuses an existing file")
	DirAccess.remove_absolute(blocker)
