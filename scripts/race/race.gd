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
## How tall the game's screen is meant to be, in its own units. A split
## screen half much bigger than that (face to face, on a phone held upright)
## draws its buttons and words bigger to match.
const HUD_HEIGHT := 720.0
## How big the map between two players' halves is, and how far down the
## line its middle is side by side. Face to face it's twice as big, since a
## phone held upright shows everything smaller.
const SHARED_MAP := 250.0
const SHARED_MAP_DOWN := 0.42
const COUNTDOWN := 3.0
## If you're further below the road than this, you've fallen off.
const FALLEN := 4.0
## If you're further from the middle of the road than this, you're lost.
const LOST := 45.0
## How far before a loop or wall ride a reset puts you, so you can build up
## speed.
const RUN_UP := 110.0
## On a sky course, how far below the road a kart has to be, and how close to
## a jump's gap, to be put back past the gap (see _fell_in_gap()).
const GAP_BELOW := 2.0
const GAP_REACH := 12.0
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
	## Whether this entrant is CPU-controlled, including on another online host.
	var cpu := false
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
## The map on the line between the halves in split screen, which sits over
## both halves' menus and so goes while one's open.
var _shared_map: CourseMap
## The physics frame a menu last closed on.
var _closed_at := -100
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
## The weather and time of day, the same all race (see Conditions). Set it
## before the race starts to choose them, like the splash does.
var conditions: Conditions
## The course as built, with its sky and sun.
var builder: TrackBuilder
## The course's id, for records.
var track_id := ""
## After a time trial, whether you set a new best time and a new best lap.
var new_records := [false, false]
## Seconds since the start. It counts up from minus the countdown.
var time := -COUNTDOWN
## The trains' clock, which online follows the host's.
var train_clock := TrainClock.new(-COUNTDOWN)
## How far the puddles or snow drifts have built up, from 0 to 1, in whole
## Puddles.STEPs (see Puddles.grow()). It goes by how far the leader's got
## through the race and never goes back. Online every device takes the
## host's.
var build_up := 0.0
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
## The layer the views and HUDs are on.
var _views: CanvasLayer
## At the end of a Grand Prix, the podium, once it's up (see show_podium()).
var podium: Podium
## The cup's standings over the podium, once it's done.
var cup_standings: GrandPrixStandings


func _init(split_override: Variant = null) -> void:
	if split_override != null:
		split = split_override
		_split_set = true


func _ready() -> void:
	# The menu pauses a race whatever it's under (see open_menu).
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var keys := MenuKeys.new()
	keys.race = self
	add_child(keys)
	mode = Game.mode
	if not _split_set:
		split = Game.race_split()
	var people := 1 if split == Game.SOLO else 2
	track = TrackPath.load_file(Game.track_path)
	track_id = Tracks.id_of(Game.track_path)
	laps = 1000000 if mode == Game.MODE_PRACTICE else track.laps
	difficulty = Game.grand_prix.difficulty if mode == Game.MODE_GRAND_PRIX and Game.grand_prix != null else Game.difficulty()
	if conditions == null:
		conditions = _conditions()
	builder = TrackBuilder.new(track, conditions)
	add_child(builder)

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
			var design := Game.stock_kart(karts.get(drivers[i], Game.DEFAULT_STOCK))
			entries.append({ "name": who.name, "design": design, "who": who, "rank": ranks.get(drivers[i], i), "line": (i % 3 - 1) * 1.5 })
		if people > 1:
			entries.append({ "name": Game.player_two_name(), "design": Game.player_two_design(), "who": Game.roster_driver(two_driver), "human": 1 })
	entries.append({ "name": Game.player_one_name() if people > 1 else Game.player_name(), "design": Game.chosen_design(), "who": Game.character, "human": 0 })
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
			racer.kart.hears_warnings = true
			if entry.human == 0:
				player = racer
			continue
		racer.cpu = true
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
	if Game.controllers != null:
		Game.controllers.unplugged.connect(_on_unplugged)
	var karts: Array[Kart] = []
	for racer in racers:
		karts.append(racer.kart)
	if builder.drifts != null:
		builder.drifts.karts = karts
	for racer in racers:
		if racer.ai != null:
			racer.ai.others = karts
			racer.ai.crossings = builder.crossings
		racer.kart.gadget_used.connect(func(kind: String) -> void:
			if kind == "lightning":
				strike_from(racer.kart)
			elif kind == "shockwave":
				shockwave_from(racer.kart))
	# The trains run on the race clock. In a time trial they keep the same
	# timetable every time, so records stay fair.
	for crossing in builder.crossings:
		crossing.own_clock = false
		crossing.time = train_clock.now
		crossing.karts = karts
		if mode == Game.MODE_TIME_TRIAL:
			crossing.use_seed(0)

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
		_views = CanvasLayer.new()
		add_child(_views)
		_add_view(player, self, _views)
	else:
		_add_split_views()
	hud = player.hud
	camera = player.camera
	# A debug switch for testing on a device. If there's a file called
	# autopilot in the app's data folder, the AI drives your kart.
	if (OS.is_debug_build() and FileAccess.file_exists("user://autopilot")) or FileAccess.file_exists("user://perflog"):
		var driver := AIDriver.new()
		driver.kart = player.kart
		driver.track = track
		driver.others.assign(karts)
		driver.crossings = builder.crossings
		add_child(driver)
		player.ai = driver
		player.kart.controls = driver.controls


