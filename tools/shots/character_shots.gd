extends SceneTree

## Pictures of the drivers for checking the pieces made in tools/characters:
## a sheet of the figure standing, sitting and astride from all round, a sheet
## of a few looks, and a close-up lit the way the driver screen lights it, to
## judge the shine. Like the other shots it needs a screen, and saves in
## build/shots/characters.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . -s tools/shots/character_shots.gd
## Add --out=/some/folder to save them there as well, and --only=necks,faces
## (any of figure, looks, closeup, necks, faces, hair, facial_hair, combos,
## headgear, headgear_hair, headgear_karts, torsos, arms, arm_closeups,
## outfits, legs, backs, long_hair, seam, pieces_check, roster)
## for just those sheets.

const OUT := "res://build/shots/characters"
const TILE := Vector2i(480, 560)
const COLUMNS := 4

var _out_too := ""
var _only: Array = []
var _view: SubViewport
var _camera: Camera3D
var _stand: Node3D
var _label: Label
var _env: Environment


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_too = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
	DisplayServer.window_set_size(TILE)
	_view = SubViewport.new()
	_view.size = TILE
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	SkyAndSun.add_to(_view, 20.0, BuilderStyle.BACKGROUND)
	# Lit like the driver screen.
	for child in _view.get_children():
		if child is WorldEnvironment:
			_env = child.environment
			_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_env.ambient_light_color = Color("#e8e8e8")
			_env.ambient_light_energy = 0.38
			_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		elif child is DirectionalLight3D:
			child.light_energy = 0.75
			child.shadow_opacity = 0.55
			child.shadow_blur = 2.5
			child.shadow_bias = 0.08
			child.shadow_normal_bias = 2.5
	CharacterRig.add_toy_lights(_view)
	_camera = Camera3D.new()
	_camera.fov = 28.0
	_view.add_child(_camera)
	_stand = Node3D.new()
	_view.add_child(_stand)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.position = Vector2(10, 6)
	_view.add_child(_label)
	_run.call_deferred()


## The bare figure: no hair, hat or anything else on, one colour all over.
func bare() -> CharacterDesign:
	return CharacterDesign.from_dict({
		"name": "Bare",
		"head": {"style": "smile", "color": "#f2cd37"},
		"hair": {"style": "none", "color": "#6b4430"},
		"headgear": {"style": "none", "color": "#f4f4f4"},
		"torso": {"style": "tee", "color": "#0d69ab"},
		"arms": {"style": "long_sleeves", "color": "#0d69ab"},
		"legs": {"style": "trousers", "color": "#0d69ab"},
	})


func clear() -> void:
	for child in _stand.get_children():
		child.free()


func snap(text: String, at: Vector3, look: Vector3) -> Image:
	_label.text = text
	_camera.position = at
	_camera.look_at(look, Vector3.UP)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	return _view.get_texture().get_image()


func sheet(images: Array, columns: int, size: Vector2i) -> Image:
	var rows := ceili(images.size() / float(columns))
	var out := Image.create(size.x * columns, size.y * rows, false, Image.FORMAT_RGBA8)
	out.fill(BuilderStyle.BACKGROUND)
	for i in images.size():
		var image: Image = images[i]
		image.convert(Image.FORMAT_RGBA8)
		out.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(i % columns * size.x, i / columns * size.y))
	return out


func save(image: Image, file: String) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	image.save_png(OUT + "/" + file)
	if _out_too != "":
		DirAccess.make_dir_recursive_absolute(_out_too)
		image.save_png(_out_too.path_join(file))
	print("saved ", file)


func rig(design: CharacterDesign, sitting: bool, astride := false) -> CharacterRig:
	clear()
	var r := CharacterRig.new(design, sitting)
	r.astride = astride
	if not sitting:
		r.position = Vector3(0.0, CharacterRig.FEET_BELOW, 0.0)
	_stand.add_child(r)
	return r


func wanted(sheet_name: String) -> bool:
	return _only.is_empty() or _only.has(sheet_name)


const VIEWS := {"front": Vector3(0, 0.15, -1), "side": Vector3(-1, 0.1, 0), "three quarter": Vector3(-0.8, 0.35, -1), "back": Vector3(0.3, 0.25, 1)}


