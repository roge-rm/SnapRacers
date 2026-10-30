class_name MenuStyle
extends RefCounted

## Builds the menu screens: a dark backdrop with speed stripes, a big title
## and a column of slanted buttons, all from UiKit.

const TOP := UiKit.INK
const BOTTOM := UiKit.INK_LOW
const ACCENT := UiKit.ACCENT
const COLUMN_WIDTH := 460.0
const BUTTON_HEIGHT := UiKit.BUTTON_HEIGHT


## The theme for every screen (see UiKit).
static func theme() -> Theme:
	return UiKit.theme()


## Pictures for the switches and the other controls the engine draws from SVG.
static func add_switches(to: Theme) -> void:
	UiKit.add_pictures(to)


## Fills the whole screen with the backdrop, top to bottom.
static func backdrop() -> Control:
	return UiKit.backdrop()


## A full screen with the backdrop and a centred column to put things in. It
## scrolls only if what's in it is taller than the screen.
static func screen(root: Control) -> VBoxContainer:
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := backdrop()
	root.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	column.add_theme_constant_override("separation", UiKit.GAP_M)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(column)
	return column


## A menu like the main menu: the logo top left, under it a column of big
## buttons that steps right with the lean, and the race picture beside them.
## Put the buttons in the column this returns (see big_button()).
static func menu_screen(root: Control, tagline := "") -> Container:
	root.theme = theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := backdrop()
	root.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var picture := RaceWindow.new()
	root.add_child(picture)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := SafeArea.new()
	root.add_child(safe)
	safe.pad(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiKit.GAP_L)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)
	column.add_child(title("SnapRacers", tagline))
	var steps := Steps.new()
	column.add_child(steps)
	picture.beside = steps
	return steps


## A column whose children step right with the lean, one under the other.
class Steps extends Container:
	const STEP := 22.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			var y := 0.0
			var i := 0
			for child in _shown():
				var want := child.get_combined_minimum_size()
				fit_child_in_rect(child, Rect2(i * STEP, y, want.x, want.y))
				y += want.y + UiKit.GAP_M
				i += 1

	func _get_minimum_size() -> Vector2:
		var room := Vector2.ZERO
		var i := 0
		for child in _shown():
			var want := child.get_combined_minimum_size()
			room.x = maxf(room.x, i * STEP + want.x)
			room.y += want.y + (UiKit.GAP_M if i > 0 else 0.0)
			i += 1
		return room

	func _shown() -> Array[Control]:
		var out: Array[Control] = []
		for child in get_children():
			if child is Control and child.visible and not child.top_level:
				out.append(child)
		return out


## The game's name (see UiKit.Logo), with a line under it in yellow when
## there's a `subtitle`.
static func title(text := "SnapRacers", subtitle := "", look := UiKit.LOGO_LOOK) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiKit.GAP_S)
	box.add_child(UiKit.logo(text, look))
	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.uppercase = true
		sub.theme_type_variation = "TaglineLabel"
		box.add_child(sub)
	return box


## A big menu button with a picture at its left end (see BigButton).
static func big_button(text: String, picture: String, action: Callable, subtitle := "") -> BigButton:
	var b := BigButton.new(text, picture, subtitle)
	if action.is_valid():
		b.tapped.connect(action)
	return b


## A pill button. It works in a scrolling list too (see ScrollButton).
static func button(text: String, action: Callable, subtitle := "") -> Button:
	var b := ScrollButton.new()
	b.text = text if subtitle == "" else "%s\n%s" % [text, subtitle]
	b.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	b.focus_mode = Control.FOCUS_ALL
	if action.is_valid():
		b.tapped.connect(action)
	return b


static var _marked := {}


## Lights up a button as the chosen one of a set, with accent text and an
## outline, or puts it back to plain.
static func mark(b: Button, on: bool) -> void:
	var colour := ACCENT if on else UiKit.WHITE
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(state, colour)
	for state in ["normal", "hover"]:
		b.remove_theme_stylebox_override(state)
		if on:
			var kind := b.theme_type_variation
			var key: String = state + "_" + kind
			if not _marked.has(key):
				var box: SlantBox
				match kind:
					"CardButton":
						box = UiKit.card(state)
					"ChoiceButton":
						box = BuilderStyle.choice_box(state)
					_:
						box = UiKit.pill(state)
				box.edge = ACCENT
				box.edge_width = 3
				_marked[key] = box
			b.add_theme_stylebox_override(state, _marked[key])


## Lights up the tab that's open, in a row of tabs.
static func mark_tab(b: Button, on: bool) -> void:
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		if on:
			b.add_theme_color_override(state, ACCENT)
		else:
			b.remove_theme_color_override(state)


## Back (or Quit) under a menu's buttons.
static func back_at_bottom(column: Container, action: Callable, text := "Back") -> Button:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	column.add_child(gap)
	var b := link(text, action, "close" if text == "Quit" else "back")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(b)
	return b