## A race over the network, set up from the host's list of who's in it
## (see NetSession). Everyone's karts are made the same way on every device.
## Ours are driven here, the host drives the AI, and the rest are remote
## karts that follow their updates (see NetRace).
## The weather and time of day for this race. Online they come from the host.
## Otherwise it's the player's pick, then the course's, then chance, except
## a course that always has one time of day keeps it. A time
## trial left to chance is a clear day, so records stay fair.
func _conditions() -> Conditions:
	if Game.net.is_online() and Game.net.setup.has("conditions"):
		return Conditions.from_dict(Game.net.setup.conditions)
	var gp := mode == Game.MODE_GRAND_PRIX and Game.grand_prix != null
	var weather := Conditions.picked(Game.grand_prix.weather if gp else Game.weather(), track.weather)
	var fixed := Conditions.fixed_time(track.theme, track.time, track.fixed_time)
	var time := Conditions.picked(Game.grand_prix.time if gp else Game.time_of_day(), track.time, fixed)
	if mode == Game.MODE_TIME_TRIAL:
		weather = "clear" if weather == Conditions.RANDOM else weather
		time = "day" if time == Conditions.RANDOM else time
	var conditions := Conditions.resolve(track.theme, weather, time, randi())
	conditions.time_fixed = fixed != ""
	return conditions


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
		racer.cpu = bool(entry.get("ai", false))
		var owner := int(entry.owner)
		if entry.get("human", false) and owner == me:
			racer.player = true
			racer.kart.hears_warnings = true
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
	input.person = index
	if humans.size() == 1:
		input.any_joypad = true
		input.both_keys = true
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
	# In split screen it's in a half that keeps running while paused.
	view.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	touch.visible = TouchControls.shown_at_start()
	# Lower down in a split screen half, where there's less room.
	touch.height = TouchControls.height_for(Game.touch_height(), humans.size() > 1)
	touch.control_size = Game.touch_size()
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
		# Someone still racing is scored where they are now.
		if can_move_on():
			Game.finish_grand_prix_race(standings().map(func(r): return r.name)))
	racer_hud.courses_pressed.connect(func() -> void: Game.show_tracks(mode, Game.racing_alone, true))
	racer_hud.camera_pressed.connect(input.press_view)
	racer_hud.pause_pressed.connect(open_menu.bind(racer))
	input.menu_pressed.connect(func() -> void:
		# Start that just closed the menu is still down when the race carries on.
		if Engine.get_physics_frames() - _closed_at > 2:
			open_menu(racer))


## Two halves of the screen, each with its own SubViewport looking at this
## race. Side by side, player 1 is on the left. Face to face, player 1 has the
## bottom half and player 2 has the top, turned around to face the other way.
## One map sits on the line between them.
func _add_split_views() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_views = layer
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
		# A paused container passes no taps on, and the menus in here have to
		# work while the race is paused. The HUD inside still pauses.
		holder.process_mode = Node.PROCESS_MODE_ALWAYS
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
			var turn := func() -> void: holder.pivot_offset = holder.size * 0.5
			holder.resized.connect(turn)
			turn.call()
		var viewport := SubViewport.new()
		Graphics.apply_to(viewport)
		# A SubViewport doesn't listen for 3D sound unless told to, and with
		# the cameras in here none of the karts would be heard. Both halves
		# listen, so each player hears what's around their own kart.
		viewport.audio_listener_enable_3d = true
		holder.add_child(viewport)
		holder.resized.connect(_fit_hud.bind(viewport, humans[i]), CONNECT_DEFERRED)
		var hud_layer := CanvasLayer.new()
		hud_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
		viewport.add_child(hud_layer)
		_add_view(humans[i], viewport, hud_layer)
		# The screen may already be its final size, so resized won't come.
		_fit_hud.call_deferred(viewport, humans[i])
	_add_shared_map(root)


