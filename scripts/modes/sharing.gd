class_name Sharing
extends RefCounted

## Courses and cups as something to send to someone else, and back again.
##
## A share code is CODE_START, then the course or cup as JSON packed small
## with deflate and written in base64, then CODE_END, so it fits in a chat
## message and it's clear where it stops. A
## course comes to about 400 characters and a cup of eight to a few thousand.
## A file is the same JSON as the game saves, so a file from the courses or
## cups folder works too.
##
## read() finds a code anywhere in what's pasted, even split over lines by a
## chat app, or takes the JSON itself. add() puts what it found with your own
## courses or cups.

const CODE_START := "SNAPRACERS:"
const CODE_END := "."
## The most a course or cup can unpack to, so a bad code can't fill the phone.
const MOST_BYTES := 1 << 20
const COURSE := "course"
const CUP := "cup"

## What a course someone's sent can have in it (see buildable()), well past
## what the game's own courses use.
const MOST_PIECES := 200
const MOST_LANDMARKS := 100
const PIECE_TYPES := ["straight", "curve", "slant", "crest", "ramp", "jump", "loop", "corkscrew"]
const LIMITS := {"length": 12.0, "size": 4.0, "rise": 8.0, "across": 6.0, "height": 10.0, "bank": 90.0}

## The game's own courses, as they'd be shared, by path.
static var _game_courses := {}


## The share code for a course or a cup.
static func code_for(data: Dictionary) -> String:
	var packed := JSON.stringify(data).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	return CODE_START + Marshalls.raw_to_base64(packed) + CODE_END


## What to send with the code, so whoever gets it knows what it is.
static func message_for(data: Dictionary) -> String:
	var by := str(data.get("made_by", "")).strip_edges()
	var what := "a SnapRacers cup" if kind_of(data) == CUP else "a SnapRacers course"
	return "%s, %s%s\n%s" % [str(data.get("name", "")), what, (" by " + by) if by != "" else "", code_for(data)]


## The file name to send a course or cup as.
static func file_name_for(data: Dictionary) -> String:
	return CourseDesign.path_for(str(data.get("name", kind_of(data)))).get_file()


## The file's contents, the same as the game saves.
static func file_for(data: Dictionary) -> String:
	return JSON.stringify(data, "\t")


## COURSE or CUP, or "" when it's neither.
static func kind_of(data: Dictionary) -> String:
	if data.get("races") is Array:
		return CUP
	if data.get("pieces") is Array:
		return COURSE
	return ""


## What was pasted or opened, as { "kind", "data" }, or { "why" } saying
## what's wrong with it.
static func read(text: String) -> Dictionary:
	var data = null
	var at := text.find(CODE_START)
	if at >= 0:
		var inside := _base64_after(text, at + CODE_START.length())
		var packed := Marshalls.base64_to_raw(inside) if inside != "" else PackedByteArray()
		if packed.is_empty():
			return {"why": "That code isn't all there."}
		var unpacked := packed.decompress_dynamic(MOST_BYTES, FileAccess.COMPRESSION_DEFLATE)
		if unpacked.is_empty():
			return {"why": "That code isn't all there."}
		data = JSON.parse_string(unpacked.get_string_from_utf8())
	elif text.strip_edges().begins_with("{"):
		data = JSON.parse_string(text.strip_edges())
	if not data is Dictionary or kind_of(data) == "":
		return {"why": "That isn't a SnapRacers course or cup."}
	if kind_of(data) == COURSE:
		var course := CourseDesign.from_dict(data)
		if course.pieces.is_empty():
			return {"why": "That course hasn't got any road."}
		if not buildable(course):
			return {"why": "That course has pieces the game can't build."}
		return {"kind": COURSE, "data": course.to_dict()}
	var cup := _clean_cup(CupDesign.from_dict(data))
	if cup.races.size() > CupDesign.MOST or not cup.races.all(func(r): return buildable(CourseDesign.from_dict(r.course))):
		return {"why": "That cup has a course the game can't build."}
	if cup.problem() != "":
		return {"why": cup.problem()}
	return {"kind": CUP, "data": cup.to_dict()}


## Whether every piece of a course someone's sent is one the track editor
## could have made, so a bad one can't build something enormous.
static func buildable(course: CourseDesign) -> bool:
	if course.pieces.size() > MOST_PIECES or course.landmarks.size() > MOST_LANDMARKS:
		return false
	if course.width < 4.0 or course.width > 30.0 or course.hills < 0.0 or course.hills > 100.0:
		return false
	for spec in course.pieces:
		if not str(spec.get("type", "straight")) in PIECE_TYPES:
			return false
		for key in LIMITS:
			if spec.has(key):
				var value = spec[key]
				if not (value is float or value is int) or absf(value) > LIMITS[key]:
					return false
				if key in ["length", "size"] and value < 1:
					return false
	return true


