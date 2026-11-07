class_name RaceHud
extends Control

## What you see during a race. Your place and lap are in the top left, and
## tapping them opens the race's menu. The clock is beside the camera button,
## with the countdown, a message now and then, and the results once you've
## finished. In split screen each player has one of these in their half, with
## smaller words and the clock in with their place and lap.
##
## Time trials and practice are just you, so they show your lap times instead
## of a place. The results offer what makes sense for the kind of race, like
## the next race of a Grand Prix or another go at a time trial.

signal again_pressed
signal garage_pressed
signal menu_pressed
## Your place and lap tapped, for the race's menu (see RaceMenu).
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
## The power-ups you're holding, in two boxes at the bottom in the middle.
var _slots: PowerupSlots
var _clock: Label
var _corner: VBoxContainer
## Where the corner was last put to keep clear of the touch controls.
var _corner_spot := Vector2(24, 12)
## Face to face, the part of this half the shared map covers.
var _map_room := Rect2()
var _map_down := 0.0
var _map_wide := 0.0
## The row with the status pill, and how far up from the bottom it was last
## put to keep clear of the touch controls.
var _bottom: HBoxContainer
var _bottom_down := 0.0
## Across the top in the middle, for the quick notes.
var _top: VBoxContainer
var _safe: SafeArea
## Face to face with two players, where the map they share sits on the line
## at the top of the half.
var _face_to_face := false
var _big: Label
var _big_was := ""
## Quick notes (see flash()), dropping in under the clock and fading.
var _message: Label
var _message_left := 0.0
var _message_row: HBoxContainer
## How long the time for the lap just finished stays up, and how many laps
## it had last time it looked.
var _split: Label
var _split_left := 0.0
var _laps_seen := 0
## Something that's going on, like the slowdown after a reset, in small
## words at the bottom in the middle, with a slim bar for how long it has left.
var _status_box: VBoxContainer
var _status: Label
## How many parts it says are lost, and for how long it's said so.
var _lost_shown := 0
var _lost_for := 0.0
var _status_bar: ProgressBar
## Under the clock, a smaller line: your best lap, or the record.
var _clock_more: Label
## Where the clock goes: "top" in the middle, "right" beside the camera
## button, or "corner" with your place and lap. In split screen it's always
## in the same box as your place and lap.
static var clock_at := "right"
## How long the parts lost line stays bright, in seconds, and how faint it
## fades to after that.
const LOST_SHOWN_FOR := 15.0
const LOST_FADED := 0.2
## How far up from the bottom the power-up boxes sit.
const SLOTS_UP := 16.0
## The camera button's size, and the least the place and lap box takes taps
## over, for the menu.
const BUTTON := Vector2(56.0, 48.0)
## An invisible button over your place and lap, for the race's menu.
var _menu: Button
## The box with your place and lap in it, lighter while it's pressed.
var _standing: PanelContainer
var _camera: IconButton
var mirror: RearViewMirror
## Split screen, with smaller words and boxes.
var _small := false
## How long a quick note stays up, in seconds, and how long it takes to fade.
const MESSAGE_FOR := 2.0
const MESSAGE_FADE := 0.5
## Made once for every HUD: nothing, for the menu button over your place and
## lap, and the faint track behind the status bar.
static var _nothing: StyleBoxEmpty
static var _bar_back: SlantBox
var _fps: Label
const RESULTS_DELAY := 2.0
const RESULTS_SLIDE := 0.25
var _results_left := -1.0
var _results_slide := 0.0
var _results_rect := Rect2()
var _results_column: VBoxContainer
var _results: ResultsPanel
var _results_title: Label
var _results_list: GridContainer
## Standings in a Grand Prix, which waits for the other player to finish.
var _next: Button
var _waiting: Label
## The on-screen driving controls, hidden once you've finished.
var touch: Control


