class_name MultiplayerMenu
extends Control

## Racing with other people. For now that's two people on one phone, sharing
## the screen side by side (landscape, half each) or face to face (portrait,
## with the phone flat between them), against six AI karts. Player 2 drives
## one of the AI karts, and you pick which one here. Racing over a network is
## coming later.

const LAYOUTS := [
	[Game.SIDE_BY_SIDE, "Side by side", "Landscape, half the screen each"],
	[Game.FACE_TO_FACE, "Face to face", "Portrait, with the phone flat between you"],
]

var _layout_buttons: Array[Button] = []
var _second: Button


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
	_second = MenuStyle.button("", _next_kart)
	column.add_child(_second)
	var go := MenuStyle.button("Pick a course", Game.show_tracks.bind(Game.MODE_RACE))
	go.custom_minimum_size.y = 72.0
	column.add_child(go)
	column.add_child(MenuStyle.heading("Online", "Racing other phones over Wi-Fi or the internet is coming later"))
	MenuStyle.back_at_bottom(column, Game.show_menu)
	_show()


func _set_layout(layout: String) -> void:
	Game.set_setting("race", "split", layout)
	_show()


## Lights up the chosen layout and shows which kart player 2 drives.
func _show() -> void:
	for button in _layout_buttons:
		MenuStyle.mark(button, button.get_meta("mode") == Game.split())
	var design := Game.stock_kart(Game.player_two_kart())
	_second.text = "Player 2 drives the %s   ›" % design.name


## Player 2 moves on to the next stock kart.
func _next_kart() -> void:
	var keys := Game.stock_keys()
	var next := keys[(keys.find(Game.player_two_kart()) + 1) % keys.size()]
	Game.set_setting("race", "player_two", next)
	_show()


func go_back() -> void:
	Game.show_menu()