func _run() -> void:
	if wanted("figure"):
		await _figure()
	if wanted("looks"):
		await _looks()
	if wanted("necks"):
		await _necks()
	if wanted("faces"):
		await _faces()
	if wanted("hair"):
		await _hair()
	if wanted("facial_hair"):
		await _facial_hair()
	if wanted("combos"):
		await _combos()
	if wanted("headgear"):
		await _headgear()
	if wanted("headgear_hair"):
		await _headgear_hair()
	if wanted("headgear_karts"):
		await _headgear_karts()
	if wanted("torsos"):
		await _torsos()
	if wanted("arms"):
		await _arms()
	if wanted("arm_closeups"):
		await _arm_closeups()
	if wanted("outfits"):
		await _outfits()
	if wanted("legs"):
		await _legs()
	if wanted("backs"):
		await _backs()
	if wanted("long_hair"):
		await _long_hair()
	if wanted("seam"):
		await _seam()
	if wanted("pieces_check"):
		await _pieces_check()
	if wanted("closeup"):
		await _closeup()
	if _only.has("roster"):
		await _roster()
	quit()


## Every built-in driver, standing, from the front three quarters.
func _roster() -> void:
	var shots := []
	var files := DirAccess.get_files_at("res://data/characters/roster")
	files.sort()
	for file in files:
		if not file.ends_with(".json"):
			continue
		var design := CharacterDesign.load_file("res://data/characters/roster/" + file)
		rig(design, false)
		var middle := Vector3(0.0, 0.52, 0.0)
		shots.append(await snap(design.name, middle + VIEWS["three quarter"].normalized() * 3.0, middle))
	save(sheet(shots, 5, TILE), "roster.png")


func _figure() -> void:
	var views := VIEWS
	var shots := []
	rig(bare(), false)
	var middle := Vector3(0.0, 0.52, 0.0)
	for v in views:
		shots.append(await snap("standing " + v, middle + views[v].normalized() * 3.0, middle))
	rig(bare(), true)
	middle = Vector3(0.0, 0.3, -0.05)
	for v in ["front", "side", "three quarter"]:
		shots.append(await snap("sitting " + v, middle + views[v].normalized() * 2.6, middle))
	var astride := rig(bare(), true, true)
	astride.grip(Vector3(-0.3, 0.42, -0.35), Vector3(0.3, 0.42, -0.35), Vector3.LEFT, Vector3.RIGHT)
	shots.append(await snap("astride side", middle + views["side"].normalized() * 2.6, middle))
	# In a kart and on a bike, holding on.
	for kart in ["kart_kid", "streak"]:
		clear()
		var model := KartModel.make(KartDesign.load_file("res://data/karts/stock/%s.json" % kart), bare())
		_stand.add_child(model)
		await process_frame
		var seat := Vector3(0.0, 0.6, 0.0)
		var found := model.find_children("*", "CharacterRig", true, false)
		if not found.is_empty():
			seat = (found[0] as Node3D).global_position + Vector3(0.0, 0.3, 0.0)
		shots.append(await snap("on the %s" % kart, seat + Vector3(-0.9, 0.35, -1.0).normalized() * 4.4, seat))
	save(sheet(shots, COLUMNS, TILE), "figure.png")


func _looks() -> void:
	var views := VIEWS
	var middle := Vector3.ZERO
	var shots := []
	# A few looks, to check the colour bands and the old pieces on the figure.
	var looks := [
		["short sleeves, shorts", {"arms": "short_sleeves", "legs": "shorts", "torso": "racing_suit"}],
		["boots, rolled sleeves", {"arms": "rolled", "legs": "boots", "torso": "jacket"}],
		["socks, wristbands", {"arms": "wristbands", "legs": "socks", "torso": "jersey"}],
		["robot", {"arms": "mechanical", "legs": "robot_legs", "torso": "robot"}],
		["gown, long gloves", {"arms": "long_gloves", "legs": "gown", "torso": "gown"}],
		["dino feet, scaly", {"arms": "scaly", "legs": "dino_feet", "torso": "dino_belly"}],
		["armoured", {"arms": "armoured", "legs": "armoured", "torso": "armour"}],
		["helmet and hair", {"headgear": "open_helmet", "hair": "short", "torso": "racing_suit"}],
	]
	for look in looks:
		var design := bare()
		for slot in look[1]:
			design.set_piece(slot, look[1][slot])
		design.set_piece("headgear", look[1].get("headgear", "none"), Color("#f4f4f4"))
		rig(design, false)
		middle = Vector3(0.0, 0.52, 0.0)
		shots.append(await snap(look[0], middle + views["three quarter"].normalized() * 3.0, middle))
	save(sheet(shots, COLUMNS, TILE), "looks.png")


