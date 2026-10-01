class_name SoundHost
extends Node

## Where the menu sounds and the music play from (see Sounds). It sits at the
## top of the scene tree so it lasts from screen to screen.
##
## It also gives every button a click as it's pressed, and Back buttons a
## different one, so no screen has to remember to. The driving controls in a
## race are left quiet.


## Every effect, loaded up front and held here so they stay loaded.
var kept: Array[AudioStream] = []


func _enter_tree() -> void:
	# The music and the menu's clicks carry on while a race is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(node)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)
	# The game's closing, so let go of everything that was kept.
	Sounds.forget()


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("clicks"):
		node.set_meta("clicks", true)
		node.pressed.connect(_pressed.bind(node))


func _pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.get_meta("quiet", false):
		return
	var up := button.get_parent()
	while up != null:
		if up is TouchControls:
			return
		up = up.get_parent()
	var text: String = button.text if button is Button else ""
	Sounds.play("fx/back" if text in ["Back", "Cancel", "Quit cup", "Leave"] else "fx/click")