func _ready() -> void:
	theme = Game.theme
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if _nothing == null:
		_nothing = StyleBoxEmpty.new()
		_bar_back = UiKit.slant(Color(UiKit.SHADOW_COLOUR, 0.45), 0.0, Color.TRANSPARENT, 0, false)

	_small = race != null and race.humans.size() > 1
	# Your place and lap in a pill in the top left corner, with the map under
	# it, so they can move out of a camera hole's way as one.
	var corner := VBoxContainer.new()
	_corner = corner
	corner.mouse_filter = MOUSE_FILTER_IGNORE
	corner.add_theme_constant_override("separation", 8 if not _small else 5)
	add_child(corner)
	corner.position = _corner_spot
	var standing := _pill(corner, true)
	_standing = standing
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -6 if not _small else -4)
	standing.add_child(lines)
	_place = _label(_kind("HudPlaceLabel"), lines)
	_lap = _label(_kind("HudLabel"), lines)
	# With two on one phone they share one map between them (see Race).
	if race != null and me != null and race.humans.size() < 2:
		map = CourseMap.new()
		map.track = race.track
		map.you = me.kart
		map.karts.assign(race.racers.map(func(r): return r.kart))
		map.cpu_karts.assign(race.racers.filter(func(r): return r.cpu).map(func(r): return r.kart))
		map.mode = Game.map_view(person)
		map.changed.connect(func(mode: String) -> void:
			Game.set_map_view(person, mode)
			flash(CourseMap.NAMES[mode]))
		corner.add_child(map)

	# The clock, in its pill, with the lap times and quick notes dropping in
	# under it.
	_face_to_face = race != null and race.humans.size() > 1 and race.split == Game.FACE_TO_FACE
	var where := clock_at
	if _small:
		where = "corner"
	# Across the top in the middle: the clock if it goes there, then the quick
	# notes.
	var top := VBoxContainer.new()
	_top = top
	top.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top.offset_top = 14.0
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
	# Split screen, the clock goes in with your place and lap, so each half
	# has one box at the top.
	var clock_lines := VBoxContainer.new()
	clock_lines.add_theme_constant_override("separation", -4)
	var timing: Control = clock_lines
	if _small:
		lines.add_child(clock_lines)
	else:
		timing = _pill(timing_home if where != "top" else _centred(top))
		timing.add_child(clock_lines)
	_clock = _label(_kind("HudClockLabel"), clock_lines)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if not _small else HORIZONTAL_ALIGNMENT_LEFT
	_clock_more = _label(_kind("HudNoteLabel"), clock_lines)
	_clock_more.horizontal_alignment = _clock.horizontal_alignment
	_split = _label(_kind("HudLabel"), _pill(timing_home if where != "top" else _centred(top)))
	_split.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_split.get_parent().visible = false
	if where == "corner" and not _small:
		# Right under your place and lap, above the map.
		corner.move_child(timing, 1)
		corner.move_child(_split.get_parent(), 2)
	if where == "right":
		for pill in [timing, _split.get_parent()]:
			pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	_message_row = _centred(top)
	_message = _label(_kind("HudLabel"), _pill(_message_row))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.get_parent().visible = false

	# The power-ups you're holding, at the bottom in the middle between the
	# controls, always there so nothing moves when one's picked up.
	_slots = PowerupSlots.new()
	add_child(_slots)
	_slots.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	_slots.offset_left = -_slots.custom_minimum_size.x * 0.5
	_slots.offset_right = _slots.custom_minimum_size.x * 0.5
	_slots.offset_top = -SLOTS_UP - PowerupSlots.BOX
	_slots.offset_bottom = -SLOTS_UP

	# What's going on, in small words with a slim bar, just above the
	# power-ups.
	var bottom := HBoxContainer.new()
	_bottom = bottom
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	_bottom_down = -SLOTS_UP - PowerupSlots.BOX - 10.0
	bottom.offset_bottom = _bottom_down
	bottom.offset_top = _bottom_down - 54.0
	# A taller one grows up, away from the power-ups.
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_status_box = VBoxContainer.new()
	_status_box.mouse_filter = MOUSE_FILTER_IGNORE
	_status_box.add_theme_constant_override("separation", 2)
	bottom.add_child(_status_box)
	_status = _label("HudSmallLabel", _status_box)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_bar = ProgressBar.new()
	_status_bar.show_percentage = false
	_status_bar.custom_minimum_size = Vector2(140.0 if not _small else 100.0, 4.0)
	_status_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_status_bar.add_theme_stylebox_override("background", _bar_back)
	_status_box.add_child(_status_bar)
	_status_box.visible = false

	# The countdown and GO!, big in the middle, popping in.
	_big = _label("CountdownLabel")
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_big.resized.connect(func() -> void: _big.pivot_offset = _big.size * 0.5)

	# The race's menu, from tapping your place and lap. It's an invisible
	# button kept over that box (see _process()).
	_menu = Button.new()
	_menu.tooltip_text = "Menu"
	# The driving keys and buttons mustn't press the HUD's buttons.
	_menu.focus_mode = FOCUS_NONE
	_menu.flat = true
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_menu.add_theme_stylebox_override(state, _nothing)
	add_child(_menu)
	_menu.pressed.connect(func() -> void: pause_pressed.emit())

	# The camera button, left of where the touch controls put reset.
	_camera = IconButton.new("camera", "Change the view")
	_camera.focus_mode = FOCUS_NONE
	_hud_look(_camera)
	add_child(_camera)
	# Its middle stays where a round 48 wide one's was, 166 in from the right.
	_camera.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	_camera.offset_left = -166.0 - BUTTON.x * 0.5
	_camera.offset_right = -166.0 + BUTTON.x * 0.5
	_camera.offset_top = 16.0
	_camera.offset_bottom = 16.0 + BUTTON.y
	_camera.pressed.connect(func() -> void: camera_pressed.emit())

	_fps = _label("HudNoteLabel")
	_fps.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_fps.offset_top = -30.0
	_fps.offset_left = 12.0

	_build_results()
	# Nothing hides under a camera hole.
	var safe := SafeArea.new()
	_safe = safe
	add_child(safe)
	for control in [corner, _camera, _fps, top, right, bottom, _slots, _results]:
		safe.watch(control)
	if not _small and race != null and race.split == Game.SOLO and me != null and me.camera != null and me.camera.mirror_available:
		mirror = RearViewMirror.new()
		mirror.camera = me.camera
		mirror.blockers.assign([corner, _camera, _clock.get_parent().get_parent(), _split.get_parent()])
		add_child(mirror)
		mirror.item_rect_changed.connect(_place_mirror_message)
		_layout_message()


