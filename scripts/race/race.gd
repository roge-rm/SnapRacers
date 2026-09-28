class_name Race
extends Node3D

## A race. Your kart and the AI karts line up on the grid, there's a
## countdown, a few laps, and then the results.
##
## You start at the back. Places come from how far around the race each kart
## has gotten. If you fall off the track or end up a long way from it, you're
## put back on it with the reset slowdown. Once you finish, the AI drives your
## kart for you while the rest come home.
##
## Two people can play on one phone (see Game.split()). Each of them gets half
## the screen with their own camera, HUD and touch controls, drawn in their
## own SubViewport. When you're face to face, the far player's half is turned
## upside down so it's the right way up from their end of the phone.

const AI_KARTS := Game.AI_KARTS
## The gap between the two halves in split screen, in pixels.
const DIVIDER := 4
const COUNTDOWN := 3.0
## If you're further below the road than this, you've fallen off.
const FALLEN := 4.0
## If you're further from the middle of the road than this, you're lost.
const LOST := 45.0
## How far before a loop or wall ride a reset puts you, so you can build up
## speed.
const RUN_UP := 35.0
const AI_NAMES_SKILL := [0.97, 0.95, 0.93, 0.91, 0.9, 0.88, 0.86]
## Karts in a race, you included.
const KARTS := 8


class Racer:
	var name := ""
	var kart: Kart
	var progress: RaceProgress
	var offset := 0.0
	var ai: AIDriver
	var player := false
	## A person's view of the race, which is theirs alone in split screen.
	var hud: RaceHud
	var camera: ChaseCamera
	var input: LocalPlayerInput


var track: TrackPath
var racers: Array[Racer] = []
## The people racing, player 1 first.
var humans: Array[Racer] = []
## Player 1.
var player: Racer
## How the screen is shared (Game.SOLO and so on). Setting it before this is
## added to the scene overrides the saved choice.
var split := ""
var _split_set := false
## Seconds since the start. It counts up from minus the countdown.
var time := -COUNTDOWN
var started := false

var studs: StudField
## Player 1's.
var hud: RaceHud
var camera: ChaseCamera
## The countdown waits until this many frames have been drawn. The first
## frames can stall for seconds while shaders compile, and the countdown used
## to run out during that and start the race before you could see it.
const FRAMES_BEFORE_COUNTDOWN := 10
var _frames_drawn := 0


func _init(mode: Variant = null) -> void:
	if mode != null:
		split = mode
		_split_set = true


func _ready() -> void:
	if not _split_set:
		split = Game.split()
	var people := 1 if split == Game.SOLO else 2
	track = TrackPath.load_file(Game.track_path)
	add_child(TrackBuilder.new(track))

	# Player 2 takes one of the AI karts, and the AI has the rest.
	var two := Game.player_two_kart()
	var keys := Game.ai_kart_keys()
	if people > 1:
		keys.erase(two)
	keys = keys.slice(0, KARTS - people)
	for i in keys.size():
		var design := KartDesign.load_file(AI_KARTS + "/" + keys[i] + ".json")
		var racer := _add_racer(design.name, design, i, Game.roster_driver(keys[i]))
		racer.ai = AIDriver.new()
		racer.ai.kart = racer.kart
		racer.ai.track = track
		racer.ai.skill = AI_NAMES_SKILL[i % AI_NAMES_SKILL.size()]
		racer.ai.line = (i % 3 - 1) * 1.5
		racer.kart.controls = racer.ai.controls
		add_child(racer.ai)

	# The people start at the back, player 1 last of all.
	if people > 1:
		var design := KartDesign.load_file(AI_KARTS + "/" + two + ".json")
		var second := _add_racer("Player 2", design, racers.size(), Game.roster_driver(two))
		second.player = true
		humans.append(second)
	player = _add_racer(Game.player_name(), Game.design, racers.size(), Game.character)
	player.player = true
	humans.push_front(player)

	var karts: Array[Kart] = []
	for racer in racers:
		karts.append(racer.kart)
	for racer in racers:
		if racer.ai != null:
			racer.ai.others = karts

	studs = StudField.new(track)
	for human in humans:
		studs.viewers.append(human.kart)
	add_child(studs)

	if people == 1:
		var layer := CanvasLayer.new()
		add_child(layer)
		_add_view(player, self, layer)
	else:
		_add_split_views()
	hud = player.hud
	camera = player.camera
	# A debug switch for testing on a device. If there's a file called
	# autopilot in the app's data folder, the AI drives your kart.
	if OS.is_debug_build() and FileAccess.file_exists("user://autopilot"):
		var driver := AIDriver.new()
		driver.kart = player.kart
		driver.track = track
		driver.others.assign(karts)
		add_child(driver)
		player.ai = driver
		player.kart.controls = driver.controls


