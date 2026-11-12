class_name DriverCard
extends ScrollButton

## A slanted card with a driver's picture and name, on the kart picker and in
## the lobby. Whoever puts it there decides what tapping it does.

## A little taller than the Race button.
const SIZE := Vector2(260, 84)

## The driver shown.
var design: CharacterDesign
var _caption := "Driver"
var _picture: TextureRect
var _name: Label
var _caption_label: Label
var _portraits: DriverPortraits


func _ready() -> void:
	_build()
	# Pictures asked for before it was in the tree are taken now.
	if design != null and _picture.texture == null:
		_portraits.take(design)


## Shows this driver on the card.
func show_driver(driver: CharacterDesign) -> void:
	_build()
	design = driver
	_name.text = driver.name
	_picture.texture = DriverPortraits.picture(driver)
	if _picture.texture == null and _portraits.is_node_ready():
		_portraits.take(driver)


## The small line over the name, "Driver" unless it's changed.
func set_caption(text: String) -> void:
	_caption = text
	if _caption_label != null:
		_caption_label.text = text


func _build() -> void:
	if _name != null:
		return
	theme_type_variation = "CardButton"
	custom_minimum_size = SIZE
	focus_mode = FOCUS_ALL
	size_flags_vertical = SIZE_SHRINK_CENTER
	_portraits = DriverPortraits.new()
	_portraits.ready_for.connect(_show_portrait)
	add_child(_portraits)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 16.0
	row.offset_right = -18.0
	row.offset_top = 4.0
	row.offset_bottom = -4.0
	add_child(row)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.custom_minimum_size = Vector2(SIZE.y * 0.75, 0)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(_picture)
	var words := VBoxContainer.new()
	words.name = "Words"
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = SIZE_EXPAND_FILL
	words.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	_caption_label = Label.new()
	_caption_label.text = _caption
	_caption_label.theme_type_variation = "SmallLabel"
	_caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption_label.custom_minimum_size.x = 120.0
	_caption_label.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_child(_caption_label)
	_name = Label.new()
	_name.name = "Name"
	_name.theme_type_variation = "LeadLabel"
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size.x = 120.0
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	words.add_child(_name)


func _show_portrait(look: String, picture: Texture2D) -> void:
	if design != null and look == DriverPortraits.key_of(design):
		_picture.texture = picture
