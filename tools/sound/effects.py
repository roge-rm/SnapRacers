"""SnapRacers' sound effects, made from scratch with synth.py.

There are three kinds:
  - engine loops, one for each kind of engine, which the game speeds up and
    slows down with the kart
  - other loops, like tire squeal and wind
  - one shots, like crashes, gadgets, studs and menu clicks

An engine is a train of firing pulses, one for each time a cylinder fires,
each one ringing the exhaust and the body like a bell. How many cylinders
there are, how evenly they fire and how the exhaust rings is what makes a
diesel sound different from a V8.
"""

import numpy as np

from synth import (
    RATE, adsr, bandpass, circular_convolve, circular_filter, decay, drive, fade,
    highpass, lowpass, mix, noise, normalise, note_freq, phase_of, ramp, reverb,
    resonator, rng, seconds, sine, square, sweep_lowpass, times, triangle, trim,
)


# Engines.

def engine(seed, cycle_hz, firings, body, rasp=0.3, grit=2.0, bright=4000.0, knock=0.0, length=1.0):
    """A loop of an engine running steadily.

    cycle_hz: how many times a second the firing pattern repeats.
    firings: (when in the cycle, 0 to 1, and how hard) for each firing.
    body: (Hz, seconds to ring, loudness) for each resonance of the exhaust.
    rasp: how much noise comes out with each firing.
    knock: sharp clatter on each firing, for a diesel.
    """
    r = rng(seed)
    period = int(round(RATE / cycle_hz))
    cycles = max(1, int(round(length * cycle_hz)))
    total = period * cycles
    pulses = np.zeros(total)
    for c in range(cycles):
        for when, strength in firings:
            i = c * period + int(when * period)
            pulses[i % total] += strength * r.uniform(0.85, 1.0)

    kernel_length = seconds(0.12)
    kernel = np.zeros(kernel_length)
    for freq, ring, loud in body:
        kernel += resonator(freq * r.uniform(0.98, 1.02), ring, kernel_length) * loud
    burst = bandpass(noise(kernel_length, seed + 1), 300, 3000) * decay(kernel_length, 0.008)
    kernel += burst * 0.5
    out = circular_convolve(pulses, kernel)

    # Noise that puffs out with each firing.
    puff = circular_convolve(pulses, decay(seconds(0.03), 0.03))
    hiss = circular_filter(noise(total, seed + 2), low=200.0, high=bright * 1.5)
    out += hiss * puff * rasp

    if knock:
        clatter = circular_filter(noise(total, seed + 3), low=2500.0, high=6000.0)
        tick = circular_convolve(pulses, decay(seconds(0.006), 0.006))
        out += clatter * tick * knock * 3.0

    out = normalise(out)
    out = drive(out, grit)
    out = circular_filter(out, low=40.0, high=bright)
    return normalise(out, 0.8)


def electric_motor(pitch=400, seed=71):
    """A whine with a gear mesh over it and a little whir."""
    total = RATE
    t = times(total)
    wobble = 1.0 + 0.08 * np.sin(2 * np.pi * 7 * t)
    out = (np.sin(2 * np.pi * pitch * t) * 1.0
           + np.sin(2 * np.pi * pitch * 2 * t) * 0.45
           + np.sin(2 * np.pi * pitch * 3 * t) * 0.2
           + np.sin(2 * np.pi * pitch * 4 * t) * 0.12) * wobble
    whir = circular_filter(noise(total, seed), low=pitch * 1.25, high=pitch * 7.5)
    out += whir * 0.35
    out += np.sin(2 * np.pi * pitch / 4 * t) * 0.25
    return normalise(circular_filter(out, low=60.0, high=6000.0), 0.7)


def hybrid():
    """A little engine with an electric whine over it."""
    body = engine(17, 50, [(0.0, 1.0), (0.5, 0.9)], [(150, 0.03, 1.0), (330, 0.015, 0.5), (800, 0.006, 0.2)], rasp=0.3, grit=2.0, bright=4000)
    return normalise(body * 0.75 + electric_motor(520, 73) * 0.45, 0.72)


