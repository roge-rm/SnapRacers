class_name SplashScreen
extends Control

## The loading screen when the game starts.
##
## The phone compiles each shader the first time something needs it, which can
## freeze the screen for seconds, and Godot's renderer for older phones can't
## do it ahead of time. So hidden under the splash this sets up a race, then
## the garage, then the driver builder, and lets each one draw for a few
## frames. That covers the road, grass, walls, pillars, karts with drivers, a
## part knocked loose and the garage's see-through and picked out parts, all
## with the sun and shadows. Godot keeps what it compiled, so after the first
## launch this is quick.
##
## It has to draw on the real screen, which uses different versions of the same
## shaders than views off the screen do.

## How many frames each scene is drawn for. The first one does the compiling,
## and the rest catch anything that only turns up once things have moved.
const WARM_FRAMES := 6
## Never flash the splash up for less than this, even when it's all cached.
const AT_LEAST := 0.8

var _stages: Array[Callable] = []
var _scene: Node
var _frames := 0
var _shown := 0.0
var _began := 0
var _started := false
var _done := false
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
	var fill := StyleBoxFlat.new()
	fill.bg_color = MenuStyle.ACCENT
	fill.set_corner_radius_all(4)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	track.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", track)
	column.add_child(_bar)

	_status = Label.new()
	_status.text = "Getting the bricks ready"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	_status.add_theme_font_size_override("font_size", 18)
	column.add_child(_status)

	_stages = [_warm_race, _warm_garage, _warm_driver]
	_began = Time.get_ticks_msec()
	# The race and the rest are only here to get things ready, so nobody should
	# hear them. The sounds get loaded meanwhile.
	Sounds.hushed = true
	Sounds.load_all()
	# Let the splash itself get on screen first, so there's something to look
	# at while the first warm up frames stall.
	await get_tree().process_frame
	await get_tree().process_frame
	_started = true
	_next_stage()


func _warm_race() -> Node:
	# Split screen draws with the same shaders, so one player will do.
	var race := Race.new(Game.SOLO)
	add_child(race)
	# Knock a part off so a loose piece gets drawn too.
	var last: Array[int] = [race.player.kart.design.parts.size() - 1]
	race.player.kart.lose_parts(last)
	return race


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
	var stages_total := 3.0
	var finished := stages_total - _stages.size() - (1 if _scene != null else 0)
	_bar.value = clampf((finished + float(_frames) / WARM_FRAMES) / stages_total, 0.0, 1.0) * 100.0
	if _scene != null and _frames >= WARM_FRAMES:
		_next_stage()
	elif _scene == null and _shown >= AT_LEAST:
		_done = true
		print("Warm-up took %d ms" % (Time.get_ticks_msec() - _began))
		Sounds.hushed = false
		Game.show_menu()


func go_back() -> void:
	pass # nothing to go back to yet
