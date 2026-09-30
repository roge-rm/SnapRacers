"""SnapRacers' music, written out note by note and played by a little
tracker built on synth.py.

Each tune is bars of sixteen steps. The melody is written by hand as (note,
steps) pairs, and the chords under it are named once for each bar, which the
bass, the arpeggios and the pads are all worked out from. Drums come from
patterns of steps.

Every tune loops. Anything still ringing past the end (the reverb, a long
note) is folded back onto the start, so it goes around without a gap.
"""

import numpy as np

from synth import (
    RATE, adsr, bandpass, decay, drive, highpass, lowpass, noise, normalise, note_freq,
    reverb, sine, saw, square, sweep_lowpass, ramp, seconds, times, triangle,
)

# Chords by name, as the notes in them from the root up, in semitones.
SHAPES = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11],
    "m7": [0, 3, 7, 10], "sus": [0, 5, 7], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9],
}
ROOTS = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
         "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def chord_notes(name, octave):
    """A chord like "Am7" as Hz from `octave` up."""
    root = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
    shape = SHAPES[name[len(root):]]
    base = 12 * (octave + 1) + ROOTS[root]
    return [440.0 * 2.0 ** ((base + s - 69) / 12.0) for s in shape]


# Instruments. Each makes one note: (Hz, seconds, how hard) to samples.

def kick(_f, _d, v):
    n = seconds(0.3)
    body = sine(np.geomspace(160, 45, n), n) * decay(n, 0.28)
    click = highpass(noise(n, 1), 3000) * decay(n, 0.004) * 0.3
    return drive(body + click, 1.5) * v


def snare(_f, _d, v):
    n = seconds(0.2)
    rattle = bandpass(noise(n, 2), 1200, 7000) * decay(n, 0.13)
    tone = sine(np.geomspace(230, 180, n), n) * decay(n, 0.06)
    return (rattle * 0.8 + tone * 0.6) * v


def clap(_f, _d, v):
    n = seconds(0.25)
    burst = bandpass(noise(n, 3), 900, 5000)
    env = np.zeros(n)
    for at in (0.0, 0.012, 0.024):
        s = seconds(at)
        env[s:] += decay(n - s, 0.012 if at < 0.02 else 0.15)
    return burst * env * 0.5 * v


def hat(_f, d, v):
    n = seconds(max(d, 0.05))
    return highpass(noise(n, 4), 7000) * decay(n, 0.03 if d < 0.1 else 0.18) * 0.5 * v


def bass(f, d, v):
    n = seconds(d)
    tone = saw(f, n, harmonics=30) * 0.7 + square(f / 2.0, n, harmonics=10) * 0.4
    tone = sweep_lowpass(tone, 300 + 1500 * decay(n, 0.15))
    return drive(tone * adsr(n, 0.004, 0.08, 0.7, 0.03), 1.3) * v


def lead(f, d, v):
    n = seconds(d)
    t = times(n)
    wobble = 1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) * 4.0, 0.0, 1.0)
    tone = square(f * wobble, n, 0.25, harmonics=24) * 0.6 + saw(f * 1.004, n, harmonics=24) * 0.3
    tone = sweep_lowpass(tone, 1200 + 3000 * decay(n, 0.25))
    return tone * adsr(n, 0.008, 0.1, 0.75, 0.04) * v


def bell(f, d, v):
    """A toy xylophone."""
    n = seconds(max(d, 0.6))
    tone = triangle(f, n) + sine(f * 4.0, n) * 0.25 * decay(n, 0.08) + sine(f * 2.0, n) * 0.2
    return tone * decay(n, 0.7) * adsr(n, 0.002, 0.0, 1.0, 0.02) * 0.8 * v


def pluck(f, d, v):
    n = seconds(max(d, 0.12))
    tone = square(f, n, 0.5, harmonics=14)
    return lowpass(tone, 3500) * decay(n, 0.12) * 0.5 * v


def pad(f, d, v):
    n = seconds(d + 0.3)
    tone = saw(f, n, harmonics=16) + saw(f * 1.006, n, harmonics=16) + saw(f * 0.995, n, harmonics=16)
    return lowpass(tone, 1600) * adsr(n, 0.08, 0.2, 0.7, 0.3) * 0.18 * v


