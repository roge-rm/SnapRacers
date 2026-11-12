class_name DriverPortraits
extends Node

## Takes a picture of a whole driver, head to feet, standing and turned a
## little to one side, for the driver picker. Pictures are taken a few at a
## time in small views off the screen and kept while the game runs.
##
## They're kept under the driver's look, so a driver changed on the driver
## screen gets a new picture and going back to an old look finds it taken.

signal ready_for(key: String, picture: Texture2D)

## Three wide by four high, about the shape of a standing figure.
const SIZE := Vector2i(240, 320)
const FILL := 0.92
## In front of them (they face -Z), a little to their right and above.
const FROM := Vector3(-0.5, 0.25, -1.0)
const AT_ONCE := 4

static var _pictures := {}

var _views: Array[PictureStudio] = []
var _queue: Array = []
var _headless := false


## What a picture of this driver is kept under: their look, without the name.
static func key_of(design: CharacterDesign) -> String:
	var look := design.to_dict()
	look.erase("name")
	return JSON.stringify(look, "", true).md5_text()


## The picture of this driver, or null if it hasn't been taken yet.
static func picture(design: CharacterDesign) -> Texture2D:
	return _pictures.get(key_of(design))


## Takes this driver's picture, if there isn't one already, and says when
## it's ready through ready_for, under key_of(design).
func take(design: CharacterDesign) -> void:
	var key := key_of(design)
	if _headless or _pictures.has(key) or _queue.any(func(job): return job[0] == key):
		return
	if _views.any(func(studio): return studio.key == key):
		return
	_queue.append([key, design.duplicate_design()])
	set_process(true)


func _ready() -> void:
	# With no screen (the headless tests) there's nothing to take pictures with.
	_headless = DisplayServer.get_name() == "headless"
	set_process(false)
	if _headless:
		return
	for i in AT_ONCE:
		var studio := PictureStudio.new(SIZE)
		# The toy plastic's own lights, without the sky, which turns flat
		# plastic pale blue.
		CharacterRig.add_toy_lights(studio)
		add_child(studio)
		_views.append(studio)


func _process(_delta: float) -> void:
	var busy := false
	for studio in _views:
		var done := studio.taken()
		if done != null:
			_pictures[studio.key] = ImageTexture.create_from_image(done)
			ready_for.emit(studio.key, _pictures[studio.key])
			studio.key = ""
		if studio.key == "" and not _queue.is_empty():
			var job: Array = _queue.pop_front()
			studio.take(job[0], CharacterRig.new(job[1], false), FROM, FILL)
		busy = busy or studio.key != ""
	if not busy:
		set_process(false)
