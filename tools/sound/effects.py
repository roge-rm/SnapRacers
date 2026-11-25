"""SnapRacers' sound effects, made from scratch with synth.py.

There are three kinds:
  - engine loops, three for each kind of engine (see engines.py)
  - other loops, like tire squeal and wind
  - one shots, like crashes, gadgets, studs and menu clicks
"""

import numpy as np

import engines

from synth import (
    RATE, adsr, bandpass, circular_convolve, circular_filter, decay, drive, fade,
    highpass, lowpass, mix, noise, normalise, note_freq, phase_of, ramp, reverb,
    resonator, rng, saw, seconds, sine, square, sweep_lowpass, times, triangle, trim,
)


# Engines are in engines.py.

# Other loops.

def skid():
    """Tire squeal: a wavering squeak over a hiss."""
    total = RATE
    t = times(total)
    wander = 30 * np.sin(2 * np.pi * 3 * t) + 18 * np.sin(2 * np.pi * 5 * t + 0.7)
    p = np.cumsum(950 + wander) / RATE
    tone = np.sin(2 * np.pi * p) + 0.5 * np.sin(4 * np.pi * p) + 0.2 * np.sin(6 * np.pi * p)
    hiss = circular_filter(noise(total, 21), low=900.0, high=4000.0)
    return normalise(tone * 0.6 + normalise(hiss) * 0.5, 0.6)


def rumble():
    """Driving on grass or dirt: a low rumble with bits flicking up."""
    total = RATE
    low = circular_filter(noise(total, 31), low=30.0, high=350.0)
    r = rng(32)
    grit = np.zeros(total)
    for i in r.integers(0, total, 60):
        grit[i] = r.uniform(0.3, 1.0)
    grit = circular_convolve(grit, bandpass(noise(seconds(0.01), 33), 1000, 3000) * decay(seconds(0.01), 0.008))
    return normalise(normalise(low) + grit * 2.0, 0.7)


def wind():
    """Air rushing past at speed: a broad hiss that drifts about at random,
    with no swell that comes round again. It's long, so the repeat can't be
    heard, and the game adds gusts and the low buffet (wind_low) on top."""
    total = seconds(7.0)
    air = circular_filter(noise(total, 41), low=150.0, high=7000.0, tilt=-3.5)
    air /= np.max(np.abs(air))
    # A soft band that wanders, like air round a helmet.
    band = circular_filter(noise(total, 42), low=700.0, high=1600.0)
    band = band / np.max(np.abs(band)) * _wobble(total, 43, 0.35, 0.8)
    out = air * _wobble(total, 44, 0.4, 0.12) + band * 0.35
    return normalise(out, 0.6)


def wind_low():
    """The low buffet of the wind on you, fluttering at random."""
    total = seconds(5.3)
    low = circular_filter(noise(total, 45), low=30.0, high=260.0)
    low /= np.max(np.abs(low))
    flutter = _wobble(total, 46, 9.0, 0.5) * _wobble(total, 47, 0.5, 0.3)
    return normalise(low * flutter, 0.6)


def rain(heavy=1.0, seed=51):
    """Rain falling all around: a soft hiss with drops pattering through it."""
    total = RATE * 4
    hiss = circular_filter(noise(total, seed), low=900.0, high=7000.0) * 0.5
    drops = np.zeros(total)
    r = rng(seed + 1)
    n = seconds(0.03)
    for _ in range(int(900 * heavy)):
        at = r.integers(0, total - n)
        drops[at:at + n] += resonator(r.uniform(2500, 6500), r.uniform(0.004, 0.01), n) * r.uniform(0.1, 0.5)
    return normalise(hiss + drops, 0.55)


def storm():
    """Heavy rain with the low roll of the wind under it."""
    total = RATE * 4
    t = times(total)
    roll = circular_filter(noise(total, 61), low=40.0, high=220.0) * _wobble(total, 63, 0.6, 0.4)
    return normalise(rain(1.8, 62) + roll * 0.8, 0.65)


def gale():
    """A cold wind gusting at random, for snow and dust storms."""
    total = seconds(8.0)
    air = circular_filter(noise(total, 71), low=120.0, high=1800.0, tilt=-2.0)
    whistle = circular_filter(noise(total, 72), low=700.0, high=1100.0)
    whistle = whistle / np.max(np.abs(whistle)) * 0.4 * _wobble(total, 73, 0.3, 0.9)
    gusts = _wobble(total, 74, 0.35, 0.5) * _wobble(total, 75, 1.2, 0.15)
    return normalise((air / np.max(np.abs(air)) + whistle) * gusts, 0.55)


# Drifting. Each surface has a soft loop for a gentle drift and a hard one
# for a fast hard drift, which the game fades between by how much the tires
# slip. The loops are 2 s, and anything that wobbles does so a whole number
# of times in that, so they wrap without a click.

DRIFT_LOOP = 2.0


