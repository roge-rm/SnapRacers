#!/usr/bin/env python3
"""Makes every sound and tune in SnapRacers from scratch, into sound/.

Nothing is recorded or downloaded. The effects are built in effects.py and
the music in music.py, from the building blocks in synth.py, and they come
out the same every time. The files are kept in the repository, so building
the game doesn't need this. Run it again after changing a sound:

  uv run --with numpy --with scipy tools/sound/make_sounds.py [names...]

With names (like "fx/crash" or "music/menu") it only makes those. Effects
are 16 bit WAV, which Godot squeezes down when it imports them, and the
music is Ogg Vorbis.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import effects  # noqa: E402
import music  # noqa: E402
from synth import write_ogg, write_wav  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "sound")


def main():
    only = set(sys.argv[1:])
    if not only or any(not n.startswith("music/") for n in only):
        for name, (samples, _loop) in effects.make_all().items():
            if not only or name in only:
                write_wav(os.path.join(OUT, name + ".wav"), samples)
                print("made", name)
    for name, make in music.TUNES.items():
        if not only or "music/" + name in only:
            write_ogg(os.path.join(OUT, "music", name + ".ogg"), make(), 3)
            print("made music/" + name)


if __name__ == "__main__":
    main()
