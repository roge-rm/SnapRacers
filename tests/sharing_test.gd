extends SceneTree

## Sharing courses and cups (Sharing). A course or cup goes to a share code and
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


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## Whether two courses or cups are the same once they've been through JSON,
## which reads every number back as a float.
static func same(a, b) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))


func _initialize() -> void:
	var course := CourseDesign.from_dict(JSON.parse_string(FileAccess.get_file_as_string(Tracks.path_of("peach_pit"))))
	course.name = "Sharing test course"
	course.made_by = "Tester"
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
	check(second.path != first.path and CourseDesign.load_file(second.path).name == "Sharing test course 2", "a different one with the same name gets a number (%s)" % CourseDesign.load_file(second.path).name)
	check(Sharing.add(Sharing.read(Sharing.code_for(game_course))).said.contains("one of the game's"), "one of the game's courses isn't added")

	print("-- Cups")
	var cup := CupDesign.new()
	cup.name = "Sharing test cup"
	cup.made_by = "Tester"
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
	check(CourseDesign.saved().filter(func(p): return CourseDesign.load_file(p).name.begins_with("Sharing test course")).size() == 2, "and a course in it you've already got isn't added twice")
	var fresh := data.duplicate(true)
	fresh.name = "Sharing test cup course"
	fresh.theme = "windmill"
	var cup_two := CupDesign.new()
	cup_two.name = "Sharing test cup two"
	cup_two.add(Tracks.path_of("peach_pit"))
	cup_two.races.append({"from": "", "course": fresh})
	var added_two := Sharing.add(Sharing.read(Sharing.code_for(cup_two.to_dict())))
	made.append(added_two.path)
	var brought := CourseDesign.saved().filter(func(p): return CourseDesign.load_file(p).name == "Sharing test cup course")
	made.append_array(brought)
	check(brought.size() == 1, "a cup brings a course of its own with it, to race on its own")

	print("-- Online")
	var online := {"name": "Sharing test online", "made_by": "Host", "courses": [game_course, fresh]}
	var from_online := Sharing.read(JSON.stringify(Sharing.cup_from_online(online)))
	check(from_online.get("kind") == Sharing.CUP and from_online.data.races[0].from == Tracks.path_of("lemon_lake") and from_online.data.made_by == "Host", "a cup sent online can be kept, crediting whoever made it")

	for path in made:
		if path != "":
			DirAccess.remove_absolute(path)
	print("All sharing checks passed." if failures == 0 else "%d sharing checks failed." % failures)
	quit(1 if failures > 0 else 0)
