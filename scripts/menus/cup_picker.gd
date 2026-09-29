class_name CupPicker
extends Control

## Pick which Grand Prix cup to race. Each one lists its courses and the best
## you've done in it so far at each difficulty. The game's four cups come
## first, then any you've made, and you can make more from here.

const TROPHIES := { 1: "Gold trophy", 2: "Silver trophy", 3: "Bronze trophy" }
const MEDALS := { 1: "Gold", 2: "Silver", 3: "Bronze" }


func _ready() -> void:
	var column := MenuStyle.page(self, "Grand Prix", Game.show_single_player, 760.0)
	for cup in GrandPrix.cups():
		var names: Array = cup.tracks.map(func(id): return TrackPath.load_file(Tracks.path_of(id)).name)
		var button := MenuStyle.button(cup.name, Game.show_kart_picker.bind(Game.start_grand_prix.bind(cup.id), Game.show_cups, true), _line(names, cup.id))
		button.custom_minimum_size.y = 96.0
		button.set_meta("cup", cup.id)
		column.add_child(button)

	column.add_child(MenuStyle.heading("Your cups", "Put together from any courses, the game's and yours"))
	for path in CupDesign.saved():
		var mine := CupDesign.load_file(path)
		if mine == null or mine.problem() != "":
			continue
		var id := CupDesign.id_of(path)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		column.add_child(row)
		var button := MenuStyle.button(mine.name, Game.show_kart_picker.bind(_starter(mine, id), Game.show_cups, true), _line(mine.course_names(), id))
		button.custom_minimum_size.y = 96.0
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.set_meta("cup", id)
		row.add_child(button)
		row.add_child(MenuStyle.link("Change", Game.show_cup_builder.bind(path)))
	column.add_child(MenuStyle.button("Make a cup", Game.show_cup_builder.bind("")))
	MenuStyle.back_at_bottom(column, Game.show_single_player)


## The courses in a cup, and the best you've done in it at each difficulty.
static func _line(names: Array, id: String) -> String:
	var line := ", ".join(names)
	var bests := []
	for level in Difficulty.LEVELS:
		var best := Records.best_cup_place(id, level)
		if best > 0:
			bests.append("%s on %s" % [MEDALS.get(best, RaceHud.ordinal(best)), Difficulty.name_of(level)])
	if not bests.is_empty():
		line += "\n" + ", ".join(bests)
	return line


## What starts a cup of yours once a kart's picked. Its courses are put out
## to race then, and it's made here, away from this screen, which is gone
## by then.
static func _starter(mine: CupDesign, id: String) -> Callable:
	return func() -> void: Game.start_grand_prix(mine.to_cup(id))


func go_back() -> void:
	Game.show_single_player()
