class_name CupPicker
extends Control

## Pick which Grand Prix cup to race. Each one lists its four courses and the
## best you've done in it so far.

const TROPHIES := { 1: "Gold trophy", 2: "Silver trophy", 3: "Bronze trophy" }


func _ready() -> void:
	var column := MenuStyle.page(self, "Grand Prix", Game.show_single_player, 760.0)
	for cup in GrandPrix.cups():
		var names: Array = cup.tracks.map(func(id): return TrackPath.load_file(Tracks.path_of(id)).name)
		var line := ", ".join(names)
		var best := Records.best_cup_place(cup.id)
		if best > 0:
			line += "\n" + TROPHIES.get(best, "Best finish %s" % RaceHud.ordinal(best))
		var button := MenuStyle.button(cup.name, Game.show_kart_picker.bind(Game.start_grand_prix.bind(cup.id), Game.show_cups), line)
		button.custom_minimum_size.y = 96.0
		button.set_meta("cup", cup.id)
		column.add_child(button)
	MenuStyle.back_at_bottom(column, Game.show_single_player)


func go_back() -> void:
	Game.show_single_player()
