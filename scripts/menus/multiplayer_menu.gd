class_name MultiplayerMenu
extends Control

## Racing with other people: two people on one phone, sharing the screen
## side by side (landscape, half each) or face to face (portrait, with the
## phone flat between them), against six AI karts, or online against people
## on other devices. Each player picks their kart once the course is picked
## (see KartPicker).

const LAYOUTS := [
	[Game.SIDE_BY_SIDE, "Side by side", "Landscape, half the screen each"],
	[Game.FACE_TO_FACE, "Face to face", "Portrait, with the phone flat between you"],
]

var _layout_buttons: Array[Button] = []


func _ready() -> void:
	var column := MenuStyle.page(self, "Multiplayer", Game.show_menu, 760.0)
	# Two players always share the screen one way or the other.
	if Game.split() == Game.SOLO:
		Game.set_setting("race", "split", Game.SIDE_BY_SIDE)
	column.add_child(MenuStyle.heading("Two players on this phone"))
	var layouts := HBoxContainer.new()
	layouts.add_theme_constant_override("separation", 14)
	column.add_child(layouts)
	for layout in LAYOUTS:
		var button := MenuStyle.button(layout[1], _set_layout.bind(layout[0]), layout[2])
		button.custom_minimum_size.y = 84.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("mode", layout[0])
		layouts.add_child(button)
		_layout_buttons.append(button)
	var owners := ControlsPage.new()
	owners.owners_only = true
	column.add_child(owners)
	var go := MenuStyle.button("Pick a course", Game.show_tracks.bind(Game.MODE_RACE))
	go.custom_minimum_size.y = 72.0
	column.add_child(go)
	column.add_child(MenuStyle.heading("Online"))
	var online := MenuStyle.button("Host or join a game", Game.show_online)
	online.custom_minimum_size.y = 72.0
	column.add_child(online)
	MenuStyle.back_at_bottom(column, Game.show_menu)
	_show()


func _set_layout(layout: String) -> void:
	Game.set_setting("race", "split", layout)
	_show()


## Lights up the chosen layout.
func _show() -> void:
	for button in _layout_buttons:
		MenuStyle.mark(button, button.get_meta("mode") == Game.split())


func go_back() -> void:
	Game.show_menu()
