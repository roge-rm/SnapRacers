class_name TrackEditorPad
extends Node

## The track editor with a controller.
##
## - In the drawer, the d-pad moves round the pieces, A adds one to the end of
##   the road (or after the piece picked out), and LB and RB go to the tab
##   before or after. Y goes onto the road.
## - On the road, left and right step from piece to piece, A goes into its
##   buttons (surface, walls, add after), and X takes it out. B goes back to
##   the drawer.
## - With a landmark in hand, the left stick moves it, X turns it, A puts it
##   down, Back takes it away and B puts it back.
##
## LT and RT undo and redo, Back is Close it up, the right stick turns the
## view and pressing it in fits the course in view, and Start opens the file
## menu. B from the drawer leaves the editor.

const PUSH := 0.6
## How fast the right stick turns the view, and the left stick moves a
## landmark, in pixels a second.
const ORBIT := 700.0
const SLIDE := 900.0

var editor: TrackEditor
## Stepping along the road rather than in the drawer.
var on_road := false

var _triggers := { JOY_AXIS_TRIGGER_LEFT: false, JOY_AXIS_TRIGGER_RIGHT: false }


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and _triggers.has(event.axis):
		var down: bool = event.axis_value > PUSH
		if down and not _triggers[event.axis]:
			PadFocus.using_pad = true
			editor.redo() if event.axis == JOY_AXIS_TRIGGER_RIGHT else editor.undo()
		_triggers[event.axis] = down
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	PadFocus.using_pad = true
	if _button(event.button_index):
		get_viewport().set_input_as_handled()


func _button(button: JoyButton) -> bool:
	var holding := not editor._holding.is_empty()
	var in_actions := _focus_in(editor.ui._actions)
	match button:
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			if on_road and not in_actions and not holding:
				_step(1 if button == JOY_BUTTON_DPAD_RIGHT else -1)
				return true
			return _focus_drawer() if not on_road and not holding else false
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN:
			if on_road or holding:
				return false
			return _focus_drawer()
		JOY_BUTTON_A:
			if holding:
				editor.drop_landmark()
			elif on_road and not in_actions:
				var first := PadFocus.first_button(editor.ui._actions)
				if first != null:
					first.grab_focus()
			else:
				return false # the focused button takes it
		JOY_BUTTON_B:
			if holding:
				editor._drop_holding()
			elif in_actions:
				_release_focus()
			elif on_road:
				on_road = false
				editor._select(-1)
				_focus_drawer(true)
			else:
				editor.go_back()
		JOY_BUTTON_X:
			if holding:
				editor.ui.turn_landmark_pressed.emit()
			elif on_road:
				editor.delete_selected()
				if editor.course.pieces.is_empty():
					on_road = false
			else:
				return false
		JOY_BUTTON_Y:
			if holding or editor.course.pieces.is_empty():
				return false
			on_road = true
			_release_focus()
			editor._select(editor.selected if editor.selected >= 0 else editor.course.pieces.size() - 1)
			editor._follow(editor.selected)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			var ui := editor.ui
			var tabs: int = TrackEditorUI.CATEGORIES.size() + 1
			ui._show_category(posmod(ui._category + (1 if button == JOY_BUTTON_RIGHT_SHOULDER else -1), tabs))
			on_road = false
			_focus_drawer.call_deferred(true)
		JOY_BUTTON_BACK:
			if holding:
				editor.remove_landmark()
			else:
				editor.close_up()
		JOY_BUTTON_START:
			editor.ui._file_menu.popup_centered(Vector2i(320, 0))
		JOY_BUTTON_RIGHT_STICK:
			editor.fit_view()
		_:
			return false
	return true


## Picks out the piece before or after along the road.
func _step(by: int) -> void:
	var count := editor.course.pieces.size()
	if count == 0:
		return
	var next := posmod((editor.selected if editor.selected >= 0 else count - 1) + by, count)
	editor._select(next)
	editor._follow(next)
	Sounds.play("fx/pick")


func _focus_in(panel: Control) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused != null and panel.is_ancestor_of(focused)


func _focus_drawer(again := false) -> bool:
	if _focus_in(editor.ui._tiles) and not again:
		return false
	for tile in editor.ui._tiles.get_children():
		if tile is BaseButton and not tile.is_queued_for_deletion():
			tile.grab_focus()
			return true
	return false


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


## The sticks: the right one turns the view and the left one moves a
## landmark in hand.
func _process(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty() or editor == null:
		return
	var pad: int = pads[0]
	var right := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
	if right.length() > 0.2:
		editor._orbit(right * ORBIT * delta)
	if editor._holding.is_empty():
		return
	var left := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	if left.length() < 0.2:
		return
	var middle := get_viewport().get_visible_rect().size * 0.5
	var here := editor._camera.unproject_position(Vector3(float(editor._holding.at[0]), 0.0, float(editor._holding.at[1])))
	var to := editor._ground_point(here + left * SLIDE * delta)
	if not here.is_finite():
		to = editor._ground_point(middle)
	editor._holding.at = [to.x, to.z]
	editor._show_ghost()
