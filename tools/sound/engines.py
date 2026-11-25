"""SnapRacers' engines, made from scratch with synth.py.

Each engine has three loops, which the game (scripts/audio/engine_sound.gd)
fades between:
  - low: on the throttle at low revs
  - high: on the throttle near the top
  - off: off the throttle at middling revs, the burble, pops or whine of an
    engine being pushed along by the kart

Each loop is made at the revs it stands for, with the exhaust ringing at the
same notes in all three, so the low loop sounds deep and loose and the high
one tight and screaming, instead of one loop sped up like a tape.

An engine is a train of firing pulses, one for each time a cylinder fires,
each ringing the exhaust like a bell. No two firings are quite the same
strength or quite on time, and some engines miss or pop off the throttle.

TYPES holds, for each engine, how many times its firing pattern comes round
a second at idle and how many times higher that is at the top. The game has
the same numbers in EngineSound.TYPES and both use the revs below (0 is
idle, 1 the top) that each loop is made at.
"""

import numpy as np

from synth import RATE, circular_convolve, circular_filter, decay, drive, noise, resonator, rng, seconds

LOW = 0.15
OFF = 0.45
HIGH = 0.75
LENGTH = 1.6

# name: (pattern Hz at idle, top as a multiple of idle)
TYPES = {
    "engine_small": (40.0, 5.0),
    "engine_micro": (22.0, 2.6),
    "engine_big": (30.0, 5.0),
    "engine_twin": (9.0, 5.5),
    "engine_diesel": (26.0, 3.2),
    "engine_v8": (7.0, 5.0),
    "engine_rotary": (22.0, 5.5),
    "engine_flat4": (7.5, 5.0),
    "electric_motor": (90.0, 6.0),
    "electric_big": (55.0, 6.0),
    "engine_hybrid": (12.0, 5.0),
    "pedals": (14.0, 3.0),
}


def hz_at(name, rev):
    idle, span = TYPES[name]
    return idle * (1.0 + (span - 1.0) * rev)


def level(x, rms=0.22, peak=0.95):
    """Scales a loop to an even loudness, so the engines match each other."""
    r = np.sqrt(np.mean(x ** 2))
    if r <= 0.0:
        return x
    return x * min(rms / r, peak / np.max(np.abs(x)))


def loop_wobble(total, seed, rate, depth):
    """Slow random flutter that wraps round: noise smoothed below `rate` Hz."""
    w = circular_filter(noise(total, seed), high=rate)
    return 1.0 + depth * w / max(np.max(np.abs(w)), 1e-9)


def _cycles(hz, length):
    count = max(1, int(round(length * hz)))
    return count, int(round(count * RATE / hz))


