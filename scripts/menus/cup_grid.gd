class_name CupGrid
extends Control

## Every cup on one screen, each with its trophy and its courses' layouts. The
## trophy's light grey until you finish the cup in the top three, then it's
## gold, silver or bronze for your best place in the layout Reverse and
## Mirrored currently pick. Weather, Time, Reverse and Mirrored sit between
## the title and Back.
##
## In a Grand Prix you pick a cup to race. For a single race, a time trial,
## practice or a race for two you pick a cup and then one of its courses (see
## CourseGrid). Your own cups and courses are behind their own cards at the end.
## A Grand Prix from the Multiplayer menu is for two on this phone (see
## Game.cups_for_two), and both players pick a kart.

const TROPHIES := { 1: "Gold trophy", 2: "Silver trophy", 3: "Bronze trophy" }
const MEDALS := UiKit.MEDALS
## How wide a card can get, and how few go across.
const CARD_WIDTH := 200.0
const GAP := 14
## Most cups across, so 15 cards make three rows.
const MOST_ACROSS := 5
## The trophy's height on a card. The game's cups shrink it down to SMALLEST so
## every card fits on the screen, or grow it to BIGGEST to fill it.
const TROPHY := 106.0
const SMALLEST := 56.0
const BIGGEST := 180.0

var mode := Game.MODE_GRAND_PRIX
var alone := false
## Your own cups instead of the game's.
var yours := false

var _grid: GridContainer
var _column: VBoxContainer
var _conditions_row: HBoxContainer
var _weather: Button
var _time: Button
var _reversed: Button
var _mirrored: Button
var _trophies := {}
## Each card's trophy picture.
var _pictures: Array[TextureRect] = []


func _init(for_mode := Game.MODE_GRAND_PRIX, for_one := false, your_cups := false) -> void:
	mode = for_mode
	alone = for_one
	yours = your_cups


## Filed apart from the other cup lists in the pad's memory.
func focus_key() -> String:
	return "CupGrid/%s/%s/%s" % [mode, alone, yours]


func _ready() -> void:
	Game.cup_shown = ""
	var title := "Your cups" if yours else _title()
	_column = MenuStyle.page(self, title, go_back, _width(), true)
	# Your cups grows down from the top as cups are added.
	if yours:
		_column.get_parent().size_flags_vertical = Control.SIZE_FILL
	var column := _column
	_conditions_row = _make_conditions_row()
	_put_in_header(_conditions_row)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	column.add_child(_grid)
	var pictures := Game.trophy_pictures()
	pictures.ready_for.connect(_on_picture)
	if yours:
		for path in CupDesign.saved():
			var mine := CupDesign.load_file(path)
			if mine != null and mine.problem() == "":
				_your_cup(mine, path)
		var make := _card_with_words("Make a cup", "Pick its races from any course", Game.show_cup_builder.bind(""))
		make.set_meta("make", true)
		var add := _card_with_words("Add a cup", "From a code or a file", func() -> void:
			AddWindow.open(self, "Add a cup").done.connect(func(any_added: bool) -> void:
				if any_added:
					Game.show_your_cups()))
		add.set_meta("add", true)
	else:
		var number := 0
		for cup in GrandPrix.cups():
			var card := _cup_card(cup.id, cup.name, cup.get("trophy", {}), Color(cup.get("colour", "#a3a2a4")), cup.tracks.map(func(id): return Tracks.path_of(id)))
			number += 1
			card.number = "%02d" % number
			card.tapped.connect(_pick.bind(cup.id))
		if mode == Game.MODE_GRAND_PRIX:
			var mine := _card_with_words("Your cups", "Make your own, from any course", Game.show_your_cups)
			mine.set_meta("yours", true)
		else:
			var mine := _card_with_words("Your courses", "The ones you've built or been sent", Game.show_course_grid.bind(mode, alone, CourseGrid.YOURS))
			mine.set_meta("yours", true)
	# The margins grow to clear a camera hole, which changes the room.
	var margin := MenuStyle.page_margin(column)
	margin.resized.connect(_fit)
	(_column.get_parent().get_parent() as Control).resized.connect(_fit)
	margin.theme_changed.connect(_fit)
	_fit()
	PadFocus.focus_first(self)


func _title() -> String:
	match mode:
		Game.MODE_GRAND_PRIX:
			return "Grand Prix"
		Game.MODE_TIME_TRIAL:
			return "Time trial"
		Game.MODE_PRACTICE:
			return "Practice"
	return "Single race" if alone else "Pick a course"


## The page is as wide as the margins allow.
func _width() -> float:
	var room := get_viewport_rect().size.x - 80.0
	if _column != null:
		room = MenuStyle.page_room(_column)
	return maxf(room, CARD_WIDTH * 2.0 + GAP)


