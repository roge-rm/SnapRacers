extends Node

## A tap on a half hidden button in a scrolling list (the list follows the
## focus) still counts, and a drag or a touch on a coasting list doesn't. The
## presses go through the viewport like real ones.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/scroll_tap_test.tscn

var failures := 0
var list: ScrollContainer
var taps := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func build() -> void:
	if list != null:
		list.queue_free()
		await frames(2)
	get_viewport().gui_release_focus()
	list = ScrollContainer.new()
	list.follow_focus = true
	list.position = Vector2(20, 20)
	list.size = Vector2(200, 200)
	add_child(list)
	var box := VBoxContainer.new()
	list.add_child(box)
	for i in 5:
		var b := ScrollButton.new()
		b.custom_minimum_size = Vector2(200, 80)
		b.tapped.connect(func() -> void: taps += 1)
		box.add_child(b)
	await frames(3)
	taps = 0


func button(index: int) -> ScrollButton:
	return list.get_child(0).get_child(index)


## In the viewport's own coordinates, so the window's stretch doesn't move it.
func send(event: InputEvent) -> void:
	get_viewport().push_input(event, true)


func mouse(pos: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	e.position = pos
	e.global_position = pos
	return e


func touch(pos: Vector2, down: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = down
	e.position = pos
	return e


func motion(pos: Vector2, from: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = pos
	e.global_position = pos
	e.relative = pos - from
	return e


## A press and release at `pos`, `wait` frames apart. A touch comes the way
## the phone sends it, the mouse press it makes first and then the touch.
func tap(pos: Vector2, touching: bool, wait := 5) -> void:
	send(motion(pos, pos))
	send(mouse(pos, true))
	if touching:
		send(touch(pos, true))
	await frames(wait)
	send(mouse(pos, false))
	if touching:
		send(touch(pos, false))
	await frames(2)


func _ready() -> void:
	await frames(2)
	# The third button spans 160 to 240 in the list, which shows 0 to 200.
	await build()
	var spot := button(2).get_global_rect().position + Vector2(100, 20)
	await tap(spot, false)
	check(list.scroll_vertical > 4, "the list follows the focus (scrolled to %d)" % list.scroll_vertical)
	check(taps == 1, "a click on a half hidden button taps once (taps %d)" % taps)

	await build()
	await tap(spot, true)
	check(list.scroll_vertical > 4, "the list follows the focus on a touch (scrolled to %d)" % list.scroll_vertical)
	check(taps == 1, "a touch on a half hidden button taps once (taps %d)" % taps)

	await build()
	var top := button(0).get_global_rect().position + Vector2(100, 40)
	await tap(top, false)
	check(taps == 1, "a click on a button in full view taps once (taps %d)" % taps)

	await build()
	send(mouse(top, true))
	await frames(1)
	var at := top
	for i in 6:
		var to := at + Vector2(0, 10)
		send(motion(to, at))
		at = to
		await frames(1)
	send(mouse(at, false))
	await frames(2)
	check(taps == 0, "a drag does not tap (taps %d)" % taps)

	await build()
	send(mouse(top, true))
	await frames(1)
	list.scroll_vertical = 50
	await frames(2)
	send(mouse(top, false))
	await frames(2)
	check(taps == 0, "a press while the list scrolls does not tap (taps %d)" % taps)

	await build()
	list.scroll_vertical = 40
	await frames(1)
	var near := button(1).get_global_rect().position + Vector2(100, 40)
	await tap(near, true, 1)
	check(taps == 0, "a touch on a list that just scrolled does not tap (taps %d)" % taps)
	OS.delay_msec(200)
	await frames(1)
	await tap(near, true, 1)
	check(taps == 1, "a touch once the list is still taps (taps %d)" % taps)

	print("scroll tap test: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