def _wobble(total, seed, rate, depth):
    """Slow random flutter that loops: noise smoothed down below `rate` Hz."""
    w = circular_filter(noise(total, seed), high=rate)
    return 1.0 + depth * w / max(np.max(np.abs(w)), 1e-9)


def _grit(total, seed, count, low, high, ring, loud=(0.2, 1.0)):
    """Little bits of grit or snow crunching, scattered round a loop."""
    r = rng(seed)
    hits = np.zeros(total)
    for i in r.integers(0, total, count):
        hits[i] += r.uniform(*loud)
    n = seconds(ring * 3)
    kernel = bandpass(noise(n, seed + 1), low, high) * decay(n, ring)
    return circular_convolve(hits, kernel)


def drift_tarmac(hard):
    """Rubber on tarmac: a soft hiss, and on a hard drift a squeal over it
    that wavers and breaks up so it doesn't ring like a whistle."""
    total = seconds(DRIFT_LOOP)
    t = times(total)
    hiss = normalise(circular_filter(noise(total, 81), low=1400.0, high=5500.0)) * _wobble(total, 82, 6.0, 0.35)
    if not hard:
        return normalise(hiss, 0.5)
    wander = 25 * np.sin(2 * np.pi * 1.5 * t) + 14 * np.sin(2 * np.pi * 4.0 * t + 0.6) + 8 * np.sin(2 * np.pi * 9.5 * t)
    p = np.cumsum(820 + wander) / RATE
    tone = np.sin(2 * np.pi * p) + 0.35 * np.sin(4 * np.pi * p + 0.3) + 0.12 * np.sin(6 * np.pi * p)
    # The squeal catches and lets go, a few times a second.
    catch = np.clip(_wobble(total, 83, 14.0, 1.0) - 0.6, 0.0, None)
    tone = tone * catch / max(np.max(catch), 1e-9)
    rough = circular_filter(noise(total, 84), low=600.0, high=2600.0)
    return normalise(normalise(tone) * 0.45 + hiss * 0.6 + normalise(rough) * 0.25, 0.6)


def drift_dirt(hard):
    """Tires scrabbling on dirt and mud: a low scrape with grit crunching
    through it, denser and with stones flicking up on a hard drift."""
    total = seconds(DRIFT_LOOP)
    scrape = normalise(circular_filter(noise(total, 91), low=120.0, high=900.0)) * _wobble(total, 92, 5.0, 0.3)
    grit = normalise(_grit(total, 93, 260 if hard else 110, 500.0, 2500.0, 0.006))
    out = scrape * 0.7 + grit * 0.6
    if hard:
        stones = normalise(_grit(total, 94, 40, 2000.0, 6000.0, 0.004, (0.3, 1.0)))
        out += stones * 0.3 + normalise(circular_filter(noise(total, 95), low=40.0, high=200.0)) * 0.4
    return normalise(out, 0.6 if hard else 0.5)


def drift_snow(hard):
    """Tires through snow: an airy hiss, and on a hard drift a fuller spray
    with the soft squeak and crunch of packed snow."""
    total = seconds(DRIFT_LOOP)
    air = normalise(circular_filter(noise(total, 101), low=2500.0, high=9000.0)) * _wobble(total, 102, 3.0, 0.3)
    if not hard:
        return normalise(air, 0.45)
    spray = normalise(circular_filter(noise(total, 103), low=500.0, high=6000.0, tilt=-1.5)) * _wobble(total, 104, 8.0, 0.4)
    crunch = normalise(_grit(total, 105, 180, 300.0, 1400.0, 0.012))
    return normalise(air * 0.5 + spray * 0.6 + crunch * 0.4, 0.6)


def _bubbles(total, seed, count, low, high, ring=(0.01, 0.04), loud=(0.2, 1.0)):
    """Little bubbles popping round a loop: short sines that rise in pitch as
    they die away, like water plinking."""
    r = rng(seed)
    out = np.zeros(total)
    for _ in range(count):
        at = r.integers(0, total)
        time = r.uniform(*ring)
        n = seconds(time * 2.0)
        f = r.uniform(low, high)
        bubble = sine(f * (1.0 + 0.6 * times(n) / time), n) * decay(n, time) * r.uniform(*loud)
        idx = (at + np.arange(n)) % total
        np.add.at(out, idx, bubble)
    return out


def drift_water(hard):
    """Tires sliding through shallow water: a hiss of spray with bubbles
    plinking, and on a hard drift a fuller rush of water and a low slosh."""
    total = seconds(DRIFT_LOOP)
    spray = normalise(circular_filter(noise(total, 121), low=900.0, high=7000.0, tilt=-1.0)) * _wobble(total, 122, 7.0, 0.4)
    drops = normalise(_bubbles(total, 123, 140 if hard else 70, 900.0, 2600.0))
    out = spray * 0.6 + drops * 0.4
    if hard:
        rush = normalise(circular_filter(noise(total, 124), low=250.0, high=2500.0)) * _wobble(total, 125, 4.0, 0.5)
        slosh = normalise(circular_filter(noise(total, 126), low=60.0, high=400.0)) * _wobble(total, 127, 3.0, 0.7)
        out += rush * 0.5 + slosh * 0.35
    return normalise(out, 0.6 if hard else 0.4)


