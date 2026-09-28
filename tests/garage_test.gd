extends Node

## Uses the garage the way a player would, with pretend touches, and checks
## what happens to the kart.
##
## It runs as a scene rather than a -s script, because the screens use the
## Game autoload and -s scripts can't see autoloads. Run it with:
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/garage_test.tscn

var failures := 0
var garage: Garage
var step := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func touch(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = pressed
	# Straight to the garage: the headless window is tiny and stretched, so
	# a touch pushed through the viewport lands somewhere else.
	garage._unhandled_input(event)


## Where a grid position shows up on the screen.
func screen_of(cell: Vector3) -> Vector2:
	return get_viewport().get_camera_3d().unproject_position(Grid.to_metres(cell))


var host: Node


func _ready() -> void:
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	# Start from the starter kart, not whatever an earlier run left as the
	# kart being worked on.
	Game.design = KartDesign.load_file(Game.STARTER)
	Game.show_garage()


func _process(_delta: float) -> void:
	step += 1
	match step:
		3:
			garage = host.get_child(host.get_child_count() - 1)
			check(garage is Garage, "the game opens in the garage")
			garage.finger_lift = 0.0
			check(garage.design.parts.size() == 15, "with the starter kart in it")
			garage.ui.part_chosen.emit("brick_2x2")
			check(garage._holding == "brick_2x2", "picking a part in the bank puts it in your hand")
			# The top of the chassis, in the free spot beside the seat. (A little
			# further forward is hidden behind the front bricks from this angle.)
			var spot := screen_of(Vector3(8.0, 3.0, 12.5))
			check(not garage.ui.is_over_ui(spot), "that spot on the chassis isn't under a panel (%s)" % spot)
			touch(spot, true)
			touch(spot, false)
		5:
			check(garage.design.parts.size() == 16, "touching the chassis puts the brick down")
			var placed: Dictionary = garage.design.parts[15]
			check(placed.at.y == 3, "on top of the chassis (%s)" % placed.at)
			check(garage.design.problems().is_empty(), "and the kart is still fine %s" % [garage.design.problems()])
			garage.ui.undo_pressed.emit()
			check(garage.design.parts.size() == 15, "undo takes it back off")
			garage.ui.done_pressed.emit()
			check(garage._holding == "", "done empties your hand")
			var engine := screen_of(Vector3(10.0, 6.0, 14.5))
			touch(engine, true)
			touch(engine, false)
		7:
			check(garage._selected != -1, "touching a part picks it out")
			var id: String = garage.design.parts[garage._selected].id if garage._selected != -1 else ""
			check(id == "engine_small" or id == "spoiler_6", "the part I touched (%s)" % id)
			garage.ui.remove_pressed.emit()
			check(garage.design.parts.size() == 14, "remove takes it off")
			check(not garage.design.problems().is_empty(), "and then the kart has a problem %s" % [garage.design.problems()])
			garage.ui.undo_pressed.emit()
			check(garage.design.problems().is_empty(), "undo fixes it again")
			garage.ui.drive_pressed.emit()
		10:
			var screen := host.get_child(host.get_child_count() - 1)
			check(screen is TestDrive, "drive takes the kart out to the track")
			print("All garage checks passed." if failures == 0 else "%d garage checks failed." % failures)
			get_tree().quit(1 if failures > 0 else 0)
