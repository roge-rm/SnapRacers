class_name CourseGrid
extends Control

## A cup's courses as big layout cards, to pick one for a single race, a time
## trial, practice or a race for two. Each says how long a lap is and what's
## waiting on it, and in a time trial your record too. It shows your own
## courses the same way, each with Share, and a card to add one you've been
## sent.

## The cup id for the courses you've built.
const YOURS := "yours"
const GAP := 16

var mode := Game.MODE_RACE
var alone := false
var cup := ""

var _grid: GridContainer


func _init(for_mode := Game.MODE_RACE, for_one := false, cup_id := "") -> void:
	mode = for_mode
	alone = for_one
	cup = cup_id


## The courses you've built that are finished, by file.
static func your_courses() -> Array:
	return CourseDesign.saved().filter(func(p): return CourseDesign.load_file(p) != null and CourseDesign.load_file(p).problems().is_empty())


func _ready() -> void:
	Game.cup_shown = cup
	var paths := []
	var title := "Your courses"
	var colour := MenuStyle.ACCENT
	if cup == YOURS:
		paths = your_courses()
	else:
		var found := GrandPrix.cup_by_id(cup)
		paths = found.get("paths", [])
		title = found.get("name", "Courses")
		colour = Color(found.get("colour", MenuStyle.ACCENT.to_html())).lightened(0.3)
	var width := maxf(get_viewport_rect().size.x - 80.0, 600.0)
	var column := MenuStyle.page(self, title, go_back, width)
	_grid = GridContainer.new()
	# Yours are as wide as a cup's four, however many there are.
	_grid.columns = 4 if cup == YOURS else clampi(paths.size(), 1, 4)
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	column.add_child(_grid)
	var card_width := (width - GAP * (_grid.columns - 1)) / _grid.columns
	for path in paths:
		var card := _course_card(path, colour)
		card.custom_minimum_size.x = card_width
		_grid.add_child(card)
	if cup == YOURS:
		var add := MenuCard.new()
		add.set_meta("add", true)
		var gap := Control.new()
		gap.custom_minimum_size.y = 180.0
		gap.mouse_filter = MOUSE_FILTER_IGNORE
		add.content.add_child(gap)
		add.line("Add a course", 26)
		add.line("From a code or a file", 17, Color(1.0, 1.0, 1.0, 0.7))
		add.custom_minimum_size.x = card_width
		add.tapped.connect(func() -> void:
			AddWindow.open(self, "Add a course").done.connect(func(any_added: bool) -> void:
				if any_added:
					Game.show_course_grid(mode, alone, cup)))
		_grid.add_child(add)
	PadFocus.focus_first(self)


func _course_card(path: String, colour: Color) -> MenuCard:
	var id := Tracks.id_of(path)
	var outline := CourseOutline.of(path)
	var card := MenuCard.new()
	card.set_meta("track", path)
	var view := CourseOutlineView.new(path, colour)
	view.thickness = 4.0
	view.custom_minimum_size = Vector2(0.0, 400.0)
	card.content.add_child(view)
	card.line(outline.name, 26)
	card.line(outline.summary, 17, Color(1.0, 1.0, 1.0, 0.7))
	if mode == Game.MODE_TIME_TRIAL and Records.best_time(id) > 0.0:
		card.line("Record %s, best lap %s" % [RaceHud.clock(Records.best_time(id)), RaceHud.clock(Records.best_lap(id))], 17, MenuStyle.ACCENT)
	if cup == YOURS:
		var share := MenuStyle.link("Share", func() -> void:
			var course := CourseDesign.load_file(path)
			if course != null:
				ShareWindow.open(course.to_dict(), self))
		share.add_theme_font_size_override("font_size", 20)
		share.size_flags_horizontal = SIZE_SHRINK_CENTER
		# The card's words ignore the mouse, but this has to be tapped.
		share.mouse_filter = MOUSE_FILTER_STOP
		card.content.add_child(share)
	# A race from the Multiplayer menu is for two on this phone, and each
	# picks a kart.
	var two := mode == Game.MODE_RACE and not alone
	card.tapped.connect(Game.show_kart_picker.bind(_starter(mode, path, alone), Game.show_course_grid.bind(mode, alone, cup), mode == Game.MODE_RACE, two))
	return card


## What starts the race once a kart's picked. It's made here, away from the
## course cards, which are gone by then.
static func _starter(for_mode: String, path: String, for_one: bool) -> Callable:
	return func() -> void:
		Game.racing_alone = for_one
		Game.start_course(for_mode, path)


func go_back() -> void:
	Game.show_tracks(mode, alone)
