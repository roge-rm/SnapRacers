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

## The gap between the two halves in split screen, in pixels.
const DIVIDER := 4
const COUNTDOWN := 3.0
## If you're further below the road than this, you've fallen off.
const FALLEN := 4.0
## If you're further from the middle of the road than this, you're lost.
const LOST := 45.0
## How far before a loop or wall ride a reset puts you, so you can build up
## speed.
const RUN_UP := 110.0
## How far ahead on a loop's run in it looks for the climb (see _loop_coming()).
const LOOP_FOOT := 30.0
## Karts in a race, you included.
const KARTS := 8
## How often drivers check who they've passed and who's beside them.
const WATCH_EVERY := 0.25
## How close another kart has to be for a driver to look at it.
const ALONGSIDE := 4.0


class Racer:
	var name := ""
	var kart: Kart
	var progress: RaceProgress
	var offset := 0.0
	var ai: AIDriver
	var player := false
	## A person's view of the race, which is theirs alone in split screen.
	var hud: RaceHud
	var camera: RaceCamera
	var input: LocalPlayerInput


var track: TrackPath
var racers: Array[Racer] = []
## The people racing, player 1 first.
var humans: Array[Racer] = []
## The menus open now, by whose they are.
var _menus := {}
## Player 1.
var player: Racer
## How the screen is shared (Game.SOLO and so on). Setting it before this is
## added to the scene overrides the saved choice.
var split := ""
var _split_set := false
## What kind of race this is (Game.MODE_RACE and so on).
var mode := Game.MODE_RACE
## Laps to finish. Practice goes on for as long as you like.
var laps := 3
## How good the AI drivers are (see Difficulty).
var difficulty := Difficulty.DEFAULT
## The course's id, for records.
var track_id := ""
## After a time trial, whether you set a new best time and a new best lap.
var new_records := [false, false]
## Seconds since the start. It counts up from minus the countdown.
var time := -COUNTDOWN
var started := false

## The power-up boxes along the track, or null in a time trial.
var boxes: PowerupField
## Player 1's.
var hud: RaceHud
var camera: RaceCamera
## The countdown waits until this many frames have been drawn, since the first
## frames can stall for seconds while shaders compile.
const FRAMES_BEFORE_COUNTDOWN := 10
var _frames_drawn := 0
## Over a network, the race's own part of it (see NetRace), and whether the
## host's said go.
var net: NetRace
var net_go := false
var _watch_in := 0.0
## The last number of the countdown that beeped.
var _beeped := 4
## Where each racer was in the order the last time the drivers looked.
var _places := {}


func _init(split_override: Variant = null) -> void:
	if split_override != null:
		split = split_override
		_split_set = true


func _ready() -> void:
	# The menu pauses a race whatever it's under (see open_menu).
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mode = Game.mode
	if not _split_set:
		split = Game.race_split()
	var people := 1 if split == Game.SOLO else 2
	track = TrackPath.load_file(Game.track_path)
	track_id = Tracks.id_of(Game.track_path)
	laps = 1000000 if mode == Game.MODE_PRACTICE else track.laps
	difficulty = Game.grand_prix.difficulty if mode == Game.MODE_GRAND_PRIX and Game.grand_prix != null else Game.difficulty()
	add_child(TrackBuilder.new(track))

	if Game.net.is_online() and not Game.net.setup.is_empty():
		_ready_online()
		return

	# Everyone who's racing, front of the grid first. The AI starts at the
	# front and the people at the back, player 1 last of all. Time trials
	# and practice are just you.
	var entries := []
	var solo := mode == Game.MODE_TIME_TRIAL or mode == Game.MODE_PRACTICE
	if not solo:
		# Each AI driver has a stock kart, drawn at random for this race, or
		# for the whole cup in a Grand Prix.
		var drivers := Game.ai_driver_keys()
		var karts := Game.draw_karts(drivers, [Game.player_two_kart()] if people > 1 else [])
		# And a pecking order, so a different driver's the quickest each time.
		var ranks := Game.draw_ranks(drivers)
		if mode == Game.MODE_GRAND_PRIX and Game.grand_prix != null and not Game.grand_prix.karts.is_empty():
			karts = Game.grand_prix.karts
			ranks = Game.grand_prix.ranks
		# Player 2 takes the last driver's place, in the kart they picked.
		var two_driver: String = drivers.pop_back() if people > 1 else ""
		drivers.resize(mini(drivers.size(), KARTS - people))
		for i in drivers.size():
			var who := Game.roster_driver(drivers[i])
			var design := Game.stock_kart(karts.get(drivers[i], "starter"))
			entries.append({ "name": who.name, "design": design, "who": who, "rank": ranks.get(drivers[i], i), "line": (i % 3 - 1) * 1.5 })
		if people > 1:
			entries.append({ "name": "Player 2", "design": Game.stock_kart(Game.player_two_kart()), "who": Game.roster_driver(two_driver), "human": 1 })
	entries.append({ "name": Game.player_name(), "design": Game.chosen_design(), "who": Game.character, "human": 0 })
	# After the first race of a Grand Prix, the grid goes by the points so far.
	if mode == Game.MODE_GRAND_PRIX and Game.grand_prix != null and Game.grand_prix.round > 0:
		var order: Array = Game.grand_prix.grid_order()
		entries.sort_custom(func(a, b) -> bool:
			var ia := order.find(a.name)
			var ib := order.find(b.name)
			return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))

	for slot in entries.size():
		var entry: Dictionary = entries[slot]
		var racer := _add_racer(entry.name, entry.design, slot, entry.who)
		if entry.has("human"):
			racer.player = true
			if entry.human == 0:
				player = racer
			continue
		racer.ai = AIDriver.new()
		racer.ai.kart = racer.kart
		racer.ai.track = track
		Difficulty.apply(racer.ai, difficulty, entry.rank, Game.ai_driver_keys().size())
		racer.ai.line = entry.line
		racer.kart.controls = racer.ai.controls
		add_child(racer.ai)
	humans.append(player)
	player.kart.sound.wind = true
	for racer in racers:
		if racer.player and racer != player:
			humans.append(racer)
			racer.kart.sound.wind = true

	_finish_setting_up(people)


