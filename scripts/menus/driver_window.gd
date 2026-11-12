class_name DriverWindow
extends PopupPanel

## The driver cards (DriverGrid) in a window over the kart picker, to change
## who drives without going back. It stays open until a driver's picked or
## Close is tapped, fills the screen's height with the cards scrolling and
## keeps clear of a camera hole.

signal picked(key: String)
signal new_driver

## How far in from the screen's edges it sits, in the UI's own units.
const EDGE := 20.0
## Room for the scroll bar beside the cards.
const BAR := 16.0

var grid: DriverGrid
var _current := ""
var _taken_by_p1 := ""
var _player := 0
var _can_make := true


## As DriverGrid.new(): `current` is marked, and on player 2's window
## `taken_by_p1` gets a P1 tag, and without `can_make` there's no New
## driver card.
func _init(current: String, taken_by_p1 := "", for_player := 0, can_make := true) -> void:
	_current = current
	_taken_by_p1 = taken_by_p1
	_player = for_player
	_can_make = can_make


func _ready() -> void:
	theme = MenuStyle.theme()
	# It only closes with Close, B or a pick, never by tapping beside it or
	# the window losing focus. Nothing behind it can be tapped meanwhile.
	popup_window = false
	exclusive = true
	PadFocus.close_on_b(self)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	column.add_child(top)
	var heading := MenuStyle.heading("Pick a driver" if _player == 0 else "Player %d, pick your driver" % _player)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close := MenuStyle.link("Close", hide, "close")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	grid = DriverGrid.new(_current, _taken_by_p1, _player, _can_make)
	grid.custom_minimum_size.x = DriverGrid.width() + BAR
	scroll.add_child(grid)
	grid.picked.connect(func(key: String) -> void:
		hide()
		picked.emit(key))
	grid.new_driver.connect(func() -> void:
		hide()
		new_driver.emit())
	popup_hide.connect(queue_free)


## Where it goes: the screen less EDGE, shortened at the top or bottom for a
## hole in a corner and narrowed for one partway down a side, then only as
## wide as the cards need, in the middle of what's left.
func _room() -> Rect2i:
	var shown := get_parent().get_viewport().get_visible_rect()
	var rect := shown.grow(-EDGE)
	for hole in SafeArea.holes_in(get_parent().get_viewport()):
		var clear := hole.grow(SafeArea.CLEAR)
		if not rect.intersects(clear):
			continue
		var corner := clear.end.y < rect.position.y + rect.size.y * 0.35 or clear.position.y > rect.end.y - rect.size.y * 0.35
		if corner:
			if clear.get_center().y < rect.get_center().y:
				rect = Rect2(rect.position.x, clear.end.y, rect.size.x, rect.end.y - clear.end.y)
			else:
				rect.size.y = clear.position.y - rect.position.y
		elif clear.get_center().x < rect.get_center().x:
			rect = Rect2(clear.end.x, rect.position.y, rect.end.x - clear.end.x, rect.size.y)
		else:
			rect.size.x = clear.position.x - rect.position.x
	var wide := minf(rect.size.x, get_contents_minimum_size().x)
	return Rect2i(Rect2(rect.position.x + (rect.size.x - wide) * 0.5, rect.position.y, wide, rect.size.y))


## Opens the window over `parent`, with the marked card in view.
static func open(parent: Node, current: String, taken_by_p1 := "", for_player := 0, can_make := true) -> DriverWindow:
	var window := DriverWindow.new(current, taken_by_p1, for_player, can_make)
	parent.add_child(window)
	window.popup(window._room())
	if PadFocus.using_pad and window.grid.marked_card() != null:
		window.grid.marked_card().grab_focus()
	return window