## Every neck piece, from the front three quarters standing and from the side
## sitting with the arms up as if on a wheel.
func _necks() -> void:
	var shots := []
	var side := []
	for style in CharacterDesign.styles("neck"):
		var design := bare()
		design.set_piece("neck", style, Color("#c9a227") if style == "gold_chain" else Color("#c4281c"))
		rig(design, false)
		var middle := Vector3(0.0, 0.78, 0.0)
		shots.append(await snap(style, middle + Vector3(-0.45, 0.2, -1.0).normalized() * 1.5, middle))
		var sitting := rig(design, true)
		sitting.grip(Vector3(-0.17, 0.42, -0.42), Vector3(0.17, 0.42, -0.42))
		middle = Vector3(0.0, 0.42, -0.05)
		side.append(await snap(style + " sitting", middle + Vector3(-1.0, 0.3, 0.2).normalized() * 1.7, middle))
	save(sheet(shots, 5, TILE), "necks.png")
	save(sheet(side, 5, TILE), "necks_side.png")


## Every face close up, and one big.
func _faces() -> void:
	var shots := []
	for style in CharacterDesign.styles("head"):
		var design := bare()
		design.set_piece("head", style, design.skin())
		rig(design, false)
		var middle := Vector3(0.0, 0.88, 0.0)
		shots.append(await snap(style, middle + Vector3(-0.2, 0.05, -1.0).normalized() * 1.25, middle))
	save(sheet(shots, 6, TILE), "faces.png")


## Every hairstyle from the front three quarters and from behind, and the
## cut version each has for under a hat.
func _hair() -> void:
	var front := []
	var back := []
	var cut := []
	var middle := Vector3(0.0, 0.86, 0.0)
	for style in CharacterDesign.styles("hair"):
		var design := bare()
		design.set_piece("hair", style, Color("#6b4430"))
		rig(design, false)
		front.append(await snap(style, middle + Vector3(-0.6, 0.25, -1.0).normalized() * 1.5, middle))
		back.append(await snap(style + " behind", middle + Vector3(0.7, 0.3, 1.0).normalized() * 1.5, middle))
		if style == "none":
			continue
		# The cut version on its own, as it is under a hat.
		var r := CharacterRig.new(design, false)
		r.bake = false
		r.position = Vector3(0.0, CharacterRig.FEET_BELOW, 0.0)
		clear()
		_stand.add_child(r)
		for node in r.head().get_children():
			if node is MeshInstance3D and not node.has_meta("unbaked"):
				node.free()
		r.add_style("hair", "cut")
		cut.append(await snap(style + " cut", middle + Vector3(-0.8, 0.45, -1.0).normalized() * 1.5, middle))
	save(sheet(front, 5, TILE), "hair.png")
	save(sheet(back, 5, TILE), "hair_back.png")
	save(sheet(cut, 5, TILE), "hair_cut.png")


## Every facial hair close up, and a few in a mood.
func _facial_hair() -> void:
	var shots := []
	var middle := Vector3(0.0, 0.84, 0.0)
	for style in CharacterDesign.styles("facial_hair"):
		var design := bare()
		design.set_piece("facial_hair", style, Color("#8a5a2b"))
		rig(design, false)
		shots.append(await snap(style, middle + Vector3(-0.35, 0.08, -1.0).normalized() * 1.15, middle))
	for look in [["full", "laugh"], ["walrus", "surprised"], ["long", "happy"], ["sideburns", "surprised"], ["braided", "laugh"]]:
		var design := bare()
		design.set_piece("facial_hair", look[0], Color("#8a5a2b"))
		var r := rig(design, false)
		r._face.material_override = CharacterRig._new_face_material(r._paint(look[1]))
		shots.append(await snap("%s, %s" % look, middle + Vector3(-0.2, 0.08, -1.0).normalized() * 1.15, middle))
	save(sheet(shots, 6, TILE), "facial_hair.png")


## A few hair and beard pairs on a driver in a kart.
func _combos() -> void:
	var shots := []
	var pairs := [["long", "full"], ["afro", "sideburns"], ["ponytail", "none"], ["pigtails", "none"], ["mohawk", "long"], ["bob", "sideburns"], ["princess", "none"], ["braids", "braided"]]
	for pair in pairs:
		var design := bare()
		design.set_piece("hair", pair[0], Color("#c47a3a"))
		design.set_piece("facial_hair", pair[1], Color("#6b4430"))
		design.set_piece("torso", "racing_suit", Color("#c4281c"))
		clear()
		var model := KartModel.make(KartDesign.load_file("res://data/karts/stock/kart_kid.json"), design)
		_stand.add_child(model)
		await process_frame
		var seat := Vector3(0.0, 0.6, 0.0)
		var found := model.find_children("*", "CharacterRig", true, false)
		if not found.is_empty():
			seat = (found[0] as Node3D).global_position + Vector3(0.0, 0.55, 0.0)
		shots.append(await snap("%s, %s" % pair, seat + Vector3(-0.8, 0.35, -1.0).normalized() * 2.6, seat))
	save(sheet(shots, 4, TILE), "combos.png")


