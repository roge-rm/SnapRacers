extends Node

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _ready() -> void:
	for mode in [Game.MODE_RACE, Game.MODE_TIME_TRIAL, Game.MODE_GRAND_PRIX]:
		for width in [288.0, 340.0, 440.0]:
			await layout(mode, width, false)
	await layout(Game.MODE_RACE, 288.0, true)
	print("%d results layout checks passed, %d failed." % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)


func layout(mode: String, width: float, online: bool) -> void:
	var race := Race.new()
	race.mode = mode
	var session := NetSession.new()
	if online:
		race.net = NetRace.new(race, session)
	var hud := RaceHud.new()
	hud.race = race
	hud._build_results()
	var panel: PanelContainer = hud._results
	hud.remove_child(panel)
	var host := Control.new()
	host.theme = UiKit.theme()
	add_child(host)
	host.add_child(panel)
	panel.show()
	panel.size = Vector2(width, 400)
	for i in 3:
		await get_tree().process_frame
	var column := hud._results_column
	var actions: VBoxContainer = column.get_children().filter(func(child): return child is VBoxContainer)[0]
	var buttons := actions.find_children("*", "Button", true, false)
	var expected := 1 if online else (2 if mode == Game.MODE_GRAND_PRIX else 3)
	check(buttons.size() == expected and panel.size.x <= width + 0.1, "%s actions fit %.0f px card" % [mode, width])
	var inside := true
	for button: Button in buttons:
		inside = inside and panel.get_global_rect().encloses(button.get_global_rect())
	check(inside, "all action bounds stay inside the results card")
	var primary: Button = buttons[0]
	check(is_equal_approx(primary.size.x, column.size.x), "primary action fills the card's inner width")
	if expected == 3:
		var a: Button = buttons[1]
		var b: Button = buttons[2]
		check(b.position.y >= a.position.y + a.size.y and is_equal_approx(a.size.x, b.size.x), "secondary actions have evenly spaced full-width rows")
		check(is_equal_approx(a.global_position.x, primary.global_position.x) and is_equal_approx(b.global_position.x + b.size.x, primary.global_position.x + primary.size.x), "secondary row aligns with both primary edges")
	var pressed := [false]
	hud.again_pressed.connect(func() -> void: pressed[0] = true)
	if not online and mode == Game.MODE_RACE:
		primary.pressed.emit()
		check(pressed[0], "primary action keeps its race-again signal")
	host.queue_free()
	hud.free()
	if race.net != null:
		race.net.free()
	race.free()
	session.free()
	await get_tree().process_frame
