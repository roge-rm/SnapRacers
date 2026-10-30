class_name CupGrid
extends Control

## Every cup on one screen, each with its trophy and its courses' layouts. The
## trophy's light grey until you finish the cup in the top three, then it's
## gold, silver or bronze for your best place, with the levels you did it on.
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
## it's the cup for two on one phone.
static func best_place(id: String, two := false) -> int:
	var best := 0
	for level in Difficulty.LEVELS:
		var place := Records.best_cup_place(id, level, two)
		if place > 0 and (best == 0 or place < best):
			best = place
	return best


## Whether these are the Grand Prix cups for two, with their own trophies.
func _for_two() -> bool:
	return mode == Game.MODE_GRAND_PRIX and Game.cups_for_two


func _pick(id: String) -> void:
	if mode == Game.MODE_GRAND_PRIX:
		var two := Game.cups_for_two
		Game.mode = Game.MODE_GRAND_PRIX
		Game.show_kart_picker(Game.start_grand_prix.bind(id, two), Game.show_cups.bind(two), true, two)
	else:
		Game.show_course_grid(mode, alone, id)


func _cup_card(id: String, cup_name: String, spec: Dictionary, colour: Color, paths: Array) -> MenuCard:
	var card := MenuCard.new(colour)
	card.set_meta("cup", id)
	# A medal marker for each level, in order, coloured by your best place.
	var medals: Array[Color] = []
	var won := []
	var names: Array[String] = []
	for level in Difficulty.LEVELS:
		names.append(Difficulty.name_of(level))
		var place := Records.best_cup_place(id, level, _for_two())
		if place > 0 and place <= 3:
			medals.append(MEDALS[place])
			won.append("%s %s" % [Difficulty.name_of(level), ["", "gold", "silver", "bronze"][place]])
		else:
			medals.append(Color.TRANSPARENT)
	card.medals = medals
	card.medal_names = names
	card.tooltip_text = ", ".join(won)
	var finish := TrophyModel.finish_for(best_place(id, _for_two()))
	var key := TrophyThumbnails.key_of(spec, colour, finish)
	var trophy := card.picture(TrophyThumbnails.picture(key), TROPHY)
	_pictures.append(trophy)
	_trophies[key] = _trophies.get(key, []) + [trophy]
	Game.trophy_pictures().take(spec, colour, finish)
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
		Game.show_kart_picker(_starter(mine, id, Game.cups_for_two), Game.show_your_cups, true, Game.cups_for_two))
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 24)
	links.mouse_filter = MOUSE_FILTER_IGNORE
	card.content.add_child(links)
	for pair in [["Change", Game.show_cup_builder.bind(path)], ["Share", func() -> void: ShareWindow.open(mine.to_dict(), self)]]:
		var link := MenuStyle.chip(pair[0], pair[1])
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
