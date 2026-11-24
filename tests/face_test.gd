extends SceneTree

## Faces built from parts. Every eyes, brows and mouth paints in every mood,
## the new shapes and faces behave in each mood, a built face goes through a
## save, a load and a share code the same, a named face saves just as it
## always has, and face parts from a later version fall back instead of
## turning the driver away.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tests/face_test.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_shapes()
	_moods()
	_designs()
	_sharing()
	print("All face checks passed." if failures == 0 else "%d face checks failed." % failures)
	quit(1 if failures > 0 else 0)


func _shapes() -> void:
	var skin := Color("#f2cd37")
	var moods: Array = [""] + FacePrint.MOODS
	var painted := 0
	var wrong := 0
	for eyes in FacePrint.EYES:
		for brows in FacePrint.BROWS:
			for mouth in FacePrint.MOUTHS:
				for mood in moods:
					var image := FacePrint.picture([eyes, brows, mouth, []], skin, Vector2i(24, 18))
					painted += 1
					if image == null or image.get_size() != Vector2i(24, 18):
						wrong += 1
	check(wrong == 0, "every eyes, brows and mouth paints in every mood (%d faces)" % painted)
	wrong = 0
	for extra in FacePrint.EXTRAS:
		for mood in moods:
			var image := FacePrint.paint_image(["dots", "", "smile", [extra]], skin, 0.08, 0.07, "none", FacePrint.INK, mood)
			if image == null or image.get_size() != Vector2i(FacePrint.WIDE, FacePrint.TALL):
				wrong += 1
	check(wrong == 0, "every extra paints in every mood")
	# Each shape looks different from the others of its kind.
	for part in ["eyes", "brows", "mouth"]:
		var seen := {}
		for shape in FacePrint.PARTS[part]:
			var parts := ["dots", "", "smile", []]
			parts[["eyes", "brows", "mouth"].find(part)] = shape
			seen[FacePrint.picture(parts, skin).get_data()] = true
		check(seen.size() == FacePrint.PARTS[part].size(), "every %s shape looks different" % part)
	for face in FacePrint.FACES:
		var parts: Array = FacePrint.FACES[face]
		check(parts[0] in FacePrint.EYES and parts[1] in FacePrint.BROWS and parts[2] in FacePrint.MOUTHS and parts[3].all(func(e): return e in FacePrint.EXTRAS or e == "blush"), "%s is made of shapes you can pick" % face)
		check(not CharacterDesign.piece("head", face).is_empty(), "%s is in the face picker" % face)
	# A named face and its parts paint the same.
	for face in ["smile", "shades", "glasses", "unamused"]:
		check(FacePrint.paint_image(face, skin, 0.08, 0.07).get_data() == FacePrint.paint_image(FacePrint.FACES[face], skin, 0.08, 0.07).get_data(), "%s paints the same from its name or its parts" % face)


func _moods() -> void:
	check(not FacePrint.changes("blank", "blink"), "line eyes don't blink, they're already shut")
	check(FacePrint.changes("blank", "surprised"), "line eyes open wide when surprised")
	check(FacePrint.changes("unamused", "blink") and FacePrint.changes("plain", "blink"), "half closed and dot eyes blink")
	check(not FacePrint.changes("shades", "blink"), "shades still never blink")
	for mood in FacePrint.MOODS:
		check(FacePrint._in_mood(FacePrint.FACES.no_mouth, mood)[2] == "none", "no mouth stays no mouth when %s" % mood)
	check(FacePrint._in_mood(FacePrint.FACES.cat, "happy")[2] == "cat", "the cat mouth stays when happy")
	check(FacePrint._in_mood(FacePrint.FACES.kiss, "happy")[2] == "grin", "a pucker grins when happy")
	check(FacePrint._in_mood(FacePrint.FACES.unamused, "happy") == ["dots", "", "grin", []], "unamused cheers right up when happy")
	check(FacePrint._in_mood(FacePrint.FACES.glasses, "blink")[0] == "closed", "glasses blink")
	var glasses_blink := FacePrint.paint_image("glasses", Color.WHITE, 0.08, 0.07, "none", FacePrint.INK, "blink")
	var plain_blink := FacePrint.paint_image("smile", Color.WHITE, 0.08, 0.07, "none", FacePrint.INK, "blink")
	check(glasses_blink.get_data() != plain_blink.get_data(), "glasses keep their frames when they blink")


