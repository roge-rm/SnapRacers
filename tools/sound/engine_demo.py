#!/usr/bin/env python3
"""Listening demos of the engines and the wind, played the way the game
plays them, into a folder you name.

  uv run --with numpy --with scipy tools/sound/engine_demo.py OUT [BEFORE]

For each engine it plays a short lap: idle on the grid with a couple of
blips, a launch, flat out up through the gears, a lift and brake into a
corner and back on. EngineSound does the sums in the game
(scripts/audio/engine_sound.gd); this copies it. BEFORE is a folder with
the old engine/*.wav and loop/wind.wav, to make the same runs the old way
too.

It also makes the wind at a few speeds, two karts with the same engine side
by side, every kind of boost three times over (drift levels 1 to 3, tow
rope, triple, turbo, big turbo), and a pack of AI karts round the player
with the race music under them. BEFORE wants the old fx/turbo.wav and
fx/drift_whoosh_*.wav too.
"""

import math
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

import effects  # noqa: E402
import engines  # noqa: E402
from synth import RATE, write_ogg  # noqa: E402

FPS = 60
SOUND = os.path.join(os.path.dirname(__file__), "..", "..", "sound")

# Copied from EngineSound.TYPES.
TYPES = {
    "engine_small": [5.0, 1, 0.6, 0.35],
    "engine_micro": [2.6, 1, 0.7, 0.3],
    "engine_big": [5.0, 5, 0.5, 0.3],
    "engine_twin": [5.5, 5, 0.7, 0.3],
    "engine_diesel": [3.2, 5, 0.8, 0.2],
    "engine_v8": [5.0, 4, 0.8, 0.3],
    "engine_rotary": [5.5, 5, 0.65, 0.35],
    "engine_flat4": [5.0, 5, 0.75, 0.3],
    "electric_motor": [6.0, 1, 0.12, 0.0],
    "electric_big": [6.0, 1, 0.12, 0.0],
    "engine_hybrid": [5.0, 0, 0.25, 0.0],
    "pedals": [3.0, 3, 0.0, 0.0],
}
ENGINE_LEVEL = -6.0
AI_ENGINE_LEVEL = -12.0
WIND_LEVEL = -11.0
WIND_LOW_LEVEL = -14.0
MUSIC_LEVEL = -6.0


def db(x):
    return 10.0 ** (x / 20.0)


def lerp(a, b, t):
    return a + (b - a) * t


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


