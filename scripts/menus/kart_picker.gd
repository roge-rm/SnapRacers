class_name KartPicker
extends Control

## Pick a kart before a race. Your karts come first: the one in the garage,
## the ones you've saved and a last card to make a new one. Then the stock
## karts. Each card has a picture of the kart, its name and its weight, and
## one panel at the top shows the bars for the kart picked or the one a
## controller is on. In a race against the AI, Easy, Normal, Hard and Expert
## sit in the header between the title and Back. It remembers what you
## picked last time. A card at the top shows who's driving, and tapping it
## opens the driver cards to change them.
##
## Two on one phone each pick in turn on this screen, player 1 first, before
## the cups or courses are picked (see Game.show_two_setup), with
## a big tag in their own colour saying whose turn it is. Their names are on
## the Multiplayer menu.

## Cards are the size of the driver picker's, as many to a row.
const COLUMNS := DriverGrid.COLUMNS
const CARD := DriverGrid.CARD
## How much of a kart's picture to show, from its middle, so the kart fills
## more of the card.
const ZOOM := 0.8
## How wide a card's name and weight can be, to stay clear of its slanted
## right edge at the bottom.
const WORDS := CARD.x - 44.0
## The bars in the stats panel, as [label, what they measure].
const BARS := [["Speed", "speed"], ["Pull", "pull"], ["Grip", "grip"], ["Control", "control"], ["Off-road", "offroad"]]
## Each player's colour, for their tag when two are picking.
const PLAYER_COLOURS := UiKit.PLAYERS

## The stock karts don't change while the game runs, so they're loaded and
## measured once, as key -> [KartDesign, measures, weight].
static var _stock := {}

var _go: Callable
var _back: Callable
## Each kart's card, as key -> card.
var _cards := {}
var _chosen := ""
var _race: Button
var _pictures: KartThumbnails
## Who drives the karts in the pictures, the driver this player picked.
var _driver: CharacterDesign
## Added to each kart's key for its picture, since it's kept per driver.
var _look := ""
## Each card's kart, as key -> KartDesign.
var _designs := {}
## How each card's kart measures up (see _measure()), and its weight in kg.
var _measures := {}
var _masses := {}
## The lowest and highest of each measure across every kart here.
var _ranges := {}
## The stats panel's bars, as measure -> StatBar.
var _bars := {}
var _stats_grid: GridContainer
var _top: HBoxContainer
## The card at the top with who's driving, which opens the driver cards.
var driver_card: DriverCard
## The New kart card.
var new_card: Button
## The two sections' grids.
var yours: GridContainer
var stock: GridContainer
## This same screen again, for coming back from making a new driver or kart.
## With none it's a new kart picker like this one.
var here := Callable()
var _ai := false
var _levels := {}
var _difficulty_row: HBoxContainer
## Which of two players on this phone is picking, 1 or 2, or 0 when it's one.
var player := 0
## The scroll the cards are in, once they're laid out.
var _scroll: ScrollContainer


func _init(go: Callable, back: Callable, ai := false, for_player := 0) -> void:
	_go = go
	_back = back
	_ai = ai
	player = for_player


## Filed apart from the other player's picker in the pad's memory.
func focus_key() -> String:
	return "KartPicker/%d/%s" % [player, _ai]


