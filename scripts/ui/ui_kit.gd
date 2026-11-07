class_name UiKit
extends RefCounted

## The arcade racer look every screen shares: colours, type, spacing, the
## slanted boxes and the one Theme built from them. MenuStyle and BuilderStyle
## call into this.

# Colours.
const INK := Color("#0b0b12")
## The bottom of the backdrop.
const INK_LOW := Color("#22101c")
const YELLOW := Color("#ffd60a")
const RED := Color("#ff2d3d")
const GREEN := Color("#3ddc5a")
const BLUE := Color("#7fd8ff")
const WHITE := Color.WHITE
## The dark, nearly solid fill behind a panel or button.
const PANEL := Color(0.02, 0.02, 0.05, 0.85)
const PANEL_HOVER := Color(0.09, 0.09, 0.15, 0.9)
## The thin light line round a panel.
const EDGE := Color(1, 1, 1, 0.15)
const MUTED := Color(1, 1, 1, 0.6)
## Text a little quieter than white, like a drawer's heading.
const SOFT := Color(1, 1, 1, 0.85)
const FADED := Color(1, 1, 1, 0.35)
## The accent: focus, the chosen one, you.
const ACCENT := YELLOW
## Text on an accent or yellow fill.
const ON_ACCENT := INK
const DANGER := Color("#ff6b6b")
## Player 1 and player 2 on a shared screen.
const PLAYERS := [Color("#4fa8ff"), Color("#ffa63d")]
const MEDALS := { 1: Color("#f2b632"), 2: Color("#cdd3db"), 3: Color("#c47a45") }
## The touch buttons in a race: GO, brake, look back, a gadget, and the rest
## (reset and the steering buttons).
const GO_GREEN := Color("#2fb84c")
const BRAKE_RED := Color("#e0283a")
const LOOK_BLUE := Color("#1f78d1")
const GADGET_PURPLE := Color("#7b3fc4")
const BUTTON_GREY := Color("#6e6e7c")

# Type sizes, in UI pixels. SMALL is the smallest anything gets, so it stays
# readable on a phone.
const TITLE := 64
const HEADING := 30
const BODY := 22
const SMALL := 16
const DIGITS := 34
## The game's name on the menus, for its capitals (see Logo).
const LOGO := 110
## How much bigger the name's capitals are than the rest, which are small
## capitals sharing their baseline.
const LOGO_CAPITAL := 1.22
## What goes with the name on the splash and the main menu: "panel" puts it
## on a slanted panel with a yellow stripe under it, "stripes" runs a slanted
## red band from behind it off to the left edge, "flag" puts a chequered strip
## and a yellow bar under it.
const LOGO_LOOK := "stripes"
## A page's title, top left.
const PAGE_TITLE := 44
## A heading inside a page, and a card's name.
const LEAD := 24
## Back, Close and the other small word buttons.
const WORD_SIZE := 24
## A line of explanation under a heading.
const NOTE := 18
## Your place in a race.
const HUD_PLACE := 44
## The countdown and GO! in the middle of a race.
const COUNTDOWN := 120
## How many goes are left, on a power-up box or a gadget button.
const BADGE := 20
## The editors' small controls: chips, word buttons and the stats chip.
const CHIP := 20
## A part's name under its picture in an editor's drawer.
const TINY := 14

# Spacing steps.
const GAP_XS := 4
const GAP_S := 8
const GAP_M := 12
const GAP_L := 18
const GAP_XL := 24
const GAP_XXL := 40

# Slant, as how far the top moves right per pixel of height. Buttons and
# chips lean like the type, cards less so they don't look squashed.
const LEAN := 0.35
const CARD_LEAN := 0.12
const PANEL_LEAN := 0.3
## The hard drop shadow under panels and buttons.
const SHADOW := Vector2(6, 6)
const SHADOW_COLOUR := Color(0, 0, 0, 0.5)
## The dark edge round a count drawn over a picture, like x2 on a gadget.
const BADGE_OUTLINE := Color(0, 0, 0, 0.9)
## The stripes on cards and panels.
const STRIPE_WIDTH := 10.0
const UNDERLINE := 6.0

const BUTTON_HEIGHT := 60.0
## The height of a dialog's title bar.
const TITLE_BAR := 44
const STATES := ["normal", "hover", "pressed", "focus", "disabled"]

const _FONTS := "res://art/fonts/chakra_petch/"

static var _theme: Theme
static var _fonts := {}


# ------------------------------------------------------------------ type

