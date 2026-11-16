class_name KartThumbnails
extends Node

## Takes a picture of a whole kart, from in front and a little to one side, for
## the kart picker, with the picked driver in it. Each kart is set up in a small
## view off the screen and drawn once.
##
## There's one of these for the whole game (Game.kart_pictures()). Once the
## menu is up it takes every kart with your driver a few at a time (see
## take_later()), so they're mostly there by the time the picker opens. Each picture is saved under a name made from the kart and the
## driver, so after the first time it loads straight away, even after the game
## restarts. They're all taken again when the game's version or LOOK changes.
## It doesn't take any during a race or a test drive.

signal ready_for(key: String, picture: Texture2D)

const SIZE := Vector2i(320, 200)
const SAVED := "user://pictures/karts"
## Goes up when the pictures are taken differently, so the saved ones go.
const LOOK := 1
## How many pictures are saved, about 20 KB each. The ones not used for
## longest go first.
const KEEP_SAVED := 160
## How many are kept in memory, 250 KB each, the oldest going first.
const KEEP_HERE := 90
## The views take turns, so one is drawn while another's picture is read back.
const VIEWS := 2
## The most milliseconds a frame spends loading and setting up karts, past
## the first one.
const BUDGET := 6
## Frames between one background picture and the next. Each one costs a few
## milliseconds of loading or setting up a kart, so one every 8 frames
## (about 7 a second) is hardly felt on a phone that draws 15 frames a second.
const LATER_GAP := 8

## Each picture, as key -> Texture2D, and the saved name it was taken for.
static var _pictures := {}
static var _names := {}

var _views: Array[SubViewport] = []
var _cameras: Array[Camera3D] = []
var _stands: Array[Node3D] = []
## What each view is taking, as [key, name], or [] when it's free.
var _taking: Array = []
var _frames: Array[int] = []
## Each job is [key, design, driver, name].
var _queue: Array = []
## The picture last asked for under each key, as key -> name, so one that
## finishes after a newer ask isn't shown.
var _wanted := {}
## When each saved picture was last used, as name -> unix time.
var _used := {}
var _used_changed := false
var _used_written := 0
var _headless := false
## Jobs to start in the background, one every LATER_GAP frames.
var _later: Array = []
var _later_wait := 0
## How many fingers are down, and whether the mouse is.
var _fingers := {}


## The picture kept under `key`, or null if it hasn't been taken yet.
static func picture(key: String) -> Texture2D:
	return _pictures.get(key)


## The saved name for a kart's picture with this driver. It changes when
## anything that shows in the picture does.
static func name_of(design: KartDesign, driver: CharacterDesign = null) -> String:
	var kart := design.to_dict()
	kart.erase("name")
	kart.erase("about")
	var look := DriverPortraits.key_of(driver if driver != null else Kart.default_driver())
	return (JSON.stringify(kart, "", true) + look).md5_text()


## Takes a picture of this kart, if the one under `key` isn't of it already,
## and says when it's ready through ready_for. Gives back the picture if it's
## ready now, or else null.
func take(key: String, design: KartDesign, driver: CharacterDesign = null) -> Texture2D:
	if _headless:
		return null
	var name := name_of(design, driver)
	_wanted[key] = name
	if _names.get(key) == name:
		return _pictures[key]
	for job in _taking:
		if not job.is_empty() and job[0] == key and job[1] == name:
			return null
	for job in _queue:
		if job[0] == key:
			job[1] = design
			job[2] = driver
			job[3] = name
			return null
	_later = _later.filter(func(job: Array) -> bool: return job[0] != key)
	_queue.append([key, design, driver, name])
	set_process(true)
	return null


## Asks for a picture to be taken in the background, when nothing else is
## waiting and no finger or mouse is down. `take()` for the same key brings it
## forward.
func take_later(key: String, design: KartDesign, driver: CharacterDesign = null) -> void:
	if _headless:
		return
	var name := name_of(design, driver)
	if _names.get(key) == name:
		return
	for job in _later:
		if job[0] == key:
			job[1] = design
			job[2] = driver
			job[3] = name
			return
	_later.append([key, design, driver, name])
	set_process(true)


## Takes these pictures next, like the ones on the screen.
func hurry(keys: Array) -> void:
	var first := _queue.filter(func(job: Array) -> bool: return keys.has(job[0]))
	if first.is_empty():
		return
	_queue = first + _queue.filter(func(job: Array) -> bool: return not keys.has(job[0]))


## Drops the pictures still to take whose keys end in `look`, like a driver
## that's no longer picked.
func drop_look(look: String) -> void:
	_queue = _queue.filter(func(job: Array) -> bool: return not job[0].ends_with(look))
	_later = _later.filter(func(job: Array) -> bool: return not job[0].ends_with(look))


## Whether it's still taking pictures.
func busy() -> bool:
	return not _queue.is_empty() or not _later.is_empty() or _taking.any(func(job: Array) -> bool: return not job.is_empty())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	# With no screen (the headless tests) there's nothing to take pictures with.
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return
	for i in VIEWS:
		_add_view()
	_open_saved()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = true
		else:
			_fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		_fingers[event.index] = true


func _add_view() -> void:
	var view := SubViewport.new()
	view.size = SIZE
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#e8e8e8")
	env.environment.ambient_light_energy = 0.55
	view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 215.0, 0.0)
	sun.light_energy = 0.9
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.add_child(camera)
	var stand := Node3D.new()
	view.add_child(stand)
	_views.append(view)
	_cameras.append(camera)
	_stands.append(stand)
	_taking.append([])
	_frames.append(0)