def firing(seed, hz, firings, body, load, rasp=0.3, grit=2.0, bright=4000.0, jitter=1.5,
           misfire=0.0, pops=0.0, knock=0.0, whistle=0.0, length=LENGTH):
    """A loop of an engine firing `hz` times round its pattern a second.

    firings: (when in the pattern, 0 to 1, how hard, which exhaust) each.
    body: for each exhaust, a list of (Hz, seconds to ring, loudness).
    load: 1 on the throttle, 0 off it.
    jitter: how far off time a firing can be, as a percent of the pattern.
    misfire: the chance a firing comes out weak.
    pops: crackles a second from the exhaust.
    knock: a diesel's clatter on each firing.
    whistle: a turbo's whine, in Hz (0 for none).
    """
    r = rng(seed)
    cycles, total = _cycles(hz, length)
    period = RATE / hz
    out = np.zeros(total)
    puff_all = np.zeros(total)
    roughness = loop_wobble(total, seed + 9, 4.0, 0.18)
    for bank, resonances in enumerate(body):
        pulses = np.zeros(total)
        for c in range(cycles):
            for when, strength, which in firings:
                if which != bank:
                    continue
                at = (c + when) * period + r.normal(0.0, jitter * 0.01 * period)
                amp = strength * r.uniform(0.8, 1.0) * (0.45 + 0.55 * load)
                if r.random() < misfire:
                    amp *= r.uniform(0.05, 0.35)
                i = int(np.floor(at))
                frac = at - i
                pulses[i % total] += amp * (1.0 - frac)
                pulses[(i + 1) % total] += amp * frac
        pulses *= roughness
        n = seconds(0.15)
        kernel = np.zeros(n)
        for freq, ring, loud in resonances:
            kernel += resonator(freq * r.uniform(0.985, 1.015), ring * (1.0 + 0.4 * (1.0 - load)), n) * loud
        kernel += circular_filter(noise(n, seed + 1 + bank), low=250.0, high=2500.0 + 2500.0 * load) * decay(n, 0.006) * (0.3 + 0.4 * load)
        out += circular_convolve(pulses, kernel)
        puff_all += circular_convolve(pulses, decay(seconds(0.03), 0.025))

    out /= max(np.max(np.abs(out)), 1e-9)
    hiss = circular_filter(noise(total, seed + 2), low=200.0, high=bright * 1.3)
    out += hiss * puff_all / max(np.max(puff_all), 1e-9) * rasp * (0.35 + 0.65 * load)

    if knock:
        clatter = circular_filter(noise(total, seed + 3), low=2200.0, high=6000.0)
        cycles_pulses = np.zeros(total)
        for c in range(cycles):
            for when, strength, _ in firings:
                cycles_pulses[int((c + when) * period) % total] += strength * r.uniform(0.6, 1.0)
        tick = circular_convolve(cycles_pulses, decay(seconds(0.008), 0.007))
        out += clatter * tick * knock * (0.6 + 0.4 * load) * 1.5

    if pops:
        cracks = np.zeros(total)
        for _ in range(int(pops * total / RATE)):
            cracks[r.integers(0, total)] += r.uniform(0.3, 1.0) * (1.0 if r.random() < 0.7 else 2.0)
        n = seconds(0.04)
        crack = circular_filter(noise(n, seed + 4), low=400.0, high=5000.0) * decay(n, 0.012)
        crack += resonator(r.uniform(90, 140), 0.03, n) * 0.8
        out += circular_convolve(cracks, crack) * 0.9

    out = drive(out / max(np.max(np.abs(out)), 1e-9), grit * (0.55 + 0.45 * load))
    out = circular_filter(out, low=35.0, high=bright * (0.45 + 0.55 * load))

    if whistle:
        # A whole number of turns over the loop, so it wraps.
        f = round(whistle * total / RATE) * RATE / total
        t = np.arange(total) / RATE
        tone = np.sin(2 * np.pi * f * t) * loop_wobble(total, seed + 5, 3.0, 0.3)
        out += tone * 0.06 * load
    return level(out)


def motor(seed, f0, load, gear=2.7, hum=0.2, regen=False, length=LENGTH):
    """An electric motor's whine: the motor, its gears and a little air."""
    total = seconds(length)

    def tone(freq, loud):
        f = max(1, round(freq * total / RATE)) * RATE / total
        return np.sin(2 * np.pi * f * np.arange(total) / RATE) * loud

    if regen:
        # Pushed along it whines hollower and softer.
        out = tone(f0, 1.0) + tone(f0 * 3, 0.35) + tone(f0 * 5, 0.12) + tone(f0 * gear, 0.25)
    else:
        out = tone(f0, 1.0) + tone(f0 * 2, 0.5 * load + 0.1) + tone(f0 * 3, 0.25) + tone(f0 * 4, 0.15 * load)
        out += tone(f0 * gear, 0.4 * load + 0.1) + tone(f0 * gear * 2, 0.12 * load)
    out += tone(f0 / 4, hum)
    out *= loop_wobble(total, seed, 6.0, 0.12)
    whir = circular_filter(noise(total, seed + 1), low=f0 * 1.5, high=f0 * 9.0)
    out /= np.max(np.abs(out))
    out += whir / np.max(np.abs(whir)) * (0.25 + 0.2 * load)
    return level(circular_filter(out, low=50.0, high=7000.0), rms=0.18)


# The cross plane V8's firing order 1 8 4 3 6 5 7 2, a firing every 90
# degrees, with the odd cylinders on one bank's exhaust and the even on the
# other. Each bank gets an uneven beat, and that's the burble.
_V8 = [(i / 8.0, 1.0 if c in (1, 6) else 0.85, c % 2) for i, c in enumerate([1, 8, 4, 3, 6, 5, 7, 2])]
_V8_BANK = [(72, 0.06, 1.0), (160, 0.035, 0.7), (330, 0.015, 0.4), (720, 0.006, 0.2)]