def splash():
    """Rolling through shallow water: a churning wash with bubbles plinking
    and the odd slosh, which the game turns up with speed."""
    total = seconds(DRIFT_LOOP)
    wash = normalise(circular_filter(noise(total, 131), low=300.0, high=3500.0)) * _wobble(total, 132, 6.0, 0.45)
    hiss = normalise(circular_filter(noise(total, 133), low=2500.0, high=8000.0)) * _wobble(total, 134, 9.0, 0.3)
    drops = normalise(_bubbles(total, 135, 110, 700.0, 2200.0, (0.015, 0.05)))
    slosh = normalise(circular_filter(noise(total, 136), low=70.0, high=350.0)) * _wobble(total, 137, 2.5, 0.8)
    return normalise(wash * 0.55 + hiss * 0.2 + drops * 0.45 + slosh * 0.4, 0.6)


DRIFTS = {"tarmac": drift_tarmac, "dirt": drift_dirt, "snow": drift_snow, "water": drift_water}


# Boosts. The game plays a boost as a rush of air for its size (small,
# middling or big), with a turbo's roar on top of the middling and big ones
# and a thump under the big ones, each picked at random from a few made
# differently and pitched at random, so no two boosts sound the same.

def _flutter(n, seed, rate, depth):
    """Random flutter below `rate` Hz, for a one shot."""
    w = lowpass(noise(n, seed), rate, 1)
    return 1.0 + depth * w / max(np.max(np.abs(w)), 1e-9)


def boost_air(size, k):
    """A rush of air: longer, fuller and brighter for a bigger boost."""
    r = rng(300 + size * 10 + k)
    time = [0.45, 0.8, 1.4][size - 1] * [0.85, 1.0, 1.2][k - 1]
    n = seconds(time)
    air = bandpass(noise(n, 310 + size * 10 + k), r.uniform(100, 260), r.uniform(5000, 8500))
    top = [2500, 4000, 6500][size - 1] * r.uniform(0.8, 1.25)
    peak = r.uniform(0.18, 0.35)
    air = sweep_lowpass(air, ramp(n, [(0.0, r.uniform(300, 600)), (peak, top), (1.0, r.uniform(400, 900))]))
    air *= ramp(n, [(0.0, 0.0), (r.uniform(0.05, 0.14), 1.0), (1.0, 0.0)]) * _flutter(n, 320 + k, 10.0, 0.15 * size)
    rise = sine(np.geomspace(r.uniform(180, 260) + 60 * size, r.uniform(450, 600) + 200 * size, n), n)
    out = normalise(air) + rise * ramp(n, [(0.0, 0.0), (0.15, 0.1 + 0.03 * size), (1.0, 0.0)])
    return normalise(out, 0.45 + 0.12 * size)


def boost_roar(k):
    """A turbo kicking in: a roar with a whine climbing over it."""
    r = rng(340 + k)
    n = seconds(1.5 * [0.9, 1.0, 1.15][k - 1])
    roar = lowpass(noise(n, 341 + k), r.uniform(1600, 3000)) * _flutter(n, 345 + k, 14.0, 0.3)
    roar *= ramp(n, [(0.0, 0.0), (r.uniform(0.03, 0.07), 1.0), (0.5, 0.6), (1.0, 0.0)])
    start, end = r.uniform(650, 950), r.uniform(1800, 2700)
    whine = sine(np.geomspace(start, end, n), n) + sine(np.geomspace(start * 1.5, end * 1.5, n), n) * r.uniform(0.1, 0.35)
    whine *= ramp(n, [(0.0, 0.0), (0.1, 0.25), (0.6, 0.18), (1.0, 0.0)])
    return normalise(roar + whine, 0.75)


def boost_thump(k):
    """A low kick under a big boost."""
    r = rng(350 + k)
    m = seconds(0.4)
    out = sine(np.geomspace(r.uniform(85, 110), r.uniform(38, 50), m), m) * decay(m, 0.35)
    out += bandpass(noise(m, 352 + k), 200, 1500) * decay(m, 0.03) * 0.4
    return normalise(out, 0.7)


BOOSTS = {}
for _size in (1, 2, 3):
    for _k in (1, 2, 3):
        BOOSTS["boost_air_%d_%d" % (_size, _k)] = (lambda s=_size, k=_k: boost_air(s, k))
for _k in (1, 2, 3):
    BOOSTS["boost_roar_%d" % _k] = (lambda k=_k: boost_roar(k))