## One person's camera, HUD and controls. The camera goes under `world_parent`
## (the race itself, or their own SubViewport) and the HUD on `layer`.
func _add_view(racer: Racer, world_parent: Node, layer: CanvasLayer) -> void:
	var index := humans.find(racer)
	var input := LocalPlayerInput.new()
	input.use_keyboard = true
	if humans.size() == 1:
		input.any_joypad = true
	else:
		input.keys = LocalPlayerInput.LEFT_KEYS if index == 0 else LocalPlayerInput.RIGHT_KEYS
		input.pad_slot = index
	add_child(input)
	racer.input = input
	racer.kart.controls = input.controls

	var view := ChaseCamera.new()
	view.target = racer.kart
	if humans.size() > 1:
		# Leave out the other players' studs.
		for other in humans.size():
			if other != index:
				view.set_cull_mask_value(StudField.layer_of(other), false)
	world_parent.add_child(view)
	view.make_current()
	view.snap()
	racer.camera = view

	var racer_hud := RaceHud.new()
	racer_hud.race = self
	racer_hud.me = racer
	layer.add_child(racer_hud)
	var touch := TouchControls.new()
	touch.visible = DisplayServer.is_touchscreen_available()
	touch.blockers.append_array(racer_hud.buttons())
	racer_hud.add_child(touch)
	racer_hud.touch = touch
	input.touch = touch
	racer.hud = racer_hud
	racer_hud.again_pressed.connect(func() -> void: Game.show_race())
	racer_hud.garage_pressed.connect(Game.show_garage)
	racer_hud.menu_pressed.connect(Game.show_menu)


## Two halves of the screen, each with its own SubViewport looking at this
## race. Side by side, player 1 is on the left. Face to face, player 1 has the
## bottom half and player 2 has the top, turned around to face the other way.
func _add_split_views() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var divider := ColorRect.new()
	divider.color = Color.BLACK
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(divider)
	divider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gap := DIVIDER * 0.5
	for i in humans.size():
		var holder := SubViewportContainer.new()
		holder.stretch = true
		root.add_child(holder)
		if split == Game.FACE_TO_FACE:
			holder.anchor_right = 1.0
			holder.anchor_top = 0.5 if i == 0 else 0.0
			holder.anchor_bottom = 1.0 if i == 0 else 0.5
			holder.offset_top = gap if i == 0 else 0.0
			holder.offset_bottom = 0.0 if i == 0 else -gap
		else:
			holder.anchor_bottom = 1.0
			holder.anchor_left = 0.0 if i == 0 else 0.5
			holder.anchor_right = 0.5 if i == 0 else 1.0
			holder.offset_left = 0.0 if i == 0 else gap
			holder.offset_right = -gap if i == 0 else 0.0
		if split == Game.FACE_TO_FACE and i == 1:
			# It's turned all the way around its middle (not flipped, which would
			# mirror it). The middle moves as the screen settles into portrait.
			holder.rotation = PI
			holder.resized.connect(func() -> void: holder.pivot_offset = holder.size * 0.5)
		var viewport := SubViewport.new()
		holder.add_child(viewport)
		var hud_layer := CanvasLayer.new()
		viewport.add_child(hud_layer)
		_add_view(humans[i], viewport, hud_layer)


func _add_racer(racer_name: String, design: KartDesign, slot: int, who: CharacterDesign) -> Racer:
	var racer := Racer.new()
	racer.name = racer_name
	racer.kart = Kart.new()
	racer.kart.build(design, who)
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
			kart.add_studs(studs.collect(kart))
			var was_done := racer.progress.finished
			racer.progress.update(racer.offset, time)
			if racer.player and racer.progress.finished and not was_done:
				_player_finished(racer)

		# If it's fallen off or wandered far away, put it back.
		var middle := track.point_at(racer.offset)
		var below := (kart.global_position - middle).dot(track.up_at(racer.offset))
		if kart.slowdown_left <= 0.0 and (below < -FALLEN or kart.global_position.distance_to(middle) > LOST):
			kart.request_reset()
			if racer.hud != null:
				racer.hud.flash("Back on the track")


## Somewhere on the track near this racer with no other kart in the way, so
## a reset never drops one kart on top of another. It tries across the road
## first, then a little further back.
func _clear_spot(racer: Racer) -> Transform3D:
	var room := 3.5
	var across := [0.0, -3.0, 3.0, -4.5, 4.5]
	# Never put a kart back on a loop or a wall ride. Go back to where the road
	# lies flat before it, and then a run up further than that, because they
	# need speed and a kart put back right at the foot of a loop just falls off
	# it again.
	var start := racer.offset
	var backed := false
	for step in 80:
		if track.up_at(start).y > 0.95:
			break
		start -= 2.0
		backed = true
	if backed:
		start -= RUN_UP
	for back in [0.0, 5.0, 10.0, 15.0, 20.0]:
		for side in across:
			var spot := track.place_at(start - back)
			spot.origin += spot.basis.x * side
			var clear := true
			for other in racers:
				if other != racer and other.kart.global_position.distance_to(spot.origin) < room:
					clear = false
					break
			if clear:
				# The kart's been moved, so the race has to know where it is now,
				# or it goes looking for it where it was and resets it again.
				racer.offset = fposmod(start - back, track.length)
				return spot
	racer.offset = fposmod(start, track.length)
	return track.place_at(start)


## Once you're over the line the AI takes your kart home, so it doesn't just
## stop in everyone's way.
func _player_finished(racer: Racer) -> void:
	if racer.hud != null:
		racer.hud.show_results()
	if racer.ai != null:
		return
	var driver := AIDriver.new()
	driver.kart = racer.kart
	driver.track = track
	driver.skill = 0.85
	driver.others.assign(racers.map(func(r): return r.kart))
	add_child(driver)
	racer.ai = driver
	racer.kart.controls = driver.controls


## Everyone in order, with finishers by time and then the rest by how far
## around they've gotten.
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
