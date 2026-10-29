class_name SplashScreen
extends Control

## The loading screen when the game starts.
##
## The phone compiles each shader the first time something needs it, which can
## freeze the screen for seconds, and Godot's renderer for older phones can't
## do it ahead of time. So hidden under the splash this sets up a race, then
## the garage, then the driver builder, and lets each one draw for a few
## frames. That covers the road, grass, walls, pillars, karts with drivers, a
## part knocked loose, a ghost, a cannonball, tire smoke and boost flames, a
## shockwave, lightning, a shield, a cup's podium with its lamp, trophies
## and confetti, and the garage's see-through and picked out parts, all with the sun and
## shadows. The race is a storm at night and then snow by day, losing its fog
## halfway, so fog, clear skies, rain, snow, puddles, lamps and kart lights are
## all drawn too.
## Godot keeps what it compiled, so after the first launch this is quick.
##
## It has to draw on the real screen, which uses different versions of the same
## shaders than views off the screen do.
##
## Last it opens the cup screen, so its course layouts get drawn into
## pictures (see CourseOutlineView) and opening it later is quick.
##
## Meanwhile it works out the layouts of the game's courses for the cup screen
## (see CourseOutline), a few each frame. The first launch builds every course
## to do it, and after that they're saved.

## How many frames each scene is drawn for. The first one does the compiling,
## and the rest catch anything that only turns up once things have moved.
const WARM_FRAMES := 6
## Never flash the splash up for less than this, even when it's all cached.
const AT_LEAST := 0.8
## The frame the snowy race loses its fog on (see _clear_up()).
const CLEAR_AT := 3
## The most frames the cup screen's given to draw its course layouts.
const CUPS_FRAMES := 90

var _stages: Array[Callable] = []
var _stage_count := 1
var _scene: Node
var _frames := 0
var _shown := 0.0
var _began := 0
var _started := false
var _done := false
## The courses whose layouts are still to get ready.
var _outlines: Array = []
var _outlines_took := 0
## The race that loses its fog halfway (see _clear_up()).
var _clear_later: Race
var _bar: ProgressBar
var _status: Label


func _ready() -> void:
	# The splash sits on a layer above everything, so the scenes being warmed
	# up underneath (HUDs and all) never show.
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var cover := Control.new()
	layer.add_child(cover)
	var column := MenuStyle.screen(cover)
	column.add_child(MenuStyle.title())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 36.0)
	column.add_child(gap)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0.0, 8.0)
	column.add_child(_bar)

	_status = Label.new()
	_status.text = "Getting the bricks ready"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.theme_type_variation = "NoteLabel"
	column.add_child(_status)

	_stages = [_warm_race.bind("storm", "night"), _warm_race.bind("snow", "day"), _warm_garage, _warm_driver, _warm_cups]
	_stage_count = _stages.size()
	for cup in GrandPrix.cups():
		for id in cup.tracks:
			_outlines.append(Tracks.path_of(id))
		Game.trophy_pictures().take(cup.get("trophy", {}), Color(cup.get("colour", "#a3a2a4")), TrophyModel.finish_for(CupGrid.best_place(cup.id)))
	_began = Time.get_ticks_msec()
	# The race and the rest are only here to get things ready, so nobody should
	# hear them.
	Sounds.hushed = true
	# Let the splash itself get on screen first, so there's something to look
	# at while the sounds load and the first warm up frames stall. On the web
	# the page's own loading screen stays up until then.
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.snapracersShown && window.snapracersShown()")
	Sounds.load_all()
	_started = true
	_next_stage()


func _warm_race(weather: String, time: String) -> Node:
	# Split screen draws with the same shaders, so one player will do.
	var race := Race.new(Game.SOLO)
	race.conditions = Conditions.resolve("orchard", weather, time, 1)
	add_child(race)
	# Knock a part off so a loose piece gets drawn too.
	var kart := race.player.kart
	var last: Array[int] = [kart.design.parts.size() - 1]
	kart.lose_parts(last)
	# Not every kart has lights, so a lamp and the light it throws go on this
	# one, where the camera sees them.
	var lens := MeshInstance3D.new()
	lens.mesh = BoxMesh.new()
	lens.mesh.size = Vector3.ONE * 0.2
	lens.material_override = KartMesh.material("lamp")
	lens.position = Vector3(0.0, 1.2, 1.0)
	kart.add_child(lens)
	kart.add_child(HeadlightPool.new(0.0, 0.0))
	# A ghost's see-through copies, and a cannonball with its flash and smoke.
	kart.start_ghost()
	race.add_child(BrickShot.fire(kart))
	# Tire smoke and a boost's glow behind it.
	kart.fx.show_sample()
	_gadget_glows(race)
	_podium_sample(race)
	if weather == "snow":
		# A snow drift, with its own see-through shader, just ahead.
		var drift := Drifts.sample(Vector3(3.0, 0.4, 4.0))
		drift.position = Vector3(0.0, -0.3, -5.0)
		drift.rotation.y = PI
		kart.add_child(drift)
		_clear_later = race
	# A puddle, with its own shaders, just ahead and off to the side, in
	# both races so it's warmed with fog on and off.
	var puddle := Puddles.water_sample(1.5)
	puddle.position = Vector3(2.5, -0.3, -5.0)
	kart.add_child(puddle)
	return race