for _k in (1, 2):
    BOOSTS["boost_thump_%d" % _k] = (lambda k=_k: boost_thump(k))


LOOPS = {"skid": skid, "rumble": rumble, "splash": splash, "wind": wind, "wind_low": wind_low, "rain": rain, "storm": storm, "gale": gale}
for _surface, _make in DRIFTS.items():
    LOOPS["drift_%s_soft" % _surface] = lambda m=_make: m(False)
    LOOPS["drift_%s_hard" % _surface] = lambda m=_make: m(True)


# One shots.

def clack(seed, pitch=1.0, ring=0.03):
    """One plastic brick knocking against another."""
    r = rng(seed)
    n = seconds(0.08)
    out = np.zeros(n)
    for _ in range(2):
        out += resonator(r.uniform(1500, 4500) * pitch, r.uniform(0.6, 1.2) * ring, n) * r.uniform(0.5, 1.0)
    out += highpass(noise(n, seed + 100), 2000) * decay(n, 0.004) * 0.6
    return out


def thud(start_hz, end_hz, time, seed):
    n = seconds(time)
    body = sine(np.geomspace(start_hz, end_hz, n), n) * decay(n, time)
    dirt = lowpass(noise(n, seed), 1200) * decay(n, time * 0.4)
    return body + dirt * 0.6


def bump():
    return normalise(mix((thud(110, 60, 0.18, 1), 0.0), (clack(2) * 0.5, 0.0)), 0.8)


def crash():
    out = mix((thud(80, 40, 0.45, 3), 0.0), (lowpass(noise(seconds(0.3), 4), 2500) * decay(seconds(0.3), 0.2), 0.0),
              (clack(5) * 0.6, 0.01), (clack(6) * 0.5, 0.05), (clack(7) * 0.3, 0.11))
    return normalise(drive(normalise(out), 1.5), 0.9)


def bricks():
    """Bricks knocked off, clattering down and bouncing."""
    r = rng(8)
    parts = []
    at = 0.0
    gap = 0.03
    loud = 1.0
    for i in range(16):
        parts.append((clack(50 + i, r.uniform(0.8, 1.2)) * loud, at))
        at += gap * r.uniform(0.6, 1.4)
        gap *= 1.12
        loud *= 0.86
    return normalise(reverb(mix(*parts), 0.12, 0.5), 0.8)


def chime(notes, gap, ring=0.3, shape="triangle"):
    parts = []
    for i, name in enumerate(notes):
        n = seconds(ring)
        f = note_freq(name)
        tone = triangle(f, n) if shape == "triangle" else square(f, n, harmonics=8)
        tone = tone + sine(f * 2, n) * 0.3
        parts.append((tone * decay(n, ring) * adsr(n, 0.002, 0.0, 1.0, 0.0), i * gap))
    return mix(*parts)


def powerup():
    """Picking up a power-up: a quick sparkle up four notes."""
    return normalise(reverb(chime(["C6", "E6", "G6", "C7"], 0.045, 0.3), 0.2, 0.5), 0.65)


def beep(name, time):
    n = seconds(time)
    tone = square(note_freq(name), n, harmonics=12) * adsr(n, 0.003, 0.05, 0.7, 0.03)
    return normalise(lowpass(tone, 4000), 0.6)


def lap():
    return normalise(reverb(chime(["C6", "E6", "G6"], 0.07, 0.3), 0.2, 0.5), 0.6)


def final_lap():
    out = mix((chime(["C6", "E6", "G6", "C7"], 0.07, 0.25), 0.0))
    n = seconds(0.6)
    held = triangle(note_freq("C7") * (1.0 + 0.01 * np.sin(2 * np.pi * 6 * times(n))), n) * adsr(n, 0.01, 0.1, 0.6, 0.3)
    return normalise(reverb(mix((out, 0.0), (held * 0.7, 0.28)), 0.2, 0.6), 0.6)


def fanfare(melody, chord, tempo=0.11):
    """A little brass-ish fanfare: a lead over a held chord."""
    parts = []
    at = 0.0
    for name, beats in melody:
        n = seconds(beats * tempo + 0.05)
        f = note_freq(name)
        lead = square(f, n, 0.3, harmonics=10) * adsr(n, 0.01, 0.08, 0.7, 0.05)
        lead = sweep_lowpass(lead, ramp(n, [(0.0, 1500), (0.1, 4000), (1.0, 2000)]))
        parts.append((lead, at))
        at += beats * tempo
    n = seconds(at + 0.6)
    pad = sum(square(note_freq(c), n, 0.5, harmonics=6) for c in chord) * adsr(n, 0.05, 0.2, 0.5, 0.5) * 0.25
    parts.append((lowpass(pad, 2000), 0.0))
    return normalise(reverb(mix(*parts), 0.2, 0.7), 0.8)


