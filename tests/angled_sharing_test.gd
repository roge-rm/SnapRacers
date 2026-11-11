extends Node

## Run with XDG_DATA_HOME inside build/diagonals or build/creations.

var failures := 0
var checks := 0
var refused := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	var profile := OS.get_user_data_dir()
	if not profile.begins_with(ProjectSettings.globalize_path("res://build/diagonals/")) and not profile.begins_with(ProjectSettings.globalize_path("res://build/creations/")):
		push_error("Set XDG_DATA_HOME to an isolated folder inside build/diagonals or build/creations.")
		get_tree().quit(1)
		return
	call_deferred("_run")


func _course(angle := 45, size := 2, turn := "right") -> Dictionary:
	var course := CourseDesign.starter().to_dict()
	course.name = "Angled sharing"
	course.start = [12.345678, 3.0, -23.456789, 0]
	course.pieces.append({"type": "arc", "angle": angle, "size": size, "turn": turn, "rise": 1, "bank": 30, "surface": "asphalt", "edges": "walls", "sticky": true})
	return course


func _ready_course() -> Dictionary:
	var course := CourseDesign.starter().to_dict()
	course.name = "Angled cup course"
	course.pieces = []
	for i in 8:
		course.pieces.append({"type": "straight", "length": 3})
		course.pieces.append({"type": "arc", "angle": 45, "size": 3, "turn": "right"})
	return course


func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))


