extends Node

## Takes pictures of the newer power-ups in a race on Peach Pit: a tow rope
## onto the kart ahead, a brick wall, marbles and a spike trap behind, and a
## shockwave. It needs a screen, and saves in /tmp/snapracers-build/shots.
##   DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . res://tools/shots/powerup_shots.tscn

const OUT := "/tmp/snapracers-build/shots"

var race: Race
var camera: Camera3D


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/powerup_%s.png" % [OUT, name])
	print("saved ", name)


## Looks at the kart from behind and above, or from in front looking back.
func look(from_behind: bool, height := 4.0, back := 9.0) -> void:
	var kart := race.player.kart
	var along := kart.global_basis.z * (back if from_behind else -back)
	camera.global_position = kart.global_position + along + Vector3.UP * height
	camera.look_at(kart.global_position + Vector3.UP * 0.5 - along * 0.4, Vector3.UP)
	camera.make_current()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var host := Node.new()
	add_child(host)
	Game.start(host, false)
	Game.settings.set_value("race", "split", Game.SOLO)
	Game.racing_alone = true
	Game.show_race(Game.TRACKS + "/peach_pit.json")
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await frames(10)
	var kart := race.player.kart
	var driver := AIDriver.new()
	driver.kart = kart
	driver.track = race.track
	race.add_child(driver)
	race.player.ai = driver
	kart.controls = driver.controls
	camera = Camera3D.new()
	camera.far = 600.0
	race.add_child(camera)
	await frames(240)

	kart.held = ["tow", ""]
	kart.held_uses = [1, 0]
	kart.use_gadget(0)
	await frames(30)
	look(true, 7.0, 10.0)
	await frames(2)
	await shot("tow")

	await frames(120)
	kart.held = ["wall", ""]
	kart.held_uses = [1, 0]
	kart.use_gadget(0)
	await frames(12)
	look(true, 3.0, 13.0)
	await frames(2)
	await shot("wall")

	await frames(90)
	for trap in ["marbles", "spikes"]:
		kart.held = [trap, ""]
		kart.held_uses = [1, 0]
		kart._gadget_wait = [0.0, 0.0]
		kart.use_gadget(0)
		await frames(12)
		look(true, 3.0, 9.0)
		await frames(2)
		await shot(trap)
		await frames(90)

	await frames(60)
	kart.held = ["shockwave", ""]
	kart.held_uses = [1, 0]
	kart.use_gadget(0)
	look(true, 9.0, 10.0)
	await frames(8)
	await shot("shockwave")
	get_tree().quit()