def finish():
    return fanfare([("G5", 1), ("C6", 1), ("E6", 1), ("G6", 3)], ["C4", "G4", "E5"])


def win():
    return fanfare([("C6", 1), ("C6", 1), ("C6", 1), ("C6", 2), ("Ab5", 2), ("Bb5", 2), ("C6", 1), ("Bb5", 1), ("C6", 5)],
                   ["C4", "G4", "E5"], tempo=0.1)


def reset():
    n = seconds(0.55)
    whoosh = bandpass(noise(n, 9), 300, 4000)
    whoosh = sweep_lowpass(whoosh, ramp(n, [(0.0, 300), (1.0, 5000)])) * ramp(n, [(0.0, 0.0), (0.3, 1.0), (1.0, 0.0)])
    rise = sine(np.geomspace(300, 900, n), n) * ramp(n, [(0.0, 0.0), (0.2, 0.4), (1.0, 0.0)])
    return normalise(whoosh + rise, 0.7)


def plunge():
    """A kart dropping into deep water: a deep gloop as it goes in, a rush of
    spray thrown up and falling back, then bubbles rising."""
    n = seconds(1.1)
    gloop = sine(np.geomspace(220, 55, seconds(0.35)), seconds(0.35)) * decay(seconds(0.35), 0.18)
    body = lowpass(noise(seconds(0.5), 141), 500) * decay(seconds(0.5), 0.2)
    rush = bandpass(noise(n, 142), 400, 7000)
    rush = sweep_lowpass(rush, ramp(n, [(0.0, 7000), (0.4, 2500), (1.0, 900)])) * ramp(n, [(0.0, 0.0), (0.02, 1.0), (0.25, 0.5), (1.0, 0.0)])
    fall = bandpass(noise(seconds(0.6), 143), 1500, 6000) * ramp(seconds(0.6), [(0.0, 0.0), (0.3, 0.6), (1.0, 0.0)])
    bubbles = _bubbles(seconds(0.8), 144, 26, 300.0, 1100.0, (0.02, 0.06)) * ramp(seconds(0.8), [(0.0, 0.3), (0.3, 1.0), (1.0, 0.0)])
    out = mix((gloop * 0.9, 0.0), (body * 0.6, 0.0), (normalise(rush) * 0.7, 0.0), (normalise(fall) * 0.35, 0.25), (normalise(bubbles) * 0.4, 0.3))
    return normalise(out, 0.85)


def sizzle():
    """A kart dropping into lava or slime: a soft thump as it goes in, a loud
    hiss of steam that dies away, with crackles and pops through it."""
    n = seconds(1.3)
    thump = lowpass(noise(seconds(0.25), 151), 300) * decay(seconds(0.25), 0.08)
    hiss = bandpass(noise(n, 152), 2500, 10000)
    hiss = sweep_lowpass(hiss, ramp(n, [(0.0, 10000), (0.5, 6000), (1.0, 3000)])) * ramp(n, [(0.0, 0.0), (0.03, 1.0), (0.3, 0.6), (1.0, 0.0)])
    steam = bandpass(noise(n, 153), 600, 2500) * ramp(n, [(0.0, 0.0), (0.05, 0.6), (0.6, 0.25), (1.0, 0.0)])
    crackle = _grit(seconds(1.0), 154, 70, 1500.0, 6000.0, 0.004) * ramp(seconds(1.0), [(0.0, 1.0), (0.5, 0.6), (1.0, 0.0)])
    pops = _bubbles(seconds(0.9), 155, 14, 180.0, 500.0, (0.02, 0.05)) * ramp(seconds(0.9), [(0.0, 0.2), (0.3, 1.0), (1.0, 0.0)])
    out = mix((thump * 0.7, 0.0), (normalise(hiss) * 0.8, 0.0), (normalise(steam) * 0.4, 0.0), (normalise(crackle) * 0.35, 0.05), (normalise(pops) * 0.35, 0.2))
    return normalise(out, 0.8)


def rope():
    """A tow rope: a whip through the air, then a clunk as it catches."""
    n = seconds(0.45)
    whip = bandpass(noise(n, 91), 900, 4000) * ramp(n, [(0.0, 0.0), (0.18, 1.0), (0.24, 0.0), (1.0, 0.0)])
    clunk = np.roll(resonator(320, 0.08, n) + resonator(780, 0.05, n) * 0.5, seconds(0.22))
    return normalise(mix((whip, 0.0), (clunk * 0.9, 0.0), (thud(180, 90, 0.12, 92) * 0.6, 0.22)), 0.8)


def wall():
    """A brick wall dropped: a pile of bricks clattering into place."""
    clacks = [(clack(100 + i, 0.8 + 0.08 * (i % 4), 0.04) * (0.9 - i * 0.07), i * 0.045) for i in range(10)]
    return normalise(mix((thud(200, 90, 0.18, 99), 0.0), *clacks), 0.85)