func _run() -> void:
	for angle in TrackPiece.ARC_ANGLES:
		for size in range(1, 5):
			for turn in ["left", "right"]:
				var data := _course(angle, size, turn)
				var found := Sharing.validate_course(data)
				check(not found.has("why") and _same(found.data.pieces, data.pieces), "arc %d size %d %s retains its road settings" % [angle, size, turn])
		for heading in 24:
			var data := _course(angle, heading % 4 + 1, "left" if heading % 2 else "right")
			data.start[3] = heading / 6.0
			var file := Sharing.read(Sharing.file_for(data))
			var code := Sharing.read(Sharing.code_for(data))
			var saved := Sharing.validate_saved(Sharing.COURSE, data)
			check(not file.has("why") and not code.has("why") and not saved.has("why") and _same(file.data, code.data) and _same(code.data, saved.data) and absf(file.data.start[3] - heading / 6.0) < 0.000001 and absf(file.data.start[0] - data.start[0]) < 0.000001, "arc %d at heading %d survives file, code and owned validation" % [angle, heading])
	var ready := _ready_course()
	check(CourseDesign.from_dict(ready).problems().is_empty(), "the angled cup fixture is race ready")
	var cup := {"name": "Angled cup", "races": [{"course": ready, "from": ""}, {"course": ready.duplicate(true), "from": ""}]}
	cup.races[1].course.start = [1.234567, 0, 2.345678, 1.0 / 6.0]
	for text in [Sharing.file_for(cup), Sharing.code_for(cup)]:
		var found := Sharing.read(text)
		check(found.get("kind") == Sharing.CUP and found.data.races[1].course.start[3] == 1.0 / 6.0, "ready angled cup snapshots survive file and code sharing")
	check(not Sharing.validate_saved(Sharing.CUP, cup).has("why"), "owned angled cup snapshots validate")
	_bad_inputs(cup)
	_saved_policy()
	_network()
	_host_files(ready, cup)
	print("All %d angled sharing checks passed." % checks if failures == 0 else "%d of %d angled sharing checks failed." % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _reject(data: Dictionary, what: String, cup: Dictionary) -> void:
	check(Sharing.validate_course(data).has("why") and Sharing.validate_saved(Sharing.COURSE, data).has("why"), what + " is rejected before course construction")
	var wrapped := cup.duplicate(true)
	wrapped.races[1].course = data
	check(Sharing.validate_saved(Sharing.CUP, wrapped).has("why") and Sharing.read(Sharing.code_for(wrapped)).has("why"), what + " is rejected inside owned and portable cup snapshots")


func _bad_inputs(cup: Dictionary) -> void:
	for angle in [0, 15, 30.5, 31, 46, 91, NAN, INF, -INF, "45", true, [], null]:
		var data := _course()
		data.pieces[1].angle = angle
		_reject(data, "angle " + str(angle), cup)
	for size in [0, 1.5, 5, 1000000000, NAN, INF, "2", false]:
		var data := _course()
		data.pieces[1].size = size
		_reject(data, "arc size " + str(size), cup)
	for setting in [{"cut": true}, {"cut": 1}, {"rise": 9}, {"bank": 91}, {"surface": []}, {"edges": {}}, {"sticky": "true"}, {"length": 1000000000}, {"rise": NAN}]:
		var data := _course()
		data.pieces[1].merge(setting, true)
		_reject(data, "road setting " + str(setting), cup)
	for kind in ["fitted", "join", "fitted_join", "teleporter", 4, null]:
		var data := _course()
		data.pieces[1].type = kind
		_reject(data, "piece type " + str(kind), cup)
	for start in [null, false, {}, [0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, -1], [0, 0, 0, 4], [0, 0, 0, 0.25], [0, 0, 0, 1.0 / 6.0 + 0.0001], [0, 0, 0, 4.0 - 0.00000001], [0, 0, 0, NAN], [0, 0, 0, INF], [NAN, 0, 0, 0], [0, INF, 0, 0], [0, 0, -100001, 0], ["0", 0, 0, 0], [0, 0, 0, "1"]]:
		var data := _course()
		data.start = start
		_reject(data, "start " + str(start), cup)
	for heading in 24:
		var data := _course()
		data.start[3] = heading / 6.0 + (0.00000001 if heading % 6 else 0.0)
		var found := Sharing.validate_course(data)
		check(not found.has("why") and found.data.start[3] == heading / 6.0, "start heading %d canonicalises JSON roundoff" % heading)
	for start in [[], [0, 0, 0, 0], [0, 0, 0, 1], [0, 0, 0, 2], [0, 0, 0, 3]]:
		var data := _course()
		data.start = start
		check(not Sharing.validate_course(data).has("why"), "legacy start " + str(start) + " still validates")
	var legacy := _course()
	legacy.pieces = [{"type": "curve", "size": 2.5, "cut": true}, {"type": "straight", "length": 1.5}]
	check(not Sharing.validate_course(legacy).has("why"), "legacy fractional sizes, lengths and cut curves retain their validation")
	var invalid := CourseDesign.from_dict(_course())
	invalid.start.basis = Basis(Vector3.UP, PI / 7.0)
	check(not Sharing.buildable(invalid), "design validation rejects a start off the 24 headings")
	invalid.start = Transform3D.IDENTITY
	invalid.pieces[1].angle = 30.5
	check(not Sharing.buildable(invalid), "design validation checks arc fields before any geometry")
	check(Sharing.game_path_of({"pieces": [], "start": [0, 0, 0, 0.25]}) == "", "stock identity rejects an invalid raw start without serialising it")


func _saved_policy() -> void:
	var draft := _course()
	draft.pieces = []
	check(not Sharing.validate_saved(Sharing.COURSE, draft).has("why") and Sharing.validate_course(draft).has("why"), "empty owned courses remain editable and portable courses need road")
	var cup := {"name": "Draft angled cup", "races": [{"course": _course(), "from": ""}]}
	check(not Sharing.validate_saved(Sharing.CUP, cup).has("why") and Sharing.read(Sharing.code_for(cup)).has("why"), "owned cup drafts keep their separate readiness policy")
	var large := _course()
	large.pieces.resize(Sharing.MOST_PIECES + 1)
	large.pieces.fill({"type": "arc", "angle": 30, "size": 4})
	check(not Sharing.validate_saved(Sharing.COURSE, large).has("why") and Sharing.validate_course(large).has("why"), "large owned angled courses stay editable while portable piece limits hold")
	large.pieces = _course().pieces
	large.landmarks = []
	for i in Sharing.MOST_LANDMARKS + 1:
		large.landmarks.append({"prop": Props.ROOM.keys()[0], "at": [i, i]})
	check(not Sharing.validate_saved(Sharing.COURSE, large).has("why") and Sharing.validate_course(large).has("why"), "owned landmark counts remain separate from portable limits")
	large = _course()
	large.name = "x".repeat(Sharing.MOST_NAME + 1)
	check(not Sharing.validate_saved(Sharing.COURSE, large).has("why") and Sharing.validate_course(large).has("why"), "owned name lengths remain separate from portable limits")


func _network() -> void:
	var net := NetSession.new()
	get_tree().root.add_child(net)
	net.ended.connect(func(_reason: String): refused += 1)
	check(NetSession.VERSION == 19 and Sharing.VERSION == 1, "engine tuning and reverse or mirrored layouts require network protocol 19 and retain sharing format 1")
	check(net._check({"version": 18}).contains("different version") and net._check({"version": 19, "players": []}) == "Nobody to race.", "online peers reject protocol 18 and accept the protocol 19 handshake")
	var bad := _course()
	bad.start[3] = 0.25
	var values: Array = [bad]
	bad = _course()
	bad.pieces[1].angle = 30.5
	values.append(bad)
	bad = _course()
	bad.pieces[0].length = 1000000000
	values.append(bad)
	bad = _course()
	bad.pieces[1].type = "fitted"
	values.append(bad)
	values.append([])
	for data in values:
		var before := refused
		net._begin({"course": data})
		check(refused == before + 1 and net.setup.is_empty() and net.last_problem == "The host's course can't be built.", "online raw course rejection ends cleanly before writing or building")
	net.free()


func _put(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _host_files(ready: Dictionary, cup: Dictionary) -> void:
	var folder := "user://host-fixtures"
	_put(folder + "/courses/good.json", ready)
	_put(folder + "/cups/good.json", cup)
	var bad := ready.duplicate(true)
	bad.start = [0, 0, 0, 0.25]
	_put(folder + "/courses/bad.json", bad)
	var bad_cup := cup.duplicate(true)
	bad_cup.races[0].course = bad
	_put(folder + "/cups/bad.json", bad_cup)
	var server := DedicatedServer.new()
	server.config_path = folder + "/config.json"
	var courses := server.courses()
	var cups := server.cups()
	check(courses.has("mine_good") and not courses.has("mine_bad"), "dedicated course discovery validates raw starts before constructing designs")
	check(cups.has("mine_good") and not cups.has("mine_bad"), "dedicated cup discovery validates every raw snapshot before readiness geometry")
	server.free()