## A colour for each piece of headgear on the sheets.
const GEAR_COLOURS := {"crown": "#c9a227", "tiara": "#c8ccd0", "mushroom": "#c4281c", "cowboy": "#a0703c", "top_hat": "#2b2b2b", "wizard": "#4b3a8f", "pirate": "#2b2b2b", "viking": "#9aa0a6", "beanie": "#4b9f4a", "cap": "#0d69ab", "hard_hat": "#f2cd37", "dino_hood": "#4b9f4a", "aviator": "#7a4a2a", "horns": "#c4281c", "party": "#d86cb0", "beret": "#c4281c", "headband": "#f2f2f2"}


func _gear(design: CharacterDesign, style: String) -> void:
	design.set_piece("headgear", style, Color(GEAR_COLOURS.get(style, "#c4281c")))


## Every piece of headgear on short hair, from the front three quarters and
## from behind.
func _headgear() -> void:
	var front := []
	var back := []
	var middle := Vector3(0.0, 0.97, 0.0)
	for style in CharacterDesign.styles("headgear"):
		var design := bare()
		design.set_piece("hair", "short", Color("#6b4430"))
		_gear(design, style)
		rig(design, false)
		front.append(await snap(style, middle + Vector3(-0.6, 0.25, -1.0).normalized() * 1.9, middle))
		back.append(await snap(style + " behind", middle + Vector3(0.7, 0.3, 1.0).normalized() * 1.9, middle))
	save(sheet(front, 6, TILE), "headgear.png")
	save(sheet(back, 6, TILE), "headgear_back.png")


## A few pieces of headgear on each of the tall or long hairdos.
func _headgear_hair() -> void:
	var size := Vector2i(320, 370)
	_view.size = size
	DisplayServer.window_set_size(size)
	var gear := ["none", "cap", "beanie", "cowboy", "crown", "top_hat", "headband", "tiara", "party", "horns"]
	var middle := Vector3(0.0, 0.95, 0.0)
	var shots := []
	for hair in ["afro", "mohawk", "spiky", "bun", "pigtails", "ponytail", "long", "princess"]:
		for style in gear:
			var design := bare()
			design.set_piece("hair", hair, Color("#6b4430"))
			_gear(design, style)
			rig(design, false)
			shots.append(await snap("%s, %s" % [hair, style], middle + Vector3(-0.6, 0.25, -1.0).normalized() * 1.85, middle))
	save(sheet(shots, gear.size(), size), "headgear_hair.png")
	_view.size = TILE
	DisplayServer.window_set_size(TILE)


## A few pieces of headgear on drivers in karts, with the head turned.
func _headgear_karts() -> void:
	var shots := []
	var looks := [["racing_helmet", "long"], ["cowboy", "afro"], ["crown", "princess"], ["party", "mohawk"], ["viking", "braids"], ["headband", "ponytail"], ["wizard", "long"], ["pirate", "bun"]]
	for look in looks:
		var design := bare()
		design.set_piece("hair", look[1], Color("#c47a3a"))
		_gear(design, look[0])
		design.set_piece("torso", "racing_suit", Color("#c4281c"))
		clear()
		var model := KartModel.make(KartDesign.load_file("res://data/karts/stock/kart_kid.json"), design)
		_stand.add_child(model)
		await process_frame
		var seat := Vector3(0.0, 0.6, 0.0)
		var found := model.find_children("*", "CharacterRig", true, false)
		if not found.is_empty():
			seat = (found[0] as Node3D).global_position + Vector3(0.0, 0.55, 0.0)
			(found[0] as CharacterRig).look(1.0 if shots.size() % 2 == 0 else -1.0)
		for frame in 30:
			await process_frame
		shots.append(await snap("%s, %s" % look, seat + Vector3(-0.8, 0.35, -1.0).normalized() * 2.6, seat))
	save(sheet(shots, 4, TILE), "headgear_karts.png")


func _closeup() -> void:
	var shots := []
	var middle := Vector3.ZERO
	# Close up, lit like the driver screen, to judge the shine.
	_view.size = Vector2i(900, 900)
	DisplayServer.window_set_size(_view.size)
	_label.text = ""
	var r := rig(bare(), false)
	r.rotation.y = PI * 0.8
	shots.append(await snap("", Vector3(0.0, 1.0, 2.0), Vector3(0.0, 0.72, 0.0)))
	r.rotation.y = PI
	shots.append(await snap("", Vector3(0.0, 0.62, 1.6), Vector3(0.0, 0.42, 0.0)))
	save(sheet(shots, 2, _view.size), "closeup.png")