## A half that's much bigger than the game's screen draws its buttons and
## words bigger, so they're as big on the phone as they'd be side by side. The
## 3D isn't touched.
func _fit_hud(viewport: SubViewport, human: Racer) -> void:
	var size := Vector2(viewport.size)
	var grow := maxf(1.0, minf(size.x, size.y) / HUD_HEIGHT)
	viewport.size_2d_override_stretch = grow > 1.0
	viewport.size_2d_override = Vector2i((size / grow).round()) if grow > 1.0 else Vector2i.ZERO
	# Face to face, the shared map reaches into the top of each half, so
	# what's there moves down out of its way.
	if split == Game.FACE_TO_FACE and human.hud != null and human.hud.map != null:
		human.hud.make_room_for_map(human.hud.map.across * 0.5 / grow, human.hud.map.across / grow)


## The one map two players share, on the line between their halves, with
## each of them marked in their colour.
func _add_shared_map(root: Control) -> void:
	var map := CourseMap.new()
	map.track = track
	map.karts.assign(racers.map(func(r): return r.kart))
	map.cpu_karts.assign(racers.filter(func(r): return r.cpu).map(func(r): return r.kart))
	for i in humans.size():
		map.players.append([humans[i].kart, KartPicker.PLAYER_COLOURS[mini(i, KartPicker.PLAYER_COLOURS.size() - 1)]])
	map.across = SHARED_MAP * (2.0 if split == Game.FACE_TO_FACE else 1.0)
	map.mode = Game.map_view(0)
	root.add_child(map)
	_shared_map = map
	var place := func() -> void:
		var size := map.get_combined_minimum_size()
		var middle := Vector2(0.5, SHARED_MAP_DOWN if split == Game.SIDE_BY_SIDE else 0.5) * root.size
		map.position = middle - size * 0.5
		map.size = size
	root.resized.connect(place)
	map.minimum_size_changed.connect(place)
	place.call()
	for human in humans:
		human.hud.map = map
		map.changed.connect(func(mode: String) -> void:
			Game.set_map_view(0, mode)
			human.hud.flash(CourseMap.NAMES[mode]))


