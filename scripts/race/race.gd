class_name Race
extends Node3D

## A race: your kart and the AI karts on the grid, a countdown, a few laps
## and the results.
##
## You start at the back. Places come from how far round the race each kart
## has got. Fall off the track, or end up a long way from it, and you're put
## back on it with the reset slowdown. Once you finish, the AI drives your
## kart for you while the rest come home.

const TRACK := "res://data/tracks/brickyard.json"
const AI_KARTS := "res://data/karts/ai"
const COUNTDOWN := 3.0
## Further below the road than this and you've fallen off.
const FALLEN := 4.0
## Further from the middle of the road than this and you're lost.
const LOST := 45.0
const AI_NAMES_SKILL := [0.97, 0.94, 0.92, 0.9, 0.87]


class Racer:
	var name := ""
	var kart: Kart
	var progress: RaceProgress
	var offset := 0.0
	var ai: AIDriver
	var player := false


var track: TrackPath
var racers: Array[Racer] = []
var player: Racer
## Seconds since the start. It counts up from minus the countdown.
var time := -COUNTDOWN
var started := false

var hud: RaceHud
var camera: ChaseCamera
var _player_input: LocalPlayerInput
## The countdown waits until this many frames have been drawn. The first
## frames can stall for seconds while shaders compile, and the countdown used
## to run out during that, starting the race before you could see it.
const FRAMES_BEFORE_COUNTDOWN := 10
var _frames_drawn := 0


func _ready() -> void:
	track = TrackPath.load_file(TRACK)
	add_child(TrackBuilder.new(track))

	var files := Array(DirAccess.get_files_at(AI_KARTS)).filter(func(f): return f.ends_with(".json"))
	files.sort()
	for i in files.size():
		var design := KartDesign.load_file(AI_KARTS + "/" + files[i])
		var racer := _add_racer(design.name, design, i)
		racer.ai = AIDriver.new()
		racer.ai.kart = racer.kart
		racer.ai.track = track
		racer.ai.skill = AI_NAMES_SKILL[i % AI_NAMES_SKILL.size()]
		racer.ai.line = (i % 3 - 1) * 1.5
		racer.kart.controls = racer.ai.controls
		add_child(racer.ai)

	var karts: Array[Kart] = []
	for racer in racers:
		karts.append(racer.kart)

	# You start at the back.
	player = _add_racer(Game.player_name(), Game.design, racers.size())
	player.player = true
	karts.append(player.kart)
	for racer in racers:
		if racer.ai != null:
			racer.ai.others = karts
	_player_input = LocalPlayerInput.new()
	_player_input.use_keyboard = true
	_player_input.any_joypad = true
	add_child(_player_input)
	player.kart.controls = _player_input.controls

	camera = ChaseCamera.new()
	camera.target = player.kart
	add_child(camera)
	camera.make_current()
	camera.snap()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = RaceHud.new()
	hud.race = self
	layer.add_child(hud)
	var touch := TouchControls.new()
	touch.visible = DisplayServer.is_touchscreen_available()
	touch.blockers.append_array(hud.buttons())
	hud.add_child(touch)
	hud.touch = touch
	_player_input.touch = touch
	# A debug switch for testing on a device: with a file called autopilot
	# in the app's data folder, the AI drives your kart.
	if OS.is_debug_build() and FileAccess.file_exists("user://autopilot"):
		var driver := AIDriver.new()
		driver.kart = player.kart
		driver.track = track
		driver.others.assign(racers.map(func(r): return r.kart))
		add_child(driver)
		player.ai = driver
		player.kart.controls = driver.controls
	hud.again_pressed.connect(Game.show_race)
	hud.garage_pressed.connect(Game.show_garage)
	hud.menu_pressed.connect(Game.show_menu)


func _add_racer(racer_name: String, design: KartDesign, slot: int) -> Racer:
	var racer := Racer.new()
	racer.name = racer_name
	racer.kart = Kart.new()
	racer.kart.build(design)
	var place := track.grid_slot(slot)
	racer.kart.transform = place
	racer.kart.locked = true
	racer.offset = track.offset_of(place.origin)
	racer.progress = RaceProgress.new(track.length, track.laps, racer.offset)
	racer.kart.reset_to = func(_where: Vector3) -> Transform3D:
		return _clear_spot(racer)
	add_child(racer.kart)
	racers.append(racer)
	return racer


func _process(_delta: float) -> void:
	_frames_drawn += 1
	if _frames_drawn == FRAMES_BEFORE_COUNTDOWN:
		Game.show_loading(false)


func _physics_process(delta: float) -> void:
	if _frames_drawn < FRAMES_BEFORE_COUNTDOWN:
		return
	time += delta
	if not started and time >= 0.0:
		started = true
		for racer in racers:
			racer.kart.locked = false

	for racer in racers:
		var kart := racer.kart
		racer.offset = track.offset_of(kart.global_position, racer.offset, 40.0)
		if racer.ai != null:
			racer.ai.offset = racer.offset
		if started:
			var was_done := racer.progress.finished
			racer.progress.update(racer.offset, time)
			if racer.player and racer.progress.finished and not was_done:
				_player_finished()

		# Fallen off, or wandered far away: put it back.
		var middle := track.point_at(racer.offset)
		var below := (kart.global_position - middle).dot(track.up_at(racer.offset))
		if kart.slowdown_left <= 0.0 and (below < -FALLEN or kart.global_position.distance_to(middle) > LOST):
			kart.request_reset()
			if racer.player:
				hud.flash("Back on the track")


## Somewhere on the track near this racer with no other kart in the way, so
## a reset never drops one kart on top of another. It tries across the road
## first, then a little further back.
func _clear_spot(racer: Racer) -> Transform3D:
	var room := 3.5
	var across := [0.0, -3.0, 3.0, -4.5, 4.5]
	for back in [0.0, 5.0, 10.0, 15.0, 20.0]:
		for side in across:
			var spot := track.place_at(racer.offset - back)
			spot.origin += spot.basis.x * side
			var clear := true
			for other in racers:
				if other != racer and other.kart.global_position.distance_to(spot.origin) < room:
					clear = false
					break
			if clear:
				return spot
	return track.place_at(racer.offset)


## Once you're over the line the AI takes your kart home, so it doesn't just
## stop in everyone's way.
func _player_finished() -> void:
	hud.show_results()
	if player.ai != null:
		return
	var driver := AIDriver.new()
	driver.kart = player.kart
	driver.track = track
	driver.skill = 0.85
	driver.others.assign(racers.map(func(r): return r.kart))
	add_child(driver)
	player.ai = driver
	player.kart.controls = driver.controls


## Everyone in order: finishers by time, then the rest by how far round
## they've got.
func standings() -> Array[Racer]:
	var order := racers.duplicate()
	order.sort_custom(func(a: Racer, b: Racer) -> bool:
		if a.progress.finished != b.progress.finished:
			return a.progress.finished
		if a.progress.finished:
			return a.progress.finish_time < b.progress.finish_time
		return a.progress.distance() > b.progress.distance())
	var out: Array[Racer] = []
	out.assign(order)
	return out


func place_of(racer: Racer) -> int:
	return standings().find(racer) + 1


func go_back() -> void:
	Game.show_menu()