## Every torso from the front three quarters and from behind.
func _torsos() -> void:
	var front := []
	var back := []
	var middle := Vector3(0.0, 0.62, 0.0)
	for style in CharacterDesign.styles("torso"):
		var design := bare()
		design.set_piece("torso", style, Color("#c4281c"))
		design.set_piece("arms", "long_sleeves", Color("#c4281c"))
		rig(design, false)
		front.append(await snap(style, middle + Vector3(-0.45, 0.15, -1.0).normalized() * 2.3, middle))
		back.append(await snap(style + " behind", middle + Vector3(0.45, 0.2, 1.0).normalized() * 2.3, middle))
	save(sheet(front, 6, TILE), "torsos.png")
	save(sheet(back, 6, TILE), "torsos_back.png")


## Every arm style, on a plain torso, from the front three quarters.
func _arms() -> void:
	var shots := []
	var middle := Vector3(0.0, 0.62, 0.0)
	for style in CharacterDesign.styles("arms"):
		var design := bare()
		design.set_piece("torso", "tee", Color("#0d69ab"))
		design.set_piece("arms", style, Color("#c4281c") if style != "mechanical" and style != "armoured" else Color("#9aa0a6"))
		rig(design, false)
		shots.append(await snap(style, middle + Vector3(-0.7, 0.15, -1.0).normalized() * 2.3, middle))
	save(sheet(shots, 5, TILE), "arms.png")


## The sleeved arm styles close up by the elbow from a few sides, to see where
## two colours meet.
func _arm_closeups() -> void:
	var shots := []
	for style in ["short_sleeves", "wristbands", "puffed", "rolled", "furry", "long_gloves", "rolled_long_gloves", "short_long_gloves"]:
		var design := bare()
		design.set_piece("arms", style, Color("#0d69ab"))
		var r := rig(design, false)
		await process_frame
		var elbow: Vector3 = r._arm[0].global_transform * CharacterRig.elbow(0)
		for view in [Vector3(-1.0, 0.2, -0.6), Vector3(-0.6, -0.3, -1.0), Vector3(-1.0, 0.6, 0.4)]:
			shots.append(await snap(style, elbow + view.normalized() * 0.45, elbow))
	save(sheet(shots, 3, TILE), "arm_closeups.png")


## A few whole outfits on drivers in karts and astride a bike.
func _outfits() -> void:
	var shots := []
	var outfits := [
		["racing", "kart_kid", {"torso": ["racing_suit", "#c4281c"], "arms": ["racing_gloves", "#c4281c"], "hair": "short", "headgear": "racing_helmet", "neck": "none"}],
		["knight", "kart_kid", {"torso": ["tunic", "#0d69ab"], "arms": ["armoured", "#9aa0a6"], "hair": "long", "headgear": "none", "neck": "none"}],
		["pirate", "kart_kid", {"torso": ["pirate_coat", "#7a2a2a"], "arms": ["puffed", "#f2f2f2"], "hair": "ponytail", "headgear": "pirate", "neck": "neckerchief"}],
		["lab", "kart_kid", {"torso": ["lab_coat", "#f2f2f2"], "arms": ["watch", "#f2f2f2"], "hair": "afro", "headgear": "none", "neck": "tie"}],
		["biker", "streak", {"torso": ["leather", "#2b2b2b"], "arms": ["spiked_bracers", "#2b2b2b"], "hair": "mohawk", "headgear": "none", "neck": "spiked_collar"}],
		["overalls", "scrambler", {"torso": ["overalls", "#f2cd37"], "arms": ["rolled", "#f2cd37"], "hair": "bun", "headgear": "cap", "neck": "none"}],
		["gown", "long_fork", {"torso": ["gown", "#d86cb0"], "arms": ["long_gloves", "#d86cb0"], "hair": "princess", "headgear": "tiara", "neck": "pearls"}],
		["space", "zippy", {"torso": ["space_suit", "#f2f2f2"], "arms": ["mechanical", "#9aa0a6"], "hair": "bob", "headgear": "none", "neck": "none"}],
	]
	for look in outfits:
		var design := bare()
		var parts: Dictionary = look[2]
		for slot in ["torso", "arms"]:
			design.set_piece(slot, parts[slot][0], Color(parts[slot][1]))
		design.set_piece("hair", parts.hair, Color("#6b4430"))
		_gear(design, parts.headgear)
		design.set_piece("neck", parts.neck, Color("#c4281c"))
		clear()
		var model := KartModel.make(KartDesign.load_file("res://data/karts/stock/%s.json" % look[1]), design)
		_stand.add_child(model)
		await process_frame
		var seat := Vector3(0.0, 0.6, 0.0)
		var found := model.find_children("*", "CharacterRig", true, false)
		if not found.is_empty():
			seat = (found[0] as Node3D).global_position + Vector3(0.0, 0.45 if look[1] == "kart_kid" else 0.5, 0.0)
		for frame in 20:
			await process_frame
		var view := Vector3(-0.8, 0.3, -1.0) if look[1] == "kart_kid" else Vector3(-0.75, 0.2, -1.0)
		shots.append(await snap("%s on the %s" % [look[0], look[1]], seat + view.normalized() * (3.0 if look[1] == "kart_kid" else 3.8), seat))
	save(sheet(shots, 4, TILE), "outfits.png")