def _engine(name, rev, load, seed, **kw):
    return firing(seed, hz_at(name, rev), **kw, load=load)


def small(rev, load, seed):
    # A kart's two stroke single: nasal and ringing, missing and popping off
    # the throttle.
    return _engine("engine_small", rev, load, seed, firings=[(0.0, 1.0, 0)],
                   body=[[(650, 0.012, 1.0), (1400, 0.006, 0.6), (300, 0.02, 0.5)]],
                   rasp=0.6, grit=3.0, bright=7000, jitter=3.0,
                   misfire=0.35 * (1 - load), pops=3.0 * (1 - load))


def micro(rev, load, seed):
    # A lawnmower: a chuggy thump and a valve tick.
    return _engine("engine_micro", rev, load, seed, firings=[(0.0, 1.0, 0)],
                   body=[[(180, 0.035, 1.0), (420, 0.02, 0.6), (950, 0.008, 0.3)]],
                   rasp=0.45, grit=3.5, bright=4500, jitter=4.0, knock=0.3,
                   misfire=0.25 * (1 - load), pops=1.5 * (1 - load))


def big(rev, load, seed):
    # A smooth four, firing twice a turn, with a hum from the intake.
    return _engine("engine_big", rev, load, seed, firings=[(0.0, 1.0, 0), (0.5, 0.95, 0)],
                   body=[[(220, 0.03, 1.0), (560, 0.015, 0.5), (1250, 0.006, 0.25)]],
                   rasp=0.25, grit=2.0, bright=4500, jitter=1.2, misfire=0.03 * (1 - load))


def twin(rev, load, seed):
    # A V twin: two firings close together, then a gap.
    return _engine("engine_twin", rev, load, seed, firings=[(0.0, 1.0, 0), (0.4375, 0.9, 0)],
                   body=[[(95, 0.06, 1.0), (230, 0.03, 0.6), (620, 0.01, 0.3)]],
                   rasp=0.4, grit=3.0, bright=3800, jitter=2.5, misfire=0.08 * (1 - load),
                   pops=2.0 * (1 - load))


def diesel(rev, load, seed):
    # Low and clattering, with a turbo whistling on the throttle.
    return _engine("engine_diesel", rev, load, seed, firings=[(0.0, 1.0, 0), (0.5, 0.92, 0)],
                   body=[[(85, 0.05, 1.0), (200, 0.03, 0.6), (450, 0.01, 0.2)]],
                   rasp=0.2, grit=2.0, bright=5500, jitter=2.0, knock=1.0,
                   whistle=2200 + 2600 * rev)


def v8(rev, load, seed):
    return _engine("engine_v8", rev, load, seed, firings=_V8,
                   body=[_V8_BANK, [(f * 1.07, ring, loud) for f, ring, loud in _V8_BANK]],
                   rasp=0.3, grit=2.6, bright=3200, jitter=1.5, misfire=0.05 * (1 - load),
                   pops=4.0 * (1 - load))


def rotary(rev, load, seed):
    # A rotary: smooth and buzzy, lumpy low down and crackling off the
    # throttle.
    rough = 1.0 - rev
    return _engine("engine_rotary", rev, load, seed, firings=[(0.0, 1.0, 0), (0.5, 1.0, 0)],
                   body=[[(260, 0.02, 1.0), (620, 0.012, 0.6), (1500, 0.005, 0.35)]],
                   rasp=0.35, grit=2.2, bright=6500, jitter=1.0 + 4.0 * rough,
                   misfire=0.15 * rough, pops=5.0 * (1 - load))


def flat4(rev, load, seed):
    # A boxer's uneven exhaust, a rumble on the offbeat.
    return _engine("engine_flat4", rev, load, seed,
                   firings=[(0.0, 1.0, 0), (0.27, 0.7, 0), (0.5, 0.95, 0), (0.77, 0.75, 0)],
                   body=[[(95, 0.05, 1.0), (210, 0.03, 0.6), (470, 0.01, 0.25)]],
                   rasp=0.3, grit=2.4, bright=3300, jitter=1.8, pops=1.5 * (1 - load))


def electric(rev, load, seed):
    return motor(seed, hz_at("electric_motor", rev), load, gear=2.7, hum=0.15, regen=load < 0.5)


def electric_big(rev, load, seed):
    return motor(seed, hz_at("electric_big", rev), load, gear=3.3, hum=0.4, regen=load < 0.5)