## A shockwave's burst, a lightning strike and a shield bubble on the
## player's kart, each with its own see-through glow and the first two with
## a light. A light in range needs its own version of every shader it falls
## on, so these go off again once the fog is gone (see _process()).
func _gadget_glows(race: Race) -> void:
	var kart := race.player.kart
	var ring := ShockRing.new()
	race.add_child(ring)
	ring.global_position = kart.global_position + Vector3.UP * 0.3
	kart._show_zap()
	kart.shield_left = Kart.SHIELD_TIME
	kart._show_bubble()


## A podium in front of the camera as it is once the show's over, with the
## trophy held up, confetti coming down, a place tag and its lamp on, and a
## trophy in each finish beside it. Its own camera stays off.
func _podium_sample(race: Race) -> void:
	var view := get_viewport().get_camera_3d()
	if view == null:
		return
	var everyone := race.racers.slice(0, 4).map(func(r: Race.Racer) -> Array: return [r.name, r.kart.design, r.kart.driver if r.kart.driver != null else Kart.default_driver()])
	var at := view.global_position - view.global_basis.z * 10.0
	at.y = race.player.kart.global_position.y
	var cup: Dictionary = GrandPrix.cups()[0]
	var podium := Podium.new(everyone, Podium.colour_of(cup), [at, Podium._turns_toward(view.global_position - at), false])
	podium.lit = true
	if everyone.size() > 3:
		podium.players = { everyone[3][0]: UiKit.ACCENT }
	podium.trophy_spec = cup.get("trophy", {})
	race.add_child(podium)
	podium.finish()
	view.make_current()
	for i in TrophyModel.FINISHES.size():
		var trophy := TrophyModel.make(podium.trophy_spec, podium.trophy_colour, TrophyModel.FINISHES[i])
		trophy.scale = Vector3.ONE * 0.3
		race.add_child(trophy)
		trophy.global_position = at + view.global_basis.x * (i - 1.5) * 0.6 + Vector3.UP * 1.0


## Halfway through the snow, the fog goes, so clear weather is covered too,
## and the lights go off again in it.
func _clear_up(race: Race) -> void:
	for found in race.find_children("*", "WorldEnvironment", true, false):
		(found as WorldEnvironment).environment.fog_enabled = false
	race.add_child(BrickShot.fire(race.player.kart))
	_gadget_glows(race)


func _warm_garage() -> Node:
	var garage := Garage.new()
	add_child(garage)
	# Pick one part out (highlighted) and hold another (the see through ghost).
	garage.select(0)
	garage.start_placing("brick_2x2")
	return garage


func _warm_driver() -> Node:
	var builder := DriverBuilder.new()
	add_child(builder)
	return builder


## The cup screen, on a layer of its own so it fills the screen as it would.
func _warm_cups() -> Node:
	var layer := CanvasLayer.new()
	layer.set_meta("cups", true)
	var grid := CupGrid.new(Game.MODE_GRAND_PRIX)
	layer.add_child(grid)
	add_child(layer)
	# Only for looking at: it can't be picked out with a controller or tapped.
	for control: Control in grid.find_children("*", "Control", true, false) + [grid]:
		control.focus_mode = Control.FOCUS_NONE
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and grid.is_ancestor_of(focused):
		focused.release_focus()
	return layer


## Gets course layouts ready for up to a few milliseconds, and at least one.
func _outline_some() -> void:
	var from := Time.get_ticks_msec()
	while not _outlines.is_empty():
		CourseOutline.of(_outlines.pop_front())
		if Time.get_ticks_msec() - from > 6:
			break
	_outlines_took += Time.get_ticks_msec() - from


func _next_stage() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	_frames = 0
	if not _stages.is_empty():
		var stage: Callable = _stages.pop_front()
		_scene = stage.call()


func _process(delta: float) -> void:
	_shown += delta
	if not _started or _done:
		return
	_frames += 1
	_outline_some()
	var stages_total := float(_stage_count)
	var finished := stages_total - _stages.size() - (1 if _scene != null else 0)
	# The cup screen can take longer than WARM_FRAMES, so its share fills
	# more and more slowly instead.
	var part := minf(float(_frames) / WARM_FRAMES, 1.0)
	if _scene != null and _scene.has_meta("cups"):
		part = 1.0 - pow(0.5, float(_frames) / WARM_FRAMES)
	_bar.value = clampf((finished + part) / stages_total, 0.0, 1.0) * 100.0
	if _clear_later != null and _scene == _clear_later and _frames == CLEAR_AT:
		_clear_up(_clear_later)
		_clear_later = null
	if _scene != null and _frames >= WARM_FRAMES and not _drawing_cups():
		_next_stage()
	elif _scene == null and _shown >= AT_LEAST and _outlines.is_empty():
		_done = true
		print("Warm-up took %d ms, with %d ms of course layouts" % [Time.get_ticks_msec() - _began, _outlines_took])
		Sounds.hushed = false
		Game.show_menu()


## Whether the cup screen's still drawing its pictures, for up to
## CUPS_FRAMES frames.
func _drawing_cups() -> bool:
	return _scene.has_meta("cups") and _frames < CUPS_FRAMES and CourseOutlineView.busy()


func go_back() -> void:
	pass # nothing to go back to yet
