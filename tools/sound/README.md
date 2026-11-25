# Sound tools

Every sound and tune in SnapRacers is made here by a little synthesizer written in Python. Nothing is recorded or downloaded, so it's all under the same licence as the game.

- `synth.py` has the building blocks, like oscillators, noise, envelopes, filters, a small reverb and writing WAV and Ogg files.
- `engines.py` makes the engines. Each one has three loops, made at low and high revs on the throttle and middling revs off it, which the game fades between as it runs through pretend gears (`scripts/audio/engine_sound.gd`). An engine is a pulse for each time a cylinder fires, each one ringing the exhaust like a bell, and the number of cylinders, how evenly they fire, how they miss or pop and how the exhaust rings make a diesel sound different from a V8.
- `effects.py` makes the other sound effects. The loops (tire squeal, wind and so on) wrap around from the end to the start without a click. Boosts come in a few of each size, which the game picks from and pitches at random.
- `engine_demo.py` plays the engines, wind and boosts the way the game does, into a folder you name, for listening to.
- `music.py` is a little tracker. The melodies are written out by hand, note by note, and the bass, arpeggios and chords come from the chord for each bar. The music is chill funk, a swung groove with a soft kit, finger bass, electric piano and guitar, and each cup adds its own instrument. Every tune loops.
- `make_sounds.py` runs them all and writes the files into `sound`.
- `inst_demo.py` plays each cup's flavour instrument (clavinet, banjo, timpani, choir and so on) on a short phrase over a light beat, as `inst_*.ogg` in a folder you name.

It needs numpy and scipy, and ffmpeg for the Ogg files. `uv` fetches the Python parts:

```
uv run --with numpy --with scipy tools/sound/make_sounds.py
uv run --with numpy --with scipy tools/sound/make_sounds.py fx/crash music/menu
```

The first makes everything (the music takes a few minutes) and the second only the sounds named. The finished files are in the repository, so building the game doesn't need any of this.

After making a new sound, run the Godot import (`tools/run-tests.sh` does it first thing). A new loop needs `edit/loop_mode=2` in its `.wav.import` file, and a new tune `loop=true` in its `.ogg.import`, and then another import. `tests/sound_test.gd` checks they're all there and all loop.