def keys(f, d, v):
    """An electric piano: a soft sine with a bit of bark and tremolo."""
    n = seconds(d + 0.2)
    t = times(n)
    tone = sine(f, n) + sine(f * 2.0, n) * 0.3 * decay(n, 0.3) + triangle(f * 3.0, n) * 0.05 * decay(n, 0.1)
    return tone * (0.85 + 0.15 * np.sin(2 * np.pi * 4.5 * t)) * adsr(n, 0.005, 0.4, 0.5, 0.2) * 0.35 * v


# Making patterns.

def melody(steps_per_bar, *bars):
    """Hand written (note, steps) pairs, bar by bar, to (step, Hz, steps). A
    note of "." is a rest."""
    out = []
    at = 0
    for bar_index, bar in enumerate(bars):
        start = bar_index * steps_per_bar
        at = start
        for name, length in bar:
            if name != ".":
                out.append((at, note_freq(name), length))
            at += length
        assert at - start == steps_per_bar, "bar %d is %d steps" % (bar_index, at - start)
    return out


def drums(pattern, bars, offset=0):
    """A drum pattern like "x...x...x...x..." repeated for `bars` bars. X is
    an accent and o a soft hit."""
    out = []
    for b in range(bars):
        for i, c in enumerate(pattern):
            if c in "xXo":
                out.append((offset + b * len(pattern) + i, 0.0, 1, {"x": 0.8, "X": 1.0, "o": 0.45}[c]))
    return out


def bassline(chords, rhythm, octave=2, offset=0):
    """A bass part from the chord roots. Rhythm is sixteen steps of "r" (the
    root), "o" (an octave up), "5" (the fifth), "-" (hold) or "." (rest)."""
    out = []
    for b, name in enumerate(chords):
        root = chord_notes(name, octave)[0]
        fifth = root * 2.0 ** (7 / 12)
        i = 0
        while i < len(rhythm):
            c = rhythm[i]
            if c in "ro5":
                length = 1
                while i + length < len(rhythm) and rhythm[i + length] == "-":
                    length += 1
                f = {"r": root, "o": root * 2.0, "5": fifth}[c]
                out.append((offset + b * 16 + i, f, length))
                i += length
            else:
                i += 1
    return out


def arps(chords, octave=4, order=(0, 1, 2, 3, 2, 1), every=1, offset=0):
    """Up and down the chord, a note every `every` steps."""
    out = []
    for b, name in enumerate(chords):
        notes = chord_notes(name, octave)
        notes = notes + [notes[0] * 2.0]
        for k, step in enumerate(range(0, 16, every)):
            out.append((offset + b * 16 + step, notes[order[k % len(order)] % len(notes)], every))
    return out


def held(chords, octave=4, offset=0, length=16):
    """Each chord held for the bar."""
    out = []
    for b, name in enumerate(chords):
        for f in chord_notes(name, octave):
            out.append((offset + b * 16, f, length))
    return out


def comp(chords, rhythm, octave=4, offset=0):
    """Chords stabbed on the steps marked "x" in a sixteen step rhythm."""
    out = []
    for b, name in enumerate(chords):
        for i, c in enumerate(rhythm):
            if c == "x":
                for f in chord_notes(name, octave):
                    out.append((offset + b * 16 + i, f, 2))
    return out


# Playing a tune.

def render(bpm, bars, parts, wet=0.18):
    """Plays the parts over `bars` bars and folds the tail back onto the
    start so it loops. Each part is (instrument, notes, loudness, pan, reverb
    send), and each note is (step, Hz, steps) or (step, Hz, steps, how hard)."""
    step = 60.0 / bpm / 4.0
    total = seconds(bars * 16 * step)
    spill = seconds(3.0)
    left = np.zeros(total + spill)
    right = np.zeros(total + spill)
    send_l = np.zeros(total + spill)
    send_r = np.zeros(total + spill)
    for instrument, notes, loud, pan, send in parts:
        track = np.zeros(total + spill)
        for note in notes:
            at, f, length = note[0], note[1], note[2]
            v = note[3] if len(note) > 3 else 1.0
            sound = instrument(f, length * step, v)
            s = seconds(at * step)
            end = min(s + len(sound), len(track))
            track[s:end] += sound[: end - s]
        gl = np.cos((pan + 1.0) * np.pi / 4.0) * loud
        gr = np.sin((pan + 1.0) * np.pi / 4.0) * loud
        left += track * gl
        right += track * gr
        send_l += track * gl * send
        send_r += track * gr * send
    left += reverb(send_l, 1.0, 1.0) * wet * 3.0
    right += reverb(send_r, 1.0, 0.93) * wet * 3.0
    # Fold what rings on past the end back onto the start.
    for ch in (left, right):
        ch[:spill] += ch[total:total + spill]
    out = np.stack([left[:total], right[:total]])
    out = np.tanh(out / np.max(np.abs(out)) * 1.6) / np.tanh(1.6)
    return out * 0.85


