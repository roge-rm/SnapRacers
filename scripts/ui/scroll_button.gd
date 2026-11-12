class_name ScrollButton
extends Button

## A button that can sit in a scrolling list. A drag that starts on it goes
## through to the list, so you can scroll by dragging anywhere, and a finger
## or mouse click only does its thing if it didn't move and the list didn't
## scroll. A touch that stops the list coasting doesn't count as a tap either.
## A controller or key press always counts, even if the list has scrolled.
##
## let_scroll gives any other button the same behaviour.

signal tapped

const DRAG := 20.0
## A touch this soon after the list last moved is taken as stopping it, in
## milliseconds.
const STILL_FOR := 150

var _drag: Drag


func _init() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	_drag = Drag.new(self)
	pressed.connect(func() -> void:
		if _drag.counts():
			tapped.emit())
	focus_entered.connect(func() -> void: UiMotion.pop(self))
	button_down.connect(func() -> void: UiMotion.press(self))


func _ready() -> void:
	_drag.find_list()


## Whether the list has scrolled since the finger went down.
func scrolled() -> bool:
	return _drag.scrolled()


func _gui_input(event: InputEvent) -> void:
	_drag.feed(event)


## Makes `button` let drags through to the scrolling list it's in, and run
## `action` only on a press that counts as a tap. Connect the action here
## instead of to `pressed`.
static func let_scroll(button: BaseButton, action: Callable) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var drag := Drag.new(button)
	button.set_meta("scroll_drag", drag)
	button.gui_input.connect(drag.feed)
	button.pressed.connect(func() -> void:
		if drag.counts():
			action.call())
	if button.is_inside_tree():
		drag.find_list()
	else:
		button.ready.connect(drag.find_list, CONNECT_ONE_SHOT)


## Follows one button's finger or mouse presses to tell a tap from a drag.
class Drag:
	extends RefCounted

	var _button: Control
	var _press := Vector2.ZERO
	var _moved := false
	var _pointer := false
	var _list: ScrollContainer
	var _scroll_at := Vector2.ZERO
	## The frame the button last took the focus, to tell the list's jump to
	## show it from a real scroll.
	var _focus_frame := -1

	func _init(button: Control) -> void:
		_button = button
		button.focus_entered.connect(func() -> void: _focus_frame = Engine.get_process_frames())

	func _note_scroll() -> void:
		_scroll_at = Vector2(_list.scroll_horizontal, _list.scroll_vertical)

	## Finds the list the button is in and starts noting when it scrolls:
	## scrolled_at is the last time in milliseconds, scrolled_frame its frame
	## and scrolled_before the last time from an earlier frame.
	func find_list() -> void:
		var up := _button.get_parent()
		while up != null and not up is ScrollContainer:
			up = up.get_parent()
		_list = up
		if _list != null and not _list.has_meta("scrolled_at"):
			_list.set_meta("scrolled_at", 0)
			_list.set_meta("scrolled_before", 0)
			_list.set_meta("scrolled_frame", -1)
			var list := _list
			var mark := func(_value: float) -> void:
				var frame := Engine.get_process_frames()
				if int(list.get_meta("scrolled_frame")) != frame:
					list.set_meta("scrolled_before", list.get_meta("scrolled_at"))
					list.set_meta("scrolled_frame", frame)
				list.set_meta("scrolled_at", Time.get_ticks_msec())
			_list.get_v_scroll_bar().value_changed.connect(mark)
			_list.get_h_scroll_bar().value_changed.connect(mark)

	func scrolled() -> bool:
		if _list == null:
			return false
		return Vector2(_list.scroll_horizontal, _list.scroll_vertical).distance_to(_scroll_at) > 4.0

	## Whether the press that just ended counts as a tap. Clears it either way.
	func counts() -> bool:
		var skip := _pointer and (_moved or scrolled())
		_pointer = false
		_moved = false
		return not skip

	func feed(event: InputEvent) -> void:
		var down: bool = (event is InputEventScreenTouch and event.pressed) \
				or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if down:
			_press = event.position
			_moved = false
			_pointer = true
			if _list != null:
				_pressed_list()
		elif event is InputEventScreenDrag and event.position.distance_to(_press) > DRAG:
			_moved = true
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT \
				and event.position.distance_to(_press) > DRAG:
			_moved = true

	## A press that gave the button the focus made the list jump to show it,
	## in this frame and maybe once more at the end of it. That jump isn't the
	## list moving, so the press is taken from after it, and only a scroll
	## from an earlier frame counts as the list still coasting.
	func _pressed_list() -> void:
		_note_scroll()
		var frame := Engine.get_process_frames()
		var last := int(_list.get_meta("scrolled_at", 0))
		var own := _focus_frame == frame
		if own and int(_list.get_meta("scrolled_frame", -1)) == frame:
			last = int(_list.get_meta("scrolled_before", 0))
		if Time.get_ticks_msec() - last < STILL_FOR:
			_moved = true
		if own:
			await _button.get_tree().process_frame
			if _pointer and not _moved:
				_note_scroll()
