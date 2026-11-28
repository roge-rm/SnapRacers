extends Node

## Checks the sound: every sound and tune is there and loops if it should,
## every stock kart has an engine to hear, a kart keeps its sound when bits
## fall off, each cup has its own race tune, the menu shuffles tunes, and
## the volumes work.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/sound_test.tscn


class Runner:
	extends Node

	var failures := 0

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func _ready() -> void:
		# Every sound is there, and the loops loop.
		var missing := []
		var not_looping := []
		for name in Sounds.ALL:
			var sound := Sounds.stream(name)
			if sound == null:
				missing.append(name)
			elif (name.begins_with("engine/") or name.begins_with("loop/")) and (sound as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD:
				not_looping.append(name)
		for tune in Sounds.TUNES:
			var music := Sounds.stream("music/" + tune)
			if music == null:
				missing.append("music/" + tune)
			elif not (music as AudioStreamOggVorbis).loop:
				not_looping.append("music/" + tune)
		check(missing.is_empty(), "every sound and tune is there %s" % [missing])
		check(not_looping.is_empty(), "and the engines, loops and tunes all loop %s" % [not_looping])

		# Every stock kart has an engine you can hear.
		var silent := []
		for file in DirAccess.get_files_at("res://data/karts/stock"):
			if not file.ends_with(".json"):
				continue
			var design := KartDesign.load_file("res://data/karts/stock/" + file)
			var stats := KartStats.compute(design, {}, null, KartStats.DRIVER_MASS)
			var engine := KartSound.engine_for(stats)
			var heard := (engine != "" and Sounds.stream("engine/%s_low" % engine) != null) or stats.thrust > 0.0
			if not heard:
				silent.append(file)
		check(silent.is_empty(), "every stock kart has an engine to hear %s" % [silent])

		# Each cup has its own race tune.
		var tunes := {}
		for cup in GrandPrix.cups():
			for track in cup.tracks:
				tunes[Sounds.race_tune(track)] = true
		check(tunes.size() == GrandPrix.cups().size(), "each cup has its own race tune (%d for %d cups)" % [tunes.size(), GrandPrix.cups().size()])

		# The volumes.
		Sounds.setup(0.5, 1.0)
		var music := AudioServer.get_bus_index(Sounds.MUSIC_BUS)
		var effects := AudioServer.get_bus_index(Sounds.EFFECTS_BUS)
		check(music != -1 and effects != -1, "there are Music and Effects buses")
		check(AudioServer.get_bus_volume_db(music) < AudioServer.get_bus_volume_db(effects), "and half volume is quieter than full")
		Sounds.set_volume(Sounds.MUSIC_BUS, 0.0)
		check(AudioServer.is_bus_mute(music), "and nothing at all is muted")
		await check_menu_music()

		check_engine_revs()

		for bus in Sounds.SUB_BUSES:
			var index := AudioServer.get_bus_index(bus)
			check(index != -1 and AudioServer.get_bus_send(index) == Sounds.EFFECTS_BUS, "the %s bus is under Effects" % bus)
		check(Sounds.bus_for("fx/hit", true) == Sounds.POWERUPS_BUS and Sounds.bus_for("fx/crash", true) == Sounds.CRASHES_BUS and Sounds.bus_for("fx/bump", true) == Sounds.CRASHES_BUS, "gadget sounds play on Power-ups and crashes on Crashes")
		check(Sounds.bus_for("fx/homing_warning", false) == Sounds.POWERUPS_BUS and Sounds.bus_for("fx/bricks", true) == Sounds.CRASHES_BUS and Sounds.bus_for("fx/bricks", false) == Sounds.CRASHES_BUS, "the homing warning plays on Power-ups and bricks on Crashes")
		check(Sounds.bus_for("fx/boost_roar_1", true) == Sounds.BOOSTS_BUS and Sounds.bus_for("fx/click", false) == Sounds.MENUS_BUS, "boosts play on Boosts and clicks on Menus")
		var menu_source := FileAccess.get_file_as_string("res://scripts/race/race_menu.gd")
		check(not menu_source.contains("SUB_BUSES"), "the race menu has no group sliders")

		# A kart keeps its sound when a part comes off.
		add_child(TestTrack.new())
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		add_child(kart)
		kart.global_position = Vector3(0.0, 1.0, 0.0)
		await get_tree().process_frame
		var sound := kart.sound
		check(sound != null and sound._engine.stream == Sounds.stream("engine/engine_small_low") and sound._engine_off.stream == Sounds.stream("engine/engine_small_off"), "the starter kart sounds like a small engine")
		check(sound._engine.bus == Sounds.ENGINES_BUS and sound._jet.bus == Sounds.ENGINES_BUS and sound._drift_soft.bus == Sounds.SLIDING_BUS and sound._skid.bus == Sounds.SLIDING_BUS, "a kart's engine and sliding players are on their buses")
		check(sound._wind.bus == Sounds.WIND_BUS and sound._rumble.bus == Sounds.ROAD_BUS and sound._splash.bus == Sounds.ROAD_BUS, "and its wind and road players too")
		var one: Array[int] = [kart.design.parts.size() - 1]
		kart.lose_parts(one)
		check(kart.sound == sound and sound.is_inside_tree(), "and keeps its sound when a part comes off")

		# With no sound card, as here, nothing's played at all.
		check(not Sounds.audible(), "with no sound card there's nothing to hear")
		var before := get_tree().root.find_children("*", "AudioStreamPlayer", true, false).size()
		Sounds.play("fx/click")
		await get_tree().process_frame
		await get_tree().process_frame
		check(get_tree().root.find_children("*", "AudioStreamPlayer", true, false).size() == before, "so a click doesn't leave a player behind")

		print("All sound checks passed." if failures == 0 else "%d sound checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)


	## The engine runs through its gears, eases off the throttle onto its off
	## loop, and two karts with the same engine sound a little different.
	func check_engine_revs() -> void:
		var revs := EngineSound.new("engine_v8", 7)
		var dt := 1.0 / 60.0
		var speed := 0.0
		var most_gear := 0
		var dropped := false
		var before := 0.0
		for i in 600:
			speed = minf(speed + dt * 0.12, 1.0)
			var gear := revs.gear
			revs.step(dt, speed, 1.0, true, false, false)
			if revs.gear > gear:
				before = revs.rev
			if before > 0.0 and revs.rev < before - 0.1:
				dropped = true
			most_gear = maxi(most_gear, revs.gear)
		check(most_gear == revs.gears - 1, "the V8 goes up through all its gears (%d)" % (most_gear + 1))
		check(dropped, "and the revs drop at a shift")
		var on := revs.levels()
		check(on.y > on.x and on.y > on.z * 4.0, "and near the top it's on the high loop %s" % on)
		for i in 60:
			revs.step(dt, speed, 0.0, true, false, false)
		var off := revs.levels()
		check(off.z > off.y and off.z > off.x, "lifting off moves it onto the off loop %s" % off)
		var idle := EngineSound.new("engine_v8", 8)
		for i in 120:
			idle.step(dt, 0.0, 0.0, true, true, false)
		check(idle.rev < 0.05 and idle.levels().x > 0.0, "standing still it idles on the low loop")
		var other := EngineSound.new("engine_v8", 9)
		check(not is_equal_approx(other.detune, revs.detune), "and two V8s are pitched a little apart")
		check(KartSound.AI_ENGINE_LEVEL < KartSound.ENGINE_LEVEL, "the AI's engines are quieter than yours")


	func check_menu_music() -> void:
		Sounds.music("menu")
		await get_tree().process_frame
		var intro := Sounds._music
		check(Sounds.music_playing() == "menu", "the menu starts with its original tune")
		check(not (intro.stream as AudioStreamOggVorbis).loop, "the menu player ends instead of looping")
		Sounds.music("menu")
		check(Sounds._music == intro, "changing menu screens leaves the original tune playing")
		# This seed repeats at the shuffle boundary unless the first tune is swapped.
		Sounds._menu_rng.seed = 5

		var race_count := Sounds.TUNES.size() - 1
		var unique := true
		var continuous := true
		var last := ""
		var boundary_repeat := false
		for cycle in 2:
			var heard := []
			for i in race_count:
				Sounds._music.finished.emit()
				var name := Sounds.music_playing()
				unique = unique and name != "menu" and name in Sounds.TUNES and name not in heard
				if cycle == 1 and i == 0:
					boundary_repeat = name == last
				heard.append(name)
				last = name
				var player := Sounds._music
				Sounds.music("menu")
				continuous = continuous and Sounds._music == player and Sounds.music_playing() == name
		check(unique, "finishing tunes plays every race song once in each of two shuffles")
		check(not boundary_repeat, "a new shuffle doesn't repeat the last tune")
		check(continuous, "changing menu and editor screens keeps the current race song playing")
		var playlist := Sounds._music
		intro.finished.emit()
		check(Sounds._music == playlist, "a finished signal from an older menu player is ignored")

		var name := Sounds.music_playing()
		Sounds.music(name)
		var race := Sounds._music
		check(race != playlist and (race.stream as AudioStreamOggVorbis).loop, "a race using the current menu song gets a looping player")
		playlist.finished.emit()
		check(Sounds._music == race and Sounds.music_playing() == name, "the old menu player can't advance the race music")
		Sounds.music(name)
		check(Sounds._music == race, "asking for the current race tune leaves it playing")

		Sounds.music("menu")
		check(Sounds.music_playing() != "menu" and Sounds.music_playing() != last, "returning from a race continues the shuffle")
		var remaining := Sounds._menu_bag.duplicate()
		var expected: String = remaining.back()
		Sounds.music("race_one")
		Sounds.music("menu")
		check(Sounds.music_playing() == expected and Sounds._menu_bag.size() == remaining.size() - 1, "race interruptions keep the remaining songs in order")

		playlist = Sounds._music
		remaining = Sounds._menu_bag.duplicate()
		expected = remaining.back()
		Sounds.music("")
		playlist.finished.emit()
		check(Sounds._music == null and Sounds.music_playing() == "", "stopping music ignores the old player's finished signal")
		Sounds.music("menu")
		check(Sounds.music_playing() == expected, "restarting menu music keeps its shuffle progress")

		var loops := true
		for tune in Sounds.TUNES:
			loops = loops and (Sounds.stream("music/" + tune) as AudioStreamOggVorbis).loop
		check(loops, "all shared music streams still loop for races")

		Sounds._host.queue_free()
		await get_tree().process_frame
		Sounds.forget()
		Sounds.music("menu")
		await get_tree().process_frame
		check(Sounds.music_playing() == "menu" and Sounds._menu_bag.is_empty(), "forgetting sounds resets the intro and shuffle")
		Sounds.music("")
		await get_tree().create_timer(Sounds.CROSSFADE + 0.1).timeout
		check(Sounds._host.get_child_count() == 0, "faded music players are freed")
		Sounds._host.queue_free()
		Sounds.forget()
		await get_tree().process_frame


func _ready() -> void:
	add_child(Runner.new())
