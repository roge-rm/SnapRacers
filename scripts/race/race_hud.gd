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
var _corner: VBoxContainer
var _safe: SafeArea
## Face to face with two players, where the map they share sits on the line
## at the top of the half.
var _face_to_face := false
var _big: Label
var _big_was := ""
## Quick notes (see flash()), dropping in under the clock and fading.
var _message: Label
var _message_left := 0.0
## How long the time for the lap just finished stays up, and how many laps
## it had last time it looked.
var _split: Label
var _split_left := 0.0
var _laps_seen := 0
## Something that's going on, like the slowdown after a reset, in a pill at
## the bottom in the middle, with a bar for how long it has left.
var _status: Label
## How many parts it says are lost, and for how long it's said so.
var _lost_shown := 0
var _lost_for := 0.0
var _status_bar: ProgressBar
## Under the clock, a smaller line: your best lap, or the record.
var _clock_more: Label
## Where the clock goes: "top" under the menu button, "right" beside the
## camera button, or "corner" with your place and lap.
static var clock_at := "right"
## How long the parts lost line stays bright, in seconds, and how faint it
## fades to after that.
const LOST_SHOWN_FOR := 15.0
const LOST_FADED := 0.2
## The pills' colours.
const PILL := Color(0.04, 0.04, 0.1, 0.55)
const BEST := Color("#7dff8a")
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

	# Your place and lap, and the power-ups you're holding, in pills together
	# in the top left corner so they can move out of a camera hole's way as
	# one.
	var corner := VBoxContainer.new()
	_corner = corner
	corner.mouse_filter = MOUSE_FILTER_IGNORE
	corner.add_theme_constant_override("separation", 8)
	add_child(corner)
	corner.position = Vector2(24, 12)
	var standing := _pill(corner)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -6)
	standing.add_child(lines)
	_place = _label(44, lines)
	_lap = _label(24, lines)
	_held = _label(22, _pill(corner))
	_held.add_theme_color_override("font_color", Color("#f2cd37"))
	# With two on one phone they share one map between them (see Race).
	if race != null and me != null and race.humans.size() < 2:
		map = CourseMap.new()
		map.track = race.track
		map.you = me.kart
		map.karts.assign(race.racers.map(func(r): return r.kart))
		map.mode = Game.map_view(person)
		map.changed.connect(func(mode: String) -> void:
			Game.set_map_view(person, mode)
			flash(CourseMap.NAMES[mode]))
		corner.add_child(map)

	# The clock, in its pill, with the lap times and quick notes dropping in
	# under it.
	_face_to_face = race != null and race.humans.size() > 1 and race.split == Game.FACE_TO_FACE
	# Face to face it's with your place and lap, out of the way of the map on
	# the line, and side by side each half's too narrow for it beside the
	# camera button, so it goes under the menu button.
	var where := clock_at
	if _face_to_face:
		where = "corner"
	elif race != null and race.humans.size() > 1 and where == "right":
		where = "top"
	# Under the menu button in the middle: the clock if it goes there, then
	# the quick notes.
	var top := VBoxContainer.new()
	top.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top.offset_top = 14.0 + IconButton.SIZE + 10.0
	# Beside the camera button on the right, if the clock goes there.
	var right := VBoxContainer.new()
	right.mouse_filter = MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	right.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -210.0
	right.offset_left = -210.0
	right.offset_top = 16.0
	var timing_home: Node = {"corner": corner, "right": right}.get(where, top)
	var timing := _pill(timing_home if where != "top" else _centred(top))
	var clock_lines := VBoxContainer.new()
	clock_lines.add_theme_constant_override("separation", -4)
	timing.add_child(clock_lines)
	_clock = _label(30, clock_lines)
	_clock.add_theme_font_override("font", _even_digits())
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_more = _label(18, clock_lines)
	_clock_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_more.add_theme_color_override("font_color", MenuStyle.ACCENT.lightened(0.3))
	_split = _label(22, _pill(timing_home if where != "top" else _centred(top)))
	_split.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_split.get_parent().visible = false
	if where == "corner":
		# Right under your place and lap, above the map.
		corner.move_child(timing, 1)
		corner.move_child(_split.get_parent(), 2)
	if where == "right":
		for pill in [timing, _split.get_parent()]:
			pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	_message = _label(24, _pill(_centred(top)))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.get_parent().visible = false

	# What's going on, at the bottom in the middle between the controls.
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bottom.offset_top = -78.0
	bottom.offset_bottom = -24.0
	var status_pill := _pill(bottom)
	var status_lines := VBoxContainer.new()
	status_lines.add_theme_constant_override("separation", 4)
	status_pill.add_child(status_lines)
	_status = _label(22, status_lines)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_bar = ProgressBar.new()
	_status_bar.show_percentage = false
	_status_bar.custom_minimum_size = Vector2(200.0, 6.0)
	_status_bar.mouse_filter = MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#f2cd37")
	fill.set_corner_radius_all(3)
	var track_box := StyleBoxFlat.new()
	track_box.bg_color = Color(1.0, 1.0, 1.0, 0.15)
	track_box.set_corner_radius_all(3)
	_status_bar.add_theme_stylebox_override("fill", fill)
	_status_bar.add_theme_stylebox_override("background", track_box)
	status_lines.add_child(_status_bar)
	status_pill.visible = false

	# The countdown and GO!, big in the middle, popping in.
	_big = _label(120)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_big.resized.connect(func() -> void: _big.pivot_offset = _big.size * 0.5)

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
	# right where the menu button would be, so the menu goes in the top left
	# corner, and your place, lap and the clock go down below the map (see
	# make_room_for_map()).
	if _face_to_face:
		_menu.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
		_menu.offset_left = 24.0
		_menu.offset_right = 24.0 + IconButton.SIZE
		_menu.offset_top = 16.0
		_menu.offset_bottom = 16.0 + IconButton.SIZE

	_fps = _label(18)
	_fps.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_fps.offset_top = -30.0
	_fps.offset_left = 12.0

	_build_results()
	# Nothing hides under a camera hole.
	var safe := SafeArea.new()
	_safe = safe
	add_child(safe)
	for control in [corner, _menu, _camera, _fps, top, right, bottom]:
		safe.watch(control)