## Everything after the grid's filled: the AI's view of the other karts,
## the power-up boxes, and each person's view.
func _finish_setting_up(people: int) -> void:
	var karts: Array[Kart] = []
	for racer in racers:
		karts.append(racer.kart)
	for racer in racers:
		if racer.ai != null:
			racer.ai.others = karts
		racer.kart.gadget_used.connect(func(kind: String) -> void:
			if kind == "lightning":
				strike_from(racer.kart))

	# Time trials are just driving, with no power-ups to pick up.
	if mode != Game.MODE_TIME_TRIAL:
		boxes = PowerupField.new(track)
		boxes.race = self
		for human in humans:
			boxes.viewers.append(human.kart)
		add_child(boxes)

	# A dedicated server has nobody of its own to show the race to.
	if player == null:
		return
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


## A race over the network, set up from the host's list of who's in it
## (see NetSession). Everyone's karts are made the same way on every device.
## Ours are driven here, the host drives the AI, and the rest are remote
## karts that follow their updates (see NetRace).
func _ready_online() -> void:
	var setup: Dictionary = Game.net.setup
	laps = int(setup.laps)
	difficulty = setup.difficulty
	net = NetRace.new(self, Game.net)
	var me := Game.net.my_id()
	var mine: Array[Racer] = []
	var entries: Array = setup.entries
	for slot in entries.size():
		var entry: Dictionary = entries[slot]
		var racer := _add_racer(entry.name, KartDesign.from_dict(entry.kart), slot, CharacterDesign.from_dict(entry.driver))
		var owner := int(entry.owner)
		if entry.get("human", false) and owner == me:
			racer.player = true
			racer.set_meta("local", int(entry.local))
			mine.append(racer)
		elif entry.get("ai", false) and owner == me:
			racer.ai = AIDriver.new()
			racer.ai.kart = racer.kart
			racer.ai.track = track
			Difficulty.apply(racer.ai, difficulty, int(entry.rank), Game.ai_driver_keys().size())
			racer.ai.line = float(entry.line)
			racer.kart.controls = racer.ai.controls
			add_child(racer.ai)
		net.add(slot, racer, owner)
	mine.sort_custom(func(a, b) -> bool: return a.get_meta("local") < b.get_meta("local"))
	for racer in mine:
		humans.append(racer)
		racer.kart.sound.wind = true
	player = humans[0] if not humans.is_empty() else null
	split = Game.split() if humans.size() >= 2 else Game.SOLO
	add_child(net)
	_finish_setting_up(maxi(humans.size(), 1))


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

	var view := RaceCamera.new()
	view.target = racer.kart
	view.track = track
	view.input = input
	# Your own head is on a layer of its own, so your first person view can
	# leave it out while everyone else still sees it.
	view.head_layer = RaceCamera.head_layer_of(index)
	racer.kart.head_layer = view.head_layer
	view.view = Game.camera_view(index)
	view.view_changed.connect(func(which: String) -> void:
		Game.set_camera_view(index, which)
		racer.hud.flash(RaceCamera.NAMES[which]))
	if humans.size() > 1:
		# Leave out the other players' power-up boxes.
		for other in humans.size():
			if other != index:
				view.set_cull_mask_value(PowerupField.layer_of(other), false)
	world_parent.add_child(view)
	view.make_current()
	view.snap()
	racer.camera = view

	var racer_hud := RaceHud.new()
	racer_hud.race = self
	racer_hud.me = racer
	racer_hud.person = index
	layer.add_child(racer_hud)
	var touch := TouchControls.new()
	touch.visible = DisplayServer.is_touchscreen_available()
	# Lower down in a split screen half, where there's less room.
	touch.height = TouchControls.HEIGHT if humans.size() == 1 else TouchControls.HEIGHT_SPLIT
	touch.steering = Game.steering(index)
	touch.blockers.append_array(racer_hud.buttons())
	racer_hud.add_child(touch)
	racer_hud.touch = touch
	input.touch = touch
	racer.hud = racer_hud
	racer_hud.again_pressed.connect(func() -> void: Game.show_race())
	racer_hud.garage_pressed.connect(Game.show_garage)
	racer_hud.menu_pressed.connect(leave)
	racer_hud.next_pressed.connect(func() -> void:
		Game.finish_grand_prix_race(standings().map(func(r): return r.name)))
	racer_hud.courses_pressed.connect(func() -> void: Game.show_tracks(mode))
	racer_hud.camera_pressed.connect(input.press_view)
	racer_hud.pause_pressed.connect(open_menu.bind(racer))
	input.menu_pressed.connect(open_menu.bind(racer))


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
	racer.progress = RaceProgress.new(track.length, laps, racer.offset)
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
	# Over the network the countdown waits for the host, once everyone's
	# loaded.
	if net != null and not net_go:
		return
	time += delta
	# A beep for each number of the countdown, and a higher one for GO.
	if not started and ceili(-time) < _beeped and ceili(-time) >= 1:
		_beeped = ceili(-time)
		Sounds.play("fx/beep")
	if not started and time >= 0.0:
		Sounds.play("fx/go")
		started = true
		for racer in racers:
			racer.kart.locked = false

	for racer in racers:
		var kart := racer.kart
		racer.offset = track.offset_of(kart.global_position, racer.offset, 40.0)
		if racer.ai != null:
			racer.ai.offset = racer.offset
		if started:
			if boxes != null and not kart.remote:
				boxes.collect(kart)
			var was_done := racer.progress.finished
			var was_lap := racer.progress.current_lap()
			racer.progress.update(racer.offset, time)
			if racer.player and not racer.progress.finished and racer.progress.current_lap() > was_lap:
				Sounds.play("fx/final_lap" if racer.progress.current_lap() == laps else "fx/lap")
			if racer.progress.finished and not was_done:
				if racer.player:
					Sounds.play("fx/win" if place_of(racer) == 1 and mode != Game.MODE_TIME_TRIAL else "fx/finish")
				# The winner cheers and everyone else is happy to be done.
				if place_of(racer) == 1:
					racer.kart.cheer()
				else:
					racer.kart.react("happy", 3.0)
				if racer.player:
					_player_finished(racer)

		# If it's fallen off or wandered far away, put it back.
		var middle := track.point_at(racer.offset)
		var below := (kart.global_position - middle).dot(track.up_at(racer.offset))
		if kart.slowdown_left <= 0.0 and (below < -FALLEN or kart.global_position.distance_to(middle) > LOST):
			if OS.has_environment("RACE_DEBUG"):
				print("OFF %s at %.0f m: below %.1f, away %.1f, height %.1f" % [racer.name, racer.offset, below, kart.global_position.distance_to(middle), kart.global_position.y])
			kart.request_reset()
			if racer.hud != null:
				racer.hud.flash("Back on the track")

	if started:
		_watch_the_drivers(delta)

	# How far each AI driver is behind the leading person, for catching up
	# and easing off.
	if started and not humans.is_empty():
		var lead: float = humans.map(func(h): return h.progress.distance()).max()
		for racer in racers:
			if racer.ai != null and not racer.player:
				racer.ai.behind = lead - racer.progress.distance()


