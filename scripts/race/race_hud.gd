class_name RaceHud
extends Control

## What you see during a race. Your place and lap are in the top left and the
## clock is in the middle, with the countdown, a message now and then, and the
## results once you've finished. In split screen each player has one of these
## in their half.
##
## Time trials and practice are just you, so they show your lap times instead
## of a place. The results offer what makes sense for the kind of race, like
## the next race of a Grand Prix or another go at a time trial.

signal again_pressed
signal garage_pressed
signal menu_pressed
## The menu button at the top, for the race's menu (see RaceMenu).
signal pause_pressed
## Moving on to the Grand Prix standings.
signal next_pressed
## Back to the course list, to pick another.
signal courses_pressed
## The camera button, to change the view.
signal camera_pressed

var race: Race
## Whose race this shows.
var me: Race.Racer
## Which person this is, 0 for player 1, for the settings they keep.
var person := 0
## The little map under your place and lap.
var map: CourseMap

var _place: Label
var _lap: Label
## The power-ups you're holding, for when there are no touch buttons to show them.
var _held: Label
var _clock: Label
var _big: Label
var _message: Label
var _message_left := 0.0
var _menu: IconButton
var _camera: IconButton
var _fps: Label
var _results: PanelContainer
var _results_title: Label
var _results_list: GridContainer
## The on-screen driving controls, hidden once you've finished.
var touch: Control


func _ready() -> void:
	theme = Game.theme
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Your place, lap and power-ups, together in the top left corner so they
	# can move out of a camera hole's way as one.
	var corner := VBoxContainer.new()
	corner.mouse_filter = MOUSE_FILTER_IGNORE
	corner.add_theme_constant_override("separation", -4)
	add_child(corner)
	corner.position = Vector2(24, 8)
	_place = _label(56)
	_lap = _label(28)
	_held = _label(28)
	_held.add_theme_color_override("font_color", Color("#f2cd37"))
	for label in [_place, _lap, _held]:
		label.reparent(corner)
	# With two on one phone they share one map between them (see Race).
	if race != null and me != null and race.humans.size() < 2:
		var gap := Control.new()
		gap.custom_minimum_size.y = 12.0
		corner.add_child(gap)
		map = CourseMap.new()
		map.track = race.track
		map.you = me.kart
		map.karts.assign(race.racers.map(func(r): return r.kart))
		map.mode = Game.map_view(person)
		map.changed.connect(func(mode: String) -> void:
			Game.set_map_view(person, mode)
			flash(CourseMap.NAMES[mode]))
		corner.add_child(map)

	_clock = _label(28)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_clock.offset_top = 76.0

	_big = _label(120)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_and_offsets_preset(PRESET_CENTER)
	_message = _label(36)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.set_anchors_and_offsets_preset(PRESET_CENTER)
	_message.offset_top = -140.0

	# The menu, with quit and the settings, at the top in the middle.
	_menu = IconButton.new("pause", "Menu")
	# The driving keys and buttons mustn't press the HUD's buttons.
	_menu.focus_mode = FOCUS_NONE
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_menu.offset_left = -IconButton.SIZE * 0.5
	_menu.offset_right = IconButton.SIZE * 0.5
	_menu.offset_top = 14.0
	_menu.offset_bottom = 14.0 + IconButton.SIZE
	_menu.pressed.connect(func() -> void: pause_pressed.emit())

	# The camera button, left of where the touch controls put reset.
	_camera = IconButton.new("camera", "Change the view")
	_camera.focus_mode = FOCUS_NONE
	add_child(_camera)
	_camera.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_camera.offset_left = -190.0
	_camera.offset_right = -190.0 + IconButton.SIZE
	_camera.offset_top = 16.0
	_camera.offset_bottom = 16.0 + IconButton.SIZE
	_camera.pressed.connect(func() -> void: camera_pressed.emit())
	# Face to face, the map two players share sits on the line between them,
	# right where the menu button would be, so the menu goes beside the
	# camera button.
	if race != null and race.humans.size() > 1 and race.split == Game.FACE_TO_FACE:
		_menu.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
		_menu.offset_left = -190.0 - IconButton.SIZE - 20.0
		_menu.offset_right = -190.0 - 20.0
		_menu.offset_top = 16.0
		_menu.offset_bottom = 16.0 + IconButton.SIZE

	_fps = _label(18)
	_fps.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_fps.offset_top = -30.0
	_fps.offset_left = 12.0

	_build_results()
	# Nothing hides under a camera hole.
	var safe := SafeArea.new()
	add_child(safe)
	for control in [corner, _clock, _menu, _camera, _fps]:
		safe.watch(control)