## Chakra Petch for each step of the type scale: "title", "heading", "body"
## or "digits" (even-width digits, so a ticking clock doesn't jiggle).
static func font(kind := "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f := FontVariation.new()
	match kind:
		"title":
			f.base_font = load(_FONTS + "ChakraPetch-Bold.ttf")
			f.set_spacing(TextServer.SPACING_GLYPH, 1)
		"heading":
			f.base_font = load(_FONTS + "ChakraPetch-Bold.ttf")
			f.set_spacing(TextServer.SPACING_GLYPH, 1)
		"digits":
			# Made by tools/fonts/even_digits.py, as the font has no tnum.
			f.base_font = load(_FONTS + "ChakraPetch-Bold-EvenDigits.ttf")
		_:
			f.base_font = load(_FONTS + "ChakraPetch-Bold.ttf")
	_fonts[kind] = f
	return f


# ----------------------------------------------------------------- boxes

## A slanted box. Every other box here is one of these.
static func slant(fill: Color, lean := LEAN, edge := Color.TRANSPARENT, edge_width := 0, shadow := true) -> SlantBox:
	var box := SlantBox.new()
	box.fill = fill
	box.lean = lean
	box.edge = edge
	box.edge_width = edge_width
	if shadow:
		box.shadow = SHADOW
		box.shadow_colour = SHADOW_COLOUR
	return box


## Padding inside a box, with room for its lean at a given height.
static func pad(box: StyleBox, across: float, down: float, lean := 0.0, height := BUTTON_HEIGHT) -> StyleBox:
	var extra := height * lean * 0.5
	box.content_margin_left = across + extra
	box.content_margin_right = across + extra
	box.content_margin_top = down
	box.content_margin_bottom = down
	if box is SlantBox:
		(box as SlantBox).lean_height = height
	return box


## The white ring round whatever a controller or the keys have picked out.
## It's white so it can't be mixed up with the yellow on a chosen one.
static func focus_ring(lean := LEAN, gap := 5.0) -> SlantBox:
	var box := slant(Color.TRANSPARENT, lean, WHITE, 4, false)
	box.grow = gap
	return box


## A button: dark with a light edge, lit up when hovered, yellow edged when
## held.
static func pill(state: String, lean := LEAN, height := BUTTON_HEIGHT) -> StyleBox:
	var box: SlantBox
	match state:
		"hover":
			box = slant(PANEL_HOVER, lean, Color(YELLOW, 0.5), 1)
		"pressed":
			box = slant(Color(0.2, 0.17, 0.02, 0.92), lean, YELLOW, 3)
		"focus":
			box = focus_ring(lean)
		"disabled":
			box = slant(Color(1, 1, 1, 0.05), lean, Color(1, 1, 1, 0.08), 1, false)
		_:
			box = slant(PANEL, lean, EDGE, 1)
	return pad(box, 24, 10, lean, height)


## A filled button, like the big yellow one at the end of a row.
static func solid(state: String, colour: Color, lean := LEAN, height := 56.0) -> StyleBox:
	var box: SlantBox
	match state:
		"hover":
			box = slant(colour.lightened(0.1), lean)
		"pressed":
			box = slant(colour.lightened(0.25), lean)
		"focus":
			box = focus_ring(lean)
		"disabled":
			box = slant(Color(1, 1, 1, 0.05), lean, Color.TRANSPARENT, 0, false)
		_:
			box = slant(colour, lean)
	return pad(box, 28, 8, lean, height)


## A small tinted button for the smaller controls.
static func chip(state: String, lean := LEAN, height := 48.0) -> StyleBox:
	var box: SlantBox
	match state:
		"hover":
			box = slant(Color(YELLOW, 0.26), lean, Color.TRANSPARENT, 0, false)
		"pressed":
			box = slant(Color(YELLOW, 0.4), lean, Color.TRANSPARENT, 0, false)
		"focus":
			box = focus_ring(lean, 4.0)
		"disabled":
			box = slant(Color(1, 1, 1, 0.05), lean, Color.TRANSPARENT, 0, false)
		_:
			box = slant(Color(YELLOW, 0.16), lean, Color.TRANSPARENT, 0, false)
	return pad(box, 16, 4, lean, height)


## A card in a grid, like a cup or a course, with a stripe of its colour down
## the left side. A focused one has a thick yellow edge.
static func card(state: String, colour := Color.TRANSPARENT) -> StyleBox:
	var box: SlantBox
	match state:
		"hover":
			box = slant(PANEL_HOVER, CARD_LEAN, Color(1, 1, 1, 0.3), 1)
		"pressed":
			box = slant(PANEL_HOVER, CARD_LEAN, YELLOW, 3)
		"focus":
			box = slant(Color.TRANSPARENT, CARD_LEAN, YELLOW, 3, false)
		"disabled":
			box = slant(Color(PANEL, 0.4), CARD_LEAN, Color(1, 1, 1, 0.06), 1, false)
		_:
			box = slant(Color(PANEL, 0.88), CARD_LEAN, Color(1, 1, 1, 0.14), 1)
	if colour.a > 0.0 and state != "focus":
		box.stripe = colour
		box.stripe_width = STRIPE_WIDTH
	return pad(box, 14, 10, CARD_LEAN, 200.0)


## A half see-through dark panel for the HUD, with a red line along the
## bottom when `underline` is set. `small` pads it less, for a split screen
## half.
static func panel(lean := PANEL_LEAN, underline := false, small := false) -> SlantBox:
	var box := slant(Color(0.02, 0.02, 0.05, 0.5), lean, EDGE, 1, false)
	if underline:
		box.underline = RED
		box.underline_height = UNDERLINE if not small else 4.0
	if small:
		pad(box, 9, 4, lean, 60.0)
	else:
		pad(box, 14, 8, lean, 80.0)
	return box


## A small button on the race screen, like the camera one: an outline you can
## see the race through, like the touch buttons.
static func hud_button(state: String) -> SlantBox:
	var box: SlantBox
	match state:
		"pressed":
			box = slant(Color(WHITE, 0.35), PANEL_LEAN, YELLOW, 3, false)
		"hover":
			box = slant(Color(BUTTON_GREY, 0.4), PANEL_LEAN, Color(WHITE, 0.9), 3, false)
		_:
			box = slant(Color(BUTTON_GREY, 0.28), PANEL_LEAN, Color(WHITE, 0.75), 3, false)
	return box


## The backing of a popup or dialog: square, nearly solid, with a red stripe
## down the left.
static func popup() -> SlantBox:
	var box := slant(Color(INK, 0.97), 0.0, Color(1, 1, 1, 0.18), 1)
	box.stripe = RED
	box.stripe_width = 6.0
	pad(box, 24, 18)
	box.content_margin_left = 34
	return box


## The frame of a dialog window drawn inside the game's own window (always
## so on a phone or the web): it reaches up over the title bar and a little
## past the other sides, the way the engine's own one does.
static func window_frame() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(INK, 0.97)
	box.border_color = Color(1, 1, 1, 0.18)
	box.set_border_width_all(1)
	box.expand_margin_left = 8
	box.expand_margin_right = 8
	box.expand_margin_bottom = 8
	box.expand_margin_top = TITLE_BAR + 8
	return box


## A text field.
static func field(focused := false) -> StyleBox:
	var box := slant(Color(1, 1, 1, 0.05), 0.15, YELLOW if focused else Color(1, 1, 1, 0.45), 2, false)
	return pad(box, 16, 10, 0.15, 50.0)


# ----------------------------------------------------------------- theme

## The one theme for every screen, the HUD and the editors.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	_theme = t
	t.default_font = font("body")
	t.default_font_size = BODY

	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		for state in STATES:
			t.set_stylebox(state, type, pill(state))
		t.set_font("font", type, font("heading"))
		for colour_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			t.set_color(colour_name, type, WHITE)
		t.set_color("font_disabled_color", type, FADED)
		t.set_constant("h_separation", type, GAP_M)
	# A switch or tick box is a line of text with its picture, so no box
	# round it until it's focused.
	for type in ["CheckBox", "CheckButton"]:
		var plain := StyleBoxEmpty.new()
		pad(plain, 12, 6)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(state, type, plain)
		t.set_color("font_hover_color", type, YELLOW)

	t.set_color("font_color", "Label", WHITE)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	# Kinds of label for the type scale, picked with theme_type_variation.
	for kind in [
		["TitleLabel", "title", TITLE, WHITE], ["HeadingLabel", "heading", HEADING, WHITE],
		["SmallLabel", "body", SMALL, MUTED], ["DigitsLabel", "digits", DIGITS, WHITE],
		["LogoLabel", "title", LOGO, YELLOW], ["PageTitleLabel", "title", PAGE_TITLE, WHITE],
		["TaglineLabel", "heading", HEADING, YELLOW], ["LeadLabel", "heading", LEAD, WHITE],
		["LeadAccentLabel", "heading", LEAD, YELLOW],
		["CardTitleLabel", "heading", 20, WHITE], ["CardTitleLitLabel", "heading", 20, YELLOW], ["NoteLabel", "body", NOTE, MUTED],
		["AccentLabel", "body", BODY, YELLOW], ["DataLabel", "body", NOTE + 2, BLUE],
		["DangerLabel", "body", NOTE + 2, DANGER], ["BannerLabel", "title", HEADING, YELLOW],
		["TagLabel", "heading", HEADING, INK],
	]:
		t.set_type_variation(kind[0], "Label")
		t.set_font("font", kind[0], font(kind[1]))
		t.set_font_size("font_size", kind[0], kind[2])
		t.set_color("font_color", kind[0], kind[3])
	# The logo: yellow with a black edge and a red copy behind it.
	t.set_color("font_outline_color", "LogoLabel", Color.BLACK)
	t.set_constant("outline_size", "LogoLabel", 10)
	t.set_color("font_shadow_color", "LogoLabel", RED)
	t.set_constant("shadow_offset_x", "LogoLabel", 7)
	t.set_constant("shadow_offset_y", "LogoLabel", 7)
	t.set_constant("shadow_outline_size", "LogoLabel", 10)
	for kind in ["PageTitleLabel", "BannerLabel"]:
		t.set_color("font_outline_color", kind, Color.BLACK)
		t.set_constant("outline_size", kind, 6)
	# The race screen's words, with a black edge so they read over the race.
	for kind in [
		["HudPlaceLabel", "title", HUD_PLACE, YELLOW, 6], ["HudLabel", "heading", LEAD, WHITE, 4],
		["HudBestLabel", "heading", LEAD, GREEN, 4], ["HudClockLabel", "digits", DIGITS, WHITE, 4],
		["HudNoteLabel", "heading", NOTE, YELLOW, 4], ["CountdownLabel", "title", COUNTDOWN, YELLOW, 14],
		# Smaller ones for a split screen half, and the status line.
		["HudPlaceSmallLabel", "title", 30, YELLOW, 5], ["HudSmallLabel", "heading", NOTE, WHITE, 4],
		["HudBestSmallLabel", "heading", NOTE, GREEN, 4], ["HudClockSmallLabel", "digits", 24, WHITE, 4],
		["HudNoteSmallLabel", "heading", SMALL, YELLOW, 4],
		["TimeLabel", "digits", BODY, WHITE, 0], ["TimeAccentLabel", "digits", BODY, YELLOW, 0],
	]:
		t.set_type_variation(kind[0], "Label")
		t.set_font("font", kind[0], font(kind[1]))
		t.set_font_size("font_size", kind[0], kind[2])
		t.set_color("font_color", kind[0], kind[3])
		t.set_color("font_outline_color", kind[0], Color(0, 0, 0, 0.85))
		t.set_constant("outline_size", kind[0], kind[4])
	_add_button_kinds(t)

	for type in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", type, field())
		t.set_stylebox("focus", type, field(true))
		t.set_stylebox("read_only", type, field())
	t.set_color("font_color", "LineEdit", WHITE)
	t.set_color("font_placeholder_color", "LineEdit", FADED)
	t.set_color("caret_color", "LineEdit", YELLOW)
	t.set_color("selection_color", "LineEdit", Color(YELLOW, 0.35))

	t.set_stylebox("panel", "PanelContainer", pad(slant(PANEL, 0.0, EDGE, 1, false), 12, 10))
	t.set_stylebox("panel", "Panel", slant(PANEL, 0.0, EDGE, 1, false))
	for type in ["PopupPanel", "PopupMenu", "AcceptDialog", "ConfirmationDialog", "FileDialog"]:
		t.set_stylebox("panel", type, popup())
	t.set_stylebox("embedded_border", "Window", window_frame())
	t.set_stylebox("embedded_unfocused_border", "Window", window_frame())
	t.set_font("title_font", "Window", font("heading"))
	t.set_color("title_color", "Window", WHITE)
	t.set_font_size("title_font_size", "Window", BODY)
	t.set_constant("title_height", "Window", TITLE_BAR)
	t.set_constant("close_h_offset", "Window", 34)
	t.set_constant("close_v_offset", "Window", 32)
	t.set_icon("close", "Window", icon_picture("close", WHITE, 22))
	t.set_icon("close_pressed", "Window", icon_picture("close", YELLOW, 22))

	var hover := slant(Color(YELLOW, 0.22), 0.0, Color.TRANSPARENT, 0, false)
	t.set_stylebox("hover", "PopupMenu", hover)
	t.set_font("font", "PopupMenu", font("heading"))
	t.set_color("font_color", "PopupMenu", WHITE)
	t.set_color("font_hover_color", "PopupMenu", YELLOW)
	t.set_color("font_disabled_color", "PopupMenu", FADED)
	t.set_constant("v_separation", "PopupMenu", GAP_L)
	t.set_stylebox("separator", "PopupMenu", _line(Color(1, 1, 1, 0.15)))

	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	t.set_stylebox("background", "ProgressBar", track)
	var done := StyleBoxFlat.new()
	done.bg_color = YELLOW
	t.set_stylebox("fill", "ProgressBar", done)
	t.set_color("font_color", "ProgressBar", WHITE)

	_add_sliders(t)
	_add_scroll_bars(t)
	add_pictures(t)
	# Loaded by path, so the race code that uses the kit (touch controls,
	# sounds) doesn't pull in the editors' buttons and Game with them, which
	# tests run with -s can't load.
	load("res://scripts/ui/builder_style.gd").add_to(t)
	return t


## Kinds of button, picked with theme_type_variation.
static func _add_button_kinds(t: Theme) -> void:
	var text_states := ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]
	# Back, Close and the like: a small dark slanted box.
	t.set_type_variation("SmallButton", "Button")
	for state in STATES:
		t.set_stylebox(state, "SmallButton", pad(pill(state, LEAN, 48.0), 18, 6, LEAN, 48.0))
	t.set_font_size("font_size", "SmallButton", WORD_SIZE)
	t.set_color("font_hover_color", "SmallButton", YELLOW)
	t.set_color("icon_normal_color", "SmallButton", YELLOW)
	t.set_color("icon_hover_color", "SmallButton", YELLOW)
	t.set_color("icon_focus_color", "SmallButton", YELLOW)
	t.set_color("icon_pressed_color", "SmallButton", YELLOW)
	# Change, Share and the like, on a card or in a row: a yellow chip.
	t.set_type_variation("ChipButton", "Button")
	for state in STATES:
		t.set_stylebox(state, "ChipButton", chip(state, LEAN, 40.0))
	t.set_font_size("font_size", "ChipButton", NOTE)
	for name in text_states:
		t.set_color(name, "ChipButton", YELLOW)
	# The one to press next, like Race or Save: solid yellow.
	t.set_type_variation("MainButton", "Button")
	for state in STATES:
		t.set_stylebox(state, "MainButton", solid(state, YELLOW, LEAN, BUTTON_HEIGHT))
	for name in text_states:
		t.set_color(name, "MainButton", ON_ACCENT)
	# A big card with things on it, like a kart to pick.
	t.set_type_variation("CardButton", "Button")
	for state in STATES:
		t.set_stylebox(state, "CardButton", card(state))
	# A key on the on-screen keyboard.
	t.set_type_variation("KeyButton", "Button")
	for state in STATES:
		t.set_stylebox(state, "KeyButton", pad(pill(state, 0.2, 48.0), 8, 4, 0.2, 48.0))
	t.set_font_size("font_size", "KeyButton", BODY)
	# A small cell in a table, like a binding in Settings > Controls.
	t.set_type_variation("CellButton", "KeyButton")
	t.set_font_size("font_size", "CellButton", NOTE)
	# A tab along the top of a page: words only, yellow when it's the one
	# open (see MenuStyle.mark_tab()).
	t.set_type_variation("TabButton", "Button")
	var none := StyleBoxEmpty.new()
	pad(none, 16, 8)
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "TabButton", none)
	t.set_font_size("font_size", "TabButton", LEAD)
	t.set_color("font_color", "TabButton", Color(WHITE, 0.8))
	t.set_color("font_hover_color", "TabButton", WHITE)
	# A big menu button that draws its own words and picture (see BigButton):
	# yellow when it's picked out.
	t.set_type_variation("BigButton", "Button")
	for state in STATES:
		var box: StyleBox
		match state:
			"hover", "focus":
				box = slant(YELLOW, LEAN)
			"pressed":
				box = slant(YELLOW.lightened(0.3), LEAN)
			_:
				box = pill(state)
		t.set_stylebox(state, "BigButton", box)
	for name in text_states + ["font_disabled_color"]:
		t.set_color(name, "BigButton", Color.TRANSPARENT)