# The tunes.

def menu_tune():
    """The garage and the menus: laid back, in F, on a toy xylophone."""
    bpm = 100
    chords = ["Fmaj7", "Am7", "Bbmaj7", "C7", "Fmaj7", "Dm7", "Gm7", "C7"] * 2
    tune = melody(16,
        [("A5", 3), ("C6", 3), ("E6", 2), ("D6", 4), ("C6", 4)],
        [("E6", 6), ("C6", 2), ("G5", 4), ("A5", 4)],
        [("D6", 3), ("F6", 3), ("D6", 2), ("C6", 4), ("Bb5", 4)],
        [("C6", 8), (".", 4), ("G5", 2), ("A5", 2)],
        [("A5", 3), ("C6", 3), ("F6", 2), ("E6", 4), ("C6", 4)],
        [("D6", 6), ("F6", 2), ("E6", 4), ("D6", 4)],
        [("Bb5", 4), ("D6", 4), ("F6", 4), ("E6", 2), ("D6", 2)],
        [("E6", 8), (".", 8)],
        [("A5", 3), ("C6", 3), ("E6", 2), ("D6", 4), ("C6", 4)],
        [("E6", 6), ("C6", 2), ("G5", 4), ("A5", 4)],
        [("D6", 3), ("F6", 3), ("D6", 2), ("C6", 4), ("Bb5", 4)],
        [("C6", 8), (".", 4), ("G5", 2), ("A5", 2)],
        [("A5", 3), ("C6", 3), ("A5", 2), ("G5", 4), ("F5", 4)],
        [("F5", 4), ("A5", 4), ("D6", 4), ("C6", 4)],
        [("Bb5", 4), ("A5", 4), ("G5", 4), ("E5", 4)],
        [("F5", 12), (".", 4)],
    )
    parts = [
        (kick, drums("x.....x...x.....", 16), 0.55, 0.0, 0.0),
        (snare, drums("....x.......x...", 16), 0.35, 0.05, 0.15),
        (hat, drums("..o...o...o...oo", 16), 0.3, 0.3, 0.05),
        (bass, bassline(chords, "r--.r.o.r--.5.o.", 2), 0.5, 0.0, 0.0),
        (keys, comp(chords, "..x...x...x..x..", 4), 0.45, -0.3, 0.25),
        (bell, tune, 0.5, 0.2, 0.35),
    ]
    return render(bpm, 16, parts, wet=0.2)


def race_one():
    """The Baseplate Cup: bright and pushing along, in A minor."""
    bpm = 140
    verse = ["Am", "F", "C", "G", "Am", "F", "C", "G"]
    chorus = ["F", "G", "Em", "Am", "Dm", "G", "C", "E"]
    breakdown = ["Am", "F", "C", "G"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("E5", 2), ("A5", 2), ("B5", 2), ("C6", 4), ("B5", 2), ("A5", 2), ("G5", 2)],
        [("A5", 6), ("F5", 2), ("G5", 2), ("A5", 2), ("C6", 4)],
        [("G5", 2), ("E5", 2), ("G5", 2), ("C6", 4), ("D6", 2), ("E6", 4)],
        [("D6", 6), ("B5", 2), ("G5", 4), (".", 4)],
        [("E5", 2), ("A5", 2), ("B5", 2), ("C6", 4), ("B5", 2), ("A5", 2), ("B5", 2)],
        [("C6", 4), ("A5", 4), ("F6", 4), ("E6", 2), ("D6", 2)],
        [("E6", 4), ("D6", 2), ("C6", 2), ("G5", 4), ("C6", 4)],
        [("B5", 8), ("D6", 4), ("B5", 4)],
    ]
    b = [
        [("A5", 3), ("A5", 1), ("C6", 2), ("A5", 2), ("G5", 4), ("F5", 4)],
        [("G5", 3), ("G5", 1), ("B5", 2), ("D6", 2), ("D6", 4), ("C6", 2), ("B5", 2)],
        [("B5", 4), ("G5", 2), ("E5", 2), ("G5", 4), ("B5", 4)],
        [("C6", 8), ("A5", 4), ("E6", 4)],
        [("F6", 4), ("E6", 2), ("D6", 2), ("A5", 4), ("D6", 4)],
        [("D6", 4), ("C6", 2), ("B5", 2), ("G5", 4), ("B5", 4)],
        [("C6", 4), ("E6", 4), ("G6", 4), ("E6", 4)],
        [("G#5", 4), ("B5", 4), ("E6", 6), ("D6", 2)],
    ]
    rest = [[(".", 16)]] * 4
    tune = melody(16, *(a + b + a + rest))
    bars = len(chords)
    parts = [
        (kick, drums("x...x...x...x...", bars), 0.6, 0.0, 0.0),
        (snare, drums("....x.......x..o", bars), 0.4, 0.05, 0.12),
        (clap, drums("....x.......x...", bars), 0.3, -0.05, 0.2),
        (hat, drums("o.x.o.x.o.x.o.xo", bars), 0.28, 0.35, 0.03),
        (bass, bassline(chords, "r-r-o-r-r-r-o-5-", 2), 0.5, 0.0, 0.0),
        (pluck, arps(chords, 4, (0, 1, 2, 3, 2, 1, 0, 2)), 0.3, -0.35, 0.3),
        (pad, held(chords, 3), 0.4, 0.0, 0.3),
        (lead, tune, 0.42, 0.1, 0.3),
    ]
    return render(bpm, bars, parts, wet=0.16)


