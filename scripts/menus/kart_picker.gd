class_name KartPicker
extends Control

## Pick a kart before a race, either the one you built in the garage or one of
## the stock karts. In a race against the AI, Easy, Normal, Hard and Expert sit
## in the header between the title and Back. Each card has a picture of the
## kart, a line about it and bars for how it compares with the rest. It
## remembers what you picked last time.
##
## Two on one phone each pick in turn on this screen, player 1 first, with
## a big tag in their own colour saying whose turn it is, and their name,
## which they can change.

const COLUMNS := 3
## A card's size. Buttons don't grow to fit what's put inside them, so it's
## set to fit the picture, the name, four lines about it and the bars, with the page above it on a 720 high screen.
const CARD := Vector2(330, 410)
## The bars on each card, as [label, what they measure].
const BARS := [["Speed", "speed"], ["Pull", "pull"], ["Grip", "grip"], ["Control", "control"], ["Off-road", "offroad"]]
## Each player's colour, for their tag when two are picking.
const PLAYER_COLOURS := UiKit.PLAYERS

var _go: Callable
var _back: Callable
var _cards := {}
var _chosen := ""
var _chosen_label: Label
var _race: Button
var _pictures: KartThumbnails
var _ai := false
var _levels := {}
var _difficulty_row: HBoxContainer
## Which of two players on this phone is picking, 1 or 2, or 0 when it's one.
var player := 0
var _name: LineEdit


func _init(go: Callable, back: Callable, ai := false, for_player := 0) -> void:
	_go = go
	_back = back
	_ai = ai
	player = for_player


## Filed apart from the other player's picker in the pad's memory.
func focus_key() -> String:
	return "KartPicker/%d/%s" % [player, _ai]


func _ready() -> void:
	var title := "Pick a kart" if player == 0 else "Player %d, pick your kart" % player
	var column := MenuStyle.page(self, title, go_back, CARD.x * COLUMNS + 24.0 * (COLUMNS - 1))
	_pictures = KartThumbnails.new()
	_pictures.ready_for.connect(_show_picture)
	add_child(_pictures)

	# What you're racing in and the button to go, which stay put above the
	# cards as you scroll, in the page's outer column.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	var outer: VBoxContainer = column.get_parent().get_parent().get_parent()
	outer.add_child(top)
	outer.move_child(top, 1)
	if _ai and player != 2:
		_difficulty_row = _make_difficulty_row()
		_put_in_header(_difficulty_row, outer)
		_show_level(Game.difficulty())
	if player > 0:
		top.add_child(_player_tag())
	if player > 0:
		# Player 1's name is the one in Settings, and player 2 has their own.
		var key := "name" if player == 1 else "name_two"
		_name = LineEdit.new()
		PadKeyboard.attach(_name)
		_name.placeholder_text = "Player %d's name" % player
		_name.max_length = 16
		_name.text = Game.player_one_name() if player == 1 else Game.player_two_name()
		_name.custom_minimum_size = Vector2(260.0, 48.0)
		_name.text_changed.connect(func(text: String) -> void: Game.set_setting("player", key, text.strip_edges()))
		top.add_child(_name)
	_chosen_label = Label.new()
	_chosen_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_chosen_label.theme_type_variation = "LeadLabel"
	top.add_child(_chosen_label)
	_race = MenuStyle.button("Next" if player == 1 else "Race", func() -> void: _go.call())
	_race.custom_minimum_size.x = 220.0
	_race.theme_type_variation = "MainButton"
	top.add_child(_race)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	column.add_child(grid)
	var entries := [[Game.OWN_KART, Game.design]]
	for key in Game.stock_keys():
		entries.append([key, Game.stock_kart(key)])
	var ranges := _ranges(entries.map(func(e): return _measure(e[1])))
	for entry in entries:
		var card := _card(entry[0], entry[1], ranges)
		grid.add_child(card)
		_cards[entry[0]] = card
	MenuStyle.back_at_bottom(column, go_back)
	# Your own kart changes in the garage, so take its picture again each time.
	KartThumbnails.forget(Game.OWN_KART)
	var last := Game.player_two_kart() if player == 2 else Game.kart_choice()
	_choose(last if not (last == Game.OWN_KART and not Game.design.problems().is_empty()) else Game.DEFAULT_STOCK)


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
	tag.add_theme_stylebox_override("panel", UiKit.pad(UiKit.slant(PLAYER_COLOURS[player - 1]), 22, 4, UiKit.LEAN, 48.0))
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
	var design: KartDesign = Game.design if key == Game.OWN_KART else Game.stock_kart(key)
	var kart := "the garage kart, %s" % design.name if player == 2 else "your own kart, %s" % design.name
	_chosen_label.text = "Racing in %s" % (kart if key == Game.OWN_KART else "the %s" % design.name)