## Every leg style standing, seated and astride, a sheet each, and a few
## whole outfits with skirts and boots in karts and on bikes.
func _legs() -> void:
	for pose in ["standing", "seated", "astride"]:
		var shots := []
		for style in CharacterDesign.styles("legs"):
			var design := bare()
			design.set_piece("legs", style, Color("#9aa0a6") if style in ["robot_legs", "armoured"] else Color("#c4281c"))
			rig(design, pose != "standing", pose == "astride")
			if pose == "standing":
				var middle := Vector3(0.0, 0.42, 0.0)
				shots.append(await snap(style, middle + Vector3(-0.6, 0.2, -1.0).normalized() * 2.2, middle))
			else:
				var middle := Vector3(0.0, 0.25, -0.12)
				shots.append(await snap("%s %s" % [style, pose], middle + Vector3(-0.9, 0.55, -1.0).normalized() * 2.0, middle))
		save(sheet(shots, 5, TILE), "legs_%s.png" % pose)
	var shots := []
	var outfits := [
		["gown", "kart_kid", {"torso": ["gown", "#d86cb0"], "arms": ["long_gloves", "#d86cb0"], "legs": ["gown", "#d86cb0"], "hair": "princess", "headgear": "tiara"}],
		["kilt", "kart_kid", {"torso": ["tunic", "#0d69ab"], "arms": ["rolled", "#f2f2f2"], "legs": ["kilt", "#4b9f4a"], "hair": "short", "headgear": "none"}],
		["skirt", "night_shift", {"torso": ["stripes", "#0d69ab"], "arms": ["short_sleeves", "#0d69ab"], "legs": ["skirt", "#7a3fb8"], "hair": "bob", "headgear": "none"}],
		["cowboy", "flathead", {"torso": ["plaid", "#c4281c"], "arms": ["long_sleeves", "#c4281c"], "legs": ["cowboy", "#1f4e8c"], "hair": "short", "headgear": "cowboy"}],
		["gown", "long_fork", {"torso": ["gown", "#d86cb0"], "arms": ["long_gloves", "#d86cb0"], "legs": ["gown", "#d86cb0"], "hair": "princess", "headgear": "tiara"}],
		["skirt", "zippy", {"torso": ["flowery", "#f2cd37"], "arms": ["short_sleeves", "#f2cd37"], "legs": ["skirt", "#7a3fb8"], "hair": "ponytail", "headgear": "none"}],
		["kilt", "scrambler", {"torso": ["jersey", "#4b9f4a"], "arms": ["racing_gloves", "#4b9f4a"], "legs": ["kilt", "#4b9f4a"], "hair": "spiky", "headgear": "none"}],
		["dino", "tiddler", {"torso": ["dino_belly", "#4b9f4a"], "arms": ["scaly", "#4b9f4a"], "legs": ["dino_feet", "#4b9f4a"], "hair": "none", "headgear": "none"}],
	]
	for look in outfits:
		var design := bare()
		var parts: Dictionary = look[2]
		for slot in ["torso", "arms", "legs"]:
			design.set_piece(slot, parts[slot][0], Color(parts[slot][1]))
		design.set_piece("hair", parts.hair, Color("#6b4430"))
		_gear(design, parts.headgear)
		clear()
		var model := KartModel.make(KartDesign.load_file("res://data/karts/stock/%s.json" % look[1]), design)
		_stand.add_child(model)
		await process_frame
		var seat := Vector3(0.0, 0.6, 0.0)
		var found := model.find_children("*", "CharacterRig", true, false)
		var astride := false
		if not found.is_empty():
			seat = (found[0] as Node3D).global_position + Vector3(0.0, 0.3, 0.0)
			astride = (found[0] as CharacterRig).astride
		for frame in 20:
			await process_frame
		var view := Vector3(-0.9, 0.35, -1.0) if not astride else Vector3(-1.0, 0.2, -0.7)
		shots.append(await snap("%s on the %s" % [look[0], look[1]], seat + view.normalized() * (3.0 if not astride else 3.4), seat))
	save(sheet(shots, 4, TILE), "legs_outfits.png")