## As many cards across as fit. The game's cups make even rows of up to five,
## with their trophies sized so the rows fill the screen's height.
func _fit() -> void:
	var room := _width()
	_column.custom_minimum_size.x = room
	var across := maxi(2, floori((room + GAP) / (CARD_WIDTH + GAP)))
	var count := _grid.get_child_count()
	if not yours:
		across = mini(across, maxi(2, ceili(count / ceilf(count / float(MOST_ACROSS)))))
	_grid.columns = across
	var width := (room - GAP * (across - 1)) / across
	for card in _grid.get_children():
		card.custom_minimum_size.x = width
	if not yours:
		_fit_height(ceili(count / float(across)))


## Sizes the trophies so this many rows of cards fill the height under the
## title. Past SMALLEST the page scrolls instead.
func _fit_height(rows: int) -> void:
	var scroll := _column.get_parent().get_parent() as Control
	var high := scroll.size.y
	if high <= 0.0 or rows < 1 or _pictures.is_empty():
		return
	# What's on a card besides its trophy, with the card's margins of 10.
	var content := (_grid.get_child(0) as MenuCard).content
	var rest := 20.0 + content.get_theme_constant("separation") * (content.get_child_count() - 1)
	for child in content.get_children():
		if child != _pictures[0]:
			rest += child.get_combined_minimum_size().y
	var each := (high - GAP * (rows - 1)) / rows
	var picture := clampf(floorf(each - rest), SMALLEST, BIGGEST)
	for rect in _pictures:
		rect.custom_minimum_size.y = picture


## Your best place in a cup at any level, for its trophy, or 0. With `two`
## it's the cup for two on one phone. `layout` is reverse, mirrored, or both;
## empty is ordinary.
static func best_place(id: String, two := false, layout := "") -> int:
	var best := 0
	for level in Difficulty.LEVELS:
		var place := Records.best_cup_place(id, level, two, layout)
		if place > 0 and (best == 0 or place < best):
			best = place
	return best


## Gold, silver, bronze or clear for each difficulty, in the picked layout.
static func medals_for(id: String, two := false, layout := "") -> Array[Color]:
	var medals: Array[Color] = []
	for level in Difficulty.LEVELS:
		var place := Records.best_cup_place(id, level, two, layout)
		medals.append(MEDALS[place] if place > 0 and place <= 3 else Color.TRANSPARENT)
	return medals


## Whether these are the Grand Prix cups for two, with their own trophies.
func _for_two() -> bool:
	return mode == Game.MODE_GRAND_PRIX and Game.cups_for_two


func _pick(id: String) -> void:
	if mode == Game.MODE_GRAND_PRIX:
		var two := Game.cups_for_two
		Game.mode = Game.MODE_GRAND_PRIX
		Game.show_race_setup(Game.start_grand_prix.bind(id, two), Game.show_cups.bind(two), true, two)
	else:
		Game.show_course_grid(mode, alone, id)


func _cup_card(id: String, cup_name: String, spec: Dictionary, colour: Color, paths: Array) -> MenuCard:
	var card := MenuCard.new(colour)
	card.set_meta("cup", id)
	card.set_meta("trophy_spec", spec)
	card.set_meta("trophy_colour", colour)
	var names: Array[String] = []
	for level in Difficulty.LEVELS:
		names.append(Difficulty.name_of(level))
	card.medal_names = names
	var trophy := card.picture(null, TROPHY)
	_pictures.append(trophy)
	card.set_meta("trophy", trophy)
	_paint_card(card)
	card.line(cup_name)
	var layouts := HBoxContainer.new()
	layouts.add_theme_constant_override("separation", 4)
	layouts.mouse_filter = MOUSE_FILTER_IGNORE
	card.content.add_child(layouts)
	for path in paths:
		var view := CourseOutlineView.new(path, colour.lightened(0.3))
		view.thickness = 1.6
		view.custom_minimum_size = Vector2(0.0, 40.0)
		view.size_flags_horizontal = SIZE_EXPAND_FILL
		layouts.add_child(view)
	_grid.add_child(card)
	return card


func _your_cup(mine: CupDesign, path: String) -> void:
	var id := CupDesign.id_of(path)
	var paths := mine.races.map(func(r): return str(r.from))
	var card := _cup_card(id, mine.name, TrophyModel.spec_for(mine.name), TrophyModel.colour_for(mine.name), paths)
	card.tapped.connect(func() -> void:
		Game.mode = Game.MODE_GRAND_PRIX
		Game.show_race_setup(_starter(mine, id, Game.cups_for_two), Game.show_your_cups, true, Game.cups_for_two))
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_right", MenuCard.EDGE)
	inset.mouse_filter = MOUSE_FILTER_IGNORE
	card.content.add_child(inset)
	var links := VBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 6)
	links.mouse_filter = MOUSE_FILTER_IGNORE
	inset.add_child(links)
	for pair in [["Change", Game.show_cup_builder.bind(path)], ["Share", func() -> void: ShareWindow.open(mine.to_dict(), self)]]:
		var link := MenuStyle.chip(pair[0], pair[1])
		link.custom_minimum_size.y = 40.0
		# The card's words ignore the mouse, but these have to be tapped.
		link.mouse_filter = MOUSE_FILTER_STOP
		links.add_child(link)