## How a kart measures up on each bar, before it's compared with the others.
static func _measure(design: KartDesign) -> Dictionary:
	var stats := KartStats.compute(design)
	return {
		"speed": stats.top_speed(),
		"pull": stats.pull(),
		"grip": stats.cornering() + stats.lift_area * 0.5,
		"control": stats.control,
		"offroad": stats.offroad,
	}


## The lowest and highest of each measure across every kart.
static func _ranges(all: Array) -> Dictionary:
	var out := {}
	for bar in BARS:
		var values: Array = all.map(func(m): return m[bar[1]])
		out[bar[1]] = Vector2(values.min(), values.max())
	return out


func _card(key: String, design: KartDesign, ranges: Dictionary) -> Button:
	var card := ScrollButton.new()
	card.theme_type_variation = "CardButton"
	card.custom_minimum_size = CARD
	card.focus_mode = FOCUS_ALL
	card.set_meta("kart", key)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 20.0
	box.offset_right = -14.0
	box.offset_top = 10.0
	box.offset_bottom = -12.0
	card.add_child(box)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.custom_minimum_size = Vector2(0, 100)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	picture.texture = KartThumbnails.picture(key)
	box.add_child(picture)
	var own := key == Game.OWN_KART
	var title := Label.new()
	title.text = ("The garage kart, %s" if player == 2 else "Your kart, %s") % design.name if own else design.name
	title.theme_type_variation = "LeadLabel"
	# A long garage name goes on to a second line.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(CARD.x - 34.0, 0)
	box.add_child(title)
	var problems: Array[String] = design.problems() if own else ([] as Array[String])
	var about := Label.new()
	var built := "The one in the garage." if player == 2 else "The one you built in the garage."
	about.text = design.about if not own else (built if problems.is_empty() else problems[0])
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(CARD.x - 34.0, 0)
	about.theme_type_variation = "SmallLabel" if problems.is_empty() else "DangerLabel"
	box.add_child(about)
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	# Keep the bars inside the card's slanted lower edge.
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_right", ceili(UiKit.CARD_LEAN * 200.0))
	inset.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(inset)
	var meters := VBoxContainer.new()
	meters.add_theme_constant_override("separation", 4)
	meters.mouse_filter = MOUSE_FILTER_IGNORE
	inset.add_child(meters)
	var measured := _measure(design)
	for bar in BARS:
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		meters.add_child(row)
		var label := Label.new()
		label.text = bar[0]
		label.custom_minimum_size.x = 90.0
		label.theme_type_variation = "SmallLabel"
		row.add_child(label)
		var range: Vector2 = ranges[bar[1]]
		var amount := inverse_lerp(range.x, range.y, measured[bar[1]]) if range.y > range.x else 1.0
		var meter := StatBar.new(lerpf(0.12, 1.0, clampf(amount, 0.0, 1.0)))
		meter.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(meter)
	# A kart that can't be driven can be looked at but not picked.
	card.disabled = not problems.is_empty()
	card.tapped.connect(_choose.bind(key))
	_pictures.take(key, design, Game.character)
	return card


func _show_picture(key: String, picture: Texture2D) -> void:
	if _cards.has(key):
		_cards[key].get_node("Box/Picture").texture = picture


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