def shockwave():
    """A shockwave: a deep thump and a whoosh going out."""
    n = seconds(0.8)
    thump = sine(np.geomspace(110, 38, n), n) * decay(n, 0.3)
    whoosh = bandpass(noise(n, 95), 300, 2500) * ramp(n, [(0.0, 0.0), (0.08, 1.0), (1.0, 0.0)]) * 0.7
    return normalise(drive(thump * 1.4 + whoosh, 1.6), 0.9)


def marbles():
    """Marbles: a handful of little round bricks rattling out across the road."""
    clicks = [(clack(120 + i, 1.5 + 0.1 * (i % 5), 0.015) * (0.8 - i * 0.04), i * 0.03 + 0.01 * (i % 3)) for i in range(16)]
    return normalise(mix(*clicks), 0.8)


def spikes():
    """A spike trap: sharp little pieces clattering down, with a bright ring."""
    n = seconds(0.4)
    ring = sum(resonator(f, 0.12, n) * a for f, a in [(2400, 0.6), (3600, 0.4), (5200, 0.25)])
    clacks = [(clack(140 + i, 1.8, 0.01) * 0.7, i * 0.035) for i in range(8)]
    return normalise(mix((ring, 0.0), *clacks), 0.8)


def drop():
    return normalise(mix((thud(220, 120, 0.15, 11), 0.0), (resonator(900, 0.05, seconds(0.1)) * 0.4, 0.0), (clack(12) * 0.4, 0.0)), 0.8)


def cannon():
    n = seconds(0.3)
    pop = lowpass(noise(n, 13), 3000) * decay(n, 0.05)
    boom = sine(np.geomspace(300, 70, n), n) * decay(n, 0.25)
    return normalise(drive(pop + boom, 2.0), 0.9)


def hit():
    return normalise(mix((thud(160, 80, 0.15, 14), 0.0), (clack(15, 1.1) * 0.8, 0.0), (clack(16, 0.9) * 0.4, 0.03)), 0.85)


def homing_warning():
    """A homing brick coming for you: a soft round bip that slides up a little."""
    n = seconds(0.14)
    pitch = np.geomspace(1050, 1400, n)
    tone = sine(pitch, n) + sine(pitch * 2, n) * 0.12
    return normalise(reverb(tone * adsr(n, 0.012, 0.05, 0.6, 0.07), 0.15, 0.4), 0.5)


def repair():
    clicks = [(clack(60 + i, 1.4, 0.01) * 0.5, i * 0.05) for i in range(6)]
    sparkle = chime(["C6", "G6", "C7"], 0.08, 0.35)
    return normalise(reverb(mix(*clicks, (sparkle * 0.6, 0.32)), 0.2, 0.5), 0.7)


def shield():
    n = seconds(0.9)
    t = times(n)
    base = np.geomspace(600, 1200, n)
    tone = sum(sine(base * m, n) for m in (1.0, 1.007, 1.5, 2.003)) * (0.7 + 0.3 * np.sin(2 * np.pi * 18 * t))
    return normalise(reverb(tone * adsr(n, 0.05, 0.1, 0.8, 0.5), 0.3, 0.6), 0.6)


def ghost():
    """Going ghostly: a breathy whoosh with a wobbly tone that sinks away."""
    n = seconds(0.9)
    t = times(n)
    breath = bandpass(noise(n, 81), 400, 2500) * ramp(n, [(0.0, 0.0), (0.15, 0.6), (1.0, 0.0)])
    pitch = np.geomspace(900, 300, n) * (1.0 + 0.04 * np.sin(2 * np.pi * 7 * t))
    tone = (sine(pitch, n) + sine(pitch * 1.5, n) * 0.4) * adsr(n, 0.05, 0.1, 0.7, 0.4)
    return normalise(reverb(breath + tone * 0.6, 0.35, 0.8), 0.6)


def lightning():
    """A thunderclap on the kart: a sharp crack, then a short low roll.
    Quieter than the storm's thunder."""
    n = seconds(1.5)
    crack = highpass(noise(n, 82), 200) * decay(n, 0.045)
    snap = highpass(noise(n, 84), 500) * np.roll(decay(n, 0.03), seconds(0.045)) * 0.4
    boom = lowpass(noise(n, 86), 110) * ramp(n, [(0.0, 0.0), (0.015, 1.0), (0.12, 0.65), (1.0, 0.0)]) * 2.4
    roll = lowpass(noise(n, 87), 70) * ramp(n, [(0.0, 0.0), (0.06, 1.0), (0.3, 0.5), (1.0, 0.0)]) * 1.8
    return normalise(drive(crack + snap + boom + roll, 1.15), 0.42)