## A card with only words on it, for the ones at the end.
func _card_with_words(text: String, more: String, action: Callable) -> MenuCard:
	var card := MenuCard.new()
	card.content.alignment = BoxContainer.ALIGNMENT_CENTER
	card.plus()
	card.line(text)
	card.line(more, false)
	card.tapped.connect(action)
	_grid.add_child(card)
	return card


## What starts a cup of yours once a kart's picked. Its courses are put out to
## race then, and it's made here because this screen is gone by then.
static func _starter(mine: CupDesign, id: String, two: bool) -> Callable:
	return func() -> void: Game.start_grand_prix(mine.to_cup(id), two)


## Weather, time, reverse and mirrored, in the header between the title and Back.
func _make_conditions_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_weather = MenuStyle.button("", func() -> void:
		Game.set_weather(Conditions.next_pick(Game.weather(), Conditions.WEATHERS))
		_show_conditions())
	_time = MenuStyle.button("", func() -> void:
		Game.set_time_of_day(Conditions.next_pick(Game.time_of_day(), Conditions.TIMES))
		_show_conditions())
	_reversed = MenuStyle.button("", func() -> void:
		Game.set_reversed(not Game.reversed())
		_show_conditions())
	_mirrored = MenuStyle.button("", func() -> void:
		Game.set_mirrored(not Game.mirrored())
		_show_conditions())
	for button in [_weather, _time, _reversed, _mirrored]:
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(button)
	_show_conditions()
	return row


## Puts the conditions in the title row, in the space the red bars used.
func _put_in_header(row: HBoxContainer) -> void:
	var outer: VBoxContainer = _column.get_parent().get_parent().get_parent()
	var top: HBoxContainer = outer.get_child(0)
	var back: Control = top.get_child(top.get_child_count() - 1)
	for child in top.get_children():
		if child is MenuStyle.Bars:
			child.visible = false
			child.custom_minimum_size = Vector2.ZERO
			child.size_flags_horizontal = SIZE_SHRINK_BEGIN
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.size_flags_vertical = SIZE_SHRINK_CENTER
	back.size_flags_horizontal = SIZE_SHRINK_END
	top.add_child(row)
	top.move_child(row, 1)


func _show_conditions() -> void:
	_weather.text = Conditions.WEATHER_NAMES[Game.weather()]
	_time.text = Conditions.TIME_NAMES[Game.time_of_day()]
	_reversed.text = "Reverse"
	_mirrored.text = "Mirrored"
	MenuStyle.mark(_reversed, Game.reversed())
	MenuStyle.mark(_mirrored, Game.mirrored())
	if _grid != null:
		_paint_all()


func _paint_all() -> void:
	for card in _grid.get_children():
		if card.has_meta("cup"):
			_paint_card(card)


func _paint_card(card: MenuCard) -> void:
	var id: String = card.get_meta("cup")
	var two := _for_two()
	var layout := Records.layout_key(Game.reversed(), Game.mirrored())
	var medals := medals_for(id, two, layout)
	card.medals = medals
	var won: PackedStringArray = []
	for i in medals.size():
		if medals[i].a > 0.0:
			var place := Records.best_cup_place(id, Difficulty.LEVELS[i], two, layout)
			won.append("%s %s" % [Difficulty.name_of(Difficulty.LEVELS[i]), ["", "gold", "silver", "bronze"][place]])
	card.tooltip_text = ", ".join(won)
	var spec: Dictionary = card.get_meta("trophy_spec")
	var colour: Color = card.get_meta("trophy_colour")
	var finish := TrophyModel.finish_for(best_place(id, two, layout))
	var key := TrophyThumbnails.key_of(spec, colour, finish)
	var trophy: TextureRect = card.get_meta("trophy")
	for list in _trophies.values():
		list.erase(trophy)
	trophy.texture = TrophyThumbnails.picture(key)
	_trophies[key] = _trophies.get(key, []) + [trophy]
	Game.trophy_pictures().take(spec, colour, finish)


func _on_picture(key: String, picture: Texture2D) -> void:
	for rect in _trophies.get(key, []):
		if is_instance_valid(rect):
			rect.texture = picture


func go_back() -> void:
	if yours:
		Game.show_cups(Game.cups_for_two)
	elif mode == Game.MODE_GRAND_PRIX and Game.cups_for_two:
		Game.show_multiplayer()
	elif mode == Game.MODE_RACE and not alone:
		Game.show_multiplayer()
	else:
		Game.show_single_player()
