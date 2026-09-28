class_name CupPicker
extends Control

## Pick which Grand Prix cup to race. Each one lists its four courses and the
## best you've done in it so far at each difficulty.

const TROPHIES := { 1: "Gold trophy", 2: "Silver trophy", 3: "Bronze trophy" }
const MEDALS := { 1: "Gold", 2: "Silver", 3: "Bronze" }


func _ready() -> void:
	var column := MenuStyle.page(self, "Grand Prix", Game.show_single_player, 760.0)
	for cup in GrandPrix.cups():
		var names: Array = cup.tracks.map(func(id): return TrackPath.load_file(Tracks.path_of(id)).name)
		var line := ", ".join(names)
		# The best you've done at each difficulty.
		var bests := []
		for level in Difficulty.LEVELS:
			var best := Records.best_cup_place(cup.id, level)
			if best > 0:
				bests.append("%s on %s" % [MEDALS.get(best, RaceHud.ordinal(best)), Difficulty.name_of(level)])
		if not bests.is_empty():
			line += "\n" + ", ".join(bests)
		var button := MenuStyle.button(cup.name, Game.show_kart_picker.bind(Game.start_grand_prix.bind(cup.id), Game.show_cups, true), line)
		button.custom_minimum_size.y = 96.0
		button.set_meta("cup", cup.id)
		column.add_child(button)
	MenuStyle.back_at_bottom(column, Game.show_single_player)


func go_back() -> void:
	Game.show_single_player()