const BACK_COLOURS := {"angel_wings": "#f2f2f2", "fairy_wings": "#d86cb0", "bat_wings": "#5a2d82", "dino_tail": "#4b9f4a", "shell": "#4b9f4a", "fox_tail": "#e8782b", "backpack": "#e8782b", "air_tanks": "#f2cd37", "guitar": "#a0703c", "parachute": "#4b9f4a", "radio": "#4b9f4a"}


## Every back piece standing, from behind and from the side, then each one
## seated in a kart (upright seats in turn), lying back in a lay-down seat and
## astride a bike.
func _backs() -> void:
	var styles := CharacterDesign.styles("back").filter(func(s): return s != "none")
	for view in [["behind", Vector3(-0.75, 0.3, 1.0)], ["side", Vector3(-1.0, 0.2, 0.15)]]:
		var shots := []
		for style in styles:
			var design := bare()
			design.set_piece("back", style, Color(BACK_COLOURS.get(style, "#c4281c")))
			design.set_piece("hair", "ponytail", Color("#6b4430"))
			rig(design, false)
			var middle := Vector3(0.0, 0.5, 0.0)
			shots.append(await snap(style, middle + view[1].normalized() * 2.3, middle))
		save(sheet(shots, 5, TILE), "backs_standing_%s.png" % view[0])
	var rides := [
		["seated", ["kart_kid", "oval_ace", "redline"], Vector3(-0.9, 0.5, 0.9)],
		["reclined", ["night_shift"], Vector3(-1.0, 0.45, 0.6)],
		["astride", ["streak", "long_fork", "scrambler", "zippy", "twin_nose"], Vector3(-1.0, 0.35, 0.7)],
	]
	for ride in rides:
		var shots := []
		var karts: Array = ride[1]
		for k in styles.size():
			var style: String = styles[k]
			var kart: String = karts[k % karts.size()]
			var design := bare()
			design.set_piece("back", style, Color(BACK_COLOURS.get(style, "#c4281c")))
			clear()
			var model := KartModel.make(KartDesign.load_file("res://data/karts/stock/%s.json" % kart), design)
			_stand.add_child(model)
			await process_frame
			var seat := Vector3(0.0, 0.6, 0.0)
			var found := model.find_children("*", "CharacterRig", true, false)
			if not found.is_empty():
				seat = (found[0] as Node3D).global_position + Vector3(0.0, 0.25, 0.0)
			for frame in 10:
				await process_frame
			shots.append(await snap("%s in the %s" % [style, kart], seat + (ride[2] as Vector3).normalized() * 3.0, seat))
		save(sheet(shots, 5, TILE), "backs_%s.png" % ride[0])


## The long hairdos and newer short ones standing from the front, side and
## behind, then the long ones in a kart from the side, lying back and on a
## bike, and under a racing helmet, a cap and with a cape.
func _long_hair() -> void:
	var middle := Vector3(0.0, 0.62, 0.0)
	var styles := ["long_straight", "long_wavy", "long_swept", "long_fringe", "long_curly", "low_ponytail", "messy_side_part", "swept_messy", "slicked_back"]
	var shots := []
	for style in styles:
		var design := bare()
		design.set_piece("hair", style, Color("#6b4430"))
		rig(design, false)
		for view in [["front", Vector3(-0.35, 0.2, -1.0)], ["side", Vector3(-1.0, 0.15, 0.0)], ["behind", Vector3(0.4, 0.25, 1.0)]]:
			shots.append(await snap("%s %s" % [style, view[0]], middle + (view[1] as Vector3).normalized() * 2.2, middle))
	save(sheet(shots, 3, TILE), "long_hair_standing.png")
	var long := styles.slice(0, 6)
	shots = []
	for style in long:
		for ride in [["kart_kid", Vector3(-1.0, 0.2, 0.05)], ["redline", Vector3(-1.0, 0.3, 0.3)], ["night_shift", Vector3(-1.0, 0.4, 0.5)], ["streak", Vector3(-1.0, 0.3, 0.4)]]:
			var design := bare()
			design.set_piece("hair", style, Color("#c47a3a"))
			design.set_piece("torso", "racing_suit", Color("#c4281c"))
			clear()
			var model := KartModel.make(KartDesign.load_file("res://data/karts/stock/%s.json" % ride[0]), design)
			_stand.add_child(model)
			await process_frame
			var seat := Vector3(0.0, 0.6, 0.0)
			var found := model.find_children("*", "CharacterRig", true, false)
			if not found.is_empty():
				seat = (found[0] as Node3D).global_position + Vector3(0.0, 0.4, 0.0)
			for frame in 10:
				await process_frame
			shots.append(await snap("%s in the %s" % [style, ride[0]], seat + (ride[1] as Vector3).normalized() * 2.6, seat))
	save(sheet(shots, 4, TILE), "long_hair_karts.png")
	shots = []
	for style in long:
		for wear in [["headgear", "racing_helmet", "#f4f4f4", Vector3(-0.8, 0.25, 0.9)], ["headgear", "cap", "#0d69ab", Vector3(-0.8, 0.25, 0.9)], ["back", "cape", "#c4281c", Vector3(0.5, 0.25, 1.0)]]:
			var design := bare()
			design.set_piece("hair", style, Color("#6b4430"))
			design.set_piece(wear[0], wear[1], Color(wear[2]))
			rig(design, false)
			shots.append(await snap("%s, %s" % [style, wear[1]], middle + (wear[3] as Vector3).normalized() * 2.2, middle))
	save(sheet(shots, 3, TILE), "long_hair_gear.png")