def hybrid(rev, load, seed):
    # A three cylinder (three firings every two turns) with a motor whining
    # over it. Low down it's mostly the motor.
    hz = hz_at("engine_hybrid", rev)
    if load < 0.5:
        return level(motor(seed + 50, hz * 8.0, load, gear=2.2, hum=0.0, regen=True))
    body = firing(seed, hz, [(0.0, 1.0, 0), (1 / 3, 0.95, 0), (2 / 3, 0.97, 0)],
                  [[(180, 0.03, 1.0), (420, 0.015, 0.5), (1000, 0.006, 0.2)]], load,
                  rasp=0.3, grit=2.0, bright=4200, jitter=1.5)
    whine = motor(seed + 50, hz * 8.0, load, gear=2.2, hum=0.0, length=len(body) / RATE)
    engine_part = 0.25 + 0.75 * rev
    return level(body * engine_part + whine * (1.2 - engine_part))


def pedals(rev, load, seed):
    """Pedalling: the chain whirring and the cranks ticking. Off the pedals
    it's the freewheel clicking."""
    hz = hz_at("pedals", rev)
    total = seconds(LENGTH)
    r = rng(seed)
    if load < 0.5:
        ticks = np.zeros(total)
        count = int(round(hz * LENGTH))
        for k in range(count):
            ticks[int(k * total / count + r.normal(0, 8)) % total] += r.uniform(0.6, 1.0)
        n = seconds(0.01)
        click = resonator(3200, 0.003, n) + resonator(5100, 0.002, n) * 0.5
        out = circular_convolve(ticks, click)
        out += circular_filter(noise(total, seed + 1), low=1500.0, high=6000.0) * 0.04
        return level(out, rms=0.08)
    whir = circular_filter(noise(total, seed + 2), low=900.0, high=4000.0)
    links = int(round(hz * 2.5 * LENGTH))
    t = np.arange(total) / total
    chain = (0.55 + 0.45 * np.sin(2 * np.pi * links * t)) * whir
    ticks = np.zeros(total)
    strokes = int(round(hz / 6.0 * LENGTH)) * 2
    for k in range(max(strokes, 2)):
        ticks[int(k * total / max(strokes, 2)) % total] += r.uniform(0.5, 1.0)
    n = seconds(0.02)
    thunk = resonator(900, 0.006, n) + resonator(2300, 0.003, n) * 0.4
    out = chain / np.max(np.abs(chain)) * 0.6 + circular_convolve(ticks, thunk)
    return level(out, rms=0.1)


def jet(seed=81):
    """A roar with a turbine whining over it. The game spools it up and down."""
    total = seconds(3.0)
    roar = circular_filter(noise(total, seed), low=60.0, high=2500.0, tilt=-3.0)
    body = circular_filter(noise(total, seed + 1), low=250.0, high=900.0)
    flicker = loop_wobble(total, seed + 2, 5.0, 0.18)

    def tone(freq, loud):
        f = round(freq * total / RATE) * RATE / total
        return np.sin(2 * np.pi * f * np.arange(total) / RATE) * loud

    whine = (tone(2400, 0.1) + tone(3650, 0.05) + tone(4800, 0.03)) * loop_wobble(total, seed + 3, 2.0, 0.3)
    out = (roar / np.max(np.abs(roar)) * 0.8 + body / np.max(np.abs(body)) * 0.5) * flicker + whine
    return level(out, rms=0.2)


MAKERS = {
    "engine_small": small,
    "engine_micro": micro,
    "engine_big": big,
    "engine_twin": twin,
    "engine_diesel": diesel,
    "engine_v8": v8,
    "engine_rotary": rotary,
    "engine_flat4": flat4,
    "electric_motor": electric,
    "electric_big": electric_big,
    "engine_hybrid": hybrid,
    "pedals": pedals,
}


def make_all():
    """Every engine loop: "engine/<name>_low" and so on to samples."""
    out = {}
    for k, (name, make) in enumerate(MAKERS.items()):
        seed = 1000 + k * 10
        out["engine/%s_low" % name] = make(LOW, 1.0, seed)
        out["engine/%s_high" % name] = make(HIGH, 1.0, seed + 3)
        out["engine/%s_off" % name] = make(OFF, 0.0, seed + 6)
    out["engine/jet"] = jet()
    return out
