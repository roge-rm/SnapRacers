class_name GrandPrixStandings
extends Control

## The points table between Grand Prix races, and the trophy at the end.
##
## Online, the host moves everyone on to the next race (and back to the lobby
## at the end), and a cup raced online doesn't count toward your trophies.
## For two on this phone both players show in their colours, and the trophy
## goes by whichever of them did better.
##
## At the end of a cup off the network it's shown over the podium, in the
## race scene (see Race.show_standings()): a see-through panel down the
## right side, or over the middle on a narrow screen.

## How wide the panel over the podium is, and its gap from the screen's edges.
const SIDE_WIDTH := 600.0
const SIDE_MARGIN := 24.0
## The panel goes to the side if it leaves at least this much of the width
## clear, on a screen at least this wide for its height.
const SIDE_CLEAR := 0.4
const SIDE_ASPECT := 1.2
const TITLE_SIZE := 36
## Presses over the podium are ignored this long after it appears.
const IGNORE_INPUT := 0.4

## Sent when the panel has been laid out again for a new window size, with
## `clear` changed.
signal laid_out

var grand_prix: GrandPrix
## Shown over the podium rather than as a screen of its own.
var over_podium := false
## How much of the screen's width, from the left, the panel leaves clear
## over the podium. 1 when it's over the middle.
var clear := 1.0
var _age := 0.0
var _recorded := false
var _relaying := false


func _init(gp: GrandPrix, over := false) -> void:
	grand_prix = gp
	over_podium = over


func _ready() -> void:
	if over_podium:
		get_viewport().size_changed.connect(_relay)
	_build()


func _exit_tree() -> void:
	var port := get_viewport()
	if port != null and port.size_changed.is_connected(_relay):
		port.size_changed.disconnect(_relay)


func _process(delta: float) -> void:
	_age += delta


## Whether presses count yet, once the panel has finished appearing.
func accepting() -> bool:
	return not over_podium or _age >= IGNORE_INPUT


func _input(event: InputEvent) -> void:
	if accepting():
		return
	var press: bool = (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton) and event.pressed
	if press or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


## Lays the panel out again for the window's new size, once the frame's
## resizing is done.
func _relay() -> void:
	if _relaying:
		return
	_relaying = true
	await get_tree().process_frame
	_relaying = false
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	modulate.a = 1.0
	_build()
	laid_out.emit()


func _build() -> void:
	var done := grand_prix.finished()
	var races := grand_prix.track_ids().size()
	var level := Difficulty.name_of(grand_prix.difficulty)
	var column := _over_podium() if over_podium else _between_races()
	var where := Label.new()
	where.text = level if done else "%s, after race %d of %d" % [level, grand_prix.round, races]
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if not over_podium else HORIZONTAL_ALIGNMENT_LEFT
	where.uppercase = true
	where.theme_type_variation = "LeadLabel"
	column.add_child(where)
	var standings := grand_prix.standings()
	var people: Array = grand_prix.people if not grand_prix.people.is_empty() else [Game.player_name()]
	var names := standings.map(func(s): return s[0])
	var place := grand_prix.best_place() if not grand_prix.people.is_empty() else names.find(people[0]) + 1
	if done:
		var trophy: String = CupGrid.TROPHIES.get(place, "")
		var news := "You won the %s!" % grand_prix.cup.name if place == 1 else "You finished %s." % RaceHud.ordinal(place)
		if grand_prix.two and place > 0:
			var who: String = names[place - 1]
			news = "%s won the %s!" % [who, grand_prix.cup.name] if place == 1 else "%s finished %s." % [who, RaceHud.ordinal(place)]
		if trophy != "":
			news += " That's a %s." % trophy.to_lower()
		var banner := Label.new()
		banner.text = news
		banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		banner.theme_type_variation = "BannerLabel"
		column.add_child(banner)
		if not Game.net.is_online() and not _recorded:
			_recorded = true
			Records.add_cup_place(grand_prix.cup.id, place, grand_prix.difficulty, grand_prix.two)
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 40)
	table.add_theme_constant_override("v_separation", 6)
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(table)
	for i in standings.size():
		for text in [RaceHud.ordinal(i + 1), standings[i][0], ("%d point" if standings[i][1] == 1 else "%d points") % standings[i][1]]:
			var cell := Label.new()
			cell.text = text
			cell.theme_type_variation = "LeadLabel"
			var person := people.find(standings[i][0])
			if person >= 0 and grand_prix.two:
				cell.add_theme_color_override("font_color", KartPicker.PLAYER_COLOURS[mini(person, KartPicker.PLAYER_COLOURS.size() - 1)])
			elif person >= 0:
				cell.theme_type_variation = "LeadAccentLabel"
			table.add_child(cell)
	if Game.net.is_online():
		if Game.net.is_host():
			var carry_on := MenuStyle.button("Back to the lobby" if done else "Next race", Game.net.back_to_lobby if done else Game.net.next_round)
			carry_on.custom_minimum_size.y = 84.0
			column.add_child(carry_on)
		else:
			column.add_child(MenuStyle.heading("Waiting for the host to carry on"))
	elif done:
		var two := grand_prix.two
		column.add_child(MenuStyle.button("Race another cup", func() -> void:
			Game.grand_prix = null
			Game.show_cups(two)))
	else:
		var next := TrackPath.load_file(grand_prix.track_path())
		next.apply_layout(grand_prix.mirrored, grand_prix.reversed)
		var button := MenuStyle.button("Next race", Game.next_grand_prix_race, next.name)
		button.theme_type_variation = "MainButton"
		button.custom_minimum_size.y = 84.0
		column.add_child(button)

	if over_podium and UiMotion.enabled(self) and _age < IGNORE_INPUT:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, UiMotion.FADE * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The heading, standings and next race button form one centred block.