## A small dark button for Back, Close and the like, with a picture of
## `icon` ("back", "close" or "plus") when there's one.
static func link(text: String, action: Callable, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "SmallButton"
	b.focus_mode = Control.FOCUS_ALL
	if icon != "":
		b.icon = _icon(icon)
	b.pressed.connect(action)
	return b


## A small yellow chip button, for Change, Share and the like on a card or
## in a row.
static func chip(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "ChipButton"
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(action)
	return b


static var _icons := {}


static func _icon(what: String) -> Texture2D:
	if not _icons.has(what):
		_icons[what] = UiKit.icon_picture(what, UiKit.WHITE)
	return _icons[what]


## A slider for a setting, big enough for a thumb, with a thick track filled in
## the accent colour up to a slanted handle (see UiKit).
static func slider(value: float, changed: Callable, low := 0.0, high := 1.0, step := 0.1) -> HSlider:
	var s := HSlider.new()
	s.min_value = low
	s.max_value = high
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(320.0, 48.0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(changed)
	return s


## A heading, with a line of grey explanation under it when there's one.
static func heading(text: String, explanation := "") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = text
	label.uppercase = true
	label.theme_type_variation = "LeadLabel"
	box.add_child(label)
	if explanation != "":
		var more := Label.new()
		more.text = explanation
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.theme_type_variation = "NoteLabel"
		box.add_child(more)
	return box


## A page with its title in the top left, Back in the top right and a column
## underneath for what's on it. Returns that column.
## With `centred` the margin away from a camera hole grows to match, for a
## column as wide as the room inside the margins (see page_room()).
static func page(root: Control, heading_text: String, back: Callable, width := 760.0, centred := false) -> VBoxContainer:
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
	# The title and Back stay clear of a camera hole.
	var safe := SafeArea.new()
	root.add_child(safe)
	safe.pad(margin, centred)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP_M)
	outer.add_child(top)
	# The title on a red slanted ribbon, with bars trailing off it.
	var title_box := ribbon(heading_text)
	top.add_child(title_box)
	var bars := Bars.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bars)
	var back_button := link("Back", back, "back")
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(back_button)
	# A long title is cut short with dots rather than squeezing Back.
	var fit := func() -> void:
		var across := margin.get_viewport_rect().size.x - margin.get_theme_constant("margin_left") - margin.get_theme_constant("margin_right")
		var room := across - back_button.get_combined_minimum_size().x - bars.custom_minimum_size.x - top.get_theme_constant("separation") * 2
		fit_ribbon(title_box, heading_text, room)
	margin.resized.connect(fit)
	margin.theme_changed.connect(fit)
	fit.call_deferred()

	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Card pages sit in the middle of the room under the title; a tall one still scrolls.
	if centred:
		centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0.0)
	column.add_theme_constant_override("separation", 18)
	centre.add_child(column)
	return column


static var _ribbon_box: StyleBox


## A page's title on a red slanted ribbon.
static func ribbon(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _ribbon())
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.uppercase = true
	label.theme_type_variation = "PageTitleLabel"
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(label)
	return box


## Makes a ribbon() with `text` on it no wider than `room`, its words cut
## short with dots if they don't fit.
static func fit_ribbon(box: PanelContainer, text: String, room: float) -> void:
	var label := box.get_child(0) as Label
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var whole := font.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + label.get_theme_constant("outline_size")
	label.custom_minimum_size.x = clampf(whole, 0.0, maxf(room - _ribbon().get_minimum_size().x, 60.0))


static func _ribbon() -> StyleBox:
	if _ribbon_box == null:
		_ribbon_box = UiKit.pad(UiKit.slant(UiKit.RED, UiKit.LEAN), 26, 0, UiKit.LEAN, 60.0)
	return _ribbon_box


## The red bars after a page's title, each shorter and fainter.
class Bars extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(100, 0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var middle := size.y * 0.5
		for i in 4:
			var high := 44.0 - i * 8.0
			UiKit.draw_slant(self, Rect2(4.0 + i * 22.0, middle - high * 0.5, 14.0, high), Color(UiKit.RED, 0.8 - i * 0.18), 0.12)


## The page's margin container, for a column made by page().
static func page_margin(column: Control) -> MarginContainer:
	var node := column.get_parent()
	while node != null and not node is MarginContainer:
		node = node.get_parent()
	return node


## How wide a column made by page() can be inside the page's margins, which
## grow to clear a camera hole.
static func page_room(column: Control) -> float:
	# The margin container's own size grows with what's in it, so this goes
	# by the screen's.
	var margin := page_margin(column)
	return margin.get_viewport_rect().size.x - margin.get_theme_constant("margin_left") - margin.get_theme_constant("margin_right")