## Clears out the saved pictures if they were taken by another version, and
## the ones not used for longest when there are too many.
func _open_saved() -> void:
	var stamp := "%d %s" % [LOOK, ProjectSettings.get_setting("application/config/version", "")]
	DirAccess.make_dir_recursive_absolute(SAVED)
	var files := DirAccess.get_files_at(SAVED)
	var stamp_path := SAVED + "/stamp.txt"
	if not FileAccess.file_exists(stamp_path) or FileAccess.get_file_as_string(stamp_path) != stamp:
		for file in files:
			DirAccess.remove_absolute(SAVED + "/" + file)
		files = PackedStringArray()
		var file := FileAccess.open(SAVED + "/stamp.txt", FileAccess.WRITE)
		if file != null:
			file.store_string(stamp)
	var used: Variant = null
	if FileAccess.file_exists(SAVED + "/used.json"):
		used = JSON.parse_string(FileAccess.get_file_as_string(SAVED + "/used.json"))
	var names: Array[String] = []
	for file in files:
		if file.ends_with(".kart"):
			names.append(file.get_basename())
	for name in names:
		_used[name] = int(used.get(name, 0)) if used is Dictionary else 0
	if names.size() > KEEP_SAVED:
		names.sort_custom(func(a: String, b: String) -> bool: return _used[a] < _used[b])
		for name in names.slice(0, names.size() - KEEP_SAVED):
			DirAccess.remove_absolute(_path(name))
			_used.erase(name)
		_save_used()


static func _path(name: String) -> String:
	return "%s/%s.kart" % [SAVED, name]


## Saves a picture as its pixels, packed, which is a lot quicker to save and
## load than a PNG and comes out about the same size.
static func _save(image: Image, name: String) -> void:
	image.convert(Image.FORMAT_RGBA8)
	var file := FileAccess.open_compressed(_path(name), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file != null:
		file.store_32(image.get_width())
		file.store_32(image.get_height())
		file.store_buffer(image.get_data())


static func _load(name: String) -> Image:
	var file := FileAccess.open_compressed(_path(name), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var width := file.get_32()
	var height := file.get_32()
	if width != SIZE.x or height != SIZE.y:
		return null
	var data := file.get_buffer(width * height * 4)
	if data.size() != width * height * 4:
		return null
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


func _save_used() -> void:
	var file := FileAccess.open(SAVED + "/used.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_used))
	_used_changed = false
	_used_written = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	var from := Time.get_ticks_msec()
	for i in _views.size():
		if _taking[i].is_empty():
			continue
		_frames[i] += 1
		# One frame to draw it, one more for the picture to be ready.
		if _frames[i] < 2:
			continue
		var image := _views[i].get_texture().get_image()
		if image != null and not image.is_empty():
			_save(image, _taking[i][1])
			_keep(_taking[i][0], _taking[i][1], ImageTexture.create_from_image(image))
		_taking[i] = []
		for child in _stands[i].get_children():
			child.queue_free()
	# Saved every few seconds too, so a game that's closed midway keeps them.
	if _used_changed and Time.get_ticks_msec() - _used_written > 5000:
		_save_used()
	var racing := Game._screen is Race or Game._screen is TestDrive
	var started := false
	while not racing and not _queue.is_empty() and (not started or Time.get_ticks_msec() - from < BUDGET):
		var job: Array = _queue.front()
		if _used.has(job[3]):
			_queue.pop_front()
			started = true
			var image := _load(job[3])
			if image != null and not image.is_empty():
				_keep(job[0], job[3], ImageTexture.create_from_image(image))
				continue
			_used.erase(job[3])
			_queue.push_front(job)
		var free := -1
		for i in _taking.size():
			if _taking[i].is_empty():
				free = i
				break
		if free < 0:
			break
		_queue.pop_front()
		_set_up(free, job)
		started = true
	# One background picture at a time, only while nothing else is waiting.
	if not racing and _queue.is_empty() and not _later.is_empty():
		_later_wait -= 1
		var touching := not _fingers.is_empty() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if _later_wait <= 0 and not touching:
			_queue.append(_later.pop_front())
			_later_wait = LATER_GAP
	if not racing and not busy():
		set_process(false)
		if _used_changed:
			_save_used()


## Puts a kart in view `i` to have its picture taken.
func _set_up(i: int, job: Array) -> void:
	_taking[i] = [job[0], job[3]]
	_frames[i] = 0
	_stands[i].add_child(KartModel.make(job[1], job[2]))
	var box := KartModel.bounds(job[1])
	var middle := box.get_center()
	# From in front, up a bit and off to the left, and big enough to fit the
	# kart whichever way it's longest.
	var camera := _cameras[i]
	camera.size = maxf(box.size.y * 1.6, maxf(box.size.x, box.size.z) * 0.95)
	camera.position = middle + Vector3(-1.0, 0.75, -1.4).normalized() * 10.0
	camera.look_at(middle, Vector3.UP)
	_views[i].render_target_update_mode = SubViewport.UPDATE_ONCE


func _keep(key: String, name: String, picture: Texture2D) -> void:
	_used[name] = int(Time.get_unix_time_from_system())
	_used_changed = true
	if _wanted.get(key, name) != name:
		return
	_pictures.erase(key)
	_pictures[key] = picture
	_names[key] = name
	while _pictures.size() > KEEP_HERE:
		var oldest: String = _pictures.keys()[0]
		_pictures.erase(oldest)
		_names.erase(oldest)
	ready_for.emit(key, picture)