## The base64 in a code, from `from` up to CODE_END, or "" if it doesn't get
## there. Spaces and line breaks are skipped, since a chat app may have
## wrapped it.
static func _base64_after(text: String, from: int) -> String:
	var out := ""
	for i in range(from, text.length()):
		var c := text[i]
		if c == CODE_END:
			return out
		if c in " \t\r\n":
			continue
		if not ((c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c in "+/="):
			return ""
		out += c
	return ""


## A cup from someone else, with every race that says it's one of the game's
## courses checked that it really is. The rest are raced from the copy in the
## cup.
static func _clean_cup(cup: CupDesign) -> CupDesign:
	var game := {}
	for id in Tracks.all():
		game[Tracks.path_of(id)] = true
	for race in cup.races:
		if not game.has(str(race.from)):
			race.from = game_path_of(race.course)
	return cup


## The path of the game's own course that's the same as this one, or "".
static func game_path_of(course: Dictionary) -> String:
	if _game_courses.is_empty():
		for id in Tracks.all():
			var path := Tracks.path_of(id)
			var theirs = JSON.parse_string(FileAccess.get_file_as_string(path))
			if theirs is Dictionary:
				_game_courses[path] = CourseDesign.from_dict(theirs).to_dict()
	var mine := CourseDesign.from_dict(course).to_dict()
	for path in _game_courses:
		if _game_courses[path] == mine:
			return path
	return ""


## A cup the way it's sent online ({ "name", "made_by", "courses" }) as one
## to keep, with the game's own courses raced from the game.
static func cup_from_online(cup: Dictionary) -> Dictionary:
	var races := []
	for course in cup.get("courses", []):
		if course is Dictionary:
			races.append({"from": game_path_of(course), "course": course})
	return {"name": str(cup.get("name", "A cup")), "made_by": str(cup.get("made_by", "")), "races": races}


## The file of yours that's the same as this, or "". The name doesn't
## count, since one added under another name is still the same one.
static func yours_already(kind: String, data: Dictionary) -> String:
	var wanted := _unnamed(kind, data)
	for path in (CourseDesign.saved() if kind == COURSE else CupDesign.saved()):
		var mine = JSON.parse_string(FileAccess.get_file_as_string(path))
		if mine is Dictionary and _unnamed(kind, mine) == wanted:
			return path
	return ""


## A course or cup as it's saved, without its name.
static func _unnamed(kind: String, data: Dictionary) -> Dictionary:
	var out := CourseDesign.from_dict(data).to_dict() if kind == COURSE else CupDesign.from_dict(data).to_dict()
	out.erase("name")
	return out


## Whether this is one of the game's own courses, which needs no keeping.
static func is_the_games(kind: String, data: Dictionary) -> bool:
	return kind == COURSE and game_path_of(data) != ""


## Puts a course or cup that's been read with your own, and says how it went
## as { "path", "said" }. A cup's own courses go with your courses too, so
## each can be raced on its own. Something you've already got isn't saved
## twice, and one with the same name as one of yours gets a number after it.
static func add(found: Dictionary) -> Dictionary:
	var kind: String = found.kind
	var data: Dictionary = found.data
	if is_the_games(kind, data):
		return {"path": game_path_of(data), "said": "%s is one of the game's courses already." % data.get("name", "That")}
	var have := yours_already(kind, data)
	if have != "":
		return {"path": have, "said": "You've already got %s." % data.get("name", "that")}
	if kind == COURSE:
		var course := CourseDesign.from_dict(data)
		course.name = _free_name(course.name, CourseDesign.path_for)
		var path := course.save()
		return {"path": path, "said": "%s is with your courses now." % course.name if path != "" else "I couldn't save it."}
	var cup := CupDesign.from_dict(data)
	for race in cup.races:
		if str(race.from) == "" and yours_already(COURSE, race.course) == "":
			var course := CourseDesign.from_dict(race.course)
			course.name = _free_name(course.name, CourseDesign.path_for)
			course.save()
	cup.name = _free_name(cup.name, CupDesign.path_for)
	var path := cup.save()
	return {"path": path, "said": "%s is with your cups now." % cup.name if path != "" else "I couldn't save it."}


## This name, or with a number after it if one of yours already has its file.
static func _free_name(wanted: String, path_for: Callable) -> String:
	var name := wanted.strip_edges() if wanted.strip_edges() != "" else "Shared"
	var tries := 1
	var out := name
	while FileAccess.file_exists(path_for.call(out)):
		tries += 1
		out = "%s %d" % [name, tries]
	return out
