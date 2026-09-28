class_name Sounds
extends RefCounted

## Everything to do with playing sound: one shots in the menus or out in the
## world, the music, and the Music and Effects volumes.
##
## Every sound in the game is made by tools/sound/make_sounds.py and lives in
## sound/, as sound/fx/<name>.wav, sound/engine/<name>.wav,
## sound/loop/<name>.wav and sound/music/<name>.ogg. A sound is asked for by
## its folder and name, like "fx/crash".
##
## It's all static, with no autoload, so karts and tests can use it without
## the game's screens around.

const MUSIC_BUS := "Music"
const EFFECTS_BUS := "Effects"
## How long one tune takes to fade into the next.
const CROSSFADE := 1.2
## How loud the music plays at full volume. The tunes are mixed loud, and
## under the karts they want to sit back a little.
const MUSIC_LEVEL := -6.0

## While this is on nothing plays, for a race set up behind the splash screen
## to get its shaders ready.
static var hushed := false

## Whether there's anything to hear. The headless tests run with no sound
## card, and there anything still playing when they quit gets reported as a
## leak, so nothing is played at all.
static func audible() -> bool:
	return AudioServer.get_driver_name() != "Dummy"


## Every sound the game has, so they can all be loaded up front.
const ALL := [
	"fx/bump", "fx/crash", "fx/bricks", "fx/stud", "fx/beep", "fx/go", "fx/lap", "fx/final_lap",
	"fx/finish", "fx/win", "fx/reset", "fx/turbo", "fx/spring", "fx/drop", "fx/cannon", "fx/hit",
	"fx/repair", "fx/shield", "fx/magnet", "fx/ram", "fx/click", "fx/back", "fx/snap", "fx/unsnap",
	"fx/pick", "fx/nope",
	"engine/engine_small", "engine/engine_micro", "engine/engine_big", "engine/engine_twin",
	"engine/engine_diesel", "engine/engine_v8", "engine/electric_motor", "engine/jet",
	"loop/skid", "loop/rumble", "loop/wind",
]
const TUNES := ["menu", "race_one", "race_two", "race_three", "race_four"]

static var _music: AudioStreamPlayer
static var _music_name := ""
static var _host: SoundHost


## The sound with this name. Godot keeps a loaded sound while anything's
## using it, so asking again is quick.
static func stream(name: String) -> AudioStream:
	var path := "res://sound/%s.%s" % [name, "ogg" if name.begins_with("music/") else "wav"]
	return load(path) if ResourceLoader.exists(path) else null


## Lets go of every sound and the music, when the game closes.
static func forget() -> void:
	_music = null
	_music_name = ""
	_host = null


## Loads every effect, so the first crash doesn't wait on the disk.
static func load_all() -> void:
	var host := _host_node()
	if host != null:
		for name in ALL:
			host.kept.append(stream(name))


## Makes the Music and Effects buses if they aren't there, at these volumes
## (0 to 1), and starts listening for button presses to click.
static func setup(music_volume: float, effects_volume: float) -> void:
	for bus in [MUSIC_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	set_volume(MUSIC_BUS, music_volume)
	set_volume(EFFECTS_BUS, effects_volume)
	_host_node()


## Sets a bus's volume, 0 to 1. At 0 it's muted.
static func set_volume(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	# Squared, so the slider feels even: halfway sounds about half as loud.
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume * volume, 0.0001)))


## Plays a sound once, the same wherever you are, for the menus and for
## things that happen to you in a race.
static func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var sound := stream(name)
	var host := _host_node()
	if sound == null or host == null or hushed:
		return
	var player := AudioStreamPlayer.new()
	player.stream = sound
	player.bus = EFFECTS_BUS
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	# It starts once it's in the tree, which the host might not be quite yet.
	player.autoplay = audible()
	host.add_child(player)
	if not audible():
		player.queue_free()


## Plays a sound once out in the world, following `where` around, so it's
## quieter the further away it is.
static func play_at(name: String, where: Node3D, volume_db := 0.0, pitch := 1.0) -> void:
	var sound := stream(name)
	if sound == null or where == null or not where.is_inside_tree() or hushed:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.bus = EFFECTS_BUS
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 8.0
	player.max_distance = 90.0
	player.finished.connect(player.queue_free)
	player.autoplay = audible()
	where.add_child(player)
	if not audible():
		player.queue_free()


## Plays this tune, fading out whatever was playing. Asking for the tune
## that's already playing leaves it going. "" fades the music out.
static func music(name: String) -> void:
	var host := _host_node()
	if host == null or name == _music_name:
		return
	_music_name = name
	var old := _music
	_music = null
	var tree := host.get_tree() if host.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if old != null:
		var out := tree.create_tween().bind_node(old)
		out.tween_property(old, "volume_db", -60.0, CROSSFADE)
		out.tween_callback(old.queue_free)
	var tune := stream("music/" + name) if name != "" else null
	if tune == null:
		return
	_music = AudioStreamPlayer.new()
	_music.stream = tune
	_music.bus = MUSIC_BUS
	_music.volume_db = -40.0
	_music.autoplay = audible()
	host.add_child(_music)
	tree.create_tween().bind_node(_music).tween_property(_music, "volume_db", MUSIC_LEVEL, CROSSFADE * 0.6)


## The tune that's playing, or "".
static func music_playing() -> String:
	return _music_name


## The race tune for a course: each Grand Prix cup has its own, and a course
## that isn't in a cup gets the first.
static func race_tune(track_id: String) -> String:
	var tunes := ["race_one", "race_two", "race_three", "race_four"]
	var cups := GrandPrix.cups()
	for i in cups.size():
		if track_id in cups[i].get("tracks", []):
			return tunes[i % tunes.size()]
	return tunes[0]


## The node the menu sounds and the music play from, made the first time
## it's wanted, at the top of the scene tree so it lasts from screen to
## screen.
static func _host_node() -> SoundHost:
	if _host != null and is_instance_valid(_host):
		return _host
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_host = SoundHost.new()
	_host.name = "Sounds"
	tree.root.add_child.call_deferred(_host)
	return _host
