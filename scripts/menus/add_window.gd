class_name AddWindow
extends PopupPanel

## Adds a course or cup someone's sent you, from a share code or a file (see
## Sharing). Whichever it turns out to be goes with your courses or your cups.

## Something was added, or was yours already, with its kind and where it is.
signal added(kind: String, path: String)
## It's closed, with whether anything was added while it was open.
signal done(any_added: bool)

var heading := "Add a course or cup"
var _code: LineEdit
var _said: Label
var _any_added := false


func _init(title := "") -> void:
	if title != "":
		heading = title


func _ready() -> void:
	theme = MenuStyle.theme()
	var panel := BuilderStyle.scrim(16, 1.0)
	panel.set_content_margin_all(24)
	add_theme_stylebox_override("panel", panel)
	# It stays open while Android's share sheet or file picker is in front,
	# and closes with Close. Nothing behind it can be tapped meanwhile.
	popup_window = false
	exclusive = true
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560.0, 0.0)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.add_child(MenuStyle.heading(heading))
	# The web can't read what's been copied until it's pasted in.
	if not OS.has_feature("web"):
		column.add_child(MenuStyle.button("Add the code I copied", func() -> void: _add(DisplayServer.clipboard_get())))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	_code = LineEdit.new()
	_code.placeholder_text = "Paste a code"
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size.y = MenuStyle.BUTTON_HEIGHT
	_code.text_submitted.connect(func(text: String) -> void: _add(text))
	row.add_child(_code)
	row.add_child(MenuStyle.button("Add", func() -> void: _add(_code.text)))
	column.add_child(MenuStyle.button("Open a file", func() -> void:
		ShareSheet.open_file(self, func(text: String, why: String) -> void:
			if text != "":
				_add(text)
			elif why != "":
				_say(why))))
	_said = Label.new()
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.add_theme_color_override("font_color", MenuStyle.ACCENT)
	column.add_child(_said)
	column.add_child(MenuStyle.link("Close", hide))
	popup_hide.connect(func() -> void:
		done.emit(_any_added)
		queue_free())


func _add(text: String) -> void:
	if text.strip_edges() == "":
		_say("There's nothing to add.")
		return
	var found := Sharing.read(text)
	if found.has("why"):
		_say(found.why)
		return
	var result := Sharing.add(found)
	_say(result.said)
	_code.text = ""
	if result.path != "":
		_any_added = true
		added.emit(found.kind, result.path)


func _say(text: String) -> void:
	_said.text = text


## Opens an add window over `parent`.
static func open(parent: Node, title := "") -> AddWindow:
	var window := AddWindow.new(title)
	parent.add_child(window)
	window.popup_centered()
	PadFocus.focus_first(window)
	return window