def thunder():
    """Thunder: a crack overhead, then a long low roll that dies away."""
    n = seconds(3.5)
    crack = highpass(noise(n, 91), 800) * decay(n, 0.15) * 0.8
    roll = lowpass(noise(n, 92), 140) * ramp(n, [(0.0, 0.0), (0.06, 1.0), (0.4, 0.8), (1.0, 0.0)]) * 3.0
    rumble = lowpass(noise(n, 93), 60) * ramp(n, [(0.0, 0.0), (0.2, 1.0), (1.0, 0.0)]) * 3.0
    return normalise(drive(crack + roll + rumble, 1.3), 0.9)


def crossing_bell():
    """A level crossing's bell: one bright ding, played over and over."""
    n = seconds(0.5)
    ding = sum(resonator(f, d, n) * a for f, d, a in [(1180, 0.35, 1.0), (2950, 0.18, 0.45), (4400, 0.08, 0.2)])
    tap = highpass(noise(n, 95), 3000) * decay(n, 0.004) * 0.4
    return normalise(ding + tap, 0.6)


def train_horn():
    """A toy train's horn: two notes together, held for a moment."""
    n = seconds(1.3)
    wobble = 1.0 + 0.004 * sine(5.5, n)
    tone = sum(saw(f * wobble, n, harmonics=10) * a for f, a in [(311, 1.0), (392, 0.8)])
    tone = lowpass(tone, 2200) * adsr(n, 0.04, 0.1, 0.85, 0.25)
    return normalise(reverb(tone, 0.15, 0.6), 0.7)


def ram():
    n = seconds(0.6)
    clang = sum(resonator(f, d, n) * a for f, d, a in [(520, 0.5, 1.0), (1370, 0.35, 0.6), (2210, 0.25, 0.4), (3100, 0.15, 0.3)])
    return normalise(mix((clang, 0.0), (thud(120, 60, 0.2, 17), 0.0)), 0.85)


def click():
    n = seconds(0.04)
    return normalise(resonator(1800, 0.015, n) + resonator(600, 0.02, n) * 0.5, 0.5)


def back():
    return normalise(mix((click(), 0.0), (resonator(1200, 0.02, seconds(0.04)) * 0.5, 0.045)), 0.5)


def snap():
    """A brick pressing onto studs: two quick clicks."""
    def one(seed):
        n = seconds(0.05)
        return resonator(3000, 0.008, n) + resonator(5200, 0.006, n) * 0.6 + resonator(300, 0.02, n) * 0.5 \
            + highpass(noise(n, seed), 3000) * decay(n, 0.003) * 0.5
    return normalise(mix((one(18), 0.0), (one(19) * 0.7, 0.025)), 0.7)


def unsnap():
    n = seconds(0.06)
    pop = sine(np.geomspace(400, 900, n), n) * decay(n, 0.05)
    return normalise(mix((pop, 0.0), (clack(20, 1.2, 0.01) * 0.3, 0.0)), 0.6)


def pick():
    n = seconds(0.05)
    return normalise(resonator(1200, 0.02, n) + resonator(2400, 0.01, n) * 0.3, 0.45)


def nope():
    n = seconds(0.12)
    one = lowpass(square(150, n, 0.5, harmonics=20), 2000) * adsr(n, 0.005, 0.0, 1.0, 0.02)
    return normalise(mix((one, 0.0), (one, 0.15)), 0.5)


def _brass(name, beats, tempo, bright=4500.0):
    """One brassy note: a pulse wave that opens up as it's blown, with a
    little vibrato coming in as it's held."""
    n = seconds(beats * tempo + 0.08)
    t = times(n)
    vibrato = 1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.4, 0.0, 1.0)
    tone = square(note_freq(name) * vibrato, n, 0.32, harmonics=14) * adsr(n, 0.015, 0.1, 0.75, 0.07)
    return sweep_lowpass(tone, ramp(n, [(0.0, 1200), (0.08, bright), (1.0, bright * 0.6)]))


def _drum(time, seed):
    """A big round drum, for the fanfare."""
    return thud(95, 70, time, seed) * 0.9