## What's on a gadget button, with how many goes are left when there's more
## than one, like "Triple turbo x3".
static func held_name(kart: Kart, slot: int) -> String:
	var name := Powerups.name_of(kart.held[slot])
	return name + (" x%d" % kart.held_uses[slot] if kart.held_uses[slot] > 1 else "")


## Moves your place, lap and the clock down below the map two players share
## face to face, which reaches `down` into the top of this half.
func make_room_for_map(down: float) -> void:
	if _face_to_face and _corner != null:
		_corner.position.y = maxf(8.0, down + 10.0)
		if _safe != null:
			_safe.moved(_corner)


func buttons() -> Array[Control]:
	return [_menu, _camera, _results, map] if map != null else [_menu, _camera, _results]


func _label(size: int, parent: Node = null) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", maxi(4, size / 10) if parent != null else maxi(6, size / 8))
	label.mouse_filter = MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label


## A rounded, dark, see-through pill to put words in, so they read over
## anything behind them.
func _pill(parent: Node) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = PILL
	box.set_corner_radius_all(14)
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(pill)
	return pill


## A row across the top that keeps what's put in it in the middle.
func _centred(top: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(row)
	return row


## The theme's font with every digit the same width, so a ticking clock
## doesn't jiggle.
static func _even_digits() -> Font:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.opentype_features = { TextServerManager.get_primary_interface().name_to_tag("tnum"): 1 }
	return font


## A quick note in a pill under the clock, which fades after a moment.
func flash(text: String) -> void:
	_message.text = text
	_message_left = 1.8
	_message.get_parent().visible = true


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
	_held.get_parent().visible = not trial and not names.is_empty()
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
	_clock.text = clock(shown)
	var more := ""
	if trial and Records.best_time(race.track_id) > 0.0 and not me.progress.finished:
		more = "record %s" % clock(Records.best_time(race.track_id))
	elif (practice or trial) and me.progress.best_lap() > 0.0:
		more = "best lap %s" % clock(me.progress.best_lap())
	_clock_more.text = more
	_clock_more.visible = more != ""

	# The time for each lap as it's done, green when it's your best.
	var laps := me.progress.lap_times.size()
	if laps > _laps_seen and laps > 0:
		var lap: float = me.progress.lap_times[-1]
		var best := laps > 1 and lap <= me.progress.best_lap()
		_split.text = "Lap %d   %s%s" % [laps, clock(lap), "   best" if best else ""]
		_split.add_theme_color_override("font_color", BEST if best else Color.WHITE)
		_split_left = 4.0
	_laps_seen = laps
	_split_left = maxf(_split_left - delta, 0.0)
	_split.get_parent().visible = _split_left > 0.0
	_split.get_parent().modulate.a = clampf(_split_left / 0.5, 0.0, 1.0)

	# The countdown, then GO! for a moment, each one popping in.
	var big := ""
	if race.time < 0.0:
		big = str(ceili(-race.time))
		_big.modulate.a = 1.0
	elif race.time < 1.0:
		big = "GO!"
		_big.modulate.a = 1.0 - race.time
	_big.text = big
	if big != _big_was and big != "":
		_big.scale = Vector2.ONE * 1.5
		create_tween().tween_property(_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_big_was = big

	# What's going on, at the bottom.
	var status := ""
	var left := -1.0
	var faint := 1.0
	var lost := me.kart.lost.size()
	if lost != _lost_shown:
		_lost_shown = lost
		_lost_for = 0.0
	_lost_for += delta
	if me.kart.slowdown_left > 0.0:
		status = "Reset slowdown"
		left = me.kart.slowdown_left / Kart.RESET_SLOWDOWN_TIME
	elif lost > 0:
		status = "%d part%s lost, reset to fix" % [lost, "" if lost == 1 else "s"]
		# Once you've seen it a while it fades back, until more come off.
		faint = lerpf(1.0, LOST_FADED, clampf(_lost_for - LOST_SHOWN_FOR, 0.0, 1.0))
	if _results.visible:
		status = ""
	_status.text = status
	_status.get_parent().get_parent().visible = status != ""
	_status.get_parent().get_parent().modulate.a = faint
	_status_bar.visible = left >= 0.0
	_status_bar.value = left * 100.0

	if _message_left > 0.0:
		_message_left -= delta
		_message.get_parent().modulate.a = clampf(_message_left / 0.4, 0.0, 1.0)
	else:
		_message.get_parent().visible = false

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
