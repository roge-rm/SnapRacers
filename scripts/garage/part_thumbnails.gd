class_name PartThumbnails
extends Node

## Takes a little picture of every part for the garage's drawer. Each part is
## set up on its own in a small view off the screen, lit and seen from above at
## an angle, framed to fill the picture, and drawn once.
##
## There's one of these for the whole game (Game.part_pictures). It starts
## during the splash, so the pictures are there by the time the garage opens,
## and it saves them, so after the first launch they load straight away. They're
## taken again when the parts change.

signal ready_for(id: String, picture: Texture2D)

const SIZE := Vector2i(160, 120)
const SAVED := "user://pictures/parts"
## Goes up when the pictures are taken differently, so the saved ones go.
const LOOK := 2
## How much of the picture a part fills.
const FILL := 0.88
## Dark parts would be lost on the drawer's dark tiles, so in the pictures
## they're never darker than this.
const DARKEST := 0.42
## How many pictures are taken at the same time.
const AT_ONCE := 8

static var _pictures := {}

var _views: Array[PictureStudio] = []
var _queue: Array = []
var _stamp := ""


## The picture of a part, or null if it hasn't been taken yet.
static func picture(id: String) -> Texture2D:
	return _pictures.get(id)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# With no screen (the headless tests) there's nothing to take pictures with.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for i in AT_ONCE:
		var studio := PictureStudio.new(SIZE)
		add_child(studio)
		_views.append(studio)
	_stamp = _work_out_stamp()
	var keep := FileAccess.get_file_as_string(SAVED + "/stamp.txt") == _stamp
	if not keep:
		DirAccess.make_dir_recursive_absolute(SAVED)
		for file in DirAccess.get_files_at(SAVED):
			DirAccess.remove_absolute(SAVED + "/" + file)
	for id in PartCatalog.ids():
		if _pictures.has(id):
			continue
		if keep and _load(id):
			continue
		_queue.append(id)
	if not keep:
		var file := FileAccess.open(SAVED + "/stamp.txt", FileAccess.WRITE)
		if file != null:
			file.store_string(_stamp)


## Takes these parts' pictures next, like the ones on the tab just opened.
func hurry(ids: Array) -> void:
	var first := ids.filter(func(id: String) -> bool: return _queue.has(id))
	if first.is_empty():
		return
	_queue = first + _queue.filter(func(id: String) -> bool: return not first.has(id))
	set_process(DisplayServer.get_name() != "headless")


## What the parts are, so the saved pictures can tell if they've changed.
static func _work_out_stamp() -> String:
	var text := "%d %s" % [LOOK, ProjectSettings.get_setting("application/config/version", "")]
	for path in [PartCatalog.PATH, PartCatalog.MADE_PATH]:
		text += FileAccess.get_file_as_string(path)
	return text.md5_text()


func _load(id: String) -> bool:
	var path := "%s/%s.png" % [SAVED, id]
	if not FileAccess.file_exists(path):
		return false
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return false
	_pictures[id] = ImageTexture.create_from_image(image)
	return true


func _process(_delta: float) -> void:
	var busy := false
	for studio in _views:
		var done := studio.taken()
		if done != null:
			_pictures[studio.key] = ImageTexture.create_from_image(done)
			done.save_png("%s/%s.png" % [SAVED, studio.key])
			ready_for.emit(studio.key, _pictures[studio.key])
			studio.key = ""
		if studio.key == "" and not _queue.is_empty():
			var id: String = _queue.pop_front()
			var made := PartVisuals.make(PartCatalog.get_part(id), PartCatalog.fine_size(id) * Grid.FINE)
			_lighten(made)
			studio.take(id, made, Vector3(1.0, 0.9, -1.3), FILL)
		busy = busy or studio.key != ""
	if not busy:
		set_process(false)


## Lifts dark colours, so black tires and dark tiles show up in the drawer.
static func _lighten(made: Node3D) -> void:
	for node in made.find_children("*", "GeometryInstance3D", true, false):
		var shown := node as GeometryInstance3D
		var material := shown.material_override as StandardMaterial3D
		if material == null or material.albedo_color.v >= DARKEST:
			continue
		var lighter := material.duplicate() as StandardMaterial3D
		lighter.albedo_color.v = DARKEST
		shown.material_override = lighter