## What's on a gadget button, with how many goes are left when there's more
## than one, like "Triple turbo x3".
static func held_name(kart: Kart, slot: int) -> String:
	var name := Powerups.name_of(kart.held[slot])
	return name + (" x%d" % kart.held_uses[slot] if kart.held_uses[slot] > 1 else "")


## Puts the room for the shared map in the middle of the top, as wide as the HUD is now.
func _place_map_room() -> void:
	_map_room = Rect2((size.x - _map_wide) * 0.5, 0.0, _map_wide, _map_down)
	if _safe != null:
		_clear_of_touch(_touch_areas())


## Keeps your place, lap and the clock clear of the map two players share
## face to face, which reaches `down` into the top of this half and is `wide`
## across its middle, and puts the quick notes under it.
func make_room_for_map(down: float, wide: float) -> void:
	if _face_to_face and _corner != null:
		_map_down = down
		_map_wide = wide
		_place_map_room()
		if not resized.is_connected(_place_map_room):
			resized.connect(_place_map_room)
		# The quick notes go under the map.
		_top.offset_top = maxf(14.0, down + 8.0)
		if _safe != null:
			_safe.moved(_top)
		_clear_of_touch(_touch_areas())


## Keeps your place and lap and the status line out from under the touch
## controls. Face to face the corner tries the top left, then below the map,
## then under the camera button. The status line moves up past any control
## it would sit on. `areas` are the touch controls' (see _touch_areas()).
func _clear_of_touch(areas: Array[Rect2]) -> void:
	if _safe == null:
		return
	if _face_to_face and _corner.size.y > 0.0:
		var taken := areas.duplicate()
		taken.append_array([_map_room, _camera.get_rect()])
		var spots := [
			Vector2(24.0, 12.0),
			Vector2(24.0, maxf(8.0, _map_room.end.y + 10.0)),
			Vector2(24.0, _camera.get_rect().end.y + 10.0),
		]
		# The first clear spot, else the one with the least overlap.
		var spot: Vector2 = spots[1]
		var least := INF
		for each: Vector2 in spots:
			var box := Rect2(each, _corner.size).grow(4.0)
			var over := 0.0 if box.end.y <= size.y else INF
			for r: Rect2 in taken:
				over += r.intersection(box).get_area()
			if over < least:
				least = over
				spot = each
			if over == 0.0:
				break
		if spot != _corner_spot:
			_corner_spot = spot
			_corner.position = spot
			_safe.moved(_corner)
	if not _status_box.visible:
		return
	var down := -SLOTS_UP - PowerupSlots.BOX - 10.0
	if areas.is_empty():
		if down != _bottom_down:
			_bottom_down = down
			_bottom.offset_bottom = down
			_bottom.offset_top = down - 54.0
			_safe.moved(_bottom)
		return
	var box := Rect2(Vector2(_bottom.position.x + _status_box.position.x, size.y + down - _status_box.size.y), _status_box.size)
	for i in 4:
		for r in areas:
			if r.grow(8.0).intersects(box):
				box.position.y = r.position.y - 8.0 - box.size.y
	down = box.end.y - size.y
	if down != _bottom_down:
		_bottom_down = down
		_bottom.offset_bottom = down
		_bottom.offset_top = down - 54.0
		_safe.moved(_bottom)