## What's on a gadget button, with how many goes are left when there's more
## than one, like "Triple turbo x3".
static func held_name(kart: Kart, slot: int) -> String:
	var name := Powerups.name_of(kart.held[slot])
	return name + (" x%d" % kart.held_uses[slot] if kart.held_uses[slot] > 1 else "")


func buttons() -> Array[Control]:
	return [_menu, _camera, _results, map] if map != null else [_menu, _camera, _results]


func _label(size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(6, size / 8))
	label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func flash(text: String) -> void:
	_message.text = text
	_message_left = 1.5


static func ordinal(n: int) -> String:
	var ending := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1:
				ending = "st"
			2:
				ending = "nd"
			3:
				ending = "rd"
	return "%d%s" % [n, ending]


static func clock(seconds: float) -> String:
	seconds = maxf(seconds, 0.0)
	return "%d:%05.2f" % [int(seconds / 60.0), fmod(seconds, 60.0)]


func _process(delta: float) -> void:
	if race == null or me == null:
		return
	_fps.visible = Game.show_fps()
	_fps.text = "%d fps" % Engine.get_frames_per_second()
	var practice := race.mode == Game.MODE_PRACTICE
	var trial := race.mode == Game.MODE_TIME_TRIAL
	if practice or trial:
		_place.text = "Practice" if practice else "Time trial"
	else:
		_place.text = "%s / %d" % [ordinal(race.place_of(me)), race.racers.size()]
	if practice:
		_lap.text = "Lap %d" % me.progress.current_lap()
	else:
		_lap.text = "Lap %d / %d" % [me.progress.current_lap(), race.laps]
	if me.progress.finished:
		_lap.text = "Finished"
	var names := []
	for slot in Powerups.HOLD:
		if me.kart.held[slot] != "":
			names.append(held_name(me.kart, slot))
	_held.visible = not trial and not names.is_empty()
	_held.text = "  ".join(names)
	if touch != null:
		for slot in Powerups.HOLD:
			touch.gadget_names[slot] = held_name(me.kart, slot).replace(" x", "\n") if me.kart.held[slot] != "" else ""
			touch.gadget_ready[slot] = me.kart.can_use(slot)
		touch.queue_redraw()
	var shown := me.progress.finish_time if me.progress.finished else race.time
	if practice:
		# The lap you're on, since the whole session could go on for ages.
		shown = race.time - me.progress.lap_started() if me.progress.laps >= 0 else 0.0
	var text := clock(shown)
	if not me.progress.lap_times.is_empty():
		text += "\nlast lap %s" % clock(me.progress.lap_times[-1])
	if (practice or trial) and me.progress.best_lap() > 0.0:
		text += "\nbest lap %s" % clock(me.progress.best_lap())
	if trial and Records.best_time(race.track_id) > 0.0 and not me.progress.finished:
		text += "\nrecord %s" % clock(Records.best_time(race.track_id))
	_clock.text = text

	# The countdown, then GO! for a moment.
	if race.time < 0.0:
		_big.text = str(ceili(-race.time))
		_big.modulate.a = 1.0
	elif race.time < 1.0:
		_big.text = "GO!"
		_big.modulate.a = 1.0 - race.time
	else:
		_big.text = ""

	var status := ""
	if me.kart.slowdown_left > 0.0:
		status = "Reset slowdown"
	elif not me.kart.lost.is_empty():
		var n := me.kart.lost.size()
		status = "%d part%s lost, reset to fix" % [n, "" if n == 1 else "s"]
	if _results.visible:
		status = ""
	if _message_left > 0.0:
		_message_left -= delta
		_message.modulate.a = clampf(_message_left / 0.4, 0.0, 1.0)
	else:
		_message.text = status
		_message.modulate.a = 0.8

	if _results.visible:
		_fill_results()