static func _line(colour: Color) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = colour
	line.thickness = 2
	return line


static func _add_sliders(t: Theme) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	track.skew = Vector2(LEAN, 0)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = YELLOW
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var knob := grabber(WHITE)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", grabber(YELLOW))
	t.set_icon("grabber_disabled", "HSlider", grabber(FADED))
	t.set_stylebox("focus", "HSlider", focus_ring(0.0, 4.0))


static func _add_scroll_bars(t: Theme) -> void:
	var states := {
		"scroll": Color(1, 1, 1, 0.06),
		"scroll_focus": Color(1, 1, 1, 0.1),
		"grabber": Color(YELLOW, 0.55),
		"grabber_highlight": Color(YELLOW, 0.8),
		"grabber_pressed": YELLOW,
	}
	var none := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	for type in ["VScrollBar", "HScrollBar"]:
		for state in states:
			var box := StyleBoxFlat.new()
			box.bg_color = states[state]
			if type == "VScrollBar":
				box.content_margin_left = 5.0
				box.content_margin_right = 5.0
			else:
				box.content_margin_top = 5.0
				box.content_margin_bottom = 5.0
			t.set_stylebox(state, type, box)
		for icon in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			t.set_icon(icon, type, none)


# -------------------------------------------------------------- pictures
# The engine draws its own icons from SVG, which our cut down engine leaves
# out, so on a phone or the web they'd be blank. These are drawn here.

