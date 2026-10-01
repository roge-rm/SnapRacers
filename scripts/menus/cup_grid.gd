class_name CupGrid
extends Control

## Every cup on one screen, each with its trophy and its courses' layouts. The
## trophy's light grey until you finish the cup in the top three, then it's
## gold, silver or bronze for your best place, with the levels you did it on.
##
## In a Grand Prix you pick a cup to race. For a single race, a time trial,
## practice or a race for two you pick a cup and then one of its courses (see
## CourseGrid). Your own cups and courses are behind their own cards at the end.

const TROPHIES := { 1: "Gold trophy", 2: "Silver trophy", 3: "Bronze trophy" }
const MEDALS := { 1: Color("#f2b632"), 2: Color("#cdd3db"), 3: Color("#c47a45") }
## How wide a card can get, and how few go across.
const CARD_WIDTH := 220.0
const GAP := 14

var mode := Game.MODE_GRAND_PRIX
var alone := false
## Your own cups instead of the game's.
var yours := false

var _grid: GridContainer
var _trophies := {}


func _init(for_mode := Game.MODE_GRAND_PRIX, for_one := false, your_cups := false) -> void:
	mode = for_mode
	alone = for_one
	yours = your_cups


func _ready() -> void:
	Game.cup_shown = ""
	var title := "Your cups" if yours else _title()
	var column := MenuStyle.page(self, title, go_back, _width())
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
	else:
		for cup in GrandPrix.cups():
			var card := _cup_card(cup.id, cup.name, cup.get("trophy", {}), Color(cup.get("colour", "#a3a2a4")), cup.tracks.map(func(id): return Tracks.path_of(id)))
			card.tapped.connect(_pick.bind(cup.id))
		if mode == Game.MODE_GRAND_PRIX:
			var mine := _card_with_words("Your cups", "Make your own, from any course", Game.show_your_cups)
			mine.set_meta("yours", true)
		elif not CourseGrid.your_courses().is_empty():
			var mine := _card_with_words("Your courses", "The ones you've built", Game.show_course_grid.bind(mode, alone, CourseGrid.YOURS))
			mine.set_meta("yours", true)
	resized.connect(_fit)
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


## The page is as wide as the screen allows.
func _width() -> float:
	return maxf(get_viewport_rect().size.x - 80.0, CARD_WIDTH * 2.0 + GAP)


## As many cards across as fit. The game's cups go no more than half across,
## so they make two even rows that fill the screen.
func _fit() -> void:
	var room := _width()
	var across := maxi(2, floori((room + GAP) / (CARD_WIDTH + GAP)))
	if not yours:
		across = mini(across, maxi(2, ceili(_grid.get_child_count() / 2.0)))
	_grid.columns = across
	var width := (room - GAP * (across - 1)) / across
	for card in _grid.get_children():
		card.custom_minimum_size.x = width


## Your best place in a cup at any level, for its trophy, or 0.
static func best_place(id: String) -> int:
	var best := 0
	for level in Difficulty.LEVELS:
		var place := Records.best_cup_place(id, level)
		if place > 0 and (best == 0 or place < best):
			best = place
	return best


func _pick(id: String) -> void:
	if mode == Game.MODE_GRAND_PRIX:
		Game.show_kart_picker(Game.start_grand_prix.bind(id), Game.show_cups, true)
	else:
		Game.show_course_grid(mode, alone, id)


func _cup_card(id: String, cup_name: String, spec: Dictionary, colour: Color, paths: Array) -> MenuCard:
	var card := MenuCard.new()
	card.set_meta("cup", id)
	var won := []
	for level in Difficulty.LEVELS:
		var place := Records.best_cup_place(id, level)
		if place > 0 and place <= 3:
			won.append([level, place])
	var finish := TrophyModel.finish_for(best_place(id))
	var key := TrophyThumbnails.key_of(spec, colour, finish)
	var trophy := card.picture(TrophyThumbnails.picture(key), 106.0)
	_trophies[key] = _trophies.get(key, []) + [trophy]
	Game.trophy_pictures().take(spec, colour, finish)
	card.line(cup_name, 22)
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
	var levels := HBoxContainer.new()
	levels.alignment = BoxContainer.ALIGNMENT_CENTER
	levels.add_theme_constant_override("separation", 8)
	levels.mouse_filter = MOUSE_FILTER_IGNORE
	levels.custom_minimum_size.y = 22.0
	card.content.add_child(levels)
	for done in won:
		var label := Label.new()
		label.text = Difficulty.name_of(done[0])
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", MEDALS[done[1]])
		levels.add_child(label)
	_grid.add_child(card)
	return card


func _your_cup(mine: CupDesign, path: String) -> void:
	var id := CupDesign.id_of(path)
	var paths := mine.races.map(func(r): return str(r.from))
	var card := _cup_card(id, mine.name, TrophyModel.spec_for(mine.name), TrophyModel.colour_for(mine.name), paths)
	card.tapped.connect(func() -> void:
		Game.show_kart_picker(_starter(mine, id), Game.show_your_cups, true))
	var change := MenuStyle.link("Change", Game.show_cup_builder.bind(path))
	change.add_theme_font_size_override("font_size", 20)
	change.size_flags_horizontal = SIZE_SHRINK_CENTER
	card.content.add_child(change)
	# The card's words ignore the mouse, but this has to be tapped.
	change.mouse_filter = MOUSE_FILTER_STOP


## A card with only words on it, for the ones at the end.
func _card_with_words(text: String, more: String, action: Callable) -> MenuCard:
	var card := MenuCard.new()
	var gap := Control.new()
	gap.custom_minimum_size.y = 40.0
	gap.mouse_filter = MOUSE_FILTER_IGNORE
	card.content.add_child(gap)
	card.line(text, 24)
	card.line(more, 16, Color(1.0, 1.0, 1.0, 0.6))
	card.tapped.connect(action)
	_grid.add_child(card)
	return card


## What starts a cup of yours once a kart's picked. Its courses are put out to
## race then, and it's made here because this screen is gone by then.
static func _starter(mine: CupDesign, id: String) -> Callable:
	return func() -> void: Game.start_grand_prix(mine.to_cup(id))


func _on_picture(key: String, picture: Texture2D) -> void:
	for rect in _trophies.get(key, []):
		if is_instance_valid(rect):
			rect.texture = picture


func go_back() -> void:
	if yours:
		Game.show_cups()
	elif mode == Game.MODE_RACE and not alone:
		Game.show_multiplayer()
	else:
		Game.show_single_player()
