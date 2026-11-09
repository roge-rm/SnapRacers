class_name Sharing
extends RefCounted

## Courses, cups, drivers and karts as files or compressed codes to send.
## read() validates data before the design classes see it. add() keeps it in
## the player's library and rolls back a cup's new files if a save fails.

const CODE_START := "SNAPRACERS:"
const CODE_END := "."
const MOST_BYTES := 1 << 20
const FORMAT := "SnapRacers"
const VERSION := 1
const COURSE := "course"
const CUP := "cup"
const DRIVER := "driver"
const KART := "kart"
const KINDS := [COURSE, CUP, DRIVER, KART]
const MOST_PIECES := 200
const MOST_LANDMARKS := 100
## Bound model creation and connector comparisons before opening an import.
const MOST_PARTS := 256
const MOST_CONNECTORS := 4096
const MOST_CONNECTOR_PAIRS := 50000
const MOST_NAME := 120
const MOST_ABOUT := 2000
const PIECE_TYPES := ["straight", "half_straight", "quarter_straight", "adjustable_straight", "adjustable_offset", "connector", "curve", "arc", "slant", "crest", "ramp", "jump", "loop", "corkscrew", "crossing"]
const LIMITS := {"length": 12.0, "size": 4.0, "rise": 8.0, "across": 6.0, "height": 10.0, "bank": 90.0}

static var _game_courses := {}


## Explicitly tags a design for sharing. Export helpers also recognise raw
## saved designs, so ShareWindow.open(design.to_dict(), parent) works.
static func envelope_for(kind: String, data: Dictionary) -> Dictionary:
	return {"format": FORMAT, "version": VERSION, "kind": kind, "data": data.duplicate(true)}


## The design inside an envelope, or the raw saved design itself.
static func data_of(data: Dictionary) -> Dictionary:
	return data.data if _is_envelope(data) and data.get("data") is Dictionary else data


static func code_for(data: Dictionary) -> String:
	var packed := JSON.stringify(_export_data(data)).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	return CODE_START + Marshalls.raw_to_base64(packed) + CODE_END


static func message_for(data: Dictionary) -> String:
	var payload := data_of(data)
	var by := str(payload.get("made_by", "")).strip_edges()
	var noun: String = {COURSE: "course", CUP: "cup", DRIVER: "racer", KART: "kart"}.get(kind_of(data), "design")
	return "%s, a SnapRacers %s%s\n%s" % [str(payload.get("name", "")), noun, (" by " + by) if by != "" else "", code_for(data)]


static func file_name_for(data: Dictionary) -> String:
	return path_for(kind_of(data), str(data_of(data).get("name", "Shared"))).get_file()


static func file_for(data: Dictionary) -> String:
	return JSON.stringify(_export_data(data), "\t")


static func _export_data(data: Dictionary) -> Dictionary:
	var kind := kind_of(data)
	var payload := data_of(data).duplicate(true)
	if kind == CUP:
		# Only a matching stock snapshot can carry a path to another player.
		var found := _validate(CUP, payload)
		if not found.has("why"):
			payload = found.data
		else:
			for race in payload.get("races", []):
				if race is Dictionary:
					race["from"] = ""
	if kind in [DRIVER, KART] or _is_envelope(data):
		return envelope_for(kind, payload)
	return payload


static func _is_envelope(data: Dictionary) -> bool:
	return data.has("format") or data.has("version") or data.has("kind") or data.has("data")


## A kind constant, or "" when the shape or envelope isn't recognised.
static func kind_of(data: Dictionary) -> String:
	if _is_envelope(data):
		if data.get("format") == FORMAT and data.get("version") == VERSION and data.get("kind") in KINDS and data.get("data") is Dictionary:
			return data.kind
		return ""
	var kinds := []
	if data.get("races") is Array:
		kinds.append(CUP)
	if data.get("pieces") is Array:
		kinds.append(COURSE)
	if data.get("parts") is Array:
		kinds.append(KART)
	if data.get("head") is Dictionary and data.get("torso") is Dictionary:
		kinds.append(DRIVER)
	return kinds[0] if kinds.size() == 1 else ""