func _designs() -> void:
	# A driver saved with a named face reads and saves just as before.
	var old := {"name": "Old", "head": {"style": "cheeky", "color": "#f2cd37"}, "torso": {"style": "tee", "color": "#0d69ab"}}
	var design := CharacterDesign.from_dict(old)
	check(not design.has_own_face() and design.face() == FacePrint.FACES.cheeky, "an old named face loads as that face")
	check(not design.to_dict().head.has("face") and design.to_dict().head.keys().size() == 2, "a named face saves just its name and skin, as before")

	design.set_face_part("eyes", "half")
	check(design.has_own_face() and design.face() == ["half", "raised_left", "smirk", []] and design.style_of("head") == "cheeky", "changing the eyes keeps the rest and the named face it came from")
	design.set_face_part("extras", ["freckles", "scar"])
	design.set_piece("head", "", Color("#8d5524"))
	check(design.face()[3] == ["freckles", "scar"] and design.has_own_face(), "extras and a new skin colour keep the built face")
	var saved := design.to_dict()
	check(saved.head.face == {"eyes": "half", "brows": "raised_left", "mouth": "smirk", "extras": ["freckles", "scar"]}, "a built face saves its parts")
	var back := CharacterDesign.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(back.to_dict() == saved and back.face() == design.face(), "a built face comes back the same through JSON")
	var path := "user://face_test_driver.json"
	design.save(path)
	check(CharacterDesign.load_file(path).to_dict() == saved, "a built face saves to a file and loads the same")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(design.duplicate_design().face() == design.face(), "a copy keeps the built face")

	# Building a named face makes it that face.
	design.set_face_part("extras", [])
	design.set_face_part("eyes", "wink")
	check(not design.has_own_face() and design.style_of("head") == "cheeky", "putting a face back as it was goes back to the named face")
	design.set_face_part("eyes", "lines")
	design.set_face_part("brows", "")
	design.set_face_part("mouth", "flat")
	check(not design.has_own_face() and design.style_of("head") == "blank", "building a named face's parts becomes that face")
	design.set_face_part("mouth", "cat")
	design.set_piece("head", "kiss")
	check(not design.has_own_face() and design.face() == FacePrint.FACES.kiss, "picking a named face takes all of it")

	# Parts from a later version fall back to the named face's.
	var later := CharacterDesign.from_dict({"head": {"style": "smile", "color": "#f2cd37", "face": {"eyes": "laser", "brows": "flat", "mouth": 7, "extras": ["glitter", "freckles", "freckles"]}}})
	check(later.face() == ["dots", "flat", "smile", ["freckles"]], "unknown face parts fall back to the named face's")
	var unknown_style := CharacterDesign.from_dict({"head": {"style": "robot", "color": "#f2cd37", "face": {"eyes": "big", "mouth": "cat"}}})
	check(unknown_style.face()[0] == "big" and unknown_style.face()[2] == "cat", "a face's parts still load with a named face it doesn't know")

	check(CharacterDesign.well_formed(saved), "a built face is well formed for network games")
	var bad := saved.duplicate(true)
	bad.head.face = "big"
	check(not CharacterDesign.well_formed(bad), "a face that isn't parts is turned away")
	bad.head.face = {"eyes": ["big"]}
	check(not CharacterDesign.well_formed(bad), "a face part that isn't text is turned away")


func _sharing() -> void:
	var design := CharacterDesign.from_dict({"name": "Face test", "head": {"style": "smile", "color": "#f2cd37"}, "torso": {"style": "tee", "color": "#0d69ab"}})
	var named := design.to_dict()
	var old_code := Sharing.code_for(Sharing.envelope_for(Sharing.DRIVER, named))
	var read := Sharing.read(old_code)
	check(read.get("kind") == Sharing.DRIVER and not read.data.head.has("face") and read.data.head.style == "smile", "a share code with a named face reads as before")

	design.set_face_part("mouth", "pucker")
	design.set_face_part("eyes", "half")
	design.set_face_part("extras", ["sweat"])
	var built := design.to_dict()
	read = Sharing.read(Sharing.code_for(Sharing.envelope_for(Sharing.DRIVER, built)))
	check(read.get("kind") == Sharing.DRIVER and read.data == built, "a built face goes through a share code the same")
	check(CharacterDesign.from_dict(read.data).face() == ["half", "", "pucker", ["sweat"]], "a shared built face loads its parts")
	read = Sharing.read(Sharing.file_for(built))
	check(read.get("kind") == Sharing.DRIVER and read.data == built, "a built face goes through a shared file the same")

	var later := built.duplicate(true)
	later.head.face = {"eyes": "sparkly", "brows": "unibrow", "mouth": "pucker", "extras": ["warpaint"], "nose": "button"}
	read = Sharing.read(Sharing.code_for(Sharing.envelope_for(Sharing.DRIVER, later)))
	check(read.get("kind") == Sharing.DRIVER, "a driver with face parts from a later version still comes in")
	check(read.has("data") and CharacterDesign.from_dict(read.data).face() == ["dots", "", "pucker", []], "and its unknown parts fall back to the named face's")

	var bad := built.duplicate(true)
	bad.head.face = {"extras": "freckles"}
	check(Sharing.read(Sharing.code_for(Sharing.envelope_for(Sharing.DRIVER, bad))).has("why"), "extras that aren't a list are turned away")
	bad.head.face = {"eyes": 3}
	check(Sharing.read(Sharing.code_for(Sharing.envelope_for(Sharing.DRIVER, bad))).has("why"), "a face part that isn't text is turned away")