def race_two():
    """The Axle Cup, around the works and the foundry: chunky and funky, in E
    minor."""
    bpm = 132
    verse = ["Em", "Em", "C", "D", "Em", "Em", "C", "D"]
    chorus = ["G", "D", "Am", "C", "G", "D", "C", "B7"]
    breakdown = ["Em", "C", "D", "B7"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("E5", 2), (".", 2), ("E5", 2), ("G5", 2), ("A5", 2), ("G5", 2), ("E5", 2), ("D5", 2)],
        [("E5", 6), (".", 2), ("B4", 2), ("D5", 2), ("E5", 4)],
        [("G5", 2), (".", 2), ("G5", 2), ("A5", 2), ("B5", 2), ("A5", 2), ("G5", 2), ("E5", 2)],
        [("F#5", 6), ("D5", 2), ("A5", 4), ("F#5", 4)],
        [("E5", 2), (".", 2), ("E5", 2), ("G5", 2), ("A5", 2), ("G5", 2), ("E5", 2), ("D5", 2)],
        [("E5", 4), ("G5", 4), ("B5", 4), ("A5", 4)],
        [("G5", 2), ("E5", 2), ("G5", 2), ("C6", 4), ("B5", 2), ("A5", 2), ("G5", 2)],
        [("A5", 8), ("F#5", 4), ("D5", 4)],
    ]
    b = [
        [("B5", 4), ("D6", 4), ("B5", 2), ("A5", 2), ("G5", 4)],
        [("A5", 6), ("F#5", 2), ("A5", 4), ("D6", 4)],
        [("C6", 4), ("B5", 2), ("A5", 2), ("E5", 4), ("A5", 4)],
        [("G5", 6), ("E5", 2), ("G5", 4), ("C6", 4)],
        [("B5", 4), ("D6", 4), ("G6", 4), ("F#6", 2), ("E6", 2)],
        [("F#6", 6), ("E6", 2), ("D6", 4), ("A5", 4)],
        [("E6", 4), ("D6", 2), ("C6", 2), ("G5", 4), ("E6", 4)],
        [("D#6", 8), ("B5", 4), ("F#5", 4)],
    ]
    tune = melody(16, *(a + b + a + [[(".", 16)]] * 4))
    bars = len(chords)
    parts = [
        (kick, drums("x.....x...x.....", bars), 0.6, 0.0, 0.0),
        (snare, drums("....x.......x.o.", bars), 0.45, 0.05, 0.12),
        (hat, drums("x.x.x.x.x.x.x.xo", bars), 0.25, 0.35, 0.03),
        (bass, bassline(chords, "r-.r..r.o-.r.5o.", 2), 0.55, 0.0, 0.0),
        (keys, comp(chords, "..x..x....x..x..", 4), 0.4, -0.35, 0.2),
        (pad, held(chords, 3), 0.3, 0.2, 0.3),
        (lead, tune, 0.42, 0.1, 0.28),
    ]
    return render(bpm, bars, parts, wet=0.15)