## Somewhere on the track near this racer with no other kart in the way, so
## a reset never drops one kart on top of another. It tries across the road
## first, then a little further back.
func _clear_spot(racer: Racer) -> Transform3D:
	var room := 3.5
	var across := [0.0, -3.0, 3.0, -4.5, 4.5]
	# A kart is never put back on a loop or a wall ride. It goes back to where
	# the road lies flat before it, then RUN_UP further, so it has the speed
	# for another go.
	var start := racer.offset
	var backed := false
	for step in 80:
		if track.up_at(start).y > 0.95 and not _loop_coming(start):
			break
		start -= 2.0
		backed = true
	if backed:
		start -= RUN_UP
	racer.kart.run_up_reset = backed
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
				# The kart's been moved, so the race has to know where it is
				# now, or it looks for it where it was and resets it again.
				racer.offset = fposmod(start - back, track.length)
				return spot
	racer.offset = fposmod(start, track.length)
	return track.place_at(start)


## Whether this is the flat run in to a loop, or its foot where it's only
## starting to climb. A kart put back there has no speed for the loop.
func _loop_coming(offset: float) -> bool:
	if not TrackPiece.turns_over(track.piece_type_at(offset)):
		return false
	var ahead := 0.0
	while ahead <= LOOP_FOOT:
		if track.up_at(offset + ahead).y <= 0.95:
			return true
		ahead += 2.0
	return false