## Pictures for switches, tick boxes, the OptionButton arrow and SpinBox.
static func add_pictures(to: Theme) -> void:
	var on := switch_picture(true, 1.0)
	var off := switch_picture(false, 1.0)
	var on_dim := switch_picture(true, 0.4)
	var off_dim := switch_picture(false, 0.4)
	for side in ["", "_mirrored"]:
		to.set_icon("checked" + side, "CheckButton", on)
		to.set_icon("unchecked" + side, "CheckButton", off)
		to.set_icon("checked_disabled" + side, "CheckButton", on_dim)
		to.set_icon("unchecked_disabled" + side, "CheckButton", off_dim)

	var ticked := tick_picture(true, 1.0)
	var empty := tick_picture(false, 1.0)
	for type in ["CheckBox", "PopupMenu"]:
		to.set_icon("checked", type, ticked)
		to.set_icon("unchecked", type, empty)
		to.set_icon("radio_checked", type, ticked)
		to.set_icon("radio_unchecked", type, empty)
	for name in ["checked_disabled", "radio_checked_disabled"]:
		to.set_icon(name, "CheckBox", tick_picture(true, 0.4))
	for name in ["unchecked_disabled", "radio_unchecked_disabled"]:
		to.set_icon(name, "CheckBox", tick_picture(false, 0.4))

	var down := arrow_picture(Vector2.DOWN, WHITE)
	to.set_icon("arrow", "OptionButton", down)
	to.set_icon("submenu", "PopupMenu", arrow_picture(Vector2.RIGHT, WHITE))
	to.set_icon("submenu_mirrored", "PopupMenu", arrow_picture(Vector2.LEFT, WHITE))

	to.set_icon("updown", "SpinBox", updown_picture())
	for state in ["", "_hover", "_pressed", "_disabled"]:
		var ink := YELLOW if state == "_hover" or state == "_pressed" else WHITE
		if state == "_disabled":
			ink = FADED
		to.set_icon("up" + state, "SpinBox", arrow_picture(Vector2.UP, ink))
		to.set_icon("down" + state, "SpinBox", arrow_picture(Vector2.DOWN, ink))