def race_three():
    """The Gearbox Cup, through the woods, the snow and the dunes: bouncy and
    sunny, in D."""
    bpm = 124
    verse = ["D", "G", "Bm", "A", "D", "G", "A", "D"]
    chorus = ["G", "A", "F#m", "Bm", "G", "A", "Em", "A7"]
    breakdown = ["D", "G", "A", "D"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("F#5", 2), ("A5", 2), ("D6", 2), ("A5", 2), ("F#5", 2), ("A5", 2), ("B5", 4)],
        [("B5", 4), ("G5", 2), ("B5", 2), ("D6", 4), ("B5", 4)],
        [("D6", 2), ("C#6", 2), ("B5", 2), ("F#5", 2), ("B5", 4), ("D6", 4)],
        [("C#6", 6), ("A5", 2), ("E5", 4), ("A5", 4)],
        [("F#5", 2), ("A5", 2), ("D6", 2), ("F#6", 2), ("E6", 4), ("D6", 4)],
        [("B5", 2), ("D6", 2), ("G6", 4), ("F#6", 2), ("E6", 2), ("D6", 4)],
        [("C#6", 4), ("E6", 4), ("A5", 4), ("C#6", 4)],
        [("D6", 12), (".", 4)],
    ]
    b = [
        [("G5", 3), ("A5", 1), ("B5", 4), ("D6", 4), ("B5", 4)],
        [("A5", 3), ("B5", 1), ("C#6", 4), ("E6", 4), ("C#6", 4)],
        [("F#6", 4), ("E6", 2), ("C#6", 2), ("A5", 4), ("C#6", 4)],
        [("D6", 6), ("C#6", 2), ("B5", 8)],
        [("G5", 2), ("B5", 2), ("D6", 2), ("G6", 2), ("F#6", 4), ("E6", 4)],
        [("E6", 2), ("C#6", 2), ("E6", 2), ("A6", 2), ("G6", 4), ("E6", 4)],
        [("G6", 4), ("F#6", 2), ("E6", 2), ("B5", 4), ("E6", 4)],
        [("C#6", 4), ("E6", 4), ("G6", 4), ("E6", 4)],
    ]
    tune = melody(16, *(a + b + a + [[(".", 16)]] * 4))
    bars = len(chords)
    parts = [
        (kick, drums("x.......x.......", bars), 0.55, 0.0, 0.0),
        (snare, drums("....x.......x...", bars), 0.35, 0.05, 0.15),
        (hat, drums("..x...x...x...x.", bars), 0.28, 0.35, 0.05),
        (bass, bassline(chords, "r...5...r...5.o.", 2), 0.5, 0.0, 0.0),
        (pluck, arps(chords, 4, (0, 2, 1, 2), every=2), 0.35, -0.35, 0.3),
        (bell, tune, 0.45, 0.2, 0.3),
        (lead, [(at, f / 2.0, n) for at, f, n in tune], 0.16, -0.1, 0.3),
    ]
    return render(bpm, bars, parts, wet=0.2)


def race_four():
    """The Keystone Cup: the launchpad, the lava and the castle, so it's big
    and dramatic, in C minor."""
    bpm = 150
    verse = ["Cm", "Ab", "Eb", "Bb", "Cm", "Ab", "Eb", "Bb"]
    chorus = ["Fm", "Cm", "Ab", "G", "Fm", "Cm", "Db", "G"]
    breakdown = ["Cm", "Ab", "Bb", "G"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("C5", 2), ("Eb5", 2), ("G5", 2), ("C6", 4), ("Bb5", 2), ("G5", 2), ("Eb5", 2)],
        [("Ab5", 6), ("G5", 2), ("F5", 2), ("Eb5", 2), ("C5", 4)],
        [("Eb5", 2), ("G5", 2), ("Bb5", 2), ("Eb6", 4), ("D6", 2), ("C6", 2), ("Bb5", 2)],
        [("D6", 8), ("Bb5", 4), ("F5", 4)],
        [("C6", 2), ("Bb5", 2), ("G5", 2), ("C6", 4), ("D6", 2), ("Eb6", 4)],
        [("C6", 6), ("Ab5", 2), ("Eb5", 4), ("Ab5", 4)],
        [("G5", 2), ("Bb5", 2), ("Eb6", 2), ("G6", 4), ("F6", 2), ("Eb6", 2), ("D6", 2)],
        [("D6", 4), ("F6", 4), ("Bb5", 8)],
    ]
    b = [
        [("F5", 4), ("Ab5", 4), ("C6", 4), ("F6", 4)],
        [("Eb6", 6), ("D6", 2), ("C6", 4), ("G5", 4)],
        [("Ab5", 4), ("C6", 4), ("Eb6", 4), ("Ab6", 4)],
        [("G6", 8), ("F6", 4), ("D6", 4)],
        [("F6", 4), ("Eb6", 2), ("C6", 2), ("Ab5", 4), ("C6", 4)],
        [("G6", 6), ("F6", 2), ("Eb6", 4), ("C6", 4)],
        [("F6", 4), ("Db6", 4), ("Ab5", 4), ("F6", 4)],
        [("B5", 4), ("D6", 4), ("G6", 6), ("F6", 2)],
    ]
    tune = melody(16, *(a + b + a + [[(".", 16)]] * 4))
    bars = len(chords)
    parts = [
        (kick, drums("x...x...x...x.x.", bars), 0.62, 0.0, 0.0),
        (snare, drums("....x.......x...", bars), 0.45, 0.05, 0.15),
        (clap, drums("....x.......x...", bars), 0.3, -0.05, 0.2),
        (hat, drums("xxxxxxxxxxxxxxxx", bars), 0.18, 0.35, 0.03),
        (bass, bassline(chords, "rrrrrrrrrrrrrr5o", 2), 0.45, 0.0, 0.0),
        (pad, held(chords, 3), 0.45, 0.0, 0.35),
        (pluck, arps(chords, 5, (0, 1, 2, 1)), 0.2, -0.4, 0.3),
        (lead, tune, 0.45, 0.1, 0.3),
    ]
    return render(bpm, bars, parts, wet=0.18)


