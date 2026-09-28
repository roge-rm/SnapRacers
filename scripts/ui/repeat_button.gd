class_name RepeatButton
extends Button

## A button that goes off once when you press it, and then over and over for as
## long as you hold it, like a key on a keyboard. The garage's nudge buttons
## use it so you can slide a part along without tapping for every stud.

signal fired

const FIRST_WAIT := 0.35
const EVERY := 0.1

var _held := false
var _wait := 0.0


func _ready() -> void:
	focus_mode = FOCUS_NONE
	button_down.connect(func() -> void:
		_held = true
		_wait = FIRST_WAIT
		fired.emit())
	button_up.connect(func() -> void: _held = false)


func _process(delta: float) -> void:
	if not _held or disabled:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = EVERY
		fired.emit()
