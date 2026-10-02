class_name ShareWindow
extends PopupPanel

## Sends a course or cup to someone else, as a share code to paste in a
## message or as a file (see Sharing). On a phone both go through Android's
## share sheet. Elsewhere the code's copied, and the file's downloaded (the
## web) or saved where you pick (a computer).

var data: Dictionary
var _said: Label


func _init(what: Dictionary) -> void:
	data = what


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
	column.custom_minimum_size = Vector2(480.0, 0.0)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var cup := Sharing.kind_of(data) == Sharing.CUP
	column.add_child(MenuStyle.heading("Share %s" % str(data.get("name", "this")), "A cup brings its courses with it" if cup else ""))
	var title := "Share %s" % str(data.get("name", ""))
	if ShareSheet.can_send_text():
		column.add_child(MenuStyle.button("Send the code", func() -> void: _say(ShareSheet.send_text(Sharing.message_for(data), title))))
	column.add_child(MenuStyle.button("Copy the code", func() -> void: _say(ShareSheet.copy(Sharing.message_for(data)))))
	var file_words := "Send the file" if Game.plugin.has() else "Download the file" if OS.has_feature("web") else "Save the file"
	column.add_child(MenuStyle.button(file_words, func() -> void:
		_say(ShareSheet.send_file(Sharing.file_name_for(data), Sharing.file_for(data), title, self))))
	_said = Label.new()
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_said.add_theme_color_override("font_color", MenuStyle.ACCENT)
	column.add_child(_said)
	column.add_child(MenuStyle.link("Close", hide))
	popup_hide.connect(queue_free)


func _say(text: String) -> void:
	_said.text = text


## Opens a share window for this course or cup over `parent`.
static func open(what: Dictionary, parent: Node) -> ShareWindow:
	var window := ShareWindow.new(what)
	parent.add_child(window)
	window.popup_centered()
	PadFocus.focus_first(window)
	return window