def race_indoor():
    """The indoor cup, under the lights in the kart hall: tight and electronic,
    in F sharp minor."""
    bpm = 146
    verse = ["F#m", "D", "A", "E", "F#m", "D", "A", "E"]
    chorus = ["Bm", "D", "A", "E", "Bm", "D", "C#m", "C#7"]
    breakdown = ["F#m", "D", "A", "E"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("F#5", 2), (".", 2), ("C#6", 2), ("A5", 2), ("F#5", 2), ("A5", 2), ("B5", 4)],
        [("A5", 4), ("F#5", 2), ("A5", 2), ("D6", 4), ("C#6", 4)],
        [("C#6", 2), (".", 2), ("E6", 2), ("C#6", 2), ("A5", 2), ("C#6", 2), ("E6", 4)],
        [("B5", 6), ("G#5", 2), ("E5", 4), (".", 4)],
        [("F#5", 2), (".", 2), ("C#6", 2), ("A5", 2), ("F#5", 2), ("A5", 2), ("C#6", 4)],
        [("D6", 4), ("C#6", 2), ("A5", 2), ("F#6", 4), ("E6", 4)],
        [("E6", 2), ("C#6", 2), ("A5", 2), ("E6", 4), ("C#6", 2), ("B5", 4)],
        [("G#5", 8), ("B5", 4), ("C#6", 4)],
    ]
    b = [
        [("D6", 4), ("F#6", 4), ("E6", 2), ("D6", 2), ("B5", 4)],
        [("A5", 4), ("D6", 4), ("F#6", 4), ("A6", 4)],
        [("E6", 6), ("C#6", 2), ("A5", 4), ("C#6", 4)],
        [("B5", 8), ("G#5", 4), ("E5", 4)],
        [("D6", 4), ("F#6", 4), ("B6", 4), ("A6", 2), ("F#6", 2)],
        [("F#6", 6), ("E6", 2), ("D6", 4), ("A5", 4)],
        [("E6", 4), ("C#6", 4), ("G#5", 4), ("C#6", 4)],
        [("F6", 4), ("G#6", 4), ("C#6", 8)],
    ]
    tune = melody(16, *(a + b + a + [[(".", 16)]] * 4))
    bars = len(chords)
    parts = [
        (kick, drums("x...x...x...x...", bars), 0.62, 0.0, 0.0),
        (clap, drums("....x.......x...", bars), 0.35, -0.05, 0.15),
        (hat, drums("..x...x...x...xo", bars), 0.3, 0.35, 0.03),
        (bass, bassline(chords, "r.r.o.r.r.r.o.r.", 2), 0.5, 0.0, 0.0),
        (pluck, arps(chords, 5, (0, 1, 2, 3)), 0.22, -0.4, 0.3),
        (pad, held(chords, 3), 0.35, 0.1, 0.3),
        (lead, tune, 0.42, 0.1, 0.25),
    ]
    return render(bpm, bars, parts, wet=0.14)


