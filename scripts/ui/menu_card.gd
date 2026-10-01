class_name MenuCard
extends ScrollButton

## A big button for a grid, like the cups and courses, with pictures and words
## stacked in it. Put what goes on it in `content`.

var content: VBoxContainer


func _init() -> void:
	super()
	focus_mode = FOCUS_ALL
	size_flags_horizontal = SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, BuilderStyle.tile_box(state))
	var focused := BuilderStyle.tile_box("hover")
	focused.border_color = Color.WHITE
	focused.set_border_width_all(3)
	add_theme_stylebox_override("focus", focused)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_child(content)
	# The card is as tall as what's on it.
	margin.minimum_size_changed.connect(func() -> void: custom_minimum_size.y = margin.get_combined_minimum_size().y)


## A line of words on the card.
func line(text: String, font_size := 20, colour := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = MOUSE_FILTER_IGNORE
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