func _build_results() -> void:
	_results = PanelContainer.new()
	_results.visible = false
	add_child(_results)
	_results.set_anchors_and_offsets_preset(PRESET_CENTER)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_results.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_results_title = Label.new()
	_results_title.text = "Results"
	_results_title.add_theme_font_size_override("font_size", 32)
	box.add_child(_results_title)
	_results_list = GridContainer.new()
	_results_list.columns = 4 if race.mode == Game.MODE_GRAND_PRIX else (2 if race.mode == Game.MODE_TIME_TRIAL else 3)
	_results_list.add_theme_constant_override("h_separation", 28)
	box.add_child(_results_list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var choices := [["Race again", again_pressed], ["Garage", garage_pressed], ["Menu", menu_pressed]]
	match race.mode:
		Game.MODE_GRAND_PRIX:
			choices = [["Standings", next_pressed], ["Quit cup", menu_pressed]]
			if Game.grand_prix != null:
				_results_title.text = "Race %d of %d" % [Game.grand_prix.round + 1, Game.grand_prix.track_ids().size()]
		Game.MODE_TIME_TRIAL:
			choices = [["Try again", again_pressed], ["Other course", courses_pressed], ["Menu", menu_pressed]]
			_results_title.text = "Time trial"
	# Online, the host moves everyone on once everyone's home, so all you can
	# do here is leave.
	if race.net != null:
		choices = [["Leave", menu_pressed]]
		var next := Label.new()
		next.text = "The standings come up once everyone's home" if race.mode == Game.MODE_GRAND_PRIX else "Back to the lobby once everyone's home"
		next.add_theme_font_size_override("font_size", 18)
		next.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		box.add_child(next)
		box.move_child(next, box.get_child_count() - 2)
	for pair in choices:
		var button := Button.new()
		button.text = pair[0]
		button.custom_minimum_size = Vector2(160, 60)
		button.focus_mode = FOCUS_ALL
		var signal_to_send: Signal = pair[1]
		button.pressed.connect(func() -> void: signal_to_send.emit())
		row.add_child(button)


func show_results() -> void:
	_results.visible = true
	_menu.visible = false
	PadFocus.focus_first.call_deferred(_results)
	if touch != null:
		touch.visible = false
	_fill_results()
	_results.reset_size()
	_results.set_anchors_and_offsets_preset(PRESET_CENTER)


func _fill_results() -> void:
	var rows := []
	var highlight := []
	if race.mode == Game.MODE_TIME_TRIAL:
		var records: Array = race.new_records
		rows.append(["Time", clock(me.progress.finish_time) + ("  New record!" if records[0] else "")])
		rows.append(["Best lap", clock(me.progress.best_lap()) + ("  New record!" if records[1] else "")])
		for i in me.progress.lap_times.size():
			rows.append(["Lap %d" % (i + 1), clock(me.progress.lap_times[i])])
		rows.append(["Course record", clock(Records.best_time(race.track_id))])
		highlight = [records[0], records[1]]
	else:
		var standings := race.standings()
		for i in standings.size():
			var racer: Race.Racer = standings[i]
			var when := clock(racer.progress.finish_time) if racer.progress.finished else "racing"
			var row := [ordinal(i + 1), racer.name, when]
			if race.mode == Game.MODE_GRAND_PRIX:
				row.append("+%d" % (GrandPrix.POINTS[i] if i < GrandPrix.POINTS.size() else 0))
			rows.append(row)
			highlight.append(racer.player)
	var columns := _results_list.columns
	while _results_list.get_child_count() < rows.size() * columns:
		_results_list.add_child(Label.new())
	for i in rows.size():
		for column in columns:
			var cell: Label = _results_list.get_child(i * columns + column)
			cell.text = rows[i][column]
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if column >= 2 or (columns == 2 and column == 1) else HORIZONTAL_ALIGNMENT_LEFT
			var gold: bool = i < highlight.size() and highlight[i]
			cell.add_theme_color_override("font_color", Color("#f2cd37") if gold else Color.WHITE)