## Returns {kind, data}, or {why}. Raw library JSON and old course/cup codes
## remain valid; unknown envelope kinds and versions never fall back to raw.
static func read(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MOST_BYTES:
		return {"why": "That file or code is too large."}
	var data = null
	var json := JSON.new()
	var at := text.find(CODE_START)
	if at >= 0:
		var inside := _base64_after(text, at + CODE_START.length())
		var packed := Marshalls.base64_to_raw(inside) if inside != "" else PackedByteArray()
		if packed.is_empty():
			return {"why": "That code isn't all there."}
		var unpacked := packed.decompress_dynamic(MOST_BYTES, FileAccess.COMPRESSION_DEFLATE)
		if unpacked.is_empty() or unpacked.size() > MOST_BYTES:
			return {"why": "That code is incomplete or too large."}
		if json.parse(unpacked.get_string_from_utf8()) == OK:
			data = json.data
	elif text.strip_edges().begins_with("{"):
		if json.parse(text.strip_edges()) == OK:
			data = json.data
	if not data is Dictionary:
		return {"why": "That isn't a SnapRacers course, cup, racer or kart."}
	if _is_envelope(data):
		if data.get("format") != FORMAT or not _integer(data.get("version"), VERSION, VERSION):
			return {"why": "That sharing format or version isn't supported."}
		if not data.get("kind") in KINDS or not data.get("data") is Dictionary:
			return {"why": "That sharing kind isn't supported."}
		return _validate(data.kind, data.data)
	var kind := kind_of(data)
	if kind == "":
		return {"why": "That isn't a SnapRacers course, cup, racer or kart."}
	return _validate(kind, data)


## Checks saved editor data without sharing size limits or race readiness.
static func validate_saved(kind: String, data: Dictionary) -> Dictionary:
	return _validate(kind, data, true)


## Checks raw host data before start parsing or geometry can discard bad fields.
static func validate_course(data: Dictionary) -> Dictionary:
	return _validate(COURSE, data)


static func _validate(kind: String, data: Dictionary, saved := false) -> Dictionary:
	if not data.get("name", "") is String or not data.get("made_by", "") is String or (not saved and (not _text(data.get("name", ""), MOST_NAME) or not _text(data.get("made_by", ""), MOST_NAME))):
		return {"why": "That design has an invalid name or author."}
	match kind:
		COURSE:
			return _read_course(data, saved)
		CUP:
			if not data.get("races") is Array or data.races.size() < (0 if saved else CupDesign.FEWEST) or data.races.size() > CupDesign.MOST:
				return {"why": "A cup needs 2 to 8 races."}
			var cup := {"name": data.get("name", "My cup"), "made_by": data.get("made_by", ""), "races": []}
			for race in data.races:
				if not race is Dictionary or not race.get("course") is Dictionary or not _text(race.get("from", ""), 4096):
					return {"why": "That cup has an invalid race."}
				var found := _validate(COURSE, race.course, saved)
				if found.has("why"):
					return found
				var stock := game_path_of(found.data)
				if not saved and stock == "" and not CourseDesign.from_dict(found.data).problems().is_empty():
					return {"why": "%s isn't finished." % found.data.get("name", "A course")}
				cup.races.append({"from": stock, "course": found.data})
			return {"kind": CUP, "data": cup}
		DRIVER:
			if not data.get("head") is Dictionary or not data.get("torso") is Dictionary:
				return {"why": "That racer needs a head and torso."}
			for slot in CharacterDesign.SLOTS:
				if not data.has(slot):
					continue
				var entry = data[slot]
				if not entry is Dictionary or not entry.get("style") is String or not _colour(entry.get("color", "#f2cd37")):
					return {"why": "That racer has an invalid piece or colour."}
				var retired: bool = slot == "headgear" and CharacterDesign.HAIR_THAT_WAS_HEADGEAR.has(entry.style)
				if not retired and not entry.style in CharacterDesign.styles(slot):
					return {"why": "That racer has a style the game doesn't have."}
			return {"kind": DRIVER, "data": CharacterDesign.from_dict(data).to_dict()}
		KART:
			if not data.get("about", "") is String or (not saved and not _text(data.get("about", ""), MOST_ABOUT)) or not data.get("parts") is Array:
				return {"why": "That kart has invalid parts or description."}
			if not saved and data.parts.size() > MOST_PARTS:
				return {"why": "A shared kart can have up to %d parts." % MOST_PARTS}
			for entry in data.parts:
				if not entry is Dictionary or not entry.get("id") is String or PartCatalog.get_part(entry.id).is_empty():
					return {"why": "That kart has a part the game doesn't have."}
				if entry.has("pos"):
					if not _coordinates(entry.pos, [KartDesign.BUILD_SIZE.x * Grid.STUD_FINE, KartDesign.BUILD_SIZE.y * Grid.PLATE_FINE, KartDesign.BUILD_SIZE.z * Grid.STUD_FINE], false) or not _integer(entry.get("turn", 0), 0, 23):
						return {"why": "That kart has an invalid position or turn."}
				elif not _coordinates(entry.get("at", [0, 0, 0]), [KartDesign.BUILD_SIZE.x, KartDesign.BUILD_SIZE.y, KartDesign.BUILD_SIZE.z], true) or not _integer(entry.get("rot", 0), 0, 3):
					return {"why": "That kart has an invalid position or turn."}
				if entry.has("color") and not _colour(entry.color):
					return {"why": "That kart has an invalid colour."}
				if entry.has("suspension") and (not entry.suspension is String or not entry.suspension in KartDesign.SUSPENSION):
					return {"why": "That kart has invalid suspension."}
			var canonical := KartDesign.from_dict(data).to_dict()
			if not saved and not _kart_work_bounded(KartDesign.from_dict(canonical)):
				return {"why": "That kart has too many overlapping connections to import."}
			return {"kind": KART, "data": canonical}
	return {"why": "That sharing kind isn't supported."}


static func _kart_work_bounded(design: KartDesign) -> bool:
	var spots := {}
	var connectors := 0
	var pairs := 0
	for part in design.parts:
		for connector in Connectors.placed(part.id, design.place_of(part)):
			connectors += 1
			if connectors > MOST_CONNECTORS:
				return false
			var key := Connectors.key_of(connector.at)
			var count: int = spots.get(key, 0)
			pairs += count
			if pairs > MOST_CONNECTOR_PAIRS:
				return false
			spots[key] = count + 1
	return true


static func _read_course(data: Dictionary, saved := false) -> Dictionary:
	if not data.get("pieces") is Array or (not saved and data.pieces.is_empty()) or (not saved and data.pieces.size() > MOST_PIECES):
		return {"why": "That course needs 1 to %d road pieces." % MOST_PIECES}
	for key in ["theme", "weather", "time"]:
		if not _text(data.get(key, ""), MOST_NAME):
			return {"why": "That course has an invalid setting."}
	for key in ["width", "hills", "grid", "laps"]:
		if data.has(key) and not _number(data[key]):
			return {"why": "That course has an invalid size."}
	if data.has("map_rotation") and (not _number(data.map_rotation) or float(data.map_rotation) < 0.0 or float(data.map_rotation) >= 360.0):
		return {"why": "That course has an invalid map rotation."}
	if data.has("grid") and not data.grid in [TrackPiece.OLD_TILE, TrackPiece.TILE]:
		return {"why": "That course has an invalid grid."}
	if data.has("laps") and not _integer(data.laps, 1, 9):
		return {"why": "That course has an invalid lap count."}
	if data.has("fixed_time") and not data.fixed_time is bool:
		return {"why": "That course has an invalid time setting."}
	if not _start(data.get("start", [])):
		return {"why": "That course has an invalid start."}
	for spec in data.pieces:
		if not _piece(spec):
			return {"why": "That course has pieces the game can't build."}
	if not data.get("landmarks", []) is Array or (not saved and data.get("landmarks", []).size() > MOST_LANDMARKS):
		return {"why": "That course has invalid landmarks."}
	for mark in data.get("landmarks", []):
		if not mark is Dictionary or not mark.get("prop") is String or not Props.ROOM.has(mark.prop) or not _vector(mark.get("at", [0, 0]), 100000.0, 2) or not _integer(mark.get("facing", 0), 0, 3):
			return {"why": "That course has an invalid landmark."}
	var canonical := data.duplicate(true)
	if not canonical.get("start", []).is_empty():
		canonical.start[3] = roundf(float(canonical.start[3]) * 6.0) / 6.0
	var course := CourseDesign.from_dict(canonical)
	if not buildable(course, saved):
		return {"why": "That course has pieces the game can't build."}
	return {"kind": COURSE, "data": course.to_dict()}


static func _start(value: Variant) -> bool:
	if not value is Array:
		return false
	if value.is_empty():
		return true
	if value.size() != 4 or not _vector(value.slice(0, 3), 100000.0) or not _number(value[3]):
		return false
	var turns := float(value[3])
	var heading := roundf(turns * 6.0)
	# Accept decimal starts such as 0.166667, then store the canonical heading.
	return turns >= 0.0 and turns < 4.0 and heading >= 0.0 and heading < 24.0 and absf(turns * 6.0 - heading) <= 0.00001


static func _piece(spec: Variant) -> bool:
	if not spec is Dictionary or not spec.get("type", "straight") in PIECE_TYPES:
		return false
	if spec.get("type") in TrackPiece.ADJUSTABLE_TYPES:
		var kind: String = spec.type
		var allowed := ["type", "surface", "edges"]
		if kind == "connector":
			allowed.append_array(["end", "heading", "handles"])
			if not _vector(spec.get("end"), TrackPiece.MAX_METRES, 2) or not _integer(spec.get("heading"), -12, 11):
				return false
			if not _vector(spec.get("handles"), TrackPiece.MAX_METRES, 2) or spec.handles.any(func(n): return n < 0.05):
				return false
			var span := Vector2(spec.end[0], spec.end[1]).length()
			if span < 0.25 or span > TrackPiece.MAX_METRES:
				return false
		else:
			allowed.append("metres")
			var least := 2.0 if kind == "adjustable_offset" else 0.25
			if not _number(spec.get("metres")) or spec.metres < least or spec.metres > TrackPiece.MAX_METRES:
				return false
			if kind == "adjustable_offset":
				allowed.append("shift")
				if not _number(spec.get("shift")) or absf(spec.shift) > TrackPiece.MAX_SHIFT:
					return false
		for key in spec:
			if key not in allowed:
				return false
	if spec.get("type") in ["half_straight", "quarter_straight"]:
		for key in spec:
			if key not in ["type", "surface", "edges"]:
				return false
	for key in LIMITS:
		if spec.has(key) and (not _number(spec[key]) or absf(spec[key]) > LIMITS[key] or (key in ["length", "size"] and spec[key] < 1)):
			return false
	for key in ["turn", "side", "surface", "edges"]:
		if spec.has(key) and not _text(spec[key], MOST_NAME):
			return false
	for key in ["cut", "sticky"]:
		if spec.has(key) and not spec[key] is bool:
			return false
	if spec.get("type") == "arc":
		if not _integer(spec.get("angle", 90), 30, 90) or not int(spec.get("angle", 90)) in TrackPiece.ARC_ANGLES:
			return false
		if not _integer(spec.get("size", 2), 1, 4) or spec.get("cut", false):
			return false
	return true


static func _text(value: Variant, most: int) -> bool:
	return value is String and value.length() <= most


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer(value: Variant, least: int, most: int) -> bool:
	return _number(value) and value >= least and value <= most and floorf(value) == float(value)


static func _colour(value: Variant) -> bool:
	return value is String and value.length() <= 32 and Color.html_is_valid(value)


static func _vector(value: Variant, bound: float, count := 3) -> bool:
	if not value is Array or value.size() != count:
		return false
	return value.all(func(n): return _number(n) and absf(n) <= bound)


static func _coordinates(value: Variant, bounds: Array, integral: bool) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for i in 3:
		if not _number(value[i]) or absf(value[i]) > bounds[i] or (integral and floorf(value[i]) != float(value[i])):
			return false
	return true


## Checks a design. Raw payloads must pass validate_course before parsing.
static func buildable(course: CourseDesign, saved := false) -> bool:
	if not saved and (course.pieces.size() > MOST_PIECES or course.landmarks.size() > MOST_LANDMARKS):
		return false
	if not is_finite(course.map_rotation) or course.map_rotation < 0.0 or course.map_rotation >= 360.0:
		return false
	if not is_finite(course.width) or not is_finite(course.hills) or course.width < 4.0 or course.width > 30.0 or course.hills < 0.0 or course.hills > 100.0:
		return false
	if TrackPath.heading_of(course.start.basis) < 0 or not course.start.origin.is_finite() or maxf(maxf(absf(course.start.origin.x), absf(course.start.origin.y)), absf(course.start.origin.z)) > 200000.0:
		return false
	for spec in course.pieces:
		if not _piece(spec):
			return false
		if spec.get("type") in TrackPiece.ADJUSTABLE_TYPES and not TrackPiece.from_spec(spec).safe_dimensions(course.width):
			return false
	if not saved and course.pieces.any(func(spec): return str(spec.get("type", "")) == "crossing"):
		if LevelCrossing.problem(course.track()) != "":
			return false
	return true


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


## Exact normalised stock identity. A cup's inline snapshot is authoritative.
static func game_path_of(course: Dictionary) -> String:
	if _game_courses.is_empty():
		for id in Tracks.all():
			var path := Tracks.path_of(id)
			var theirs = JSON.parse_string(FileAccess.get_file_as_string(path))
			if theirs is Dictionary:
				_game_courses[path] = CourseDesign.from_dict(theirs).to_dict()
	var checked := _read_course(course, true)
	if checked.has("why"):
		return ""
	var mine: Dictionary = checked.data
	for path in _game_courses:
		if _game_courses[path] == mine:
			return path
	return ""


static func cup_from_online(cup: Dictionary) -> Dictionary:
	var races := []
	for course in cup.get("courses", []):
		if course is Dictionary:
			var found := _validate(COURSE, course)
			races.append({"from": game_path_of(found.data) if not found.has("why") else "", "course": course})
	return {"name": str(cup.get("name", "A cup")), "made_by": str(cup.get("made_by", "")), "races": races}


static func saved_paths(kind: String) -> Array[String]:
	match kind:
		COURSE: return CourseDesign.saved()
		CUP: return CupDesign.saved()
		DRIVER: return CharacterDesign.saved_paths()
		KART: return KartDesign.saved_paths()
	return []


static func path_for(kind: String, name: String) -> String:
	match kind:
		COURSE: return CourseDesign.path_for(name)
		CUP: return CupDesign.path_for(name)
		DRIVER: return "%s/%s.json" % [CharacterDesign.SAVE_DIR, CharacterDesign.file_name_for(name)]
		KART: return "%s/%s.json" % [KartDesign.SAVE_DIR, KartDesign.file_name_for(name)]
	return ""


## Content duplicates ignore the display name, and a cup's source paths and
## its course names. Repeated races and every race setting still count.
static func _unnamed(kind: String, data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	out.erase("name")
	if kind == CUP:
		for race in out.races:
			race.erase("from")
			race.course.erase("name")
	return out


static func yours_already(kind: String, data: Dictionary) -> String:
	var wanted := _unnamed(kind, data)
	for path in saved_paths(kind):
		var text := FileAccess.get_file_as_string(path)
		var mine := read(text)
		if mine.get("kind") == kind and _unnamed(kind, mine.data) == wanted:
			return path
	return ""


static func is_the_games(kind: String, data: Dictionary) -> bool:
	return kind == COURSE and game_path_of(data) != ""


## Returns {path, said}, or {path: "", said, why}. Revalidates callers' data,
## plans all names before writing and never replaces an existing file.
static func add(found: Dictionary) -> Dictionary:
	if not found.get("kind") in KINDS or not found.get("data") is Dictionary:
		return _save_error(str(found.get("why", "That design isn't valid.")))
	var checked := _validate(found.kind, found.data)
	if checked.has("why"):
		return _save_error(checked.why)
	var kind: String = checked.kind
	var data: Dictionary = checked.data
	if is_the_games(kind, data):
		return {"path": game_path_of(data), "said": "%s is one of the game's courses already." % data.get("name", "That")}
	var have := yours_already(kind, data)
	if have != "":
		return {"path": have, "said": "You've already got %s." % data.get("name", "that")}
	var plan: Array[Dictionary] = []
	var reserved := {}
	if kind == CUP:
		var courses := []
		for race in data.races:
			if race.from != "" or yours_already(COURSE, race.course) != "":
				continue
			var signature := _unnamed(COURSE, race.course)
			if signature in courses:
				continue
			courses.append(signature)
			_plan_file(COURSE, race.course.duplicate(true), reserved, plan)
	var path := _plan_file(kind, data, reserved, plan)
	if not _write_plan(plan):
		return _save_error("I couldn't save it. No new designs were kept.")
	var folder: String = {COURSE: "courses", CUP: "cups", DRIVER: "racers", KART: "karts"}[kind]
	return {"path": path, "said": "%s is with your %s now." % [data.get("name", "That"), folder]}


static func _save_error(why: String) -> Dictionary:
	return {"path": "", "said": why, "why": why}


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _plan_file(kind: String, data: Dictionary, reserved: Dictionary, plan: Array[Dictionary]) -> String:
	var name: String = str(data.get("name", "Shared")).strip_edges()
	if name == "":
		name = "Shared"
	var chosen := name
	var path := path_for(kind, chosen)
	var tries := 1
	while _exists(path) or reserved.has(path):
		tries += 1
		var suffix := " %d" % tries
		chosen = name.left(MOST_NAME - suffix.length()) + suffix
		path = path_for(kind, chosen)
	data.name = chosen
	reserved[path] = true
	plan.append({"path": path, "data": data})
	return path


static func _write_plan(plan: Array[Dictionary]) -> bool:
	var written: Array[String] = []
	for item in plan:
		var path: String = item.path
		if _exists(path) or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
			_rollback(written)
			return false
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_rollback(written)
			return false
		written.append(path)
		file.store_string(JSON.stringify(item.data, "\t"))
		file.flush()
		var error := file.get_error()
		file.close()
		if error != OK:
			_rollback(written)
			return false
	return true


static func _rollback(paths: Array[String]) -> void:
	for path in paths:
		DirAccess.remove_absolute(path)