func _ready() -> void:
	# With two, the PLAYER tag under it says whose turn it is.
	var title := "Pick a kart" if player == 0 else "Pick your kart"
	var column := MenuStyle.page(self, title, go_back, DriverGrid.width())
	_driver = CharacterDesign.for_key(Game.driver_choice(player == 2))
	_look = "@" + DriverPortraits.key_of(_driver)
	_pictures = Game.kart_pictures()
	_pictures.ready_for.connect(_show_picture)

	# Who's driving, the picked kart's bars and the button to go, which stay
	# put above the cards as you scroll, in the page's outer column.
	_top = HBoxContainer.new()
	_top.add_theme_constant_override("separation", 20)
	var outer: VBoxContainer = column.get_parent().get_parent().get_parent()
	outer.add_child(_top)
	outer.move_child(_top, 1)
	if _ai and player != 2:
		_difficulty_row = _make_difficulty_row()
		_put_in_header(_difficulty_row, outer)
		_show_level(Game.difficulty())
	if player > 0:
		_top.add_child(_player_tag())
	driver_card = DriverCard.new()
	driver_card.tapped.connect(open_drivers)
	_top.add_child(driver_card)
	driver_card.show_driver(_driver)
	_top.add_child(_stats_panel())
	_race = MenuStyle.button("Race" if player == 0 else "Next", func() -> void: _go.call())
	_race.custom_minimum_size.x = 220.0
	_race.theme_type_variation = "MainButton"
	_top.add_child(_race)
	_top.resized.connect(_fit_stats)
	# Up from Race goes to Back above it.
	var header: HBoxContainer = outer.get_child(0)
	var back: Control = header.get_child(header.get_child_count() - 1)
	_race.focus_neighbor_top = _race.get_path_to(back)

	var same_as_garage: Array[String] = []
	var entries := own_karts(same_as_garage)
	var stock_entries := stock_karts()
	for entry in entries:
		var stats := KartStats.compute(entry[1])
		_measures[entry[0]] = _measure(entry[1], stats)
		_masses[entry[0]] = stats.mass
	for key in _stock:
		_measures[key] = _stock[key][1]
		_masses[key] = _stock[key][2]
	_ranges = _ranges_of(_measures.values())
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 12)
	column.add_child(sections)
	sections.add_child(MenuStyle.heading("Your karts"))
	yours = _grid()
	sections.add_child(yours)
	for entry in entries:
		yours.add_child(_card(entry[0], entry[1]))
	new_card = _new_card()
	yours.add_child(new_card)
	sections.add_child(MenuStyle.heading("Stock karts"))
	stock = _grid()
	sections.add_child(stock)
	for entry in stock_entries:
		stock.add_child(_card(entry[0], entry[1]))
	MenuStyle.back_at_bottom(column, go_back)
	var last := Game.player_two_kart() if player == 2 else Game.kart_choice()
	if last in same_as_garage:
		last = Game.OWN_KART
	_choose(last if _cards.has(last) and not _cards[last].disabled else Game.DEFAULT_STOCK)
	_scroll_to_chosen()


## Your karts, as [pick key, KartDesign]: the one in the garage, then the saved
## ones. A saved kart that's the same as the one in the garage isn't shown
## twice, and its key goes in `same_as_garage`, since picking it last time
## picks the garage card.
static func own_karts(same_as_garage: Array[String] = []) -> Array:
	var entries := [[Game.OWN_KART, Game.design]]
	var garage_json := JSON.stringify(Game.design.to_dict())
	for path in KartDesign.saved_paths():
		var saved := KartDesign.load_file(path)
		if saved != null and JSON.stringify(saved.to_dict()) == garage_json:
			same_as_garage.append(KartDesign.key_for(path))
			continue
		entries.append([KartDesign.key_for(path), saved])
	return entries


## The stock karts, as [pick key, KartDesign].
static func stock_karts() -> Array:
	var keys := Game.stock_keys()
	if _stock.size() != keys.size() or not keys.all(func(key: String) -> bool: return _stock.has(key)):
		_stock.clear()
		for key in keys:
			var design := Game.stock_kart(key)
			var stats := KartStats.compute(design)
			_stock[key] = [design, _measure(design, stats), stats.mass]
	return _stock.keys().map(func(key: String) -> Array: return [key, _stock[key][0]])


## Asks for every kart's picture with player 1's driver, in the background, so
## they're mostly ready before the picker opens. The splash does this as it
## hands over to the menu.
static func warm_pictures() -> void:
	var driver := CharacterDesign.for_key(Game.driver_choice())
	var look := "@" + DriverPortraits.key_of(driver)
	for entry in own_karts() + stock_karts():
		Game.kart_pictures().take_later(entry[0] + look, entry[1], driver)


func go_back() -> void:
	_back.call()


## Start on a controller does what the Race or Next button does (PadFocus
## calls this).
func on_start() -> void:
	if _race != null and not _race.disabled:
		_race.pressed.emit()


## A big tag in the player's colour saying whose turn it is to pick.
func _player_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiKit.pad(UiKit.slant(Game.tag_colour(player - 1)), 22, 4, UiKit.LEAN, 48.0))
	tag.size_flags_vertical = SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = "PLAYER %d" % player
	label.theme_type_variation = "TagLabel"
	tag.add_child(label)
	return tag


## Easy, Normal, Hard and Expert, in the header between the title and Back.
func _make_difficulty_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for level in Difficulty.LEVELS:
		var button := MenuStyle.button(Difficulty.name_of(level), _show_level.bind(level))
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.size_flags_vertical = SIZE_SHRINK_CENTER
		button.set_meta("level", level)
		row.add_child(button)
		_levels[level] = button
	return row


