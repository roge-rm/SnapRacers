#!/usr/bin/env python3
"""Plays the drift sounds the way the game would, into demo clips to listen to.

  uv run --with numpy --with scipy tools/sound/drift_demo.py OUT_DIR

Each tire clip is two drifts, each with its own small pitch and texture
change, faded between the soft and hard loops by how hard it slips. The
levels are the ones the game would use, in dB.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

import effects  # noqa: E402
from synth import RATE, mix, rng, seconds, write_wav  # noqa: E402

TIRE_DB = -10.0
WHOOSH_DB = -8.0
ENGINE_DB = -12.0
# When a drift reaches each boost level, in seconds held.
LEVEL_AT = [0.6, 1.3, 2.1]


def db(x):
    return 10.0 ** (x / 20.0)


def play(loop, pitch, start=0.0):
    """Plays a loop at a changing pitch (one value a sample), from `start`
    seconds in, the way AudioStreamPlayer's pitch_scale does."""
    at = start * RATE + np.cumsum(pitch)
    return np.interp(at % len(loop), np.arange(len(loop)), loop, period=len(loop))


def envelope(n, points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return np.interp(np.arange(n) / RATE, xs, ys)


def one_drift(surface, slip_points, length, seed):
    """One drift: the slip (0 gentle to 1 hard) over time drives the fade
    between the loops, the loudness and a little pitch."""
    r = rng(seed)
    n = seconds(length)
    slip = envelope(n, slip_points)
    pitch = r.uniform(0.95, 1.05) * (0.92 + 0.16 * slip)
    soft = play(effects.DRIFTS[surface](False), pitch, r.uniform(0.0, 2.0))
    hard = play(effects.DRIFTS[surface](True), pitch, r.uniform(0.0, 2.0))
    # Fades in over 0.15 s and out over 0.3 s, louder the harder it slips.
    loud = np.clip(np.arange(n) / seconds(0.15), 0.0, 1.0) * np.clip((n - np.arange(n)) / seconds(0.3), 0.0, 1.0)
    level = loud * (0.45 + 0.55 * slip)
    return (soft * (1.0 - slip) + hard * slip) * level * db(TIRE_DB)


def tire_clip(surface, hard, seed):
    if hard:
        a = [(0.0, 0.6), (0.4, 1.0), (2.0, 0.9), (2.6, 0.7)]
        b = [(0.0, 0.7), (0.3, 1.0), (1.8, 1.0), (2.2, 0.8)]
    else:
        a = [(0.0, 0.1), (1.0, 0.3), (2.2, 0.2)]
        b = [(0.0, 0.2), (0.8, 0.25), (1.8, 0.15)]
    return mix((one_drift(surface, a, 2.6, seed), 0.1), (one_drift(surface, b, 2.2, seed + 1), 3.2))


def full_drift(surface, held, seed):
    """A whole drift held `held` s: engine, tires, then the release."""
    level = sum(1 for at in LEVEL_AT if at <= held)
    length = held + 1.4
    engine = list(effects.ENGINES.values())[0]()
    n = seconds(length)
    eng = play(engine, np.full(n, 1.6)) * db(ENGINE_DB)
    tires = one_drift(surface, [(0.0, 0.7), (0.3, 1.0), (held, 0.9)], held + 0.3, seed)
    parts = [(eng, 0.0), (tires, 0.2)]
    if level:
        parts.append((effects.boost_air(level, 2) * db(WHOOSH_DB), 0.2 + held))
    out = mix(*parts)
    return out[:n] * np.clip((n - np.arange(n)) / seconds(0.3), 0.0, 1.0)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    clips = {}
    for i, surface in enumerate(effects.DRIFTS):
        clips[surface + "-gentle"] = tire_clip(surface, False, 10 * i)
        clips[surface + "-hard"] = tire_clip(surface, True, 10 * i + 5)
    for level in (1, 2, 3):
        clips["whoosh-%d" % level] = effects.boost_air(level, 2) * db(WHOOSH_DB)
    clips["full-tarmac-purple"] = full_drift("tarmac", 2.4, 41)
    clips["full-dirt-orange"] = full_drift("dirt", 1.5, 42)
    clips["full-snow-blue"] = full_drift("snow", 0.8, 43)
    old = effects.skid()
    clips["old-skid"] = mix((play(old, np.ones(seconds(2.6))) * db(-6.0) * np.clip(np.arange(seconds(2.6)) / seconds(0.1), 0, 1), 0.1))
    for name, samples in clips.items():
        write_wav(os.path.join(out, name + ".wav"), np.clip(samples, -1.0, 1.0))
        print("made", name, "peak %.2f" % np.max(np.abs(samples)))


if __name__ == "__main__":
    main()