class EngineSound:
    """A copy of scripts/audio/engine_sound.gd."""

    def __init__(self, engine, seed):
        self.r = np.random.default_rng(seed)
        self.span, self.gears, self.idle_level, self.slip = TYPES[engine]
        self.rev = 0.0
        self.load = 0.0
        self.gear = 0
        self.shift_left = 0.0
        self.detune = 1.0 + self.r.uniform(-0.04, 0.04)
        self.bias = self.r.uniform(-0.08, 0.08)
        self.high_db = self.r.uniform(-2.0, 2.0)
        self.off_db = self.r.uniform(-2.0, 2.0)
        self.shift_at = self.r.uniform(0.86, 0.94)
        self.rough = self.r.uniform(0.003, 0.012)
        self.pitch_walk = [0.0, 0.0, 0.0]
        self.level_walk = [0.0, 0.0, 0.0]
        self.rough_walk = [0.0, 0.0, 0.0]

    def wheel_rev(self, speed, g):
        top = ((g + 1) / self.gears) ** 0.7 * 1.08
        return (speed / top * self.span - 1.0) / (self.span - 1.0)

    def step(self, dt, speed, throttle, grounded, locked, boosting=False):
        speed = min(max(speed, 0.0), 1.2)
        if boosting:
            throttle = 1.0
        self.shift_left = max(self.shift_left - dt, 0.0)
        free = locked or not grounded
        if free:
            want = throttle * (0.75 if locked else 0.95)
        elif self.gears == 0:
            want = lerp(speed * 0.55, 0.3 + 0.5 * speed, throttle)
        else:
            g = self.gear
            if g < self.gears - 1 and (self.wheel_rev(speed, g) > self.shift_at and throttle > 0.3 or self.wheel_rev(speed, g) > 0.98):
                self.gear += 1
                if throttle > 0.3:
                    self.shift_left = 0.14 * self.r.uniform(0.8, 1.2)
            elif g > 0 and self.wheel_rev(speed, g) < 0.22:
                self.gear -= 1
            want = max(self.wheel_rev(speed, self.gear), self.slip * throttle)
        want = min(max(want, 0.0), 1.0)
        if want > self.rev:
            rate = 8.0 if free else 4.0 + 6.0 * throttle
        else:
            rate = 14.0 if self.shift_left > 0.0 else 3.0
        self.rev = lerp(self.rev, want, 1.0 - math.exp(-dt * rate))
        want_load = 0.15 * throttle if self.shift_left > 0.0 else throttle
        self.load = lerp(self.load, want_load, 1.0 - math.exp(-dt * (12.0 if want_load > self.load else 7.0)))
        self.walk(self.pitch_walk, dt, 0.4, 1.6)
        self.walk(self.level_walk, dt, 0.3, 1.2)
        self.walk(self.rough_walk, dt, 0.02, 0.07)

    def walk(self, w, dt, soonest, latest):
        w[2] -= dt
        if w[2] <= 0.0:
            w[1] = self.r.uniform(-1.0, 1.0)
            w[2] = self.r.uniform(soonest, latest)
        w[0] = lerp(w[0], w[1], 1.0 - math.exp(-dt * 2.5 / soonest))

    def pitch(self, at):
        wobble = 1.0 + 0.012 * self.pitch_walk[0] + self.rough * (1.0 - self.rev) * self.rough_walk[0]
        return self.detune * wobble * (1.0 + (self.span - 1.0) * self.rev) / (1.0 + (self.span - 1.0) * at)

    def levels(self):
        x = smoothstep(engines.LOW + 0.05 + self.bias, engines.HIGH - 0.05 + self.bias, self.rev) * math.pi * 0.5
        overrun = smoothstep(0.06, 0.3, self.rev)
        on_amount = self.load + (1.0 - self.load) * (1.0 - overrun) * self.idle_level
        on_db = lerp(-6.0, 0.0, self.load) + lerp(-4.0, 0.0, self.rev)
        off_amount = (1.0 - self.load) * overrun
        wander = db(1.5 * self.level_walk[0])
        on = on_amount * db(on_db) * wander
        return (on * math.cos(x), on * math.sin(x) * db(self.high_db), off_amount * db(-5.0 + 3.0 * self.rev + self.off_db) * wander)


def read_wav(path):
    with wave.open(path) as f:
        return np.frombuffer(f.readframes(f.getnframes()), "<i2") / 32768.0


class Voice:
    """One looping player: a pitch and a gain for every frame."""

    def __init__(self, samples, seed=0):
        self.samples = samples
        self.pos = np.random.default_rng(seed).uniform(0, len(samples))
        self.pitch = []
        self.gain = []

    def render(self):
        per = RATE // FPS
        pitch = np.repeat(np.asarray(self.pitch), per)
        gain = np.repeat(np.asarray(self.gain), per)
        # Smoothed a little, as the mixer ramps between frames.
        k = np.ones(per) / per
        pitch = np.convolve(pitch, k, "same")
        gain = np.convolve(gain, k, "same")
        pos = (self.pos + np.cumsum(pitch)) % len(self.samples)
        i = pos.astype(int)
        f = pos - i
        s = self.samples
        out = s[i] * (1 - f) + s[(i + 1) % len(s)] * f
        return out * gain


def lap(length=15.0, top=28.0, start=2.0, lift=(9.0, 10.6), brake=(9.3, 10.2)):
    """The run: speed in m/s, throttle and whether on the grid, per frame."""
    frames = int(length * FPS)
    v = 0.0
    out = []
    for n in range(frames):
        t = n / FPS
        locked = t < start
        throttle = 0.0
        if locked:
            # Two blips on the grid.
            for b in (0.7, 1.4):
                if b <= t < b + 0.25:
                    throttle = 1.0
        elif not (lift[0] <= t < lift[1]):
            throttle = 1.0
        braking = brake[0] <= t < brake[1]
        if not locked:
            a = throttle * 7.5 * (1 - (v / top) ** 2) - 0.8 - 0.4 * (v / top) ** 2
            if braking:
                a -= 13.0
            v = max(v + a / FPS, 0.0)
        out.append((v, throttle, locked))
    return out


