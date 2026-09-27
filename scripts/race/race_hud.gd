class_name RaceHud
extends Control

## What you see during a race: your place and lap in the top left, the clock
## in the middle, the countdown, the odd message, and the results once you've
## finished.

signal again_pressed
signal garage_pressed
signal menu_pressed

var race: Race

var _place: Label
var _lap: Label
var _studs: Label
var _clock: Label
var _big: Label
var _message: Label
var _message_left := 0.0
var _quit: Button
var _fps: Label
var _results: PanelContainer
var _results_list: GridContainer
## The on-screen driving controls, hidden once you've finished.
var touch: Control


func _ready() -> void:
	theme = Game.theme
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_place = _label(56)
	_place.position = Vector2(24, 8)
	_lap = _label(28)
	_lap.position = Vector2(26, 80)
	_studs = _label(28)
	_studs.position = Vector2(26, 118)
	_studs.add_theme_color_override("font_color", Color("#f2cd37"))

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

	_quit = Button.new()
	_quit.text = "Quit"
	_quit.custom_minimum_size = Vector2(130, 56)
	_quit.focus_mode = FOCUS_NONE
	add_child(_quit)
	_quit.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_quit.position.y = 12
	_quit.pressed.connect(func() -> void: menu_pressed.emit())

	_fps = _label(18)
	_fps.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	_fps.offset_top = -30.0
	_fps.offset_left = 12.0

	_build_results()


func buttons() -> Array[Control]:
	return [_quit, _results]


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
	if race == null or race.player == null:
		return
	_fps.visible = Game.show_fps()
	_fps.text = "%d fps" % Engine.get_frames_per_second()
	var me := race.player
	_place.text = "%s / %d" % [ordinal(race.place_of(me)), race.racers.size()]
	_lap.text = "Lap %d / %d" % [me.progress.current_lap(), race.track.laps]
	if me.progress.finished:
		_lap.text = "Finished"
	_studs.text = "%d stud%s" % [me.kart.studs, "" if me.kart.studs == 1 else "s"]
	if touch != null:
		var buttons := me.kart.buttons()
		for slot in 2:
			if slot < buttons.size():
				var def: Dictionary = buttons[slot][1]
				touch.gadget_names[slot] = "%s\n%d" % [def.get("name", ""), def.get("cost", 0)]
				touch.gadget_ready[slot] = me.kart.can_use(slot)
			else:
				touch.gadget_names[slot] = ""
		touch.queue_redraw()
	var shown := me.progress.finish_time if me.progress.finished else race.time
	var text := clock(shown)
	if not me.progress.lap_times.is_empty():
		text += "\nlast lap %s" % clock(me.progress.lap_times[-1])
	_clock.text = text

	# The countdown, then GO for a moment.
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
	var title := Label.new()
	title.text = "Results"
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	_results_list = GridContainer.new()
	_results_list.columns = 3
	_results_list.add_theme_constant_override("h_separation", 28)
	box.add_child(_results_list)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for pair in [["Race again", again_pressed], ["Garage", garage_pressed], ["Menu", menu_pressed]]:
		var button := Button.new()
		button.text = pair[0]
		button.custom_minimum_size = Vector2(160, 60)
		button.focus_mode = FOCUS_NONE
		var signal_to_send: Signal = pair[1]
		button.pressed.connect(func() -> void: signal_to_send.emit())
		row.add_child(button)


func show_results() -> void:
	_results.visible = true
	_quit.visible = false
	if touch != null:
		touch.visible = false
	_fill_results()
	_results.reset_size()
	_results.set_anchors_and_offsets_preset(PRESET_CENTER)


func _fill_results() -> void:
	var standings := race.standings()
	while _results_list.get_child_count() < standings.size() * 3:
		var cell := Label.new()
		_results_list.add_child(cell)
	for i in standings.size():
		var racer: Race.Racer = standings[i]
		var when := clock(racer.progress.finish_time) if racer.progress.finished else "racing"
		var texts := [ordinal(i + 1), racer.name, when]
		for column in 3:
			var cell: Label = _results_list.get_child(i * 3 + column)
			cell.text = texts[column]
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if column == 2 else HORIZONTAL_ALIGNMENT_LEFT
			cell.add_theme_color_override("font_color", Color("#f2cd37") if racer.player else Color.WHITE)
