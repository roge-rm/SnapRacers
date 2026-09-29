extends Node

## The first scene. It just hands over to Game, which runs the screens, or
## starts the dedicated server when that's what it's asked to be.


func _ready() -> void:
	if DedicatedServer.wanted():
		Game.start_server(self)
	else:
		Game.start(self)