func buttons() -> Array[Control]:
	return [_menu, _camera, _results, map] if map != null else [_menu, _camera, _results]


## A label in one of the kit's HUD kinds, like "HudLabel" (see UiKit.theme()).
func _label(kind: String, parent: Node = null) -> Label:
	var label := Label.new()
	label.theme_type_variation = kind
	label.mouse_filter = MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(label)
	return label


## A HUD label kind, or its smaller one in split screen, like
## "HudSmallLabel" for "HudLabel".
func _kind(kind: String) -> String:
	return kind.replace("Label", "SmallLabel") if _small else kind


## The kit's see-through slanted panel to put words in, with a red line along
## the bottom when `underline` is set.
func _pill(parent: Node, underline := false) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_LEAN, underline, _small))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(pill)
	return pill


## The camera button as a small slanted outline.
static func _hud_look(button: IconButton) -> void:
	button.custom_minimum_size = BUTTON
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, UiKit.hud_button(state))


## A row across the top that keeps what's put in it in the middle.
func _centred(top: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(row)
	return row


## A quick note in a pill under the clock, which fades after a moment.
func flash(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_FOR
	_message.get_parent().visible = true
	_message.get_parent().modulate.a = 1.0
	_layout_message()


func _layout_message() -> void:
	if mirror == null:
		return
	var pill := _message.get_parent() as Control
	if mirror.is_active():
		# Keep quick notes out of the clock's container while the mirror is up.
		if pill.get_parent() != self:
			pill.reparent(self, false)
		mirror._fit()
		_place_mirror_message()
	elif pill.get_parent() != _message_row:
		pill.reparent(_message_row, false)
		pill.reset_size()


func _place_mirror_message() -> void:
	var pill := _message.get_parent() as Control
	if pill.get_parent() != self:
		return
	pill.size = pill.get_combined_minimum_size()
	var room := mirror.get_rect()
	pill.position = Vector2(clampf(room.get_center().x - pill.size.x * 0.5, RearViewMirror.GAP, maxf(RearViewMirror.GAP, size.x - pill.size.x - RearViewMirror.GAP)), room.end.y + RearViewMirror.GAP)
	var into := get_global_transform_with_canvas().affine_inverse()
	var holes := SafeArea.holes_in(get_viewport()).map(func(hole: Rect2) -> Rect2: return into * hole)
	for i in holes.size():
		var below := pill.position.y
		for hole: Rect2 in holes:
			if pill.get_rect().intersects(hole.grow(RearViewMirror.GAP)):
				below = maxf(below, hole.end.y + RearViewMirror.GAP)
		if is_equal_approx(below, pill.position.y):
			break
		pill.position.y = below


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
	# Touch controls show what's held on their gadget buttons already.
	_slots.visible = not trial and _results_left < 0.0 and not _results.visible and (touch == null or not touch.visible)
	_slots.show_held(me.kart.held, me.kart.held_uses)
	if touch != null:
		for slot in Powerups.HOLD:
			var held: String = me.kart.held[slot]
			touch.show_gadget(slot, held_name(me.kart, slot) if held != "" else "", held, me.kart.held_uses[slot], me.kart.can_use(slot))
	var shown := me.progress.finish_time if me.progress.finished else race.time
	if practice:
		# The lap you're on, since the whole session could go on for ages.
		shown = race.time - me.progress.lap_started() if me.progress.laps >= 0 else 0.0
	_clock.text = clock(shown)
	var more := ""
	if trial and race.conditions.records_allowed() and Records.best_time(race.track_id) > 0.0 and not me.progress.finished:
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
		_split.theme_type_variation = _kind("HudBestLabel" if best else "HudLabel")
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
	if _results.visible or _results_left >= 0.0:
		status = ""
	_status.text = status
	_status_box.visible = status != ""
	_status_box.modulate.a = faint
	_status_bar.visible = left >= 0.0
	_status_bar.value = left * 100.0

	if _message_left > 0.0:
		_message_left -= delta
		_message.get_parent().modulate.a = clampf(_message_left / MESSAGE_FADE, 0.0, 1.0)
	else:
		_message.get_parent().visible = false
	_layout_message()

	if _results_left >= 0.0:
		_results_left -= delta
		_show_waiting()
		if _results_left <= 0.0:
			_results_left = -1.0
			_reveal_results()
	if _results.visible:
		_fill_results()
		_show_waiting()
		_results_slide = maxf(_results_slide - delta / RESULTS_SLIDE, 0.0)
		_layout_results()
	var areas := _touch_areas()
	_clear_of_touch(areas)
	# The menu button covers your place and lap, at least BUTTON big.
	var target := _standing.get_global_rect()
	target.size = target.size.max(BUTTON)
	target.position -= get_global_rect().position
	# Touch controls under it win, so the button keeps the biggest clear part
	# that's still BUTTON big. A sliver is too small to tap on purpose.
	for r in areas:
		if not r.intersects(target):
			continue
		var pieces: Array[Rect2] = [
			Rect2(target.position, Vector2(r.position.x - target.position.x, target.size.y)),
			Rect2(Vector2(r.end.x, target.position.y), Vector2(target.end.x - r.end.x, target.size.y)),
			Rect2(target.position, Vector2(target.size.x, r.position.y - target.position.y)),
			Rect2(Vector2(target.position.x, r.end.y), Vector2(target.size.x, target.end.y - r.end.y)),
		]
		var best := Rect2(target.position, Vector2.ZERO)
		for piece in pieces:
			if piece.size.x >= BUTTON.x and piece.size.y >= BUTTON.y and piece.get_area() > best.get_area():
				best = piece
		target = best
	# With no such part there's no tap area (a controller's menu button
	# still works).
	var room := target.size.x >= BUTTON.x and target.size.y >= BUTTON.y
	_menu.mouse_filter = MOUSE_FILTER_STOP if room else MOUSE_FILTER_IGNORE
	if room:
		_menu.position = target.position
		_menu.size = target.size
	_standing.modulate = Color(1.4, 1.4, 1.4) if _menu.button_pressed else Color.WHITE


## The touch controls' areas in this HUD, or none when they're hidden.
func _touch_areas() -> Array[Rect2]:
	if touch != null and touch.visible:
		return touch.areas()
	return []


func _build_results() -> void:
	_results = ResultsPanel.new()
	_results.visible = false
	_results.add_theme_stylebox_override("panel", UiKit.popup())
	add_child(_results)
	var box := VBoxContainer.new()
	_results_column = box
	box.add_theme_constant_override("separation", UiKit.GAP_M)
	_results.add_child(box)
	_results_title = Label.new()
	_results_title.text = "Results"
	_results_title.theme_type_variation = "LeadLabel"
	box.add_child(_results_title)
	_results_list = GridContainer.new()
	_results_list.columns = 4 if race.mode == Game.MODE_GRAND_PRIX else (2 if race.mode == Game.MODE_TIME_TRIAL else 3)
	_results_list.add_theme_constant_override("h_separation", 12)
	var scroll := ScrollContainer.new()
	_results.table = scroll
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_results_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_results_list)
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
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
		next.theme_type_variation = "NoteLabel"
		next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(next)
		box.move_child(next, box.get_child_count() - 2)
	for pair in choices:
		var button := Button.new()
		button.text = pair[0]
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = FOCUS_ALL
		if row.get_child_count() == 0:
			button.theme_type_variation = "MainButton"
		var signal_to_send: Signal = pair[1]
		button.pressed.connect(func() -> void: signal_to_send.emit())
		row.add_child(button)
		if signal_to_send == next_pressed:
			_next = button
	if _next != null and race.humans.size() > 1:
		_waiting = Label.new()
		_waiting.theme_type_variation = "NoteLabel"
		_waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(_waiting)


## The other player's still racing, so Standings waits for them, or until
## all but one of the racers are home.
func _show_waiting() -> void:
	if _next == null:
		return
	var ready := race.can_move_on()
	_next.disabled = not ready
	if _waiting != null:
		_waiting.visible = not ready
		if not ready:
			var out := race.humans.filter(func(r: Race.Racer) -> bool: return not r.progress.finished)
			_waiting.text = "%s is still racing" % out[0].name


func show_results() -> void:
	_fill_results()
	_show_waiting()
	if _results.visible or _results_left >= 0.0:
		return
	_results_left = RESULTS_DELAY
	_menu.visible = false
	if touch != null:
		touch.visible = false
		touch.set_process_input(false)
	flash("Finished" if race.mode == Game.MODE_TIME_TRIAL else "%s place" % ordinal(race.place_of(me)))


func _reveal_results() -> void:
	_results.visible = true
	_results_slide = 1.0 if DisplayServer.get_name() != "headless" else 0.0
	_layout_results()
	PadFocus.focus_first.call_deferred(_results)


## Wide views leave the car clear in the middle. Short or narrow views keep
## the table below it, with scrolling for the rest of the field.
func _layout_results() -> void:
	var side := size.x >= 1000.0 and not _small
	var width := minf(440.0, size.x * 0.34) if side else minf(440.0, size.x - 32.0)
	var height := minf(_results_column.get_combined_minimum_size().y + _results_list.get_combined_minimum_size().y + 40.0, size.y - 32.0 if side else size.y * 0.42)
	var at := Vector2(size.x - width - 16.0, (size.y - height) * 0.5) if side else Vector2((size.x - width) * 0.5, size.y - height - 16.0)
	at += Vector2((width + 16.0) * _results_slide, 0.0) if side else Vector2(0.0, (height + 16.0) * _results_slide)
	var wanted := Rect2(at, Vector2(width, height))
	if not wanted.is_equal_approx(_results_rect):
		_results_rect = wanted
		_results.size = wanted.size
		_results.position = wanted.position
		if _safe != null:
			_safe.moved(_results)
			_safe.refit()
	if me.camera != null:
		var camera := me.camera
		var distance := camera.global_position.distance_to(me.kart.global_position + Vector3.UP * RaceCamera.LOOK_HEIGHT)
		var half_height := distance * tan(deg_to_rad(camera.fov) * 0.5)
		var shown := 1.0 - _results_slide
		camera.h_offset = (width + 32.0) / size.y * half_height * shown if side else 0.0
		camera.v_offset = 0.0 if side else -(height + 32.0) / size.y * half_height * shown


func _fill_results() -> void:
	var rows := []
	var highlight := []
	if race.mode == Game.MODE_TIME_TRIAL:
		var records: Array = race.new_records
		rows.append(["Time", clock(me.progress.finish_time) + ("  New record!" if records[0] else "")])
		rows.append(["Best lap", clock(me.progress.best_lap()) + ("  New record!" if records[1] else "")])
		for i in me.progress.lap_times.size():
			rows.append(["Lap %d" % (i + 1), clock(me.progress.lap_times[i])])
		if race.conditions.records_allowed():
			rows.append(["Course record", clock(Records.best_time(race.track_id))])
		else:
			rows.append(["Records", "Clear daytime only"])
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
		var cell := Label.new()
		if _results_list.get_child_count() % columns == 1:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.custom_minimum_size.x = 60.0
		_results_list.add_child(cell)
	for i in rows.size():
		for column in columns:
			var cell: Label = _results_list.get_child(i * columns + column)
			cell.text = rows[i][column]
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if column >= 2 or (columns == 2 and column == 1) else HORIZONTAL_ALIGNMENT_LEFT
			var gold: bool = i < highlight.size() and highlight[i]
			# Times in even-width digits, and you or a new record in yellow.
			var time := column == columns - 1 if columns == 2 else column == 2
			if time:
				cell.theme_type_variation = "TimeAccentLabel" if gold else "TimeLabel"
			else:
				cell.theme_type_variation = "AccentLabel" if gold else ""


## Shoulder buttons page through the table while the action buttons stay put.
class ResultsPanel extends PanelContainer:
	var table: ScrollContainer

	func next_tab(by: int) -> void:
		table.scroll_vertical += by * maxi(int(table.size.y * 0.8), 32)