## How much of the pixel at `p` is inside a parallelogram over `rect`
## leaning by `lean`, for soft edges.
static func _inside(p: Vector2, rect: Rect2, lean: float) -> float:
	var shift := rect.size.y * lean * 0.5
	var left := rect.position.x + shift - lean * (p.y - rect.position.y)
	var right := left + rect.size.x - shift * 2.0
	var across := minf(p.x - left, right - p.x) / sqrt(1.0 + lean * lean)
	var down := minf(p.y - rect.position.y, rect.end.y - p.y)
	return clampf(minf(across, down) + 0.5, 0.0, 1.0)


## Paints a leaning shape onto a picture, over what's there.
static func _paint(image: Image, rect: Rect2, lean: float, colour: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var cover := _inside(Vector2(x + 0.5, y + 0.5), rect, lean)
			if cover > 0.0:
				image.set_pixel(x, y, image.get_pixel(x, y).blend(Color(colour, colour.a * cover)))


static func _blank(width: int, height: int) -> Image:
	return Image.create_empty(width, height, false, Image.FORMAT_RGBA8)


## A switch: a slanted track with a block at one end, yellow when it's on.
static func switch_picture(on: bool, alpha: float) -> ImageTexture:
	var image := _blank(66, 32)
	var whole := Rect2(1, 2, 64, 28)
	_paint(image, whole, LEAN, Color(YELLOW, alpha) if on else Color(1, 1, 1, 0.22 * alpha))
	var block := Rect2(whole.end.x - 30, 6, 26, 20) if on else Rect2(whole.position.x + 4, 6, 26, 20)
	_paint(image, block, LEAN, Color(INK, alpha) if on else Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


## A slanted tick box, yellow with a dark tick when it's ticked.
static func tick_picture(ticked: bool, alpha: float) -> ImageTexture:
	var image := _blank(34, 30)
	var whole := Rect2(1, 1, 32, 28)
	if ticked:
		_paint(image, whole, LEAN * 0.6, Color(YELLOW, alpha))
		_line_on(image, [Vector2(9, 15), Vector2(15, 21), Vector2(25, 8)], 3.5, Color(INK, alpha))
	else:
		_paint(image, whole, LEAN * 0.6, Color(1, 1, 1, 0.6 * alpha))
		_paint(image, whole.grow(-3.0), LEAN * 0.6, Color(INK, 0.92))
	return ImageTexture.create_from_image(image)


## A chevron pointing `towards`.
static func arrow_picture(towards: Vector2, ink: Color) -> ImageTexture:
	var image := _blank(20, 20)
	var c := Vector2(10, 10)
	var side := Vector2(-towards.y, towards.x)
	_line_on(image, [c - towards * 3.5 + side * 6.0, c + towards * 3.5, c - towards * 3.5 - side * 6.0], 3.0, ink)
	return ImageTexture.create_from_image(image)


## The SpinBox's up and down arrows, one over the other.
static func updown_picture() -> ImageTexture:
	var image := _blank(20, 32)
	_line_on(image, [Vector2(4, 13), Vector2(10, 7), Vector2(16, 13)], 3.0, WHITE)
	_line_on(image, [Vector2(4, 19), Vector2(10, 25), Vector2(16, 19)], 3.0, WHITE)
	return ImageTexture.create_from_image(image)


## A small picture for a button's icon: "back" (an arrow), "close" (a cross)
## or "plus".
static func icon_picture(what: String, ink: Color, size := 20) -> ImageTexture:
	var image := _blank(size, size)
	var k := size / 24.0
	var p := func(x: float, y: float) -> Vector2: return Vector2(12 + x, 12 + y) * k
	var w := 3.5 * k
	match what:
		"back":
			_line_on(image, [p.call(10, 0), p.call(-9, 0)], w, ink)
			_line_on(image, [p.call(-2, -7), p.call(-9, 0), p.call(-2, 7)], w, ink)
		"plus":
			_line_on(image, [p.call(0, -10), p.call(0, 10)], w * 1.2, ink)
			_line_on(image, [p.call(-10, 0), p.call(10, 0)], w * 1.2, ink)
		_:
			_line_on(image, [p.call(-8, -8), p.call(8, 8)], w, ink)
			_line_on(image, [p.call(8, -8), p.call(-8, 8)], w, ink)
	return ImageTexture.create_from_image(image)


## Draws a small line picture centred on `c`, `s` pixels across, onto any
## control from its _draw(). The pictures: race (a chequered flag), two
## (people), wrench, cards, gear, info, close, back, plus, trophy, clock, loop,
## person, track, pause, camera, reset (an arrow going round) and look (an
## eye with an arrow pointing back).
static func draw_icon(on: CanvasItem, what: String, c: Vector2, s: float, ink: Color, w := 3.0) -> void:
	var k := s / 24.0
	var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
	w *= k
	match what:
		"race":
			on.draw_line(p.call(-8, 12), p.call(-8, -11), ink, w, true)
			for row in 3:
				for col in 4:
					var cell := Rect2(p.call(-7 + col * 4.5, -11 + row * 4), Vector2(4.5, 4) * k)
					on.draw_rect(cell, ink if (row + col) % 2 == 0 else Color(ink, 0.25))
		"two":
			on.draw_circle(p.call(-5, -5), 4.2 * k, ink)
			on.draw_circle(p.call(6, -4), 3.6 * k, ink)
			_half_disc(on, p.call(-5, 10), 8.0 * k, ink)
			_half_disc(on, p.call(6, 10), 6.5 * k, Color(ink, 0.75))
		"person":
			on.draw_circle(p.call(0, -5), 5.0 * k, ink)
			_half_disc(on, p.call(0, 11), 9.0 * k, ink)
		"wrench":
			on.draw_line(p.call(-9, 9), p.call(2, -2), ink, w * 1.5, true)
			on.draw_arc(p.call(5, -5), 6.0 * k, deg_to_rad(-10), deg_to_rad(260), 16, ink, w * 1.1, true)
		"cards":
			on.draw_polyline(PackedVector2Array([p.call(-11, 3), p.call(-11, -10), p.call(4, -10), p.call(4, -8)]), ink, w * 0.75, true)
			on.draw_polyline(PackedVector2Array([p.call(-8, 6), p.call(-8, -6), p.call(7, -6), p.call(7, -3)]), ink, w * 0.75, true)
			on.draw_rect(Rect2(p.call(-4, -2), Vector2(15, 13) * k), ink, false, w * 0.8)
			for y in [2, 6]:
				on.draw_line(p.call(-1, y), p.call(8, y), ink, w * 0.65, true)
		"gear":
			on.draw_arc(c, 6.5 * k, 0, TAU, 24, ink, w * 1.2, true)
			for i in 8:
				var a := Vector2.from_angle(i * TAU / 8.0)
				on.draw_line(c + a * 8.0 * k, c + a * 11.5 * k, ink, w * 1.3)
		"info":
			on.draw_arc(c, 10.5 * k, 0, TAU, 32, ink, w * 0.8, true)
			on.draw_circle(p.call(0, -5.5), 1.9 * k, ink)
			on.draw_line(p.call(0, -1.5), p.call(0, 6.5), ink, w, true)
		"close":
			on.draw_line(p.call(-8, -8), p.call(8, 8), ink, w, true)
			on.draw_line(p.call(8, -8), p.call(-8, 8), ink, w, true)
		"back":
			on.draw_line(p.call(9, 0), p.call(-8, 0), ink, w, true)
			on.draw_line(p.call(-9, 0), p.call(-2, -7), ink, w, true)
			on.draw_line(p.call(-9, 0), p.call(-2, 7), ink, w, true)
		"plus":
			on.draw_line(p.call(0, -10), p.call(0, 10), ink, w * 1.3, true)
			on.draw_line(p.call(-10, 0), p.call(10, 0), ink, w * 1.3, true)
		"trophy":
			on.draw_colored_polygon(PackedVector2Array([p.call(-8, -10), p.call(8, -10), p.call(6, -1), p.call(0, 3), p.call(-6, -1)]), ink)
			on.draw_arc(p.call(-8, -5), 4.0 * k, PI * 0.5, PI * 1.5, 10, ink, w * 0.7, true)
			on.draw_arc(p.call(8, -5), 4.0 * k, -PI * 0.5, PI * 0.5, 10, ink, w * 0.7, true)
			on.draw_line(p.call(0, 2), p.call(0, 8), ink, w * 1.2)
			on.draw_rect(Rect2(p.call(-6, 8), Vector2(12, 3.5) * k), ink)
		"clock":
			on.draw_arc(p.call(0, 2), 9.5 * k, 0, TAU, 32, ink, w * 0.9, true)
			on.draw_line(p.call(0, 2), p.call(0, -4), ink, w * 0.9, true)
			on.draw_line(p.call(0, 2), p.call(4.5, 4.5), ink, w * 0.9, true)
			on.draw_line(p.call(-3, -10.5), p.call(3, -10.5), ink, w)
		"loop":
			on.draw_arc(c, 9.0 * k, deg_to_rad(30), deg_to_rad(330), 28, ink, w, true)
			var tip := c + Vector2.from_angle(deg_to_rad(330)) * 9.0 * k
			on.draw_colored_polygon(PackedVector2Array([tip + Vector2(-1, -6) * k, tip + Vector2(5, 2) * k, tip + Vector2(-5, 3) * k]), ink)
		"track":
			var road := PackedVector2Array([p.call(-10, 10), p.call(-4, -2), p.call(4, 2), p.call(10, -10)])
			on.draw_polyline(road, ink, w * 1.6, true)
			on.draw_line(p.call(6, -10), p.call(10, -10), ink, w)
		"pause":
			for x in [-5.0, 5.0]:
				on.draw_line(p.call(x, -9), p.call(x, 9), ink, w * 1.35)
		"camera":
			on.draw_rect(Rect2(p.call(-11, -6), Vector2(22, 15) * k), ink, false, w)
			on.draw_circle(p.call(0, 1.5), 4.0 * k, ink)
			on.draw_rect(Rect2(p.call(-5, -10), Vector2(10, 4) * k), ink)
		"reset":
			var r := 9.0 * k
			var end := deg_to_rad(320.0)
			on.draw_arc(c, r, deg_to_rad(40.0), end, 28, ink, w, true)
			var tip := c + Vector2.from_angle(end) * r
			var ahead := Vector2.from_angle(end + PI * 0.5)
			var out := Vector2.from_angle(end)
			on.draw_colored_polygon(PackedVector2Array([tip + ahead * 6.5 * k, tip + out * 5.5 * k, tip - out * 5.5 * k]), ink)
		"look":
			var eye := PackedVector2Array()
			for i in 17:
				var t := i / 16.0
				eye.append(p.call(lerpf(-11, 11, t), -3 - sin(t * PI) * 6.5))
			for i in range(15, 0, -1):
				var t := i / 16.0
				eye.append(p.call(lerpf(-11, 11, t), -3 + sin(t * PI) * 6.5))
			eye.append(eye[0])
			on.draw_polyline(eye, ink, w * 0.8, true)
			on.draw_circle(p.call(0, -3), 3.4 * k, ink)
			on.draw_line(p.call(9, 9.5), p.call(-7, 9.5), ink, w * 0.9, true)
			on.draw_line(p.call(-8, 9.5), p.call(-3.5, 5.5), ink, w * 0.9, true)
			on.draw_line(p.call(-8, 9.5), p.call(-3.5, 13.5), ink, w * 0.9, true)


static func _half_disc(on: CanvasItem, base: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(base + Vector2.from_angle(PI + i / 16.0 * PI) * r)
	on.draw_colored_polygon(pts, ink)


## A slanted block of colour drawn from a control's _draw(), like the medal
## markers and the picture blocks on the menu buttons. It stays inside `rect`.
static func draw_slant(on: CanvasItem, rect: Rect2, colour: Color, lean := LEAN) -> void:
	on.draw_colored_polygon(slant_points(rect, lean), colour)


## The corners of a slanted shape inside `rect`, top left first.
static func slant_points(rect: Rect2, lean := LEAN) -> PackedVector2Array:
	var shift := minf(rect.size.y * lean, rect.size.x * 0.5)
	return PackedVector2Array([
		rect.position + Vector2(shift, 0), Vector2(rect.end.x, rect.position.y),
		rect.end - Vector2(shift, 0), Vector2(rect.position.x, rect.end.y)])


## A slider's handle: a slanted white block.
static func grabber(colour: Color) -> ImageTexture:
	var image := _blank(26, 32)
	_paint(image, Rect2(1, 1, 24, 30), LEAN, Color(0, 0, 0, 0.5))
	_paint(image, Rect2(1, 1, 22, 28), LEAN, colour)
	return ImageTexture.create_from_image(image)


## Draws a thick line through `points` onto a picture, with soft edges.
static func _line_on(image: Image, points: Array, width: float, ink: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var p := Vector2(x + 0.5, y + 0.5)
			var near := INF
			for i in points.size() - 1:
				var closest := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
				near = minf(near, p.distance_to(closest))
			var cover := clampf(width * 0.5 - near + 0.5, 0.0, 1.0)
			if cover > 0.0:
				image.set_pixel(x, y, image.get_pixel(x, y).blend(Color(ink, ink.a * cover)))


# ------------------------------------------------------------------ logo

## The game's name as the menus show it (see Logo).
static func logo(text := "SnapRacers", look := LOGO_LOOK, capitals := LOGO) -> Logo:
	var l := Logo.new()
	l.text = text
	l.look = look
	l.capitals = capitals
	return l


## A name in yellow capitals with a black edge and a red copy behind it. The
## letters that are capitals in `text` are drawn `LOGO_CAPITAL` times the size
## of the rest, on the same baseline. `look` adds what goes with it (see
## LOGO_LOOK), and "" draws the name alone. The stripes run off to the
## left edge of the screen, past this control.
class Logo extends Control:
	const SHADOW_AT := Vector2(7, 7)
	const OUTLINE := 10
	## Room round the name for the panel, and the gap and height of the strip
	## under it, at LOGO size.
	const PANEL_PAD := Vector2(36, 22)
	## How tall the capitals are for their size, in this font.
	const CAP := 0.7
	const STRIP_GAP := 10.0
	const STRIP := 22.0

	var text := "SnapRacers":
		set(value):
			text = value
			_changed()
	var look := LOGO_LOOK:
		set(value):
			look = value
			_changed()
	## The size of the capitals, in UI pixels.
	var capitals := LOGO:
		set(value):
			capitals = value
			_changed()
	var _runs: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_changed()
		# The stripes reach the screen's edge, so they follow where this is.
		set_notify_transform(true)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED and look == "stripes":
			queue_redraw()

	func _changed() -> void:
		_runs.clear()
		var small := roundi(capitals / LOGO_CAPITAL)
		for letter in text:
			var big := letter != letter.to_lower()
			var want := capitals if big else small
			if not _runs.is_empty() and _runs[-1][1] == want:
				_runs[-1][0] += letter.to_upper()
			else:
				_runs.append([letter.to_upper(), want])
		update_minimum_size()
		queue_redraw()

	func _scale() -> float:
		return capitals / float(LOGO)

	func _letters_size() -> Vector2:
		var f := UiKit.font("title")
		var wide := 0.0
		for run in _runs:
			wide += f.get_string_size(run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, run[1]).x
		var s := _scale()
		return Vector2(wide + (OUTLINE + SHADOW_AT.x) * s, capitals * CAP + (OUTLINE + SHADOW_AT.y) * s)

	## Where the letters start, inside what this takes up.
	func _letters_at() -> Vector2:
		if look == "panel":
			return PANEL_PAD * _scale() + Vector2(size.y * UiKit.PANEL_LEAN * 0.5, 0)
		return Vector2.ZERO

	func _get_minimum_size() -> Vector2:
		var room := _letters_size()
		var s := _scale()
		match look:
			"panel":
				room.y += PANEL_PAD.y * 2.0 * s
				room.x += PANEL_PAD.x * 1.6 * s + room.y * UiKit.PANEL_LEAN
			"flag", "stripes":
				room.y += (STRIP_GAP + STRIP) * s
		return room

	func _draw() -> void:
		var s := _scale()
		var letters := Rect2(_letters_at(), _letters_size())
		var f := UiKit.font("title")
		# The capitals' tops and the baseline, for the bands around them.
		var cap_top := letters.position.y + OUTLINE * 0.5 * s
		var base := cap_top + capitals * CAP
		match look:
			"panel":
				var back := Rect2(Vector2.ZERO, size)
				UiKit.draw_slant(self, Rect2(back.position + UiKit.SHADOW, back.size), UiKit.SHADOW_COLOUR, UiKit.PANEL_LEAN)
				UiKit.draw_slant(self, back, UiKit.PANEL, UiKit.PANEL_LEAN)
				var under := 8.0 * s
				var shift := size.y * UiKit.PANEL_LEAN
				var tilt := under * UiKit.PANEL_LEAN
				draw_colored_polygon(PackedVector2Array([
					Vector2(tilt, size.y - under), Vector2(size.x - shift + tilt, size.y - under),
					Vector2(size.x - shift, size.y), Vector2(0, size.y)]), UiKit.YELLOW)
				# A red stripe down the left, like the cards.
				var wide := 14.0 * s
				draw_colored_polygon(PackedVector2Array([
					Vector2(shift, 0), Vector2(shift + wide, 0),
					Vector2(wide + tilt, size.y - under), Vector2(tilt, size.y - under)]), UiKit.RED)
			"stripes":
				# A red stripe and a thin yellow one under the letters, from off
				# the left edge to past the last letter, then two short chips.
				var left := -get_global_transform().origin.x - 20.0
				var top := letters.end.y + STRIP_GAP * 0.5 * s
				var high := STRIP * 0.75 * s
				var end := letters.end.x + 30.0 * s
				UiKit.draw_slant(self, Rect2(left, top, end - left, high), UiKit.RED, UiKit.LEAN)
				var thin := high * 0.4
				var under := top + high + 5.0 * s
				UiKit.draw_slant(self, Rect2(left, under, end - left - 60.0 * s, thin), UiKit.YELLOW, UiKit.LEAN)
				for i in 2:
					var x := end + (12.0 + i * 30.0) * s
					UiKit.draw_slant(self, Rect2(x, top, 18.0 * s, high), Color(UiKit.RED, 0.75 - i * 0.3), UiKit.LEAN)
			"flag":
				var y := letters.end.y + STRIP_GAP * s
				var strip := STRIP * s
				var square := strip * 0.5
				var x0 := letters.position.x + 4.0 * s
				var flag_wide := square * 14.0
				# A chequered strip leaning like the type, then a yellow bar.
				var lean := UiKit.LEAN
				var shift := strip * lean
				var cols := int(flag_wide / square)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0 + shift, y), Vector2(x0 + shift + cols * square, y),
					Vector2(x0 + cols * square, y + strip), Vector2(x0, y + strip)]), Color(0, 0, 0, 0.55))
				# Dark backing, with every other square white on it.
				for c in cols:
					for r in 2:
						if (c + r) % 2 == 0:
							continue
						var top_y := y + r * square
						var x := x0 + c * square + (strip - r * square) * lean
						draw_colored_polygon(PackedVector2Array([
							Vector2(x, top_y), Vector2(x + square, top_y),
							Vector2(x + square - square * lean, top_y + square), Vector2(x - square * lean, top_y + square)]), Color.WHITE)
				var bar_x := x0 + cols * square + 10.0 * s
				UiKit.draw_slant(self, Rect2(bar_x, y + strip * 0.25, letters.end.x - bar_x, strip * 0.5), UiKit.YELLOW, UiKit.LEAN)
		# The red copy, then the black edge, then the yellow letters.
		for layer in 3:
			var x := letters.position.x + OUTLINE * 0.5 * s
			for run in _runs:
				var at := Vector2(x, base)
				var edge := roundi(OUTLINE * s)
				match layer:
					0:
						draw_string_outline(f, at + SHADOW_AT * s, run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, run[1], edge, UiKit.RED)
						draw_string(f, at + SHADOW_AT * s, run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, run[1], UiKit.RED)
					1:
						draw_string_outline(f, at, run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, run[1], edge, Color.BLACK)
					2:
						draw_string(f, at, run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, run[1], UiKit.YELLOW)
				x += f.get_string_size(run[0], HORIZONTAL_ALIGNMENT_LEFT, -1, run[1]).x


# -------------------------------------------------------------- backdrop

## The dark backdrop with faint speed stripes leaning with the type, now and
## then a red one. `tint` colours the stripes.
class Backdrop extends Control:
	var tint := Color.WHITE
	var red := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([UiKit.INK, UiKit.INK, UiKit.INK_LOW, UiKit.INK_LOW]))
		var lean := UiKit.LEAN
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var x := -h * lean
		while x < w + 40.0:
			var wide := rng.randf_range(2.0, 22.0)
			var alpha := rng.randf_range(0.015, 0.05)
			var colour := Color(tint, alpha)
			if red and rng.randf() < 0.12:
				colour = Color(UiKit.RED, alpha * 1.6)
			draw_colored_polygon(PackedVector2Array([Vector2(x + h * lean, 0), Vector2(x + h * lean + wide, 0), Vector2(x + wide, h), Vector2(x, h)]), colour)
			x += wide + rng.randf_range(10.0, 60.0)


static func backdrop() -> Control:
	return Backdrop.new()