def podium():
    """The fanfare on the podium: a call on the brass, answered up to a big
    held chord, with drums under it."""
    tempo = 0.14
    lead = [("G5", 1), ("G5", 1), ("G5", 1), ("C6", 3), ("G5", 1), ("C6", 1), ("E6", 3),
            ("D6", 1), ("C6", 1), ("D6", 1), ("E6", 1), ("F6", 1), ("G6", 8)]
    under = [("E5", 1), ("E5", 1), ("E5", 1), ("G5", 3), ("E5", 1), ("G5", 1), ("C6", 3),
             ("B5", 1), ("A5", 1), ("B5", 1), ("C6", 1), ("D6", 1), ("E6", 8)]
    parts = []
    for melody, loud, bright in ((lead, 1.0, 4500.0), (under, 0.55, 3000.0)):
        at = 0.0
        for name, beats in melody:
            parts.append((_brass(name, beats, tempo, bright) * loud, at))
            at += beats * tempo
    end = at
    # A low chord under the last note, swelling.
    hold = end - 8 * tempo
    n = seconds(8 * tempo + 0.9)
    chord = sum(_brass(c, 8 + 6, tempo, 2000.0)[:n] for c in ["C4", "G4", "C5"]) * 0.35
    parts.append((chord * ramp(len(chord), [(0.0, 0.4), (0.3, 1.0), (1.0, 1.0)]), hold))
    # Drums on the big notes, and a roll into the last one.
    for beat in [3, 9]:
        parts.append((_drum(0.5, 200 + beat), beat * tempo))
    roll = hold - 6 * 0.045
    for i in range(6):
        parts.append((_drum(0.12, 220 + i) * (0.35 + i * 0.08), roll + i * 0.045))
    parts.append((_drum(1.0, 230), hold))
    n_cym = seconds(1.6)
    cymbal = highpass(noise(n_cym, 240), 5000) * decay(n_cym, 1.4) * 0.25
    parts.append((cymbal, hold))
    return normalise(reverb(mix(*parts), 0.25, 0.9), 0.85)


def cheer():
    """A crowd cheering: lots of voices calling out "yay" and "woo" at once,
    clapping and a whistle or two, swelling up and dying away."""
    r = rng(300)
    length = 4.6
    total = seconds(length)
    parts = []
    for i in range(36):
        start = r.uniform(0.0, 0.7)
        time = r.uniform(1.2, 3.2)
        n = seconds(time)
        base = r.uniform(170, 420)
        # Up as they shout, then falling away.
        pitch = base * ramp(n, [(0.0, 0.8), (0.15, 1.15), (0.5, 1.05), (1.0, 0.75)])
        pitch = pitch * (1.0 + 0.02 * np.sin(2 * np.pi * r.uniform(4, 7) * times(n)))
        voice = saw(pitch, n, harmonics=24)
        breath = noise(n, 400 + i) * 0.5
        # Two formants, opening from "oo" to "ay".
        low = r.uniform(500, 800)
        high = low * r.uniform(1.6, 2.4)
        vowel = bandpass(voice + breath, low * 0.7, low * 1.3) + bandpass(voice + breath, high * 0.8, high * 1.2) * 0.6
        envelope = adsr(n, r.uniform(0.05, 0.25), 0.3, 0.6, min(0.8, time * 0.5))
        parts.append((vowel * envelope * r.uniform(0.3, 1.0), start))
    # Clapping, coming in thick and thinning out.
    claps = []
    at = 0.2
    while at < length - 0.3:
        density = np.interp(at, [0.0, 0.8, 2.5, length], [20, 90, 60, 10])
        n = seconds(0.03)
        clap = bandpass(noise(n, int(at * 1000)), r.uniform(900, 1500), r.uniform(2500, 5000)) * decay(n, 0.02)
        claps.append((clap * r.uniform(0.2, 0.6), at))
        at += r.exponential(1.0 / density)
    parts += claps
    # A couple of whistles.
    for start, seed in [(0.6, 1), (1.7, 2)]:
        n = seconds(0.7)
        glide = ramp(n, [(0.0, 1800), (0.3, 2900), (0.6, 2600), (1.0, 3100)])
        parts.append((sine(glide, n) * adsr(n, 0.03, 0.1, 0.8, 0.2) * 0.12, start))
    out = mix(*parts)[:total]
    out = lowpass(out, 7000) * ramp(len(out), [(0.0, 0.3), (0.12, 1.0), (0.55, 0.8), (1.0, 0.0)])
    return normalise(reverb(out, 0.3, 1.0), 0.6)


ONE_SHOTS = {
    "bump": bump, "crash": crash, "bricks": bricks, "powerup": powerup,
    "beep": lambda: beep("A5", 0.16), "go": lambda: beep("A6", 0.5),
    "lap": lap, "final_lap": final_lap, "finish": finish, "win": win,
    "reset": reset, "splash": plunge, "sizzle": sizzle, "rope": rope, "wall": wall, "shockwave": shockwave, "marbles": marbles, "spikes": spikes, "drop": drop, "cannon": cannon,
    "hit": hit, "homing_warning": homing_warning, "repair": repair, "shield": shield, "ghost": ghost, "lightning": lightning, "thunder": thunder, "ram": ram,
    "crossing_bell": crossing_bell, "train_horn": train_horn,
    "click": click, "back": back, "snap": snap, "unsnap": unsnap, "pick": pick, "nope": nope,
    "podium": podium, "cheer": cheer,
    **BOOSTS,
}


def make_all():
    """Every effect: name to (samples, whether it loops)."""
    out = {}
    for name, samples in engines.make_all().items():
        out[name] = (samples, True)
    for name, make in LOOPS.items():
        out["loop/" + name] = (make(), True)
    for name, make in ONE_SHOTS.items():
        out["fx/" + name] = (fade(trim(make())), False)
    return out
