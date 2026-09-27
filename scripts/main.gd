extends Node3D

## For now the game starts straight on the test track with the starter kart.
## Menus, the builders and races come later.

var kart: Kart
var camera: ChaseCamera
var speed_label: Label


func _ready() -> void:
	var track := TestTrack.new()
	add_child(track)

	var player := LocalPlayerInput.new()
	player.use_keyboard = true
	var pads := Input.get_connected_joypads()
	player.joypad = pads[0] if not pads.is_empty() else -1
	add_child(player) # before the kart, so its controls are fresh each tick

	kart = Kart.new()
	kart.build(KartDesign.load_file("res://data/karts/starter.json"))
	kart.controls = player.controls
	kart.transform = track.spawn
	add_child(kart)

	camera = ChaseCamera.new()
	camera.target = kart
	add_child(camera)
	camera.make_current()
	camera.snap()

	var hud := CanvasLayer.new()
	add_child(hud)
	speed_label = Label.new()
	speed_label.position = Vector2(24, 16)
	speed_label.add_theme_font_size_override("font_size", 28)
	speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
	speed_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(speed_label)

	var touch := TouchControls.new()
	touch.visible = DisplayServer.is_touchscreen_available()
	hud.add_child(touch)
	player.touch = touch

	Input.joy_connection_changed.connect(func(device: int, connected: bool) -> void:
		if connected and player.joypad == -1:
			player.joypad = device
		elif not connected and player.joypad == device:
			player.joypad = -1
	)


func _process(_delta: float) -> void:
	var kmh := absf(kart.forward_speed) * 3.6
	var text := "%d km/h" % roundi(kmh)
	if kart.slowdown_left > 0.0:
		text += "   reset slowdown"
	speed_label.text = text + "\n%d fps" % Engine.get_frames_per_second()