def after_engine(engine, run, top, seed, base=ENGINE_LEVEL, distance=None):
    """Plays a run the new way: returns the three voices."""
    revs = EngineSound(engine, seed)
    loops = [read_wav(os.path.join(SOUND, "engine", "%s_%s.wav" % (engine, part))) for part in ("low", "high", "off")]
    voices = [Voice(s, seed * 3 + i) for i, s in enumerate(loops)]
    made_at = [engines.LOW, engines.HIGH, engines.OFF]
    for n, (v, throttle, locked) in enumerate(run):
        revs.step(1.0 / FPS, v / top, throttle, True, locked)
        gains = revs.levels()
        near = 1.0 if distance is None else distance[n]
        for i in range(3):
            g = gains[i] if gains[i] >= 0.01 else 0.0
            voices[i].pitch.append(min(max(revs.pitch(made_at[i]), 0.25), 3.0))
            voices[i].gain.append(db(base) * g * near)
    return sum(voice.render() for voice in voices)


def before_engine(folder, engine, run, top, seed=0, distance=None):
    """Plays a run the old way: one loop pitched with the speed."""
    voice = Voice(read_wav(os.path.join(folder, "engine", engine + ".wav")), seed)
    rev = 0.0
    for n, (v, throttle, locked) in enumerate(run):
        ratio = min(v / top, 1.0)
        want = throttle * 0.45 if locked else ratio * 0.85 + throttle * 0.15
        rev = lerp(rev, want, 1.0 - math.exp(-5.0 / FPS))
        voice.pitch.append(lerp(0.6, 1.9, rev))
        near = 1.0 if distance is None else distance[n]
        voice.gain.append(db(lerp(-9.0, 0.0, max(throttle, rev * 0.6))) * near)
    return voice.render()


def jet_after(run, top, seed=1):
    voice = Voice(read_wav(os.path.join(SOUND, "engine", "jet.wav")), seed)
    spool = 0.0
    for v, throttle, locked in run:
        spool = lerp(spool, throttle, 1.0 - math.exp(-(0.9 if throttle > spool else 1.4) / FPS))
        voice.pitch.append(lerp(0.7, 1.3, spool))
        voice.gain.append(db(ENGINE_LEVEL + 1.0) * lerp(0.2, 1.0, spool))
    return voice.render()


def jet_before(folder, run, top):
    voice = Voice(read_wav(os.path.join(folder, "engine", "jet.wav")), 1)
    rev = 0.0
    for v, throttle, locked in run:
        want = throttle * 0.45 if locked else min(v / top, 1.0) * 0.85 + throttle * 0.15
        rev = lerp(rev, want, 1.0 - math.exp(-5.0 / FPS))
        voice.pitch.append(lerp(0.8, 1.3, rev))
        voice.gain.append(db(lerp(-14.0, -2.0, throttle)))
    return voice.render()


def wind_after(speeds, seed=5, grounded=None):
    """The new wind at these speeds (m/s, per frame), with its gusts."""
    r = np.random.default_rng(seed)
    hiss = Voice(read_wav(os.path.join(SOUND, "loop", "wind.wav")), seed)
    low = Voice(read_wav(os.path.join(SOUND, "loop", "wind_low.wav")), seed + 1)
    gust = aim = wait = 0.0
    for n, speed in enumerate(speeds):
        wait -= 1.0 / FPS
        if wait <= 0.0:
            aim = r.random() ** 2
            wait = r.uniform(1.2, 5.0)
        gust = lerp(gust, aim, 1.0 - math.exp(-1.2 / FPS))
        fast = min(max((speed - 6.0) / 24.0, 0.0), 1.0)
        air = 1.0 if grounded is None or grounded[n] else 1.4
        amount = fast * fast * (0.7 + 0.5 * gust) * air
        hiss.gain.append(db(WIND_LEVEL) * amount if amount >= 0.02 else 0.0)
        hiss.pitch.append(0.85 + 0.3 * fast + 0.08 * gust)
        amount = fast * (0.6 + 0.6 * gust)
        low.gain.append(db(WIND_LOW_LEVEL) * amount if amount >= 0.02 else 0.0)
        low.pitch.append(0.9 + 0.2 * fast)
    return hiss.render() + low.render()