func _add_racer(racer_name: String, design: KartDesign, slot: int, who: CharacterDesign) -> Racer:
	var racer := Racer.new()
	racer.name = racer_name
	racer.kart = Kart.new()
	racer.kart.build(design, who)
	racer.kart.grid_slot = slot
	racer.kart.weather_grip = conditions.grip()
	racer.kart.weather_drag = conditions.drag()
	racer.kart.puddles = builder.puddles
	racer.kart.drifts = builder.drifts
	racer.kart.fx.snow_lies = conditions.snow() > 0.0
	racer.kart.lights_on = conditions.dark()
	racer.kart.beams = conditions.beams()
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
	# The perflog switch (see Game.show_menu()) logs how it's running.
	if started and Engine.get_process_frames() % 300 == 0 and FileAccess.file_exists("user://perflog"):
		print("PERF %s, %s, %s graphics: %.0f fps, %.1f ms process, %.1f ms physics, %.0f draws" % [track.name, conditions.describe(), Graphics.level, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
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
	if not builder.crossings.is_empty():
		train_clock.run(delta)
		for crossing in builder.crossings:
			crossing.time = train_clock.now
		for racer in racers:
			if racer.ai != null:
				racer.ai.clock = train_clock.now
	if podium != null:
		return
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
		racer.offset = track.offset_near(kart.global_position, racer.offset, 5.0, 40.0)
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
				# Finished, the autopilot drives and homing bricks stop beeping.
				kart.hears_warnings = false
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
				var truly := track.offset_of(kart.global_position)
				print("OFF %s at %.0f m: below %.1f, away %.1f, height %.1f, speed %.1f, really at %.0f m %.1f away" % [racer.name, racer.offset, below, kart.global_position.distance_to(middle), kart.global_position.y, kart.linear_velocity.length(), truly, kart.global_position.distance_to(track.point_at(truly))])
			kart.request_reset()
			if racer.hud != null:
				racer.hud.flash("Back on the track")

	if builder.puddles != null or builder.drifts != null:
		if net == null or net.session.is_host():
			build_up = maxf(build_up, Puddles.stepped(race_share()))
		if builder.puddles != null:
			builder.puddles.grow(build_up)
		if builder.drifts != null:
			builder.drifts.grow(build_up)

	if started:
		_watch_the_drivers(delta)

	# How far each AI driver is behind the leading person, for catching up
	# and easing off.
	if started and not humans.is_empty():
		var lead: float = humans.map(func(h): return h.progress.distance()).max()
		for racer in racers:
			if racer.ai != null and not racer.player:
				racer.ai.behind = lead - racer.progress.distance()


## How far through the race the leader is, from 0 to 1. Practice goes by
## the course's own number of laps.
func race_share() -> float:
	var lead := 0.0
	for racer in racers:
		lead = maxf(lead, racer.progress.distance())
	var whole := track.length * maxi(track.laps if mode == Game.MODE_PRACTICE else laps, 1)
	return clampf(lead / whole, 0.0, 1.0)


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
	var backs := [0.0, 5.0, 10.0, 15.0, 20.0]
	# Up in the sky there's nothing in a jump's gap to land on, and a kart put
	# back on the kicker with no speed only rolls in again. So one that's
	# fallen into the gap, or off just before it, goes on past the gap to the
	# landing instead, and looks further on for room.
	if not backed and _fell_in_gap(racer, start):
		var ahead := 0.0
		while track.solid_at(start + ahead) and ahead < GAP_REACH:
			ahead += 1.0
		while not track.solid_at(start + ahead) and ahead < 200.0:
			ahead += 1.0
		start += ahead + 6.0
		backs = [0.0, -5.0, -10.0, -15.0, -20.0]
	# Never onto the rails or between the barriers with a train coming.
	for crossing in builder.crossings:
		var to_rails := fposmod(crossing.offset - start + LevelCrossing.STOP_BACK, track.length)
		var t := train_clock.now
		if to_rails < LevelCrossing.STOP_BACK * 2.0 and (crossing.timetable.blocked(t, 4.0) or crossing.timetable.lights_on(t)):
			start = crossing.offset - LevelCrossing.STOP_BACK
			backs = [0.0, 5.0, 10.0, 15.0, 20.0]
	racer.kart.run_up_reset = backed
	for back in backs:
		for side in across:
			var spot := track.place_at(start - back)
			spot.origin += spot.basis.x * side
			var clear := not _by_a_wall(spot.origin)
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


## Whether this kart is on a course up in the sky, below the road at `at`,
## and over a jump's gap or just short of one.
func _fell_in_gap(racer: Racer, at: float) -> bool:
	if not Scenery.theme_named(track.theme).get("void", false):
		return false
	var below := (racer.kart.global_position - track.point_at(at)).dot(track.up_at(at))
	if below > -GAP_BELOW:
		return false
	var ahead := 0.0
	while ahead <= GAP_REACH:
		if not track.solid_at(at + ahead):
			return true
		ahead += 1.0
	return false


## Whether a brick wall still standing is here or just in front, so a kart
## put back here would be stuck against it again.
func _by_a_wall(at: Vector3) -> bool:
	for wall in get_tree().get_nodes_in_group("brick_walls"):
		var local: Vector3 = wall.global_transform.affine_inverse() * at
		if absf(local.x) < BrickWall.HALF + 1.5 and local.z > -2.0 and local.z < 8.0 and wall.standing():
			return true
	return false


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
		new_records = Records.add_time(track_id, racer.progress.finish_time, best_lap, conditions)
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
	driver.crossings = builder.crossings
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


## Lightning from this kart strikes every kart ahead of it. Each device
## slows the karts it drives and shows the bolt on all of them (see NetRace).
func strike_from(kart: Kart) -> void:
	var order := standings()
	for racer in order:
		if racer.kart == kart:
			break
		racer.kart.zap()


## A shockwave from this kart shoves every kart near it that's driven here
## away. Over a network each device does the same for its own karts, when it
## hears the kart used it (see NetRace). The burst shows everywhere.
func shockwave_from(kart: Kart) -> void:
	var ring := ShockRing.new()
	ring.reach = Kart.SHOCK_REACH
	add_child(ring)
	ring.global_position = kart.global_position + Vector3.UP * 0.3
	BrickPile.blast(get_tree(), kart.global_position, Kart.SHOCK_REACH, BrickPile.SHOCK_SPEED)
	for racer in racers:
		if racer.kart != kart and is_instance_valid(racer.kart) and not racer.kart.remote:
			racer.kart.shoved_from(kart.global_position)


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


## Clears the karts, the power-ups and everyone's view away and puts up the
## cup's podium by the start line, with everyone from `gp`'s standings in
## the karts and drivers they raced with. Its end brings up the standings
## over it (see show_standings()).
func show_podium(gp: GrandPrix) -> Podium:
	var raced := {}
	for racer in racers:
		raced[racer.name] = [racer.kart.design, racer.kart.driver if racer.kart.driver != null else Kart.default_driver()]
	# Online, someone who left during the cup is still in the standings, in
	# what they last raced with.
	for name in gp.designs:
		if not raced.has(name):
			raced[name] = [KartDesign.from_dict(gp.designs[name][0]), CharacterDesign.from_dict(gp.designs[name][1])]
	# Anyone else in the standings stands in a stock kart as the plain racer.
	var everyone := []
	for row in gp.standings():
		if not raced.has(row[0]):
			raced[row[0]] = [Game.stock_kart(Game.DEFAULT_STOCK), Kart.default_driver()]
		everyone.append([row[0]] + raced[row[0]])
	# The people playing here, in their colours from the standings.
	var playing := {}
	for i in humans.size():
		playing[humans[i].name] = UiKit.PLAYERS[mini(i, UiKit.PLAYERS.size() - 1)] if humans.size() > 1 else UiKit.ACCENT
	for racer in _menus.keys():
		close_menu(racer)
	for racer in racers:
		for node in [racer.ai, racer.input, racer.camera, racer.hud, racer.kart]:
			if node != null:
				node.queue_free()
	racers.clear()
	humans.clear()
	player = null
	# Online, nothing more is sent or taken in for the race.
	if net != null:
		net.queue_free()
		net = null
	hud = null
	camera = null
	_shared_map = null
	if _views != null:
		_views.queue_free()
	if boxes != null:
		boxes.queue_free()
		boxes = null
	if builder.drifts != null:
		builder.drifts.karts = []
	for crossing in builder.crossings:
		crossing.karts.clear()
	# Whatever was dropped or fired, and what fell off the karts.
	for child in get_children():
		if child is BrickWall or child is BrickTrap or child is BrickPile or child is BrickShot or child is TowRope or child is Debris:
			child.queue_free()
	podium = Podium.new(everyone, Podium.colour_of(gp.cup), Podium.find_spot(track, builder), builder.ground_at)
	podium.lit = conditions.beams()
	podium.players = playing
	# Your own cups' trophies are picked from their names, as on the cups page.
	var cup := gp.cup
	podium.trophy_spec = cup.get("trophy", TrophyModel.spec_for(str(cup.get("name", ""))))
	podium.trophy_colour = Color(str(cup.colour)) if cup.has("colour") else TrophyModel.colour_for(str(cup.get("name", "")))
	add_child(podium)
	podium.finished.connect(show_standings.bind(gp))
	return podium


## Puts `gp`'s standings over the podium, and the podium's camera holds still
## with the podium in the part they leave clear. Leaving them frees the race.
func show_standings(gp: GrandPrix) -> GrandPrixStandings:
	if cup_standings != null:
		return cup_standings
	var layer := CanvasLayer.new()
	layer.name = "Standings"
	layer.layer = 10
	add_child(layer)
	cup_standings = GrandPrixStandings.new(gp, true)
	layer.add_child(cup_standings)
	if podium != null:
		podium.settle(cup_standings.clear)
		cup_standings.laid_out.connect(func() -> void: podium.settle(cup_standings.clear))
	Sounds.music("menu")
	PadFocus.focus_first.call_deferred(cup_standings)
	return cup_standings


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
			var two: bool = Game.grand_prix != null and Game.grand_prix.two
			Game.grand_prix = null
			Game.show_cups(two)
		Game.MODE_TIME_TRIAL, Game.MODE_PRACTICE:
			Game.show_tracks(mode, false, true)
		_:
			if Game.racing_alone:
				Game.show_tracks(Game.MODE_RACE, true, true)
			elif split == Game.SOLO:
				Game.show_menu()
			else:
				Game.show_multiplayer()


## Esc and Back open the menu, or close it again, or once you've finished
## leave.
func go_back() -> void:
	if cup_standings != null:
		cup_standings.go_back()
		return
	if podium != null:
		podium.skip()
		return
	if not _menus.is_empty():
		for racer in _menus.keys():
			close_menu(racer)
		return
	if all_humans_home():
		leave()
		return
	_open_any()


## Whether every person on this device has finished.
func all_humans_home() -> bool:
	return humans.all(func(r: Racer) -> bool: return r.progress.finished)


## Whether the race can move on to the standings: once everyone here is
## home, or everyone in the race but one is, so a player a lap behind
## doesn't hold it up for long.
func can_move_on() -> bool:
	return all_humans_home() or racers.filter(func(r: Racer) -> bool: return r.progress.finished).size() >= racers.size() - 1


## Opens this player's menu over their view. Off the network that pauses
## everything, and in split screen the other player gets a menu in their half
## too, so either of you can carry on.
func open_menu(racer: Racer) -> void:
	if _menus.has(racer) or racer.hud == null or racer.progress.finished:
		return
	_add_menu(racer, true)
	if _can_pause():
		for other in humans:
			if other != racer:
				_add_menu(other, false)
	_update_pause()


func _add_menu(racer: Racer, opened: bool) -> void:
	if _menus.has(racer) or racer.hud == null or racer.progress.finished:
		return
	var menu := RaceMenu.new()
	menu.race = self
	menu.racer = racer
	menu.person = humans.find(racer)
	menu.pauses = _can_pause()
	menu.focus_on_open = opened
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


## Closes this player's menu, or while the race is paused, everyone's.
func close_menu(racer: Racer) -> void:
	if not _menus.has(racer):
		return
	for other in (_menus.keys() if _can_pause() else [racer]):
		_menus[other].queue_free()
		_menus.erase(other)
	_closed_at = Engine.get_physics_frames()
	_update_pause()


func menu_open(racer: Racer) -> bool:
	return _menus.has(racer)


## A race on this device pauses, with one person or two. Online it carries
## on, since the others are still racing.
func _can_pause() -> bool:
	return not Game.net.is_online()


func _update_pause() -> void:
	if _shared_map != null:
		_shared_map.visible = _menus.is_empty()
	if is_inside_tree():
		get_tree().paused = _can_pause() and not _menus.is_empty()


## Start or B on a player's controller closes their menu, or everyone's while
## paused. It's here rather than in the menu, since in split screen the menu's
## in a half that stops taking input while the race is paused.
func _menu_keys(event: InputEvent) -> void:
	if _menus.is_empty() or not (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_START, JOY_BUTTON_B]):
		return
	for racer in _menus.keys():
		if racer.input == null or racer.input.owns_joypad(event.device):
			get_viewport().set_input_as_handled()
			close_menu(racer)
			return
	# A finished player's controller can carry on a paused race too.
	if get_tree().paused and humans.any(func(r: Racer) -> bool: return r.input != null and r.input.owns_joypad(event.device)):
		get_viewport().set_input_as_handled()
		close_menu(_menus.keys()[0])


func _exit_tree() -> void:
	get_tree().paused = false


## A controller coming unplugged pauses the race with that player's menu
## open, and in split screen says so in their half.
func _on_unplugged(person: int) -> void:
	if not started or person >= humans.size() or humans[person].progress.finished:
		return
	if _can_pause():
		open_menu(humans[person])
	humans[person].hud.flash("Controller unplugged" if humans.size() == 1 else "Player %d's controller came unplugged" % (person + 1))


## Going off to another app pauses the race, with the menu open.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and _can_pause() and started:
		_open_any()


## Opens the menu of the first player still racing.
func _open_any() -> void:
	if podium != null:
		return
	for racer in humans:
		if not racer.progress.finished:
			open_menu(racer)
			return


## Passes the controller's Start and B to the race while it's paused.
class MenuKeys extends Node:
	var race: Race

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		race._menu_keys(event)