## Puts the difficulty picks in the title row, in the space the red bars used.
func _put_in_header(row: HBoxContainer, outer: VBoxContainer) -> void:
	var header: HBoxContainer = outer.get_child(0)
	var back: Control = header.get_child(header.get_child_count() - 1)
	for child in header.get_children():
		if child is MenuStyle.Bars:
			child.visible = false
			child.custom_minimum_size = Vector2.ZERO
			child.size_flags_horizontal = SIZE_SHRINK_BEGIN
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.size_flags_vertical = SIZE_SHRINK_CENTER
	back.size_flags_horizontal = SIZE_SHRINK_END
	header.add_child(row)
	header.move_child(row, 1)
	# The title is cut short with dots so the picks and Back always fit.
	var title_box: PanelContainer = header.get_child(0)
	var title := (title_box.get_child(0) as Label).text
	var margin := MenuStyle.page_margin(outer)
	var fit := func() -> void:
		var room := MenuStyle.page_room(outer) - row.get_combined_minimum_size().x - back.get_combined_minimum_size().x - header.get_theme_constant("separation") * 3
		MenuStyle.fit_ribbon(title_box, title, room)
	margin.resized.connect(fit)
	margin.theme_changed.connect(fit)
	fit.call_deferred()


func _show_level(level: String) -> void:
	Game.set_difficulty(level)
	for other in _levels:
		MenuStyle.mark(_levels[other], other == level)


func _choose(key: String) -> void:
	_chosen = key
	if player == 2:
		Game.set_setting("race", "player_two", key)
	else:
		Game.set_kart_choice(key)
	for other in _cards:
		MenuStyle.mark(_cards[other], other == key)
	show_stats(key)


## The picked kart, as its pick key.
func chosen() -> String:
	return _chosen


## Scrolls to the picked card once it's laid out, since it can be down in the
## stock karts.
func _scroll_to_chosen() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var card: Control = _cards.get(_chosen)
	var node: Node = card
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	if node != null and is_instance_valid(card):
		var scroll := node as ScrollContainer
		_scroll = scroll
		scroll.ensure_control_visible(card)
		_hurry_shown.call_deferred(scroll)
		scroll.get_v_scroll_bar().value_changed.connect(_hurry_shown.bind(scroll).unbind(1))


## Takes the pictures of the cards on the screen first.
func _hurry_shown(scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll):
		return
	var seen := scroll.get_global_rect()
	var keys := []
	for key in _cards:
		if (_cards[key] as Control).get_global_rect().intersects(seen):
			keys.append(key + _look)
	_pictures.hurry(keys)


## How a kart measures up on each bar, before it's compared with the others.
static func _measure(design: KartDesign, stats: KartStats = null) -> Dictionary:
	if stats == null:
		stats = KartStats.compute(design)
	return {
		"speed": stats.top_speed(),
		"pull": stats.pull(),
		"grip": stats.cornering() + stats.lift_area * 0.5,
		"control": stats.control,
		"offroad": stats.offroad,
	}


## The lowest and highest of each measure across every kart.
static func _ranges_of(all: Array) -> Dictionary:
	var out := {}
	for bar in BARS:
		var values: Array = all.map(func(m): return m[bar[1]])
		out[bar[1]] = Vector2(values.min(), values.max())
	return out


## How full each bar is for this kart, 0.12 to 1, as measure -> amount.
func amounts_for(design: KartDesign, measured := {}) -> Dictionary:
	if measured.is_empty():
		measured = _measure(design)
	var out := {}
	for bar in BARS:
		var range: Vector2 = _ranges[bar[1]]
		var amount := inverse_lerp(range.x, range.y, measured[bar[1]]) if range.y > range.x else 1.0
		out[bar[1]] = lerpf(0.12, 1.0, clampf(amount, 0.0, 1.0))
	return out


## Shows this kart's bars in the stats panel.
func show_stats(key: String) -> void:
	if _bars.is_empty() or not _designs.has(key) or not is_inside_tree():
		return
	var amounts := amounts_for(_designs[key], _measures.get(key, {}))
	for bar in BARS:
		_bars[bar[1]].amount = amounts[bar[1]]
		_bars[bar[1]].queue_redraw()
	_stats_grid.set_meta("kart", key)


