class_name MenuStyle
extends RefCounted

## The look every menu screen shares, taken from ScorchDroid's menus. It has a
## dark navy to purple backdrop, a big white title, and a column of soft
## purple pill buttons. Having it in one place keeps the screens looking like
## they belong together.

const TOP := Color("#16213a")
const BOTTOM := Color("#2b1b3d")
const ACCENT := Color("#b39dff")
const COLUMN_WIDTH := 460.0
const BUTTON_HEIGHT := 60.0

static var _theme: Theme


## The theme for menu screens, with white text, pill buttons and accent
## highlights.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 22
	var states := {
		"normal": Color(ACCENT, 0.18),
		"hover": Color(ACCENT, 0.26),
		"pressed": Color(ACCENT, 0.36),
		"focus": Color(ACCENT, 0.18),
		"disabled": Color(1.0, 1.0, 1.0, 0.06),
	}
	for state in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state]
		box.set_corner_radius_all(int(BUTTON_HEIGHT * 0.5))
		box.content_margin_left = 24
		box.content_margin_right = 24
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		if state == "focus":
			box.draw_center = false
		_theme.set_stylebox(state, "Button", box)
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_theme.set_color(colour_name, "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", Color(1.0, 1.0, 1.0, 0.35))
	_theme.set_color("font_color", "Label", Color.WHITE)

	var field := StyleBoxFlat.new()
	field.bg_color = Color(1.0, 1.0, 1.0, 0.04)
	field.border_color = Color(1.0, 1.0, 1.0, 0.45)
	field.set_border_width_all(2)
	field.set_corner_radius_all(8)
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 10
	field.content_margin_bottom = 10
	_theme.set_stylebox("normal", "LineEdit", field)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = ACCENT
	_theme.set_stylebox("focus", "LineEdit", field_focus)
	_theme.set_color("font_color", "LineEdit", Color.WHITE)
	_theme.set_color("caret_color", "LineEdit", ACCENT)
	return _theme


## Fills the whole screen with the backdrop, top to bottom.
static func backdrop() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, TOP)
	gradient.set_color(1, BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## A full screen with the backdrop and a centred column to put things in. It
## scrolls only if what's in it is taller than the screen.
static func screen(root: Control) -> VBoxContainer:
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := backdrop()
	root.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	return column


static func title(text := "SnapRacers", subtitle := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	box.add_child(label)
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_color_override("font_color", ACCENT)
		box.add_child(sub)
	return box


## A pill button. It works in a scrolling list too (see ScrollButton).
static func button(text: String, action: Callable, subtitle := "") -> Button:
	var b := ScrollButton.new()
	b.text = text if subtitle == "" else "%s\n%s" % [text, subtitle]
	b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	b.focus_mode = Control.FOCUS_NONE
	if action.is_valid():
		b.tapped.connect(action)
	return b


## Lights up a button as the chosen one of a set, with accent text and an
## outline, or puts it back to plain.
static func mark(b: Button, on: bool) -> void:
	var colour := ACCENT if on else Color.WHITE
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(state, colour)
	for state in ["normal", "hover", "pressed"]:
		b.remove_theme_stylebox_override(state)
		if on:
			var box := b.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			if box != null:
				box.border_color = ACCENT
				box.set_border_width_all(3)
				b.add_theme_stylebox_override(state, box)


## Back (or Quit) under a menu's buttons, the way ScorchDroid's menus end.
static func back_at_bottom(column: Container, action: Callable, text := "Back") -> Button:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	column.add_child(gap)
	var b := link(text, action)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(b)
	return b


## Plain accent coloured text that works like a button, for Back.
static func link(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", ACCENT)
	b.add_theme_color_override("font_hover_color", ACCENT.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", ACCENT.darkened(0.2))
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(action)
	return b


## A heading with a line of grey explanation under it, like ScorchDroid's
## settings.
static func heading(text: String, explanation := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	box.add_child(label)
	if explanation != "":
		var more := Label.new()
		more.text = explanation
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
		more.add_theme_font_size_override("font_size", 18)
		box.add_child(more)
	return box


## A page with its title in the top left and Back in the top right corner,
## like ScorchDroid's settings, and a column underneath for what's on it.
## Returns that column.
static func page(root: Control, heading_text: String, back: Callable, width := 760.0) -> VBoxContainer:
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := backdrop()
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	var label := Label.new()
	label.text = heading_text
	label.add_theme_font_size_override("font_size", 44)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	top.add_child(link("Back", back))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0.0)
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	return column
