extends Node

## Looks after what carries from one screen to the next (the kart you're
## building) and swaps between the screens. There's no main menu yet, so the
## game opens in the garage.

const STARTER := "res://data/karts/starter.json"

var design: KartDesign
var theme: Theme

var _host: Node
var _screen: Node


func _ready() -> void:
	design = KartDesign.load_file(STARTER)
	theme = Theme.new()
	theme.default_font_size = 22


func start(host: Node) -> void:
	_host = host
	show_garage()


func show_garage() -> void:
	_swap(Garage.new())


func show_drive() -> void:
	_swap(TestDrive.new())


func _swap(next: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = next
	_host.add_child(next)