func _between_races() -> VBoxContainer:
	theme = MenuStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := MenuStyle.backdrop()
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := SafeArea.new()
	add_child(safe)
	safe.pad(margin, true)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 620.0
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	var title := MenuStyle.ribbon(grand_prix.cup.name)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(title)
	MenuStyle.fit_ribbon(title, grand_prix.cup.name, 620.0)
	var button := MenuStyle.link("Back", go_back, "back")
	add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.position += Vector2(-24.0, 12.0)
	safe.watch(button)
	return column


## The page over the podium: a shade over the side the panel's on, and the
## panel with the cup's name and Back at the top. Returns the column to fill.
func _over_podium() -> VBoxContainer:
	theme = MenuStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view := get_viewport_rect().size
	var left := view.x - SIDE_WIDTH - SIDE_MARGIN
	var side := view.x / maxf(view.y, 1.0) >= SIDE_ASPECT and left >= view.x * SIDE_CLEAR
	clear = left / view.x if side else 1.0
	if side:
		var fade := Gradient.new()
		fade.set_color(0, Color(UiKit.INK, 0.0))
		fade.set_color(1, Color(UiKit.INK, 0.55))
		fade.set_offset(0, clear * 0.75)
		fade.set_offset(1, clear)
		var picture := GradientTexture2D.new()
		picture.gradient = fade
		picture.width = 256
		picture.height = 4
		var shade := TextureRect.new()
		shade.texture = picture
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		var shade := ColorRect.new()
		shade.color = Color(UiKit.INK, 0.45)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	var across := left if side else maxf(SIDE_MARGIN, (view.x - SIDE_WIDTH) * 0.5)
	margin.add_theme_constant_override("margin_left", int(across))
	margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN if side else across))
	margin.add_theme_constant_override("margin_top", int(SIDE_MARGIN))
	margin.add_theme_constant_override("margin_bottom", int(SIDE_MARGIN))
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := SafeArea.new()
	add_child(safe)
	safe.pad(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BuilderStyle.scrim(28.0, 18.0, 0.72))
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", UiKit.GAP_M)
	panel.add_child(outer)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP_M)
	outer.add_child(top)
	# The cup's name a little smaller than a page's title, to fit the panel.
	var ribbon := MenuStyle.ribbon(grand_prix.cup.name)
	ribbon.get_child(0).add_theme_font_size_override("font_size", TITLE_SIZE)
	top.add_child(ribbon)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var back_button := MenuStyle.link("Back", go_back, "back")
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(back_button)
	var inside := (view.x - across - margin.get_theme_constant("margin_right")) - panel.get_theme_stylebox("panel").get_minimum_size().x
	# A long name is cut short with dots rather than squeezing Back.
	var fit := func() -> void:
		MenuStyle.fit_ribbon(ribbon, grand_prix.cup.name, inside - back_button.get_combined_minimum_size().x - top.get_theme_constant("separation") * 2)
	fit.call_deferred()

	# The panel's as tall as what's in it, and scrolls if that's taller
	# than the screen.
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = inside
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	var tall := func() -> void:
		var room := view.y - SIDE_MARGIN * 2.0 - panel.get_theme_stylebox("panel").get_minimum_size().y - top.get_combined_minimum_size().y - outer.get_theme_constant("separation")
		scroll.custom_minimum_size.y = minf(column.get_combined_minimum_size().y, room)
	column.minimum_size_changed.connect(tall)
	tall.call_deferred()
	return column


## Leaving here quits the cup (and, online, the game).
func go_back() -> void:
	var two := grand_prix.two
	Game.grand_prix = null
	if Game.net.is_online():
		Game.net.leave()
		Game.show_multiplayer()
		return
	Game.show_cups(two)
