class_name TestDrive
extends Node3D

## Takes the kart from the garage out onto the test track.

var kart: Kart
var camera: ChaseCamera
var speed_label: Label


func _ready() -> void:
	var track := TestTrack.new()
	add_child(track)

	var player := LocalPlayerInput.new()
	player.use_keyboard = true
	player.any_joypad = true
	add_child(player) # before the kart, so its controls are fresh each tick

	kart = Kart.new()
	kart.build(Game.design)
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
	var hud_root := Control.new()
	hud_root.theme = Game.theme
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	speed_label = Label.new()
	speed_label.position = Vector2(24, 16)
	speed_label.add_theme_font_size_override("font_size", 28)
	speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
	speed_label.add_theme_constant_override("outline_size", 6)
	hud_root.add_child(speed_label)

	var garage := Button.new()
	garage.text = "Garage"
	garage.custom_minimum_size = Vector2(150, 56)
	garage.focus_mode = Control.FOCUS_NONE
	hud_root.add_child(garage)
	garage.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	garage.position.y = 12
	garage.pressed.connect(Game.show_garage)

	var touch := TouchControls.new()
	touch.visible = DisplayServer.is_touchscreen_available()
	touch.blockers.append(garage)
	hud_root.add_child(touch)
	player.touch = touch

func go_back() -> void:
	Game.show_garage()


func _process(_delta: float) -> void:
	var kmh := absf(kart.forward_speed) * 3.6
	var text := "%d km/h" % roundi(kmh)
	if kart.slowdown_left > 0.0:
		text += "   reset slowdown"
	if not kart.lost.is_empty():
		var n := kart.lost.size()
		text += "   %d part%s lost, reset to fix" % [n, "" if n == 1 else "s"]
	if Game.show_fps():
		text += "\n%d fps" % Engine.get_frames_per_second()
	speed_label.text = text
