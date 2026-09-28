class_name KartPicker
extends Control

## Pick a kart before a race: the one you built in the garage, or any of the
## stock karts. Each card has a picture of the kart, what it's like, and bars
## for how it compares with the rest. Tap one to pick it, then Race. It
## remembers what you picked last time.

const COLUMNS := 3
## A card's size. Buttons don't grow to fit what's put inside them, so it's
## set to fit the picture, the name, three lines about it and the bars.
const CARD := Vector2(330, 490)
## The bars on each card, as [label, what they measure].
const BARS := [["Speed", "speed"], ["Pull", "pull"], ["Grip", "grip"], ["Control", "control"], ["Off-road", "offroad"]]

var _go: Callable
var _back: Callable
var _cards := {}
var _chosen := ""
var _chosen_label: Label
var _race: Button
var _pictures: KartThumbnails


func _init(go: Callable, back: Callable) -> void:
	_go = go
	_back = back


func _ready() -> void:
	var column := MenuStyle.page(self, "Pick a kart", go_back, CARD.x * COLUMNS + 24.0 * (COLUMNS - 1))
	_pictures = KartThumbnails.new()
	_pictures.ready_for.connect(_show_picture)
	add_child(_pictures)

	# What you're racing in, and the button to go. They stay put above the
	# cards as you scroll through them, in the page's outer column (the one
	# that holds the title and the scrolling part).
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	var outer: VBoxContainer = column.get_parent().get_parent().get_parent()
	outer.add_child(top)
	outer.move_child(top, 1)
	_chosen_label = Label.new()
	_chosen_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_chosen_label.add_theme_font_size_override("font_size", 26)
	top.add_child(_chosen_label)
	_race = MenuStyle.button("Race", func() -> void: _go.call())
	_race.custom_minimum_size.x = 220.0
	MenuStyle.mark(_race, true)
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
	_choose(Game.kart_choice() if not (Game.kart_choice() == Game.OWN_KART and not Game.design.problems().is_empty()) else "starter")


func go_back() -> void:
	_back.call()


func _choose(key: String) -> void:
	_chosen = key
	Game.set_kart_choice(key)
	for other in _cards:
		MenuStyle.mark(_cards[other], other == key)
	var design: KartDesign = Game.design if key == Game.OWN_KART else Game.stock_kart(key)
	_chosen_label.text = "Racing in %s" % ("your own kart, %s" % design.name if key == Game.OWN_KART else "the %s" % design.name)


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
	card.custom_minimum_size = CARD
	card.focus_mode = FOCUS_NONE
	card.set_meta("kart", key)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 14.0
	box.offset_right = -14.0
	box.offset_top = 10.0
	box.offset_bottom = -12.0
	card.add_child(box)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.custom_minimum_size = Vector2(0, 170)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	picture.texture = KartThumbnails.picture(key)
	box.add_child(picture)
	var own := key == Game.OWN_KART
	var title := Label.new()
	title.text = "Your kart: %s" % design.name if own else design.name
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var problems: Array[String] = design.problems() if own else ([] as Array[String])
	var about := Label.new()
	about.text = design.about if not own else ("The one you built in the garage." if problems.is_empty() else problems[0])
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(CARD.x - 28.0, 0)
	about.add_theme_font_size_override("font_size", 16)
	about.add_theme_color_override("font_color", Color(1, 1, 1, 0.65) if problems.is_empty() else BuilderStyle.DANGER)
	box.add_child(about)
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var measured := _measure(design)
	for bar in BARS:
		var row := HBoxContainer.new()
		row.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(row)
		var label := Label.new()
		label.text = bar[0]
		label.custom_minimum_size.x = 90.0
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
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
		var bar := Rect2(0, middle - 4, size.x, 8)
		draw_rect(bar, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * amount, bar.size.y)), BuilderStyle.DATA)