def wind_before(folder, speeds):
    voice = Voice(read_wav(os.path.join(folder, "loop", "wind.wav")), 5)
    for speed in speeds:
        gust = min(max((speed - 8.0) / 20.0, 0.0), 1.0)
        voice.gain.append(db(-10.0) * gust if gust >= 0.02 else 0.0)
        voice.pitch.append(1.0)
    return voice.render()


def stereo(left, right):
    n = min(len(left), len(right))
    return np.stack([left[:n], right[:n]])


def pan(x, where):
    """where -1 is hard left, 1 hard right."""
    a = (where + 1.0) * math.pi / 4.0
    return np.stack([x * math.cos(a), x * math.sin(a)])


def music(seconds):
    path = os.path.join(SOUND, "music", "race_one.ogg")
    import subprocess
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).reshape(-1, 2).T.astype(float)
    return x[:, :int(seconds * RATE)] * db(MUSIC_LEVEL)


def pack(make_engine, make_wind, run, top, seconds):
    """The player in the middle and five AI karts coming and going round it."""
    frames = len(run)
    t = np.arange(frames) / FPS
    out = pan(make_engine("engine_small", run, top, 11, True, np.full(frames, 5.0)), 0.0)
    out = out + pan(make_wind(), 0.0)
    pack_karts = [("engine_v8", 0.6, 8.0, 0.4), ("engine_twin", -0.5, 14.0, 1.3), ("engine_small", 0.3, 20.0, 2.1),
                  ("engine_diesel", -0.8, 26.0, 0.9), ("engine_big", 0.9, 11.0, 2.7)]
    for k, (engine, where, near, phase) in enumerate(pack_karts):
        distance = near + 6.0 * np.sin(t * 0.4 + phase) + 3.0
        # Each AI drives the same lap a moment behind.
        lag = int((0.2 + 0.25 * k) * FPS)
        late = [run[0]] * lag + run[:frames - lag]
        out = out + pan(make_engine(engine, late, top * (0.96 + 0.02 * k), 20 + k, False, distance), where)
    return out


# The boosts there are, and how many seconds each lasts.
BOOST_KINDS = [("drift_1", 0.6, 1), ("drift_2", 1.0, 2), ("tow_rope", 1.0, 1), ("drift_3", 1.5, 3),
               ("triple_turbo", 1.2, 3), ("turbo", 1.6, 2), ("big_turbo", 2.8, 3)]
WHOOSH_LEVEL = -13.0


def place(out, x, at, gain=1.0, pitch=1.0):
    """Adds a one shot at `at` seconds, sped up by `pitch`."""
    if pitch != 1.0:
        n = int(len(x) / pitch)
        x = np.interp(np.arange(n) * pitch, np.arange(len(x)), x)
    i = int(at * RATE)
    end = min(len(out), i + len(x))
    out[i:end] += x[:end - i] * gain


def fx(folder, name):
    return read_wav(os.path.join(folder, "fx", name + ".wav"))


def boosts_after(r=None):
    """Each boost three times in a row, the way KartSound plays them."""
    r = r or np.random.default_rng(77)
    out = np.zeros(RATE * 2 * 3 * len(BOOST_KINDS) + RATE * 3)
    at = 0.3
    for _, given, _level in BOOST_KINDS:
        size = min(max((given - 0.4) / 2.4, 0.0), 1.0)
        tier = 1 if size < 0.2 else (2 if size < 0.5 else 3)
        for _ in range(3):
            place(out, fx(SOUND, "boost_air_%d_%d" % (tier, r.integers(1, 4))), at,
                  db(WHOOSH_LEVEL + lerp(-2.0, 3.0, size) + r.uniform(-1.5, 1.5)), r.uniform(0.9, 1.12) * (1.05 - 0.1 * size))
            if size >= 0.2:
                place(out, fx(SOUND, "boost_roar_%d" % r.integers(1, 4)), at,
                      db(lerp(-15.0, -7.0, size) + r.uniform(-1.5, 1.5)), r.uniform(0.88, 1.1))
            if size >= 0.45:
                place(out, fx(SOUND, "boost_thump_%d" % r.integers(1, 3)), at,
                      db(lerp(-12.0, -6.0, size) + r.uniform(-1.0, 1.0)), r.uniform(0.9, 1.1))
            at += 1.6
        at += 0.8
    return out[:int((at + 1.0) * RATE)]


