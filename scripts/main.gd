extends Node

## The first scene. It just hands over to Game, which runs the screens.


func _ready() -> void:
	Game.start(self)