## The bars for the picked kart, between the driver card and Race.
func _stats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Stats"
	panel.add_theme_stylebox_override("panel", UiKit.pad(UiKit.slant(Color(UiKit.PANEL, 0.88), UiKit.CARD_LEAN, Color(1, 1, 1, 0.14), 1), 22, 6, UiKit.CARD_LEAN, DriverCard.SIZE.y))
	panel.custom_minimum_size.y = DriverCard.SIZE.y
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_vertical = SIZE_SHRINK_CENTER
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 24)
	_stats_grid.add_theme_constant_override("v_separation", 2)
	_stats_grid.size_flags_vertical = SIZE_SHRINK_CENTER
	panel.add_child(_stats_grid)
	for bar in BARS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL
		_stats_grid.add_child(row)
		var label := Label.new()
		label.text = bar[0]
		label.custom_minimum_size.x = 72.0
		label.theme_type_variation = "SmallLabel"
		row.add_child(label)
		var meter := StatBar.new(0.5)
		meter.custom_minimum_size.x = 40.0
		meter.size_flags_horizontal = SIZE_EXPAND_FILL
		meter.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(meter)
		_bars[bar[1]] = meter
	return panel


## One column of bars when the panel's squeezed, like two players' tag and
## name beside it with the camera hole, else two.
func _fit_stats() -> void:
	var room := _top.size.x
	for child in _top.get_children():
		if child is Control and child.visible and child != _stats_grid.get_parent():
			room -= child.get_combined_minimum_size().x
	room -= _top.get_theme_constant("separation") * (_top.get_child_count() - 1)
	var columns := 2 if room >= 330.0 else 1
	if _stats_grid.columns != columns:
		_stats_grid.columns = columns


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", DriverGrid.GAP)
	grid.add_theme_constant_override("v_separation", DriverGrid.GAP)
	return grid


## A card like a driver card: the kart's picture, its name and its weight.
## Your own karts that can't be driven say why and can't be picked.
func _card(key: String, design: KartDesign) -> ScrollButton:
	var card := _base_card(design.name)
	card.set_meta("kart", key)
	var own := key == Game.OWN_KART or key.begins_with(KartDesign.SAVED_KEY)
	var problems: Array[String] = design.problems() if own else ([] as Array[String])
	var line := Label.new()
	line.name = "Weight"
	line.text = "%d kg" % roundi(_masses[key] if _masses.has(key) else KartStats.compute(design).mass) if problems.is_empty() else problems[0]
	line.theme_type_variation = "SmallLabel" if problems.is_empty() else "DangerLabel"
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.custom_minimum_size.x = WORDS
	line.size_flags_horizontal = SIZE_SHRINK_BEGIN
	line.mouse_filter = MOUSE_FILTER_IGNORE
	card.get_node("Box/Words/Lines").add_child(line)
	card.disabled = not problems.is_empty()
	card.tapped.connect(_choose.bind(key))
	card.focus_entered.connect(show_stats.bind(key))
	card.focus_exited.connect(func() -> void: show_stats(_chosen))
	_designs[key] = design
	_cards[key] = card
	_set_picture(card, _pictures.take(key + _look, design, _driver))
	return card


func _new_card() -> ScrollButton:
	var card := _base_card("New kart")
	card.set_meta("new_kart", true)
	var plus := Label.new()
	plus.text = "+"
	plus.theme_type_variation = "HeadingLabel"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", 96)
	plus.mouse_filter = MOUSE_FILTER_IGNORE
	plus.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	card.get_node("Box/Picture").add_child(plus)
	card.tapped.connect(new_kart)
	return card


## Same size and layout as DriverGrid's cards.
func _base_card(title: String) -> ScrollButton:
	var card := ScrollButton.new()
	card.theme_type_variation = "CardButton"
	card.custom_minimum_size = CARD
	card.focus_mode = FOCUS_ALL
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 10.0
	box.offset_right = -10.0
	box.offset_top = 10.0
	box.offset_bottom = -10.0
	card.add_child(box)
	var picture := TextureRect.new()
	picture.name = "Picture"
	# It gives up some height for a name on two or three lines.
	picture.custom_minimum_size = Vector2(0, 140)
	picture.size_flags_vertical = SIZE_EXPAND_FILL
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(picture)
	# The words keep the driver cards' inset.
	var words := MarginContainer.new()
	words.name = "Words"
	words.add_theme_constant_override("margin_left", 6)
	words.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(words)
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_child(lines)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = title
	name_label.theme_type_variation = "LeadLabel"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(WORDS, 0)
	name_label.size_flags_horizontal = SIZE_SHRINK_BEGIN
	# A long name stops at two lines, with dots.
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	lines.add_child(name_label)
	return card


