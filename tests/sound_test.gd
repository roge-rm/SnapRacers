extends SceneTree

## Checks the sound: every sound and tune is there and loops if it should,
## every stock kart has an engine to hear, a kart keeps its sound when bits
## fall off, each cup has its own race tune, the menu shuffles tunes, and
## the volumes work.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/sound_test.gd


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
			var heard := (engine != "" and Sounds.stream("engine/" + engine) != null) or stats.thrust > 0.0
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

		# A kart keeps its sound when a part comes off.
		add_child(TestTrack.new())
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://tests/data/legacy/starter.json"))
		add_child(kart)
		kart.global_position = Vector3(0.0, 1.0, 0.0)
		await get_tree().process_frame
		var sound := kart.sound
		check(sound != null and sound._engine.stream == Sounds.stream("engine/engine_small"), "the starter kart sounds like a small engine")
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


func _initialize() -> void:
	root.add_child(Runner.new())
