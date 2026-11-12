class_name MenuCard
extends ScrollButton

## A big slanted card for a grid, like the cups and courses, with pictures and
## words stacked in it. Put what goes on it in `content`. It can have a
## stripe of a colour down its left side, a number in the top right corner
## and medal markers in the top left.

## How far in from the edges what's on it sits. The left leaves room for the
## stripe.
const LEFT := 28
const EDGE := 14
## Medal pill, wide enough for the three-letter difficulty name.
const PILL := Vector2(46, 20)

var content: VBoxContainer
## The number in the top right, like "01", or none.
var number := "":
	set(value):
		number = value
		queue_redraw()
## The medal markers, one slot per level: a medal's colour where it's won,
## clear where it isn't. Drawn if any medal is won.
var medals: Array[Color] = []:
	set(value):
		medals = value
		queue_redraw()

## The level's name for each marker, of which three letters are drawn on it.
var medal_names: Array[String] = []:
	set(value):
		medal_names = value
		queue_redraw()

var _stripe := Color.TRANSPARENT
## The first line of words, yellow while the card's picked out.
var _title: Label

static var _boxes := {}


var _margin: MarginContainer


func _init(stripe := Color.TRANSPARENT) -> void:
	super()
	focus_mode = FOCUS_ALL
	size_flags_horizontal = SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	_margin = margin
	set_stripe(stripe)
	margin.add_theme_constant_override("margin_right", EDGE)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(content)
	# The card is as tall as what's on it.
	margin.minimum_size_changed.connect(func() -> void: custom_minimum_size.y = margin.get_combined_minimum_size().y)
	focus_entered.connect(_light.bind(true))
	focus_exited.connect(_light.bind(false))


## Gives the card a stripe of this colour down its left side, or none if
## it's clear.
func set_stripe(stripe: Color) -> void:
	_stripe = stripe
	var key := stripe.to_html()
	if not _boxes.has(key):
		var set := {}
		for state in UiKit.STATES:
			set[state] = UiKit.card(state, stripe)
		_boxes[key] = set
	for state in UiKit.STATES:
		add_theme_stylebox_override(state, _boxes[key][state])
	_margin.add_theme_constant_override("margin_left", LEFT if stripe.a > 0.0 else EDGE + 6)
	queue_redraw()


func _light(on: bool) -> void:
	if _title != null:
		_title.theme_type_variation = "CardTitleLitLabel" if on else "CardTitleLabel"


## A line of words on the card. The first `big` one is the card's name, in
## capitals.
func line(text: String, big := true) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	if big:
		label.uppercase = true
		label.theme_type_variation = "CardTitleLabel"
		if _title == null:
			_title = label
	else:
		label.theme_type_variation = "NoteLabel"
	content.add_child(label)
	return label


## A picture on the card, kept in proportion.
func picture(texture: Texture2D, height: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0.0, height)
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(rect)
	return rect


## A red slanted block with a plus on it, for the cards that make or add
## something.
func plus() -> Control:
	var block := PlusBlock.new()
	content.add_child(block)
	return block


func _draw() -> void:
	if number != "":
		var font := UiKit.font("title")
		var high := 34
		var wide := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, high).x
		var tint := Color(_stripe.lightened(0.25), 0.6) if _stripe.a > 0.0 else UiKit.FADED
		draw_string(font, Vector2(size.x - EDGE - 8.0 - wide, 10.0 + font.get_ascent(high)), number, HORIZONTAL_ALIGNMENT_LEFT, -1, high, tint)
	if _shows_medals():
		# One under the other down the left, over the picture. Height stays in _draw.
		var y := 12.0
		var body := UiKit.font("body")
		var lift := (body.get_ascent(UiKit.SMALL) - body.get_descent(UiKit.SMALL)) * 0.5
		var tilt := _tilt()
		for i in medals.size():
			var colour := medals[i]
			var at := Rect2(_stripe_end(y + PILL.y, tilt), y, PILL.x, PILL.y)
			if colour.a > 0.0:
				UiKit.draw_slant(self, Rect2(at.position + Vector2(2, 2), at.size), UiKit.SHADOW_COLOUR, tilt)
				UiKit.draw_slant(self, at, colour, tilt)
			else:
				UiKit.draw_slant(self, at, UiKit.EDGE, tilt)
			if i < medal_names.size():
				var word := medal_names[i].substr(0, 3).to_upper()
				draw_string(body, Vector2(at.position.x + 6.0, at.get_center().y + lift), word, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SMALL, UiKit.INK if colour.a > 0.0 else UiKit.FADED)
			y += 24.0


## True if any medal is won, so empty pills still show for the other levels.
func _shows_medals() -> bool:
	for colour in medals:
		if colour.a > 0.0:
			return true
	return false


## How far the card's box leans for each pixel of height, as SlantBox works it
## out.
func _tilt() -> float:
	var height := 200.0
	if size.y > height:
		return UiKit.CARD_LEAN * height / size.y
	return UiKit.CARD_LEAN


## Where the stripe's right edge is at `y` down the card, or where it would be
## on a card without one.
func _stripe_end(y: float, tilt: float) -> float:
	var shift := size.y * tilt * 0.5
	return shift + 1.0 + 2.0 + UiKit.STRIPE_WIDTH + (size.y * 0.5 - y) * tilt


class PlusBlock extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 64)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var block := Rect2(size.x * 0.5 - 34.0, size.y * 0.5 - 26.0, 68.0, 52.0)
		UiKit.draw_slant(self, Rect2(block.position + UiKit.SHADOW * 0.6, block.size), UiKit.SHADOW_COLOUR)
		UiKit.draw_slant(self, block, UiKit.RED)
		UiKit.draw_icon(self, "plus", block.get_center(), 28.0, UiKit.WHITE, 3.5)
