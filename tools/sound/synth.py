"""The building blocks every sound and tune in SnapRacers is made from.

Everything is numpy arrays of samples at RATE, between -1 and 1. Noise comes
from a random generator with a fixed seed, so the same sounds come out every
time the tools are run.

Loops (engines, tire squeal and so on) are made "around the circle": their
noise is filtered with an FFT that wraps from the end back to the start, so
they loop without a click.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

RATE = 32000


def rng(seed):
    return np.random.default_rng(seed)


def seconds(n):
    return int(round(n * RATE))


def times(length):
    return np.arange(length) / RATE


# Oscillators. Phase is in cycles, so a changing pitch is a running sum.

def phase_of(freq, length):
    freq = np.broadcast_to(np.asarray(freq, dtype=float), (length,))
    return np.cumsum(freq) / RATE


def sine(freq, length, phase=0.0):
    return np.sin(2 * np.pi * (phase_of(freq, length) + phase))


def saw(freq, length, harmonics=None):
    """A band limited saw, added up from its harmonics so it doesn't alias."""
    p = phase_of(freq, length)
    top = float(np.max(np.broadcast_to(freq, (length,))))
    count = harmonics or max(1, int(RATE * 0.45 / max(top, 1.0)))
    out = np.zeros(length)
    for k in range(1, count + 1):
        out += np.sin(2 * np.pi * k * p) / k
    return out * 0.6


def square(freq, length, width=0.5, harmonics=None):
    """A band limited pulse wave, made from two saws."""
    p = phase_of(freq, length)
    top = float(np.max(np.broadcast_to(freq, (length,))))
    count = harmonics or max(1, int(RATE * 0.45 / max(top, 1.0)))
    out = np.zeros(length)
    for k in range(1, count + 1):
        out += (np.sin(2 * np.pi * k * p) - np.sin(2 * np.pi * k * (p - width))) / k
    return out * 0.5


def triangle(freq, length):
    p = phase_of(freq, length)
    return 2.0 * np.abs(2.0 * (p - np.floor(p + 0.5))) - 1.0


def noise(length, seed):
    return rng(seed).uniform(-1.0, 1.0, length)


# Envelopes.

def decay(length, time):
    """Falls away to about a thousandth over `time` seconds."""
    return np.exp(-times(length) * 6.9 / max(time, 1e-4))


def adsr(length, attack, dec, sustain, release):
    out = np.full(length, sustain, dtype=float)
    a = min(seconds(attack), length)
    d = min(seconds(dec), length - a)
    r = min(seconds(release), length)
    if a:
        out[:a] = np.linspace(0.0, 1.0, a, endpoint=False)
    if d:
        out[a:a + d] = np.linspace(1.0, sustain, d, endpoint=False)
    if r:
        out[length - r:] *= np.linspace(1.0, 0.0, r)
    return out


def ramp(length, points):
    """A line through (fraction of the way, value) points."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return np.interp(np.linspace(0.0, 1.0, length), xs, ys)


# Filters.

def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, min(cutoff, RATE * 0.49), "low", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, max(cutoff, 1.0), "high", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def bandpass(x, low, high, order=2):
    sos = signal.butter(order, [max(low, 1.0), min(high, RATE * 0.49)], "band", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def sweep_lowpass(x, cutoffs):
    """A simple one pole low pass whose cutoff moves, sample by sample."""
    cutoffs = np.broadcast_to(np.asarray(cutoffs, dtype=float), x.shape)
    k = 1.0 - np.exp(-2.0 * np.pi * cutoffs / RATE)
    out = np.empty_like(x)
    y = 0.0
    for i in range(len(x)):
        y += k[i] * (x[i] - y)
        out[i] = y
    return out


def circular_filter(x, low=0.0, high=None, tilt=0.0):
    """Filters a loop in the frequency domain, so the end still meets the
    start. `tilt` is dB per octave above 100 Hz, for darker or brighter noise."""
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    gain = np.ones_like(freqs)
    if low > 0.0:
        gain *= 1.0 / np.sqrt(1.0 + (low / np.maximum(freqs, 1e-3)) ** 4)
    if high is not None:
        gain *= 1.0 / np.sqrt(1.0 + (freqs / high) ** 4)
    if tilt:
        octaves = np.log2(np.maximum(freqs, 1.0) / 100.0)
        gain *= 10.0 ** (tilt * np.maximum(octaves, 0.0) / 20.0)
    return np.fft.irfft(spectrum * gain, len(x))


def circular_convolve(x, kernel):
    """Convolves a loop with a kernel, wrapping around the end."""
    padded = np.zeros(len(x))
    n = min(len(kernel), len(x))
    padded[:n] = kernel[:n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(padded), len(x))


def resonator(freq, time, length):
    """A struck resonance: a sine that dies away."""
    return sine(freq, length) * decay(length, time)


# Effects.

def drive(x, amount):
    """Soft clipping, for grit."""
    return np.tanh(x * amount) / np.tanh(amount)


def reverb(x, wet=0.2, size=1.0, seed=0):
    """A small Schroeder reverb: combs into all passes."""
    out = np.zeros(len(x))
    for delay, gain in [(1557, 0.8), (1617, 0.79), (1491, 0.8), (1422, 0.78), (1277, 0.77), (1356, 0.79)]:
        d = int(delay * size * RATE / 44100)
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -gain * min(size, 1.0)
        out += signal.lfilter([1.0], a, x)
    out /= 6.0
    for delay in [225, 556, 441, 341]:
        d = int(delay * RATE / 44100)
        b = np.zeros(d + 1)
        a = np.zeros(d + 1)
        b[0], b[d] = -0.5, 1.0
        a[0], a[d] = 1.0, -0.5
        out = signal.lfilter(b, a, out)
    out = lowpass(out, 6000)
    return x * (1.0 - wet) + out * wet


def mix(*parts):
    """Adds sounds together, starting each at a time: (sound, seconds)."""
    end = max(seconds(at) + len(s) for s, at in parts)
    out = np.zeros(end)
    for s, at in parts:
        start = seconds(at)
        out[start:start + len(s)] += s
    return out


def fade(x, fade_in=0.0, fade_out=0.005):
    x = x.copy()
    a = min(seconds(fade_in), len(x))
    b = min(seconds(fade_out), len(x))
    if a:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b:
        x[len(x) - b:] *= np.linspace(1.0, 0.0, b)
    return x


def normalise(x, peak=0.9):
    top = np.max(np.abs(x))
    return x * (peak / top) if top > 0 else x


def trim(x, floor=0.0005):
    """Cuts the silent tail off a one shot."""
    loud = np.nonzero(np.abs(x) > floor)[0]
    return x[: loud[-1] + 1] if len(loud) else x


# Notes.

NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note_freq(name):
    """A note like "C4", "F#3" or "Bb5" to Hz. A4 is 440."""
    letter = name[0]
    rest = name[1:]
    shift = 0
    while rest and rest[0] in "#b":
        shift += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + NAMES[letter] + shift
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# Files.

def write_wav(path, x, loop=False):
    """Writes 16 bit mono or stereo (a (2, n) array) PCM."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.asarray(x)
    if data.ndim == 2:
        data = data.T.reshape(-1)
        channels = 2
    else:
        channels = 1
    pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as f:
        f.setnchannels(channels)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())


def write_ogg(path, x, quality=2):
    """Writes Ogg Vorbis, by way of ffmpeg."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "out.wav")
        write_wav(raw, x)
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", raw, "-c:a", "libvorbis", "-q:a", str(quality), path],
            check=True,
        )