def race_rally():
    """The rallycross cup, over the gravel and the jumps: rocky and driving,
    in G."""
    bpm = 138
    verse = ["G", "C", "D", "G", "Em", "C", "D", "D"]
    chorus = ["C", "G", "D", "Em", "C", "G", "Am", "D7"]
    breakdown = ["G", "C", "D", "G"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("D5", 2), ("G5", 2), ("B5", 2), ("D6", 4), ("B5", 2), ("A5", 2), ("G5", 2)],
        [("E5", 4), ("G5", 2), ("C6", 2), ("E6", 4), ("D6", 4)],
        [("D6", 2), ("C6", 2), ("A5", 2), ("F#5", 2), ("A5", 4), ("D6", 4)],
        [("B5", 8), ("G5", 4), ("D5", 4)],
        [("E5", 2), ("G5", 2), ("B5", 2), ("E6", 4), ("D6", 2), ("B5", 2), ("G5", 2)],
        [("C6", 4), ("E6", 4), ("G6", 4), ("E6", 4)],
        [("F#6", 6), ("E6", 2), ("D6", 4), ("A5", 4)],
        [("D6", 8), (".", 4), ("A5", 2), ("B5", 2)],
    ]
    b = [
        [("C6", 4), ("E6", 4), ("G6", 2), ("E6", 2), ("C6", 4)],
        [("B5", 4), ("D6", 4), ("G6", 4), ("D6", 4)],
        [("A5", 4), ("D6", 4), ("F#6", 4), ("A6", 4)],
        [("G6", 6), ("F#6", 2), ("E6", 4), ("B5", 4)],
        [("E6", 4), ("C6", 2), ("E6", 2), ("G6", 4), ("E6", 4)],
        [("D6", 4), ("B5", 2), ("D6", 2), ("G6", 8)],
        [("A6", 4), ("G6", 2), ("E6", 2), ("C6", 4), ("E6", 4)],
        [("F#6", 4), ("D6", 4), ("A5", 4), ("C6", 4)],
    ]
    tune = melody(16, *(a + b + a + [[(".", 16)]] * 4))
    bars = len(chords)
    parts = [
        (kick, drums("x..x..x.x..x..x.", bars), 0.6, 0.0, 0.0),
        (snare, drums("....x.......x...", bars), 0.45, 0.05, 0.12),
        (hat, drums("x.x.x.x.x.x.x.x.", bars), 0.25, 0.35, 0.03),
        (bass, bassline(chords, "r.rr.r.rr.rr.5o.", 2), 0.55, 0.0, 0.0),
        (keys, comp(chords, "x..x..x.x..x..x.", 4), 0.35, -0.35, 0.2),
        (lead, tune, 0.45, 0.1, 0.25),
    ]
    return render(bpm, bars, parts, wet=0.14)


def race_coaster():
    """The roller coaster cup: a fairground tune, bouncy and a bit silly, in B
    flat."""
    bpm = 126
    verse = ["Bb", "F", "Bb", "F", "Eb", "Bb", "F", "Bb"]
    chorus = ["Eb", "Bb", "Cm", "F", "Eb", "Bb", "F7", "Bb"]
    breakdown = ["Bb", "Eb", "F", "Bb"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("F5", 2), ("Bb5", 2), ("D6", 2), ("F6", 4), ("D6", 2), ("Bb5", 4)],
        [("A5", 4), ("C6", 2), ("F6", 2), ("A6", 4), ("F6", 4)],
        [("F6", 2), ("D6", 2), ("Bb5", 2), ("D6", 2), ("F6", 4), ("Bb6", 4)],
        [("A6", 6), ("G6", 2), ("F6", 4), ("C6", 4)],
        [("G5", 2), ("Bb5", 2), ("Eb6", 2), ("G6", 4), ("F6", 2), ("Eb6", 4)],
        [("D6", 4), ("F6", 4), ("Bb6", 4), ("F6", 4)],
        [("A6", 4), ("G6", 2), ("F6", 2), ("C6", 4), ("Eb6", 4)],
        [("D6", 8), (".", 4), ("F5", 2), ("A5", 2)],
    ]
    b = [
        [("G6", 4), ("Eb6", 4), ("Bb5", 4), ("G5", 4)],
        [("F6", 6), ("D6", 2), ("Bb5", 8)],
        [("Eb6", 4), ("C6", 2), ("Eb6", 2), ("G6", 4), ("Eb6", 4)],
        [("F6", 4), ("A5", 4), ("C6", 4), ("F6", 4)],
        [("Bb6", 4), ("G6", 2), ("Eb6", 2), ("G6", 4), ("Bb6", 4)],
        [("Bb6", 6), ("A6", 2), ("F6", 4), ("D6", 4)],
        [("Eb6", 4), ("C6", 4), ("A5", 4), ("Eb6", 4)],
        [("D6", 12), (".", 4)],
    ]
    tune = melody(16, *(a + b + a + [[(".", 16)]] * 4))
    bars = len(chords)
    parts = [
        (kick, drums("x.......x.......", bars), 0.55, 0.0, 0.0),
        (snare, drums("....x.......x...", bars), 0.35, 0.05, 0.15),
        (hat, drums("..x...x...x...x.", bars), 0.28, 0.35, 0.05),
        (bass, bassline(chords, "r...5...r...5...", 2), 0.5, 0.0, 0.0),
        (keys, comp(chords, "..x...x...x...x.", 4), 0.35, -0.35, 0.25),
        (bell, tune, 0.5, 0.2, 0.3),
        (lead, [(at, f / 2.0, n) for at, f, n in tune], 0.14, -0.1, 0.3),
    ]
    return render(bpm, bars, parts, wet=0.2)


