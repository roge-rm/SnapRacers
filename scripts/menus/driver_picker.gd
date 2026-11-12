class_name DriverPicker
extends Control

## Pick who drives before a race: your own driver, one you've saved or a
## stock driver, or make a new one. Tapping a card picks that driver.
##
## Two on one phone each pick in turn, with a big tag in their own colour
## saying whose turn it is, and the driver player 1 took marked P1 on player
## 2's cards.

var player := 0
var _go: Callable
var _back: Callable
var _new: Callable
var _current := ""
var _taken_by_p1 := ""
var grid: DriverGrid


## `go` is called with the pick key (see CharacterDesign.for_key()),
## `back` with nothing, and `make_new` when "New driver" is tapped.
## `for_player` is 1 or 2 when two are picking, or 0.
func _init(go: Callable, back: Callable, current := CharacterDesign.OWN_KEY, taken_by_p1 := "", for_player := 0, make_new := Callable()) -> void:
	_go = go
	_back = back
	_current = current
	_taken_by_p1 = taken_by_p1
	player = for_player
	_new = make_new


## Filed apart from the other player's picker in the pad's memory.
func focus_key() -> String:
	return "DriverPicker/%d" % player


func _ready() -> void:
	var title := "Pick a driver" if player == 0 else "Player %d, pick your driver" % player
	var column := MenuStyle.page(self, title, go_back, DriverGrid.width())
	if player > 0:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 20)
		var outer: VBoxContainer = column.get_parent().get_parent().get_parent()
		outer.add_child(top)
		outer.move_child(top, 1)
		top.add_child(_player_tag())
	grid = DriverGrid.new(_current, _taken_by_p1, player)
	grid.picked.connect(func(key: String) -> void: _go.call(key))
	grid.new_driver.connect(func() -> void:
		if _new.is_valid():
			_new.call())
	column.add_child(grid)
	MenuStyle.back_at_bottom(column, go_back)


func go_back() -> void:
	_back.call()


## A big tag in the player's colour saying whose turn it is to pick.
func _player_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiKit.pad(UiKit.slant(UiKit.PLAYERS[player - 1]), 22, 4, UiKit.LEAN, 48.0))
	tag.size_flags_vertical = SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = "PLAYER %d" % player
	label.theme_type_variation = "TagLabel"
	tag.add_child(label)
	return tag