## Close up where each long hairdo's length meets the hair on the head, from
## behind and from three quarters behind, with the head turned 0, 0.35 and
## 1.3 radians. A sheet for each, seam_<style>.png.
func _seam() -> void:
	for style in ["long_straight", "long_wavy", "long_swept", "long_fringe", "long_curly", "low_ponytail"]:
		var shots := []
		var design := bare()
		design.set_piece("hair", style, Color("#6b4430"))
		var r := rig(design, false)
		await process_frame
		var nape := r.head().global_position - Vector3(0.0, 0.09, 0.0)
		for view in [["behind", Vector3(0.0, 0.2, 1.0)], ["three quarter", Vector3(-0.9, 0.2, 0.8)]]:
			for turn in [0.0, 0.35, 1.3, -1.3]:
				r.head().rotation.y = turn
				shots.append(await snap("%s %s %+.2f" % [style, view[0], turn], nape + (view[1] as Vector3).normalized() * 1.5, nape))
		save(sheet(shots, 4, TILE), "seam_%s.png" % style)


## Close ups of the pieces changed to stop colours flickering through each
## other: legs riding, skirts seated and riding, the hats, slicked back hair
## and the back pieces.
func _pieces_check() -> void:
	var shots := []
	for style in ["trousers", "jeans", "skirt", "skirt_socks", "kilt", "gown"]:
		for pose in [["seated", true, false, false], ["astride", true, true, false], ["forward", true, true, true]]:
			var design := bare()
			design.set_piece("legs", style, Color("#c4281c"))
			var r := CharacterRig.new(design, pose[1])
			r.astride = pose[2]
			r.feet_forward = pose[3]
			clear()
			_stand.add_child(r)
			var middle := Vector3(0.0, 0.15 if not pose[2] else 0.0, -0.1)
			shots.append(await snap("%s %s" % [style, pose[0]], middle + Vector3(-1.0, 0.05, -0.25).normalized() * 1.6, middle))
	save(sheet(shots, 6, TILE), "pieces_legs.png")
	shots = []
	for style in ["beanie", "hard_hat", "top_hat", "tiara", "crown", "mushroom", "dino_hood", "viking", "party", "horns"]:
		var design := bare()
		design.set_piece("hair", "short", Color("#6b4430"))
		_gear(design, style)
		var r := rig(design, false)
		await process_frame
		var middle := r.head().global_position + Vector3(0.0, 0.08, 0.0)
		shots.append(await snap(style, middle + Vector3(-0.6, 0.3, -1.0).normalized() * 1.0, middle))
		shots.append(await snap(style + " behind", middle + Vector3(0.7, 0.35, 1.0).normalized() * 1.0, middle))
	var design := bare()
	design.set_piece("hair", "slicked_back", Color("#6b4430"))
	var r := rig(design, false)
	await process_frame
	var top := r.head().global_position + Vector3(0.0, 0.08, 0.0)
	shots.append(await snap("slicked_back", top + Vector3(-0.5, 0.6, -1.0).normalized() * 1.0, top))
	shots.append(await snap("slicked_back above", top + Vector3(0.0, 1.0, -0.3).normalized() * 1.0, top))
	save(sheet(shots, 6, TILE), "pieces_headgear.png")
	shots = []
	for style in ["cape", "short_cape", "quiver", "bat_wings", "sword", "guitar"]:
		for pose in [["standing", false], ["seated", true]]:
			var design2 := bare()
			design2.set_piece("back", style, Color(BACK_COLOURS.get(style, "#c4281c")))
			var r2 := rig(design2, pose[1])
			await process_frame
			var middle := r2.upper().global_position + Vector3(0.0, 0.3, 0.0)
			shots.append(await snap("%s %s" % [style, pose[0]], middle + Vector3(-0.7, 0.35, 1.0).normalized() * 1.5, middle))
	save(sheet(shots, 6, TILE), "pieces_backs.png")
