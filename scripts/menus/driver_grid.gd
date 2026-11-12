class_name DriverGrid
extends VBoxContainer

## The cards to pick a driver from, in two parts. Your drivers: your own (the
## one on the driver screen), the ones you've saved and a last card to make a
## new one. Then the stock drivers. Each card has a picture of the driver
## standing and their name. It's on the driver picker's page, and goes in a
## popup too.

signal picked(key: String)
signal new_driver

## A card's size, for the picture, the name on up to two lines and the
## weight under it.
const CARD := Vector2(190, 300)
const COLUMNS := 5
const GAP := 24

## The pick key each card is for, as key -> card.
var cards := {}
var _current := ""
var _taken_by_p1 := ""
var _player := 0
var _can_make := true
var _portraits: DriverPortraits
## Which cards show which picture, as look key -> [card, ...].
var _waiting := {}
var _yours: GridContainer
var _stock: GridContainer


## `current` is the pick marked as yours, and on player 2's grid
## `taken_by_p1` is the one player 1 has, which gets a P1 tag. Without
## `can_make` there's no New driver card.
func _init(current: String, taken_by_p1 := "", for_player := 0, can_make := true) -> void:
	_current = current
	_taken_by_p1 = taken_by_p1
	_player = for_player
	_can_make = can_make
	add_theme_constant_override("separation", 12)


## How wide the grid is, for the page or popup around it.
static func width() -> float:
	return CARD.x * COLUMNS + GAP * (COLUMNS - 1)


func _ready() -> void:
	_portraits = DriverPortraits.new()
	_portraits.ready_for.connect(_show_picture)
	add_child(_portraits)
	add_child(MenuStyle.heading("Your drivers"))
	_yours = _section()
	add_child(MenuStyle.heading("Stock drivers"))
	_stock = _section()
	for key in CharacterDesign.pick_keys():
		var design := CharacterDesign.for_key(key)
		_add(key, design, _stock if key.begins_with(CharacterDesign.STOCK_KEY) else _yours)
	if _can_make:
		_yours.add_child(_new_card())
	mark(_current if cards.has(_current) else CharacterDesign.OWN_KEY)
	_scroll_to_marked()


## Marks this pick's card as the one picked.
func mark(key: String) -> void:
	_current = key
	for other in cards:
		MenuStyle.mark(cards[other], other == key)


## Scrolls the page or popup this is in to the marked card, once it's laid
## out, since it can be down in the stock drivers.
func _scroll_to_marked() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var card := marked_card()
	var node := get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	if node != null and card != null and is_instance_valid(card):
		(node as ScrollContainer).ensure_control_visible(card)


## The card for the marked pick, for a pad to start on.
func marked_card() -> Control:
	return cards.get(_current)


func _section() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	add_child(grid)
	return grid


func _add(key: String, design: CharacterDesign, section: GridContainer) -> void:
	var card := _card(design.name)
	card.set_meta("driver", key)
	var picture: TextureRect = card.get_node("Box/Picture")
	var look := DriverPortraits.key_of(design)
	picture.texture = DriverPortraits.picture(design)
	if picture.texture == null:
		if not _waiting.has(look):
			_waiting[look] = []
		_waiting[look].append(card)
		_portraits.take(design)
	var weight := Label.new()
	weight.text = design.weight_class()
	weight.theme_type_variation = "SmallLabel"
	weight.mouse_filter = MOUSE_FILTER_IGNORE
	card.get_node("Box").add_child(weight)
	if key == _taken_by_p1 and _player == 2:
		card.add_child(_p1_tag())
	card.tapped.connect(func() -> void:
		mark(key)
		picked.emit(key))
	section.add_child(card)
	cards[key] = card


func _new_card() -> ScrollButton:
	var card := _card("New driver")
	card.set_meta("driver", "new")
	var plus := Label.new()
	plus.text = "+"
	plus.theme_type_variation = "HeadingLabel"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", 96)
	plus.mouse_filter = MOUSE_FILTER_IGNORE
	plus.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	card.get_node("Box/Picture").add_child(plus)
	card.tapped.connect(func() -> void: new_driver.emit())
	return card


## A card with room for a picture and a name under it.
func _card(title: String) -> ScrollButton:
	var card := ScrollButton.new()
	card.theme_type_variation = "CardButton"
	card.custom_minimum_size = CARD
	card.focus_mode = FOCUS_ALL
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 16.0
	box.offset_right = -12.0
	box.offset_top = 10.0
	box.offset_bottom = -10.0
	card.add_child(box)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.custom_minimum_size = Vector2(0, 200)
	picture.size_flags_vertical = SIZE_EXPAND_FILL
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(picture)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = title
	name_label.theme_type_variation = "LeadLabel"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(CARD.x - 28.0, 0)
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	return card


## A tag in player 1's colour on the card player 1 picked.
func _p1_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiKit.pad(UiKit.slant(UiKit.PLAYERS[0]), 12, 2, UiKit.LEAN, 32.0))
	tag.mouse_filter = MOUSE_FILTER_IGNORE
	tag.position = Vector2(CARD.x - 70.0, 8.0)
	var label := Label.new()
	label.text = "P1"
	label.theme_type_variation = "TagLabel"
	tag.add_child(label)
	return tag


func _show_picture(look: String, picture: Texture2D) -> void:
	for card in _waiting.get(look, []):
		if is_instance_valid(card):
			card.get_node("Box/Picture").texture = picture
	_waiting.erase(look)