def pedals():
    """No engine at all: a chain whirring round and a tick from the cranks."""
    total = RATE
    t = times(total)
    whir = circular_filter(noise(total, 91), low=900.0, high=4000.0)
    chain = (0.5 + 0.5 * np.sin(2 * np.pi * 36 * t)) * whir
    ticks = np.zeros(total)
    for k in range(2):
        start = int(total * k / 2)
        ticks[start:start + 200] += np.exp(-np.arange(200) / 30.0) * np.sin(np.arange(200) * 0.9)
    return normalise(chain * 0.6 + ticks * 0.8, 0.5)


def jet():
    """A roar with a turbine whining over it."""
    total = RATE * 2
    t = times(total)
    roar = circular_filter(noise(total, 81), low=60.0, high=2500.0, tilt=-3.0)
    body = circular_filter(noise(total, 82), low=250.0, high=900.0)
    flicker = 1.0 + 0.15 * np.sin(2 * np.pi * 3 * t) + 0.1 * np.sin(2 * np.pi * 5 * t + 1.0)
    whine = np.sin(2 * np.pi * 2400 * t) * 0.12 + np.sin(2 * np.pi * 4800 * t) * 0.04
    out = (normalise(roar) * 0.8 + normalise(body) * 0.5) * flicker + whine
    return normalise(out, 0.75)


ENGINES = {
    # A kart's little single, buzzy and raspy.
    "engine_small": lambda: engine(11, 55, [(0.0, 1.0)], [(160, 0.03, 1.0), (380, 0.015, 0.6), (900, 0.006, 0.3)], rasp=0.5, grit=3.0, bright=5000),
    # Like a lawnmower.
    "engine_micro": lambda: engine(12, 42, [(0.0, 1.0)], [(240, 0.02, 1.0), (700, 0.01, 0.7), (1500, 0.004, 0.4)], rasp=0.7, grit=4.0, bright=6000),
    # A smooth four, firing twice a turn.
    "engine_big": lambda: engine(13, 45, [(0.0, 1.0), (0.5, 0.95)], [(130, 0.035, 1.0), (260, 0.02, 0.5), (520, 0.01, 0.25)], rasp=0.25, grit=2.0, bright=3500),
    # A V twin, lumpy with its uneven firing.
    "engine_twin": lambda: engine(14, 28, [(0.0, 1.0), (0.34, 0.85)], [(110, 0.05, 1.0), (240, 0.025, 0.5), (600, 0.008, 0.2)], rasp=0.35, grit=2.5, bright=3500),
    # Low, with a clatter on every firing.
    "engine_diesel": lambda: engine(15, 30, [(0.0, 1.0), (0.5, 0.9)], [(85, 0.05, 1.0), (190, 0.03, 0.6), (420, 0.01, 0.2)], rasp=0.2, grit=2.0, bright=6000, knock=0.8),
    # A cross plane V8 burble: four uneven firings each time around.
    "engine_v8": lambda: engine(16, 24, [(0.0, 1.0), (0.22, 0.7), (0.5, 0.95), (0.75, 0.8)], [(75, 0.06, 1.0), (160, 0.035, 0.7), (330, 0.015, 0.4), (700, 0.006, 0.2)], rasp=0.3, grit=2.5, bright=3000),
    "electric_motor": electric_motor,
    "jet": jet,
    # A rotary: three smooth, even firings every turn, and it revs high.
    "engine_rotary": lambda: engine(18, 60, [(0.0, 1.0), (0.333, 1.0), (0.667, 1.0)], [(200, 0.02, 1.0), (450, 0.012, 0.6), (1100, 0.005, 0.3)], rasp=0.2, grit=1.5, bright=6000),
    # A flat four, with the boxer's offbeat rumble.
    "engine_flat4": lambda: engine(19, 26, [(0.0, 1.0), (0.2, 0.75), (0.5, 0.95), (0.72, 0.8)], [(90, 0.05, 1.0), (200, 0.03, 0.6), (450, 0.01, 0.25)], rasp=0.3, grit=2.2, bright=3200),
    # A bigger electric motor whines lower.
    "electric_big": lambda: electric_motor(290, 72),
    "engine_hybrid": hybrid,
    "pedals": pedals,
}


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
    """Air rushing past at speed."""
    total = RATE * 2
    t = times(total)
    air = circular_filter(noise(total, 41), low=200.0, high=1500.0)
    swell = 1.0 + 0.3 * np.sin(2 * np.pi * 0.5 * t) + 0.15 * np.sin(2 * np.pi * 1.5 * t + 2.0)
    return normalise(air * swell, 0.6)


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
    roll = circular_filter(noise(total, 61), low=40.0, high=220.0) * (1.0 + 0.4 * np.sin(2 * np.pi * 0.25 * t))
    return normalise(rain(1.8, 62) + roll * 0.8, 0.65)