def race_legends():
    """The famous circuits cup: a big, proud anthem, in E flat."""
    bpm = 144
    verse = ["Eb", "Bb", "Cm", "Ab", "Eb", "Bb", "Ab", "Bb"]
    chorus = ["Ab", "Bb", "Gm", "Cm", "Ab", "Bb", "Fm", "Bb7"]
    breakdown = ["Eb", "Ab", "Bb", "Eb"]
    chords = verse + chorus + verse + breakdown
    a = [
        [("Eb5", 4), ("G5", 2), ("Bb5", 2), ("Eb6", 6), ("D6", 2)],
        [("D6", 4), ("Bb5", 4), ("F5", 4), ("Bb5", 4)],
        [("C6", 4), ("Eb6", 2), ("G6", 2), ("C6", 4), ("Bb5", 4)],
        [("Ab5", 6), ("Bb5", 2), ("C6", 4), ("Ab5", 4)],
        [("Bb5", 4), ("Eb6", 4), ("G6", 6), ("F6", 2)],
        [("F6", 4), ("D6", 4), ("Bb5", 4), ("D6", 4)],
        [("Eb6", 4), ("C6", 4), ("Ab5", 4), ("C6", 4)],
        [("Bb5", 12), (".", 4)],
    ]
    b = [
        [("C6", 4), ("Eb6", 4), ("Ab6", 4), ("G6", 2), ("F6", 2)],
        [("F6", 6), ("D6", 2), ("Bb5", 8)],
        [("G6", 4), ("F6", 2), ("D6", 2), ("Bb5", 4), ("D6", 4)],
        [("Eb6", 6), ("D6", 2), ("C6", 4), ("G5", 4)],
        [("Ab6", 4), ("G6", 2), ("Eb6", 2), ("C6", 4), ("Eb6", 4)],
        [("F6", 4), ("Bb6", 4), ("D6", 4), ("F6", 4)],
        [("Ab6", 4), ("F6", 4), ("C6", 4), ("Ab5", 4)],
        [("Bb5", 4), ("D6", 4), ("F6", 4), ("Ab6", 4)],
    ]
    tune = melody(16, *(a + b + a + [[(".", 16)]] * 4))
    bars = len(chords)
    parts = [
        (kick, drums("x...x...x...x...", bars), 0.6, 0.0, 0.0),
        (snare, drums("....x.......x..o", bars), 0.45, 0.05, 0.15),
        (hat, drums("x.x.x.x.x.x.x.x.", bars), 0.22, 0.35, 0.03),
        (bass, bassline(chords, "r-r-r-r-o-o-5-5-", 2), 0.5, 0.0, 0.0),
        (pad, held(chords, 3), 0.45, 0.0, 0.35),
        (pluck, arps(chords, 4, (0, 1, 2, 3, 2, 1)), 0.25, -0.35, 0.3),
        (lead, tune, 0.45, 0.1, 0.3),
    ]
    return render(bpm, bars, parts, wet=0.18)


TUNES = {"menu": menu_tune, "race_one": race_one, "race_two": race_two, "race_three": race_three, "race_four": race_four,
         "race_indoor": race_indoor, "race_rally": race_rally, "race_coaster": race_coaster, "race_legends": race_legends}
