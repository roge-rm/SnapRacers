class_name TrophyThumbnails
extends Node

## Takes the pictures of the cups' trophies for the cup screen, in whichever
## finish each one's won in. They're kept while the game runs.

signal ready_for(key: String, picture: Texture2D)

const SIZE := Vector2i(240, 300)
const AT_ONCE := 4

static var _pictures := {}

var _views: Array[PictureStudio] = []
var _queue: Array = []


## The key for a trophy's picture, which says what it looks like.
static func key_of(spec: Dictionary, colour: Color, finish: String) -> String:
	return "%s %s %s" % [spec.get("top", "cup"), colour.to_html(false), finish]


static func picture(key: String) -> Texture2D:
	return _pictures.get(key)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# With no screen (the headless tests) there's nothing to take pictures with.
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for i in AT_ONCE:
		var studio := PictureStudio.new(SIZE, true)
		add_child(studio)
		_views.append(studio)


## Asks for a trophy's picture, which comes back through ready_for.
func take(spec: Dictionary, colour: Color, finish: String) -> void:
	var key := key_of(spec, colour, finish)
	if _pictures.has(key) or _queue.any(func(job: Array) -> bool: return job[0] == key):
		return
	_queue.append([key, spec, colour, finish])
	set_process(not _views.is_empty())


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
			studio.take(job[0], TrophyModel.make(job[1], job[2], job[3]), Vector3(0.9, 0.55, -1.6), 0.94)
		busy = busy or studio.key != ""
	if not busy:
		set_process(false)
