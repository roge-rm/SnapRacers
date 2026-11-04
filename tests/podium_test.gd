extends Node

## The podium after a cup's last race, on every cup's last course: the top
## three jumping up onto the right steps in order with their own drivers, the
## rest of the field below on the ground clapping or sulking, the winner
## holding the cup's trophy, the karts cleared away, no errors, and the
## standings over it after, with the camera still, until Back frees the race.
## The first cup's show is watched all the way through; the others are
## skipped partway, which jumps to how it ends. The player finishes 5th, 1st
## or last by turns: off the steps they stand in front of the crowd with
## their place over them. Then two cups for two, one with a player on the
## steps and one with both off them.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/podium_test.tscn

var failures := 0
var host: Node
var errors := Errors.new()


## Counts the errors logged, so a cup that logs any fails.
class Errors extends Logger:
	var count := 0
	var last := ""

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1
		last = "%s (%s:%d)" % [rationale if rationale != "" else code, file, line]


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func screen() -> Node:
	for i in range(host.get_child_count() - 1, -1, -1):
		var child := host.get_child(i)
		if not child.is_queued_for_deletion():
			return child
	return null


func _ready() -> void:
	OS.add_logger(errors)
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.settings.set_value("race", "difficulty", Difficulty.DEFAULT)
	var cups := GrandPrix.cups()
	for i in cups.size():
		await _cup(cups[i].id, [5, 1, 0][i % 3])
	Game.settings.set_value("race", "split", Game.SIDE_BY_SIDE)
	await _two(cups[0].id, [2, 7])
	await _two(cups[1].id, [5, 7])
	Game.settings.set_value("race", "split", Game.SOLO)
	OS.remove_logger(errors)
	print("All podium checks passed." if failures == 0 else "%d podium checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The cup `id`, with the player finishing `place`, or last for 0.
func _cup(id: String, place: int) -> void:
	var before := errors.count
	Game.start_grand_prix(id)
	var gp := Game.grand_prix
	# Straight to the last race, before the first one's loaded.
	gp.round = gp.track_ids().size() - 1
	Game.track_path = gp.track_path()
	var race: Race = null
	for i in 300:
		await frames(1)
		if screen() is Race:
			race = screen()
			break
	if race == null:
		check(false, "%s: the last race starts" % id)
		return
	print("-- %s, on %s" % [id, race.track.name])
	await frames(12)
	var who := {}
	for r in race.racers:
		who[r.name] = r.kart.driver
	var order: Array = race.racers.map(func(r): return r.name)
	order.reverse()
	var me := Game.player_name()
	order.erase(me)
	order.insert(order.size() if place == 0 else place - 1, me)
	# In the first cup someone who left earlier is still top of the standings.
	var gone := "Gone Early" if id == GrandPrix.cups()[0].id else ""
	if gone != "":
		gp.points[gone] = 100
	Game.finish_grand_prix_race(order)
	await frames(3)
	var podium := race.podium
	check(podium != null and screen() == race, "the podium goes up on the course")
	if podium == null:
		return
	check(race.racers.is_empty() and race.find_children("*", "Kart", true, false).is_empty(), "and the karts are cleared away")
	var names := gp.standings().map(func(s): return s[0])
	check(podium.order.map(func(e): return e[0]) == names, "everyone's there in the standings' order")
	check(podium.drivers.size() == names.size() and podium.karts.size() == 3, "%d drivers and 3 karts" % podium.drivers.size())
	var parked := podium.karts.map(func(k): return _local(podium, k))
	check(absf(parked[0].x) < 0.01 and parked[1].x < parked[0].x and parked[2].x > parked[0].x and parked[0].z > parked[1].z and parked[0].z > parked[2].z, "the winner's car is in the centre foreground, second and third either side")
	check(range(3, podium.drivers.size()).all(func(p): return podium.players.has(podium.order[p][0]) or _local(podium, podium.drivers[p]).z < parked[0].z), "the crowd stands behind the winner's car")
	check(range(names.size()).all(func(i): return podium.drivers[i].design == who.get(names[i], Kart.default_driver())), "each in the driver they raced as")
	if gone != "":
		check(names[0] == gone and podium.order[0][0] == gone and podium.order[0][1] != null and podium.drivers[0].design == Kart.default_driver(), "someone in the standings who didn't race stands in as the plain racer")
	check(errors.count == before, "with no errors (%d%s)" % [errors.count - before, ", the last " + errors.last if errors.count > before else ""])
	# Taps right after it goes up are ignored.
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	var skipped := [false]
	podium.finished.connect(func(): skipped[0] = true)
	podium._unhandled_input(tap)
	check(not skipped[0], "a tap right after it goes up doesn't skip it")
	race.go_back()
	check(not skipped[0] and race.cup_standings == null, "and an early Back doesn't skip it either")
	check(race.find_children("*", "RaceHud", true, false).is_empty() and race.find_children("*", "TouchControls", true, false).is_empty(), "nothing of the race's HUD is left")
	var skip := podium.skip_button
	check(skip != null and skip.is_visible_in_tree() and skip.get_global_rect().position.x < 100.0 and skip.get_global_rect().position.y < 100.0, "a skip button in the top left")
	skip.pressed.emit()
	check(not skipped[0], "which doesn't skip it right away either")
	if id == GrandPrix.cups()[0].id:
		await _watch(podium)
		if podium.tags.size() == 1:
			check(podium.tags.values()[0].visible, "the player's tag shows while the camera holds still")
	else:
		# Partway, with third up and second in the air.
		podium._time = Podium.LEAPS[1] + 0.2
		await frames(3)
	# A narrow screen pulls the camera back to fit the rows.
	var wide := await _distance_in(podium, Vector2i(1280, 720))
	var narrow := await _distance_in(podium, Vector2i(768, 1024))
	check(narrow > wide and narrow <= Podium.CAMERA_FAR, "the camera pulls back on a portrait screen (%.1f m, %.1f m wide)" % [narrow, wide])
	if id == GrandPrix.cups()[1].id:
		skip.pressed.emit()
		await frames(3)
		check(skipped[0], "the skip button skips to the end")
	else:
		race.go_back()
		await frames(3)
		check(skipped[0], "Back skips to the end")
	check(podium.skip_button == null and (not is_instance_valid(skip) or not skip.is_inside_tree()), "and the skip button goes")
	var feet := []
	var across := []
	for rig in podium.drivers:
		var local: Vector3 = (rig.global_position - podium.middle).rotated(Vector3.UP, -podium.facing * PI * 0.5)
		feet.append(rig.global_position.y - CharacterRig.FEET_BELOW)
		across.append(local.x)
	check(feet[0] > feet[1] and feet[1] > feet[2], "first stands highest, then second, then third")
	check(absf(across[0]) < 0.01 and across[1] < -1.0 and across[2] > 1.0, "first in the middle, second on the left, third on the right")
	var ground: float = race.builder.ground_at(podium.middle.x, podium.middle.z)
	check(feet[2] > ground + 0.2, "on top of the steps")
	var below := true
	for i in range(3, podium.drivers.size()):
		var at := podium.drivers[i].global_position
		var floor_at: float = race.builder.ground_at(at.x, at.z) if podium.ground != null else podium.middle.y
		below = below and absf(feet[i] - floor_at) < 0.05 and (podium.players.has(podium.order[i][0]) or feet[i] < feet[2])
	check(below, "and the field stand on the ground, with the crowd below the steps")
	var mine: int = names.find(me)
	if mine >= 3:
		var front := _local(podium, podium.drivers[mine]).z
		check(range(3).all(func(p): return front > parked[p].z + podium._radius(KartModel.bounds(podium.order[p][1]))), "the player stands clear of the parked cars")
		check(_in_front(podium, [mine]), "the player, %s, stands in front of the crowd" % RaceHud.ordinal(mine + 1))
		check(podium.tags.keys() == [mine] and podium.tags[mine].get_child(0).text == RaceHud.ordinal(mine + 1), "with their place over them")
	else:
		check(podium.tags.is_empty(), "the player's on the steps, %s, with no tag" % RaceHud.ordinal(mine + 1))
	var winner := podium.drivers[0]
	var trophy := podium.trophy
	var cup: Dictionary = GrandPrix.cups().filter(func(c): return c.id == id)[0]
	var pieces := TrophyModel.pieces(cup.get("trophy", {}), Podium.colour_of(cup), "gold").size()
	check(trophy != null and winner.held() == trophy and trophy.get_parent() == winner.upper() and podium.trophy_spec == cup.get("trophy", {}) and trophy.get_child_count() == pieces + 1,
			"the winner holds the cup's trophy (%s)" % cup.get("trophy", {}).get("top", "cup"))
	if trophy != null:
		var hand := winner.hand_position(1)
		var top := winner.to_local(_box_of(trophy).end).y
		check(top > CharacterRig.HEAD_Y, "up high, its top past the middle of the head (%.2f m up)" % top)
		# In the head's own space, where its box fits it closely, whether any
		# corner of the trophy's bricks is inside it.
		var head := winner.head()
		var head_box := AABB()
		var first := true
		for shown in head.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = head.global_transform.affine_inverse() * shown.global_transform * shown.get_aabb()
			head_box = b if first else head_box.merge(b)
			first = false
		var into := trophy.find_children("*", "MeshInstance3D", true, false).filter(func(m):
			var to_head: Transform3D = head.global_transform.affine_inverse() * m.global_transform
			for v in m.mesh.get_faces():
				if head_box.has_point(to_head * v):
					return true
			return false)
		check(into.is_empty(), "clear of their head (%d of its bricks in it)" % into.size())
		check(winner.to_global(hand).distance_to(trophy.global_transform * podium.trophy_grip) < 0.01, "and in their hand")
	var clapping := range(1, podium.drivers.size()).filter(func(i): return podium.drivers[i]._clap_left > 0.0)
	var sulking := range(3, podium.drivers.size()).filter(func(i): return podium.drivers[i]._sulk_left > 0.0)
	check(clapping.size() == podium.drivers.size() - 1 - Podium.SULKING and sulking == range(podium.drivers.size() - Podium.SULKING, podium.drivers.size()),
			"second and third and the field clap, and the last %d sulk" % Podium.SULKING)
	check(podium.confetti.emitting, "and the confetti's coming down")
	var off := race.track.point_at(race.track.offset_of(podium.middle)).distance_to(podium.middle)
	print("  podium %.0f m from the middle of the road%s" % [off, ", on the start straight" if off < race.track.width else ""])
	if not Scenery.theme_named(race.track.theme).get("void", false):
		check(off > race.track.width, "beside the road, off it")
	check(errors.count == before, "and still no errors (%d%s)" % [errors.count - before, ", the last " + errors.last if errors.count > before else ""])
	var standings := race.cup_standings
	check(screen() == race and standings != null and standings.is_visible_in_tree(), "then the standings come up over the podium")
	if standings == null:
		return
	if mine < 3:
		check(standings.find_children("*", "Label", true, false).any(func(l): return l.text.contains("trophy")), "with the trophy")
	else:
		check(standings.find_children("*", "Label", true, false).any(func(l): return l.text.contains("finished %s." % RaceHud.ordinal(mine + 1))), "with where you finished")
	check(not standings.find_children("*", "Control", true, false).any(func(c): return c is UiKit.Backdrop), "and no backdrop over it")
	check(not standings.accepting(), "presses on the standings are ignored at first")
	var press := InputEventKey.new()
	press.pressed = true
	press.keycode = KEY_ENTER
	standings._input(press)
	check(get_viewport().is_input_handled(), "and swallowed")
	get_viewport().set_input_as_handled()
	var first := PadFocus.pick(standings)
	check(PadFocus._race_part(race) == standings and first != null and standings.is_ancestor_of(first), "a controller picks out their buttons (%s)" % (first.text if first is Button else "none"))
	race._open_any()
	race._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(race._menus.is_empty() and not get_tree().paused, "and the pause menu doesn't open over them")
	for i in ceili(Podium.SETTLE * 60.0) + 5:
		await frames(1)
	var held := podium.camera.global_transform
	await frames(10)
	check(podium.still() and podium.camera.global_transform.is_equal_approx(held), "the camera holds still behind them")
	check(standings.accepting(), "then they count")
	check(_tags_clear(podium), "the player's tag isn't under them")
	var laid := [0]
	standings.laid_out.connect(func(): laid[0] += 1)
	var was_window := get_window().size
	get_window().size = Vector2i(900, 1100)
	await frames(4)
	check(laid[0] == 1 and podium.camera.global_transform.is_equal_approx(podium._to) and is_equal_approx(podium.camera.h_offset, podium._shift_to), "a resize lays the panel and camera out again")
	# On a wide screen the panel's down the side, and a player off the steps
	# has their tag showing in the clear part.
	if mine >= 3:
		get_window().size = Vector2i(1600, 720)
		await frames(4)
		for i in ceili(Podium.SETTLE * 60.0) + 5:
			await frames(1)
		var tag: Control = podium.tags[mine]
		check(podium.still() and podium._clear < 1.0 and tag.visible and _tags_clear(podium), "on a wide screen the player's tag shows beside the standings (%s, clear to %.0f%%)" % [tag.get_rect(), podium._clear * 100.0])
	get_window().size = was_window
	await frames(3)
	race.go_back()
	await frames(2)
	check(not is_instance_valid(race) or race.is_queued_for_deletion(), "Back leaves, and the race goes with it")
	check(screen() is CupGrid, "back to the cups")
	await frames(2)


## Watches the show up to the trophy being in the winner's hand: the top
## three jump up third, second then first, and the trophy comes down to them.
func _watch(podium: Podium) -> void:
	var up_at := [INF, INF, INF]
	var tops := []
	var was := INF
	var falling := true
	for place in 3:
		tops.append(podium._on_step[place].y)
	while podium._time < Podium.TROPHY_IN + 0.3:
		await frames(1)
		for place in 3:
			if up_at[place] == INF and absf(podium.drivers[place].position.y - tops[place]) < 0.005:
				up_at[place] = podium._time
		if podium.trophy != null and not podium._landed:
			falling = falling and podium.trophy.global_position.y <= was + 0.0001
			was = podium.trophy.global_position.y
	check(up_at[2] < up_at[1] and up_at[1] < up_at[0] and up_at[0] < Podium.TROPHY_IN, "third, second then first jump up onto their steps (%.1f, %.1f, %.1f s)" % [up_at[2], up_at[1], up_at[0]])
	check(was < INF and falling, "the trophy comes down from above")
	check(podium.drivers[0].held() == podium.trophy, "into the winner's hand")
	check(podium.confetti.emitting, "with confetti")


## The box round everything drawn under `node`, in the world.
func _box_of(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for shown in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = shown.global_transform * shown.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## How far out a copy of `podium` puts its camera in a viewport of `size`.
func _distance_in(podium: Podium, size: Vector2i) -> float:
	var port := SubViewport.new()
	port.size = size
	add_child(port)
	var copy := Podium.new(podium.order, podium.colour, [podium.middle, podium.facing, false])
	port.add_child(copy)
	await frames(1)
	var out := copy._camera_distance()
	port.queue_free()
	return out


## Whether the drivers at `places` stand nearer the front than everyone else
## off the steps, in the podium's own space, on the ground.
func _in_front(podium: Podium, places: Array) -> bool:
	var row := -INF
	for i in range(3, podium.drivers.size()):
		if not places.has(i):
			row = maxf(row, _local(podium, podium.drivers[i]).z)
	for i in places:
		if _local(podium, podium.drivers[i]).z < row + 0.5:
			return false
	return true


func _local(podium: Podium, rig: Node3D) -> Vector3:
	return (rig.global_position - podium.middle).rotated(Vector3.UP, -podium.facing * PI * 0.5)


## Whether every tag shown is clear of the standings panel.
func _tags_clear(podium: Podium) -> bool:
	var width := get_viewport().get_visible_rect().size.x
	for tag in podium.tags.values():
		if tag.visible and (podium._clear >= 1.0 or tag.get_rect().end.x > width * podium._clear):
			return false
	return true


## A cup for two with the players finishing at `places`, player 1 first,
## skipped to the end: those off the steps in front of the crowd with their
## place in their own colour, and none for one on the steps.
func _two(id: String, places: Array) -> void:
	var before := errors.count
	Game.start_grand_prix(id, true)
	var gp := Game.grand_prix
	gp.round = gp.track_ids().size() - 1
	Game.track_path = gp.track_path()
	var race: Race = null
	for i in 300:
		await frames(1)
		if screen() is Race:
			race = screen()
			break
	if race == null:
		check(false, "%s for two: the last race starts" % id)
		return
	print("-- %s for two, finishing %s" % [id, places])
	await frames(12)
	var people := [Game.player_one_name(), Game.player_two_name()]
	var order: Array = race.racers.map(func(r): return r.name).filter(func(n): return not people.has(n))
	for i in [0, 1] if places[0] < places[1] else [1, 0]:
		order.insert(places[i] - 1, people[i])
	Game.finish_grand_prix_race(order)
	await frames(3)
	var podium := race.podium
	if podium == null:
		check(false, "the podium goes up")
		return
	podium._time = Podium.IGNORE_INPUT + 0.1
	podium.skip()
	await frames(3)
	var off := []
	for i in 2:
		if places[i] > 3:
			off.append(places[i] - 1)
	off.sort()
	var keys := podium.tags.keys()
	keys.sort()
	check(keys == off, "tags over just the players off the steps (%s)" % [keys.map(func(k): return k + 1)])
	var right := true
	for i in 2:
		var at: int = places[i] - 1
		if podium.tags.has(at):
			var tag: PanelContainer = podium.tags[at]
			right = right and tag.get_child(0).text == RaceHud.ordinal(places[i])
			right = right and (tag.get_theme_stylebox("panel") as SlantBox).fill == UiKit.PLAYERS[i]
	check(right, "each with their place in their own colour")
	check(_in_front(podium, off), "and they stand in front of the crowd")
	if off.size() == 2:
		check(_local(podium, podium.drivers[places[0] - 1]).x < 0.0 and _local(podium, podium.drivers[places[1] - 1]).x > 0.0, "player 1 on the left, player 2 on the right")
	for i in ceili(Podium.SETTLE * 60.0) + 5:
		await frames(1)
	check(podium.still() and _tags_clear(podium), "the tags stay clear of the standings")
	check(errors.count == before, "with no errors (%d%s)" % [errors.count - before, ", the last " + errors.last if errors.count > before else ""])
	race.go_back()
	await frames(3)