## Puts a kart's picture on its card, cut in to the middle of it.
func _set_picture(card: Control, picture: Texture2D) -> void:
	var rect: TextureRect = card.get_node("Box/Picture")
	if picture == null:
		rect.texture = null
		return
	var zoomed := AtlasTexture.new()
	zoomed.atlas = picture
	var whole := Vector2(picture.get_size())
	zoomed.region = Rect2(whole * (1.0 - ZOOM) * 0.5, whole * ZOOM)
	rect.texture = zoomed


func _show_picture(look_key: String, picture: Texture2D) -> void:
	var key := look_key.trim_suffix(_look)
	if look_key.ends_with(_look) and _cards.has(key):
		_set_picture(_cards[key], picture)


## Opens the garage with a new kart, and comes back here with it picked once
## it's saved.
func new_kart() -> void:
	var back := here
	if not back.is_valid():
		back = func() -> void:
			var again := KartPicker.new(_go, _back, _ai, player)
			Game._swap(again)
	KartPicker.make_new_kart(player == 2, back)


## The garage with an empty kart under a name of its own. Leaving it saves it
## with your karts if it has any parts, under a name of its own if a saved one
## has its name, picks it for player 1 or (with `second`) player 2 if it can
## be driven, and goes to `done`. If Save was used, it saves over that file.
static func make_new_kart(second: bool, done: Callable) -> Garage:
	var fresh := KartDesign.new()
	fresh.name = unique_kart_name("New kart")
	var garage := Garage.new("", done)
	garage.start = fresh
	garage.made = func(made: KartDesign) -> void:
		var path := ""
		if garage.saved_path != "":
			path = str(CreationLibrary.save(Sharing.KART, garage.saved_path, made.to_dict(), true).get("path", ""))
		elif not made.parts.is_empty():
			made.name = unique_kart_name(made.name)
			path = str(CreationLibrary.save(Sharing.KART, Sharing.path_for(Sharing.KART, made.name), made.to_dict()).get("path", ""))
		if path != "" and made.problems().is_empty():
			if second:
				Game.set_setting("race", "player_two", KartDesign.key_for(path))
			else:
				Game.set_kart_choice(KartDesign.key_for(path))
		done.call()
	Game._swap(garage)
	return garage


## `wanted` if no saved kart has its file, or else "<wanted> 2", "<wanted> 3"
## and so on.
static func unique_kart_name(wanted: String) -> String:
	wanted = wanted.strip_edges()
	if wanted == "":
		wanted = "My kart"
	var taken := func(kart_name: String) -> bool:
		return FileAccess.file_exists(Sharing.path_for(Sharing.KART, kart_name))
	if not taken.call(wanted):
		return wanted
	var n := 2
	while taken.call("%s %d" % [wanted, n]):
		n += 1
	return "%s %d" % [wanted, n]


## Opens the driver cards in a window over this screen.
func open_drivers() -> DriverWindow:
	var taken := Game.driver_choice() if player == 2 else ""
	var window := DriverWindow.open(self, Game.driver_choice(player == 2), taken, player)
	window.picked.connect(pick_driver)
	window.new_driver.connect(func() -> void:
		var back := here
		if not back.is_valid():
			back = func() -> void:
				var again := KartPicker.new(_go, _back, _ai, player)
				Game._swap(again)
		Game.show_new_driver(player == 2, back))
	return window


## Races this player as the driver with this pick key, and takes the kart
## pictures again with them in.
func pick_driver(key: String) -> void:
	Game.set_driver_choice(key, player == 2)
	_driver = CharacterDesign.for_key(key)
	var old_look := _look
	_look = "@" + DriverPortraits.key_of(_driver)
	if old_look != _look:
		_pictures.drop_look(old_look)
	driver_card.show_driver(_driver)
	for kart in _cards:
		var picture := _pictures.take(kart + _look, _designs[kart], _driver)
		if picture != null:
			_set_picture(_cards[kart], picture)
	if _scroll != null:
		_hurry_shown(_scroll)


## A short bar showing how a kart compares, filled from the left.
class StatBar:
	extends Control

	var amount := 0.5

	func _init(value: float) -> void:
		amount = value
		custom_minimum_size = Vector2(0, 10)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var middle := size.y * 0.5
		var bar := Rect2(0, middle - 5, size.x, 10)
		UiKit.draw_slant(self, bar, UiKit.EDGE)
		UiKit.draw_slant(self, Rect2(bar.position, Vector2(bar.size.x * amount, bar.size.y)), UiKit.BLUE)