def gale():
    """A cold wind gusting slowly, for snow and dust storms."""
    total = RATE * 4
    t = times(total)
    air = circular_filter(noise(total, 71), low=120.0, high=900.0)
    whistle = circular_filter(noise(total, 72), low=700.0, high=1100.0) * 0.4
    gusts = 1.0 + 0.5 * np.sin(2 * np.pi * 0.25 * t) + 0.25 * np.sin(2 * np.pi * 0.75 * t + 1.0)
    return normalise((air + whistle) * gusts, 0.55)


LOOPS = {"skid": skid, "rumble": rumble, "wind": wind, "rain": rain, "storm": storm, "gale": gale}


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


def turbo():
    n = seconds(1.0)
    roar = lowpass(noise(n, 10), 2500) * ramp(n, [(0.0, 0.0), (0.05, 1.0), (1.0, 0.0)])
    whine = sine(np.geomspace(800, 2200, n), n) * ramp(n, [(0.0, 0.0), (0.1, 0.3), (1.0, 0.0)])
    return normalise(roar + whine, 0.8)


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
    """Lightning: a sharp crackle, then a low rumble."""
    n = seconds(1.1)
    crackle = highpass(noise(n, 82), 1500) * decay(n, 0.12)
    for k, at in enumerate((0.0, 0.03, 0.07)):
        crackle = crackle + highpass(noise(n, 83 + k), 2500) * np.roll(decay(n, 0.02), seconds(at)) * 0.7
    rumble = lowpass(noise(n, 86), 180) * ramp(n, [(0.0, 0.0), (0.1, 1.0), (1.0, 0.0)]) * 2.5
    return normalise(drive(crackle + rumble, 1.5), 0.85)


def thunder():
    """Thunder: a crack overhead, then a long low roll that dies away."""
    n = seconds(3.5)
    crack = highpass(noise(n, 91), 800) * decay(n, 0.15) * 0.8
    roll = lowpass(noise(n, 92), 140) * ramp(n, [(0.0, 0.0), (0.06, 1.0), (0.4, 0.8), (1.0, 0.0)]) * 3.0
    rumble = lowpass(noise(n, 93), 60) * ramp(n, [(0.0, 0.0), (0.2, 1.0), (1.0, 0.0)]) * 3.0
    return normalise(drive(crack + roll + rumble, 1.3), 0.9)


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


ONE_SHOTS = {
    "bump": bump, "crash": crash, "bricks": bricks, "powerup": powerup,
    "beep": lambda: beep("A5", 0.16), "go": lambda: beep("A6", 0.5),
    "lap": lap, "final_lap": final_lap, "finish": finish, "win": win,
    "reset": reset, "turbo": turbo, "rope": rope, "wall": wall, "shockwave": shockwave, "marbles": marbles, "spikes": spikes, "drop": drop, "cannon": cannon,
    "hit": hit, "repair": repair, "shield": shield, "ghost": ghost, "lightning": lightning, "thunder": thunder, "ram": ram,
    "click": click, "back": back, "snap": snap, "unsnap": unsnap, "pick": pick, "nope": nope,
}


def make_all():
    """Every effect: name to (samples, whether it loops)."""
    out = {}
    for name, make in ENGINES.items():
        out["engine/" + name] = (make(), True)
    for name, make in LOOPS.items():
        out["loop/" + name] = (make(), True)
    for name, make in ONE_SHOTS.items():
        out["fx/" + name] = (fade(trim(make())), False)
    return out