def boosts_before(folder):
    """The same, the old way: a whoosh for the level, and the turbo sound
    (quieter after a drift)."""
    out = np.zeros(RATE * 2 * 3 * len(BOOST_KINDS) + RATE * 3)
    at = 0.3
    for name, _given, level in BOOST_KINDS:
        for _ in range(3):
            place(out, fx(folder, "drift_whoosh_%d" % level), at, db(WHOOSH_LEVEL))
            if name.startswith("drift"):
                place(out, fx(folder, "turbo"), at, db(-8.0))
            elif name != "tow_rope":
                place(out, fx(folder, "turbo"), at, 1.0)
            at += 1.6
        at += 0.8
    return out[:int((at + 1.0) * RATE)]


def main():
    out_dir = sys.argv[1]
    before = sys.argv[2] if len(sys.argv) > 2 else None
    os.makedirs(out_dir, exist_ok=True)
    top = 28.0
    run = lap(top=top)

    def save(name, x):
        x = np.asarray(x)
        peak = np.max(np.abs(x))
        if peak > 0.98:
            x = x * (0.98 / peak)
        write_ogg(os.path.join(out_dir, name + ".ogg"), x, 6)
        print("made", name)

    for engine in TYPES:
        save("engine_%s_after" % engine.removeprefix("engine_"), after_engine(engine, run, top, 3))
        if before:
            save("engine_%s_before" % engine.removeprefix("engine_"), before_engine(before, engine, run, top))
    save("engine_jet_after", jet_after(run, top))
    if before:
        save("engine_jet_before", jet_before(before, run, top))

    # Two karts with the same engine, one in each ear, the right one a
    # moment behind.
    for engine in ("engine_v8", "engine_small", "engine_twin"):
        late = [run[0]] * 15 + run[:-15]
        save("same_%s_left_and_right" % engine.removeprefix("engine_"),
             stereo(after_engine(engine, run, top, 41), after_engine(engine, late, top * 0.98, 42)))

    # The wind standing, then at 12, 20 and 30 m/s, 4 s each.
    steps = [0.0, 12.0, 20.0, 30.0]
    speeds = np.repeat(steps, 4 * FPS)
    speeds = np.convolve(speeds, np.ones(FPS) / FPS, "same")
    save("wind_after", wind_after(speeds))
    if before:
        save("wind_before", wind_before(before, speeds))

    # Every kind of boost, small to big, three of each.
    save("boosts_after", boosts_after())
    if before:
        save("boosts_before", boosts_before(before))

    # The pack, with the music under it.
    speeds = [v for v, _, _ in run]
    tune = music(len(run) / FPS)

    # Godot's inverse distance fall off, at most 3 dB up close.
    def near(distance, unit):
        return np.minimum(unit / distance, db(3.0))

    def mix_after(engine, r, t, seed, person, distance):
        unit = 6.0 if person else 4.0
        return after_engine(engine, r, t, seed, ENGINE_LEVEL if person else AI_ENGINE_LEVEL, near(distance, unit))

    def mix_before(engine, r, t, seed, person, distance):
        return before_engine(before, engine, r, t, seed, near(distance, 6.0))

    mix = pack(mix_after, lambda: wind_after(speeds), run, top, len(run) / FPS)
    n = min(mix.shape[1], tune.shape[1])
    save("pack_after", mix[:, :n] + tune[:, :n])
    if before:
        mix = pack(mix_before, lambda: wind_before(before, speeds), run, top, len(run) / FPS)
        save("pack_before", mix[:, :n] + tune[:, :n])


if __name__ == "__main__":
    main()