## Once you're over the line the AI takes your kart home, so it doesn't just
## stop in everyone's way.
func _player_finished(racer: Racer) -> void:
	if mode == Game.MODE_TIME_TRIAL:
		var best_lap: float = racer.progress.lap_times.min() if not racer.progress.lap_times.is_empty() else 0.0
		new_records = Records.add_time(track_id, racer.progress.finish_time, best_lap)
	if racer.hud != null:
		racer.hud.show_results()
	if racer.camera != null:
		racer.camera.finish()
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


## Every so often, drivers who've just passed someone look happy about it
## and the ones passed look cross, and everyone looks at any kart close
## beside them. It's all just for show.
func _watch_the_drivers(delta: float) -> void:
	_watch_in -= delta
	if _watch_in > 0.0:
		return
	_watch_in = WATCH_EVERY
	var order := standings()
	for i in order.size():
		var racer: Racer = order[i]
		var was: int = _places.get(racer, i)
		_places[racer] = i
		if time > 3.0 and not racer.progress.finished:
			if i < was:
				racer.kart.react("happy", 1.5)
			elif i > was:
				racer.kart.react("cross", 1.2)
	for racer in racers:
		var nearest: Kart = null
		var best := ALONGSIDE
		for other in racers:
			if other == racer:
				continue
			var gap: float = racer.kart.global_position.distance_to(other.kart.global_position)
			if gap < best:
				best = gap
				nearest = other.kart
		racer.kart.alongside = nearest


## Lightning from this kart slows every kart ahead of it that's driven here.
## Over a network each device does the same for its own karts, when it hears
## the kart used it (see NetRace).
func strike_from(kart: Kart) -> void:
	var order := standings()
	for racer in order:
		if racer.kart == kart:
			break
		if not racer.kart.remote:
			racer.kart.zap()


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


## Back to the menu this race was started from.
func leave() -> void:
	if Game.net.is_online():
		Game.net.leave()
		Game.show_multiplayer()
		return
	if Game.came_from_editor:
		Game.show_track_editor()
		return
	match mode:
		Game.MODE_GRAND_PRIX:
			Game.grand_prix = null
			Game.show_cups()
		Game.MODE_TIME_TRIAL, Game.MODE_PRACTICE:
			Game.show_tracks(mode)
		_:
			if Game.racing_alone:
				Game.show_tracks(Game.MODE_RACE, true)
			elif split == Game.SOLO:
				Game.show_menu()
			else:
				Game.show_multiplayer()


## Esc and Back open the menu, or close it again, or once you've finished
## leave.
func go_back() -> void:
	if not _menus.is_empty():
		for racer in _menus.keys():
			close_menu(racer)
		return
	if humans.is_empty() or humans.all(func(r: Racer) -> bool: return r.progress.finished):
		leave()
		return
	open_menu(humans[0])


## Opens this player's menu over their view. In a single player race that
## pauses everything.
func open_menu(racer: Racer) -> void:
	if _menus.has(racer) or racer.hud == null or racer.progress.finished:
		return
	var menu := RaceMenu.new()
	menu.race = self
	menu.racer = racer
	menu.person = humans.find(racer)
	menu.pauses = _can_pause()
	menu.can_restart = mode != Game.MODE_GRAND_PRIX and not Game.net.is_online()
	menu.resume_pressed.connect(close_menu.bind(racer))
	menu.restart_pressed.connect(func() -> void:
		get_tree().paused = false
		Game.show_race())
	menu.quit_pressed.connect(func() -> void:
		get_tree().paused = false
		leave())
	racer.hud.add_child(menu)
	_menus[racer] = menu
	_update_pause()


func close_menu(racer: Racer) -> void:
	if not _menus.has(racer):
		return
	_menus[racer].queue_free()
	_menus.erase(racer)
	_update_pause()


func menu_open(racer: Racer) -> bool:
	return _menus.has(racer)


## Only a single player race on this device pauses. With someone else
## playing, here or online, it carries on.
func _can_pause() -> bool:
	return humans.size() == 1 and not Game.net.is_online()


func _update_pause() -> void:
	if is_inside_tree():
		get_tree().paused = _can_pause() and not _menus.is_empty()


func _exit_tree() -> void:
	get_tree().paused = false


## Going off to another app pauses a single player race, with the menu open.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and _can_pause() and started and not humans.is_empty():
		open_menu(humans[0])
