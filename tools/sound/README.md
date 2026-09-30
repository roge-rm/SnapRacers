# Sound tools

Every sound and tune in SnapRacers is made here by a little synthesizer written in Python. Nothing is recorded or downloaded, so it's all under the same licence as the game.

- `synth.py` has the building blocks, like oscillators, noise, envelopes, filters, a small reverb and writing WAV and Ogg files.
- `effects.py` makes the sound effects. An engine is a pulse for each time a cylinder fires, each one ringing the exhaust like a bell, and the number of cylinders, how evenly they fire and how the exhaust rings make a diesel sound different from a V8. The loops (engines, tire squeal and wind) wrap around from the end to the start without a click.
- `music.py` is a little tracker. The melodies are written out by hand, note by note, and the bass, arpeggios and chords come from the chord for each bar. Every tune loops.
- `make_sounds.py` runs them all and writes the files into `sound`.

It needs numpy and scipy, and ffmpeg for the Ogg files. `uv` fetches the Python parts:

```
uv run --with numpy --with scipy tools/sound/make_sounds.py
uv run --with numpy --with scipy tools/sound/make_sounds.py fx/crash music/menu
```

The first makes everything (the music takes a few minutes) and the second only the sounds named. The finished files are in the repository, so building the game doesn't need any of this.

After making a new sound, run the Godot import (`tools/run-tests.sh` does it first thing). A new loop needs `edit/loop_mode=2` in its `.wav.import` file, and a new tune `loop=true` in its `.ogg.import`, and then another import. `tests/sound_test.gd` checks they're all there and all loop.
