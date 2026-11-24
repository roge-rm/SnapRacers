#!/usr/bin/env python3
"""Builds the stock karts, bikes and trikes in data/karts/stock, one JSON
file each.

They're written out part by part here instead of by hand in the JSON, because
most parts come in pairs, one on each side. `pair()` puts a part down and its
mirror image across the middle of the kart, the same way Mirror does in the
garage.

The build area is 20 studs across, 30 plates high and 24 studs long, and the
kart faces toward -Z (the low end of the third number). A position is the
front left bottom corner of the part's box once it's turned, in studs,
plates and studs. They can be part way, like 2.5 plates up, since the parts
join by their connectors and not only on the grid. `fine()` takes the fine
unit instead (a stud is 20 and a plate 8), for bikes. Rot is quarter turns
clockwise seen from above.

New wheels go on by their hub, so a wheel's middle has to be level with a
spot it clips onto. A chassis plate 2.5 plates up takes wheels 3 plates
across (like w_kart) right on its sides.

Run it from anywhere, then check them with:
  tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/report.gd
"""

import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
PARTS = json.load(open(os.path.join(ROOT, "data", "parts.json")))["parts"]
PARTS.update(json.load(open(os.path.join(ROOT, "data", "parts_made.json")))["parts"])
OUT = os.path.join(ROOT, "data", "karts", "stock")
STUD = 20
PLATE = 8
WIDTH = 20 * STUD


def fine_size(part):
    p = PARTS[part]
    if "fine_size" in p:
        return tuple(p["fine_size"])
    s = p["size"]
    return (s[0] * STUD, s[1] * PLATE, s[2] * STUD)


def turned_size(part, rot):
    s = fine_size(part)
    return (s[2], s[1], s[0]) if rot % 2 else s


def origin(part, at, rot):
    """Where the part's own origin goes for the corner of its turned box to
    be at `at`, all in the fine unit."""
    sx, sy, sz = fine_size(part)
    x, y, z = at
    return {0: (x, y, z), 1: (x + sz, y, z), 2: (x + sx, y, z + sz), 3: (x, y, z + sx)}[rot % 4]


def new_wheel(part):
    return PARTS[part]["kind"] == "wheel" and "connectors" in PARTS[part]


class Kart:
    def __init__(self, key, name, about):
        self.key = key
        self.name = name
        self.about = about
        self.parts = []

    def fine(self, part, x, y, z, rot=0, colour=None):
        """Puts a part down with its corner here, in the fine unit."""
        pos = [round(v, 2) for v in origin(part, (x, y, z), rot)]
        entry = {"id": part, "pos": pos, "turn": rot % 4}
        if colour:
            entry["color"] = colour
        self.parts.append(entry)
        return self

    def add(self, part, x, y, z, rot=0, colour=None):
        """Puts a part down with its corner here, in studs, plates and studs."""
        return self.fine(part, x * STUD, y * PLATE, z * STUD, rot, colour)

    def pair_fine(self, part, x, y, z, rot=0, colour=None):
        self.fine(part, x, y, z, rot, colour)
        # A new wheel's twin is turned right round, so its hub faces in.
        twin_rot = (rot + 2) % 4 if new_wheel(part) else (4 - rot) % 4
        twin = PARTS[part].get("mirror", part)
        sx = turned_size(twin, twin_rot)[0]
        return self.fine(twin, WIDTH - x - sx, y, z, twin_rot, colour)

    def pair(self, part, x, y, z, rot=0, colour=None):
        """Puts a part down on the left and its mirror image on the right."""
        return self.pair_fine(part, x * STUD, y * PLATE, z * STUD, rot, colour)

    def save(self):
        lines = ",\n".join("\t\t" + json.dumps(p) for p in self.parts)
        text = '{\n\t"name": %s,\n\t"about": %s,\n\t"parts": [\n%s\n\t]\n}\n' % (json.dumps(self.name), json.dumps(self.about, ensure_ascii=False), lines)
        with open(os.path.join(OUT, self.key + ".json"), "w") as f:
            f.write(text)


karts = []


def kart(key, name, about):
    k = Kart(key, name, about)
    karts.append(k)
    return k


RED = "#c4281c"
BLUE = "#0d69ab"
YELLOW = "#f2cd37"
WHITE = "#f2f3f2"
BLACK = "#1b2a34"
DARK = "#1b1b1b"
GREY = "#635f61"
SILVER = "#a3a2a4"
ORANGE = "#da8540"
TEAL = "#36aebf"
LIME = "#a4bd46"
PURPLE = "#6b3fa0"
KART_GREEN = "#4b9f4a"


def radius(wheel):
    return fine_size(wheel)[1] / 2


def racer(k, front, back, z0, length, colour=DARK, arches=2, width=6, rims=None):
    """The racers' black chassis: an axle plate at the front and back with
    the wheels on their pins out at the corners, and plates `width` wide (6,
    or 4 for a slim formula car) along the top. When the back wheels are
    bigger, plates on the front axle plate bring it level. Arches mount by
    their end cells, so `arches` (2 or 3, how wide they are) puts plates out
    beside the chassis under both ends of an arch 6 long centred on each
    wheel: one under the chassis reaching out, and one on it at chassis
    level. 0 leaves them off, for open wheels. When two plates along the top
    meet between two arches, the arch plates behind the front wheels reach a
    row further, under the seam (and do for the back arch too when the
    arches touch). Returns the top of the chassis, in plates. `rims` paints
    the wheels' rims."""
    assert width in (4, 6) and arches in (0, 2, 3)
    assert not arches or length >= 8, "arches need a chassis 8 or more long"
    assert arches + width <= 8, "arches 3 wide only fit the wide chassis"
    edge = 10 - width // 2
    axle = {6: "p_kart_axle_plate", 4: "p_kart_axle_plate_4"}[width]
    level = max(radius(front), radius(back)) - 4
    for wheel, z in ((front, z0), (back, z0 + length - 2)):
        base = radius(wheel) - 4
        assert (level - base) % PLATE == 0, "%s and %s aren't whole plates apart" % (front, back)
        k.fine(axle, (edge - 1) * STUD, base, z * STUD, colour=colour)
        k.pair_fine(wheel, edge * STUD - turned_size(wheel, 0)[0], 0, z * STUD + STUD - fine_size(wheel)[2] / 2, colour=rims)
        y = base + PLATE
        while y < level + PLATE - 0.01:
            k.fine("p_plate_2x%d" % width, edge * STUD, y, z * STUD, rot=1, colour=colour)
            y += PLATE
    # An arch 6 long sits centred on the wheel, so its end cells are 2 studs
    # before the axle plate and 1 after it.
    ends = [r for a in (z0, z0 + length - 2) for r in (a - 2, a + 3)] if arches else []
    bridge = None
    start = z0 - 2 if arches else z0
    end = z0 + length + 2 if arches else z0 + length
    sizes = range(width, 2 * width + 1, 2)
    if end - start in sizes:
        k.fine("p_plate_%dx%d" % (width, end - start), edge * STUD, level + PLATE, start * STUD, colour=colour)
    else:
        # Two plates butted together. Plates side by side don't join, so the
        # join goes over the middle of an axle plate, or a 2×2 plate under
        # it holds them together.
        axles = (z0, z0 + length - 2)
        rows = [(a, 2) for a in axles]
        if edge + arches > 9:
            # The arches' plates under the chassis reach the middle too.
            rows += [(r, 1) for a in axles for r in (a - 2, a + 3)] if arches else []
        for first in sizes:
            seam = start + first
            if end - seam not in sizes:
                continue
            on_axle = any(seam == a + 1 for a in axles)
            clear = all(seam + 1 <= r or seam - 1 >= r + n for r, n in rows)
            # Or the arch plates under the row before the seam reach a row
            # further, across it, when that row's free or the next arch's.
            free = all(seam + 1 <= r or seam >= r + n for r, n in rows) or seam in ends
            if not (on_axle or clear) and seam - 1 in ends and free:
                bridge = seam - 1
            if on_axle or clear or bridge is not None:
                break
        else:
            raise ValueError("no way to join a chassis %d long" % (end - start))
        k.fine("p_plate_%dx%d" % (width, first), edge * STUD, level + PLATE, start * STUD, colour=colour)
        k.fine("p_plate_%dx%d" % (width, end - seam), edge * STUD, level + PLATE, seam * STUD, colour=colour)
        if not on_axle and bridge is None:
            k.fine("p_plate_2x2", 9 * STUD, level, (seam - 1) * STUD, colour=colour)
    for r in sorted(set(ends)):
        if bridge is not None and r == bridge + 1:
            continue
        n = 2 if r == bridge else 1
        k.pair_fine("p_plate_%dx%d" % (n, 2 * arches), (edge - arches) * STUD, level, r * STUD, rot=1, colour=colour)
        k.pair_fine("p_plate_%dx%d" % (n, arches), (edge - arches) * STUD, level + PLATE, r * STUD, rot=1, colour=colour)
    return (level + 2 * PLATE) / PLATE


# 1. A formula racer, open wheels and wings.
k = kart("redline", "Redline", "A formula racer with open wheels, wings at both ends and a little engine behind the driver. Light and quick through the fast corners.")
T = racer(k, "w_kart_wide", "w_slick", 3, 12, arches=0, width=4)
(k.add("d_front_wing_8x2", 6, T - 1, 0, colour=WHITE)
    .add("p_nose_cone_2x6", 9, T, 0, colour=RED)
    .pair("p_curve_1x4", 8, T, 3, colour=RED)
    .add("racing_wheel", 9, T, 6)
    .add("s_lay_down_seat", 9, T, 7)
    .pair("p_curve_2x4", 7, T, 7, rot=2, colour=RED)
    .add("engine_small", 9, T, 11, colour=DARK)
    .add("p_curve_2x2", 9, T + 3, 11, rot=2, colour=RED)
    .add("d_roll_hoop", 8, T, 11, colour=SILVER)
    .pair("d_open_exhausts", 8, T, 13)
    .add("p_brick_2x2", 9, T, 13, colour=DARK)
    .add("d_rear_wing_8", 6, T + 3, 13, colour=RED))


def arches(k, T, axles, colour, sides=None, part="p_arch_2x6_smooth"):
    """Smooth arches 2 wide over each pair of wheels of a slim racer()
    chassis (width 4, arches 2), `axles` being where its axle plates start.
    A gap between two arches gets a plate reaching out under the chassis and
    a brick 2×2 in `sides` on it, with a tile level with the arch ends.
    racer() has the front arch's back plates reach into the gap's first row
    already."""
    for a in axles:
        k.pair(part, 6, T, a - 2, colour=colour)
    if sides:
        z = axles[0] + 4
        assert axles[1] - 2 - z == 2, "the gap between arches has to be 2 long"
        (k.pair("p_plate_1x4", 6, T - 2, z + 1, rot=1, colour=DARK)
            .pair("p_plate_1x2", 6, T - 1, z + 1, rot=1, colour=DARK)
            .pair("p_brick_2x2", 6, T, z, colour=sides)
            .pair("p_tile_2x2", 6, T + 3, z, colour=sides))


# 2. A muscle car, low and long with black stripes nose to tail.
k = kart("big_block", "Big Block", "A muscle car with a big engine under a long striped bonnet. Heavy and strong, and quick once it gets going.")
T = racer(k, "w_slick", "w_slick", 3, 10, width=4)
arches(k, T, (3, 11), ORANGE, sides=ORANGE)
(k.add("p_plate_4x6", 8, T, 1, colour=ORANGE)
    .add("p_bonnet_4x6_black_stripes", 8, T + 1, 1, colour=ORANGE)
    .add("p_scoop_2x3", 9, T + 4, 4, colour=SILVER)
    .add("p_tile_1x1", 8, T + 4, 6, colour=BLACK).add("p_tile_1x1", 11, T + 4, 6, colour=BLACK)
    .add("p_brick_1x4", 8, T, 7, rot=1, colour=DARK)
    .add("windscreen_4", 8, T + 3, 7)
    .add("steering_wheel", 9, T, 8)
    .add("s_racing_seat", 9, T, 9)
    .pair("p_brick_1x4", 8, T, 11, colour=ORANGE)
    .add("engine_small", 9, T, 11, colour=SILVER)
    .add("p_brick_2x2", 9, T, 13, colour=DARK)
    .add("p_tile_1x4", 8, T + 3, 11, colour=BLACK).add("p_tile_1x4", 11, T + 3, 11, colour=BLACK)
    .add("p_tile_2x2", 9, T + 3, 11, colour=ORANGE)
    .add("d_rear_wing_8", 6, T + 3, 13, colour=DARK))

# 3. A stock car for the oval, a cab in the middle and a number on the roof.
k = kart("oval_ace", "Oval Ace", "A stock car built for long fast bends, with a roof over the driver and a spoiler on the boot. Steady and easy to drive.")
T = racer(k, "w_racing", "w_racing", 3, 8, width=4)
arches(k, T, (3, 9), BLUE, part="p_arch_2x6_yellow_stripe")
(k.add("p_plate_4x4", 8, T, 1, colour=BLUE)
    .add("p_curve_4x4", 8, T + 1, 1, colour=BLUE)
    .add("p_tile_1x4", 8, T + 4, 4, rot=1, colour=BLUE)
    .pair("p_brick_1x6", 8, T, 5, colour=BLUE)
    .add("steering_wheel", 9, T, 6)
    .add("s_racing_seat", 9, T, 7)
    .add("p_cab_4x6", 8, T + 3, 5, colour=BLUE)
    .add("p_round_tile_2x2", 9, T + 9, 7, colour=WHITE)
    .pair("p_brick_1x2", 8, T, 11, colour=BLUE)
    .add("engine_small", 9, T, 11, colour=SILVER)
    .add("p_plate_2x4", 8, T + 3, 11, rot=1, colour=BLUE)
    .add("p_tile_1x4", 8, T + 4, 11, rot=1, colour=BLUE)
    .add("d_front_wing_8x2", 6, T + 4, 12, colour=YELLOW))

# 4. A little go-kart: an open frame, a small nose, side pods and the
# engine beside the seat.
k = kart("kart_kid", "Kart Kid", "A proper little go-kart, light and nippy with the engine beside the seat. Easy to learn on.")
T = racer(k, "w_kart", "w_kart_wide", 1, 10, arches=0, width=4)
(k.add("p_curve_2x4", 9, T, 0, colour=KART_GREEN)
    .add("p_tile_1x2", 9, T + 3, 3, rot=1, colour=YELLOW)
    .add("steering_wheel", 9, T, 4)
    .add("p_tile_1x2", 9, T, 5, rot=1, colour=DARK)
    .pair("p_tile_1x4", 8, T, 4, colour=DARK)
    .pair("p_tile_1x2", 8, T, 8, colour=DARK)
    .add("p_tile_2x2", 9, T, 8, colour=DARK)
    .add("p_tile_1x4", 8, T, 10, rot=1, colour=DARK)
    .add("s_bucket_seat", 9, T, 6, colour=DARK)
    .pair("p_plate_2x3", 6, T - 2, 4, rot=1, colour=KART_GREEN)
    .add("p_plate_2x8", 6, T - 2, 6, rot=1, colour=KART_GREEN)
    .add("p_tile_2x2", 6, T - 1, 4, colour=KART_GREEN)
    .add("engine_small", 6, T - 1, 6, colour=SILVER)
    .add("p_tile_2x2", 6, T + 2, 6, colour=SILVER)
    .add("p_tile_2x4", 12, T - 1, 4, colour=KART_GREEN))

# 5. A rally car in white with red and blue stripes, lamps on the bonnet,
# a light pod on the roof and mud flaps.
k = kart("gravel_rat", "Gravel Rat", "A rally car on knobbly tires with four lamps on the bonnet. At home on dirt and gravel and fine on the road too.")
T = racer(k, "w_offroad", "w_offroad", 3, 8, width=4)
arches(k, T, (3, 9), WHITE)
(k.add("p_plate_4x4", 8, T, 1, colour=WHITE)
    .add("p_plate_4x4", 8, T + 1, 1, colour=WHITE)
    .pair("d_spotlights", 8, T + 2, 1, colour=YELLOW)
    .add("p_tile_1x4", 8, T + 2, 2, rot=1, colour=WHITE)
    .add("p_tile_1x2", 8, T + 2, 3, colour=WHITE).add("p_tile_1x2", 11, T + 2, 3, colour=WHITE)
    .add("p_tile_1x2", 9, T + 2, 3, colour=RED).add("p_tile_1x2", 10, T + 2, 3, colour=BLUE)
    .pair("p_brick_1x6", 8, T, 5, colour=WHITE)
    .add("steering_wheel", 9, T, 6)
    .add("s_racing_seat", 9, T, 7)
    .add("p_cab_4x6", 8, T + 3, 5, colour=WHITE)
    .add("d_spotlights", 9, T + 9, 7, colour=WHITE)
    .add("p_tile_1x2", 9, T + 9, 8, rot=1, colour=BLUE)
    .pair("p_brick_1x2", 8, T, 11, colour=WHITE)
    .add("engine_small", 9, T, 11, colour=SILVER)
    .add("p_tile_1x2", 8, T + 3, 11, colour=WHITE).add("p_tile_1x2", 11, T + 3, 11, colour=WHITE)
    .add("p_tile_1x2", 9, T + 3, 11, colour=RED).add("p_tile_1x2", 10, T + 3, 11, colour=BLUE))
# The flaps hang from the arch plates under the chassis, behind each wheel.
for z in (6, 12):
    k.pair_fine("d_mud_flap", 6 * STUD, (T - 2) * PLATE - 12, z * STUD, colour=RED)

# 6. An endurance racer, pinched in the middle under a bubble, with a lime
# stripe nose to tail.
k = kart("night_shift", "Night Shift", "An endurance racer with the driver lying down under a bubble and a wide wing over the gearbox. Fast and smooth, and it doesn't mind a long race.")
T = racer(k, "w_racing", "w_racing", 3, 10, width=4)
arches(k, T, (3, 11), BLUE)
(k.add("p_plate_4x4", 8, T, 1, colour=BLUE)
    .add("p_bonnet_4x4_lime_stripe", 8, T + 1, 1, colour=BLUE)
    .add("d_canopy_high_back", 8, T + 4, 5))
# The bubble stands on posts a brick and a plate high, clear of the wheel.
for x in (8, 11):
    for z in (5, 10):
        k.add("p_brick_1x1", x, T, z, colour=BLUE).add("p_plate_1x1", x, T + 3, z, colour=BLUE)
(k
    .add("racing_wheel", 9, T, 5)
    .add("s_lay_down_seat", 9, T, 6)
    .add("p_plate_4x4", 8, T, 11, colour=BLUE)
    .add("p_bonnet_4x4_lime_stripe", 8, T + 1, 11, rot=2, colour=BLUE)
    .add("p_plate_2x3", 9, T - 3, 14, colour=DARK)
    .add("engine_small", 9, T - 2, 15, colour=DARK)
    .add("d_rear_wing_8", 6, T + 1, 15, colour=DARK))

# 7. A dragster: a long thin flamed body, slicks at the back with a blower
# V8 in front of them, a wing up high and a wheelie bar. It's built by hand,
# low at the nose and a step up at the back for the big wheels.
k = kart("quarter_mile", "Quarter Mile", "A dragster with a blower V8, huge slicks and a wheelie bar. Unbeatable in a straight line, and it hates corners.")
(k.add("p_kart_axle_plate_4", 7, 2.5, 0, colour=DARK)
    .pair_fine("w_drag_front", 8 * STUD - fine_size("w_drag_front")[0], 24 - radius("w_drag_front"), STUD - fine_size("w_drag_front")[2] / 2)
    .add("p_plate_2x10", 9, 2.5, 2, colour=DARK)
    .add("p_plate_2x6", 9, 2.5, 12, colour=DARK)
    .pair("p_tile_1x2", 8, 3.5, 0, colour=DARK)
    .add("p_drag_body_2x10_flames", 9, 3.5, 0, colour=PURPLE)
    .add("racing_wheel", 9, 3.5, 10)
    .add("s_racing_seat", 9, 3.5, 11)
    .add("p_plate_2x4", 9, 3.5, 14, colour=DARK)
    .add("p_kart_axle_plate_4", 7, 4.5, 16, colour=DARK)
    .pair_fine("w_drag_slick", 8 * STUD - fine_size("w_drag_slick")[0], 0, 16 * STUD + STUD - fine_size("w_drag_slick")[2] / 2)
    .add("p_jumper_1x2", 9, 5.5, 16, colour=DARK)
    .add("e_blower_v8", 8.5, 6.5, 13, colour=RED)
    .add("d_wheelie_bar", 9, 3.5, 17)
    .pair("p_brick_1x1", 8, 5.5, 17, colour=DARK)
    .add("p_plate_2x4", 8, 8.5, 17, rot=1, colour=DARK)
    .pair("p_tile_1x2", 8, 9.5, 17, colour=DARK)
    .add("d_rear_wing_8", 6, 9.5, 17, colour=PURPLE))

# 8. A hot rod: a blower V8 out front over little wheels, a flamed tub for
# the driver and big slicks at the back, with open pipes down both sides.
# It's built by hand so the engine and driver sit low: a plate 4×8 hangs
# off the back axle plate and reaches forward to the front one, with tiles
# either side of the engine joining the two.
k = kart("flathead", "Flathead", "A hot rod with a blower V8 out in the open and fat tires at the back. Loads of pull and quick on the straights.")
(k.add("p_kart_axle_plate_4", 7, 2.5, 1, colour=DARK)
    .pair_fine("w_kart_wide", 8 * STUD - fine_size("w_kart_wide")[0], 0, 2 * STUD - fine_size("w_kart_wide")[2] / 2)
    .add("p_plate_4x8", 8, 2.5, 3, colour=DARK)
    .add("p_kart_axle_plate_4", 7, 3.5, 9, colour=DARK)
    .pair_fine("w_slick", 8 * STUD - fine_size("w_slick")[0], 0, 10 * STUD - fine_size("w_slick")[2] / 2)
    .add("d_hot_rod_grille", 9, 2.5, 0)
    .pair("p_tile_1x4", 8, 3.5, 1, colour=DARK)
    .add("p_jumper_1x2", 9, 3.5, 2, colour=DARK).add("p_jumper_1x2", 9, 3.5, 3, colour=DARK)
    .add("e_blower_v8", 8.5, 4.5, 1, colour=RED)
    .pair("p_plate_2x3", 7, 3.5, 5, colour=DARK)
    .pair("d_open_exhausts", 7, 4.5, 4)
    .pair("p_tub_side_1x6_flames", 8, 4.5, 5, colour=TEAL)
    .add("windscreen_tall", 9, 3.5, 5)
    .add("steering_wheel", 9, 3.5, 6)
    .add("s_racing_seat", 9, 3.5, 7)
    .add("p_plate_2x2", 9, 4.5, 9, colour=TEAL)
    .add("p_curve_2x2", 9, 5.5, 9, rot=2, colour=TEAL))

# 9. A dune buggy: knobbly tires, a short yellow nose, a roll cage with
# lamps on top and the engine out the back.
k = kart("sandhopper", "Sandhopper", "A dune buggy on big knobbly tires with a roll cage and lamps on top. Happiest off the road, in sand and on grass.")
T = racer(k, "w_offroad", "w_offroad", 1, 8, arches=0, width=4)
(k.add("p_bonnet_4x4", 8, T, 0, colour=YELLOW)
    .pair("p_tile_1x2", 8, T, 5, colour=YELLOW)
    .add("d_roll_cage_4x4", 8, T, 4, colour=DARK)
    .add("d_light_1x1", 8.5, T + 11.8, 6, colour=YELLOW).add("d_light_1x1", 9.5, T + 11.8, 6, colour=YELLOW).add("d_light_1x1", 10.5, T + 11.8, 6, colour=YELLOW)
    .add("steering_wheel", 9, T, 4)
    .add("s_racing_seat", 9, T, 5)
    .add("engine_small", 9, T, 8, colour=SILVER)
    .add("p_tile_2x2", 9, T + 3, 8, colour=SILVER)
    .pair("d_exhaust", 8, T, 8))

# 10. An electric racer in white with teal stripes, smooth over the wheels,
# with an open cockpit and a wing at each end.
k = kart("volt", "Volt", "A racer in white and teal, smooth and light, with wings at both ends. Easy to drive.")
T = racer(k, "w_racing", "w_racing", 4, 10, width=4)
arches(k, T, (4, 12), WHITE, sides=WHITE, part="p_arch_2x6_teal_stripe")
(k.add("d_front_wing_8x2", 6, T - 1, 0, colour=BLUE)
    .add("p_plate_4x4", 8, T, 0, colour=WHITE)
    .add("p_bonnet_4x4", 8, T + 1, 0, colour=WHITE)
    .add("windscreen_2", 9, T, 4)
    .add("racing_wheel", 9, T, 5)
    .add("s_lay_down_seat", 9, T, 6)
    .pair("p_brick_1x6", 8, T, 4, colour=WHITE)
    .pair("p_tile_1x2", 8, T + 3, 4, colour=WHITE)
    .pair("p_tile_1x4", 8, T + 3, 6, colour=BLUE)
    .add("p_plate_4x4", 8, T, 10, colour=WHITE)
    .add("ballast", 8, T + 1, 10, colour=WHITE).add("ballast", 10, T + 1, 10, colour=WHITE)
    .add("ballast", 8, T + 1, 12, colour=WHITE).add("ballast", 10, T + 1, 12, colour=WHITE)
    .add("engine_small", 9, T, 14, colour=DARK)
    .pair("p_tile_1x2", 8, T, 14, colour=WHITE)
    .add("d_rear_wing_8", 6, T + 3, 14, colour=BLUE))


# 25. A sprint kart: tiny and low on soft slicks, rounded side pods and a
# little single behind the seat.
k = kart("shifter", "Shifter", "A tiny sprint kart on soft slicks, the lightest of the karts. Nothing goes round a corner faster, but it's slow down the straights.")
T = racer(k, "w_kart_slick", "w_kart_slick", 1, 8, arches=0, width=4)
(k.add("p_curve_2x4", 9, T, 0, colour=ORANGE)
    .add("p_tile_1x2", 9, T + 3, 3, rot=1, colour=WHITE)
    .add("steering_wheel", 9, T, 4)
    .add("s_bucket_seat", 9, T, 5, colour=DARK)
    .pair("p_tile_1x4", 8, T, 4, colour=DARK)
    .add("engine_micro", 9, T, 7, colour=SILVER)
    .add("p_tile_1x2", 10, T, 7, colour=DARK)
    .pair("p_plate_2x3", 6, T - 2, 4, rot=1, colour=ORANGE)
    .pair("p_curve_2x2", 6, T - 1, 4, colour=ORANGE))

# 26. A sprint car: a small nose, the driver in a cage with a huge flat wing
# on top, the engine behind and a wider tire on the right back corner.
k = kart("dirt_wing", "Dirt Wing", "A sprint car with a huge wing on top and a fat tire on the right. Brilliant on dirt, and a bit twitchy on tarmac.")
T = racer(k, "w_racing", "w_truck", 2, 10, arches=0, width=4, rims=YELLOW)
# The right back wheel is the wide one.
wide = [p for p in k.parts if p["id"] == "w_truck"][-1]
k.parts.remove(wide)
k.fine("w_sprint_right", 12 * STUD, 0, 11 * STUD - fine_size("w_sprint_right")[2] / 2, rot=2, colour=YELLOW)
(k.add("p_curve_2x4", 9, T, 0, colour=BLUE)
    .pair("p_curve_1x4", 8, T, 0, colour=BLUE)
    .add("d_roll_cage_4x4", 8, T, 4, colour=DARK)
    .add("steering_wheel", 9, T, 4)
    .add("s_racing_seat", 9, T, 5)
    .pair("p_tile_1x2", 8, T, 5, colour=BLUE)
    .add("engine_v8", 9, T, 8, colour=SILVER)
    .pair("p_brick_1x4", 8, T, 8, colour=BLUE)
    .add("p_curve_2x4", 9, T + 3, 8, rot=2, colour=BLUE)
    .pair("p_tile_1x4", 8, T + 3, 8, colour=YELLOW)
    .add("d_sprint_wing", 6.5, T + 11.8, 3.5, colour=YELLOW))

# 27. A rally hatchback: a short striped bonnet, a car cab right to the
# back with the engine in behind the seat, and lamps on the roof.
k = kart("hot_hatch", "Hot Hatch", "A little rally hatchback on knobbly tires. It grips on everything, road, dirt or grass, and it's middling on the straights.")
T = racer(k, "w_offroad", "w_offroad", 3, 8, width=4)
arches(k, T, (3, 9), RED)
(k.add("p_plate_4x6", 8, T, 1, colour=RED)
    .add("p_bonnet_4x6_black_stripes", 8, T + 1, 1, colour=RED)
    .pair("p_brick_1x6", 8, T, 7, colour=RED)
    .add("steering_wheel", 9, T, 7)
    .add("s_racing_seat", 9, T, 8)
    .add("engine_small", 9, T, 11, colour=SILVER)
    .add("p_cab_4x6", 8, T + 3, 7, colour=RED)
    .add("d_spotlights", 9, T + 9, 9, colour=YELLOW)
    .add("p_tile_1x2", 9, T + 9, 10, rot=1, colour=WHITE))

# 28. A long closed-cockpit endurance prototype in purple: a bubble over a
# lay-down driver, side pods between the arches and the engine under a long fin.
k = kart("long_lap", "Long Lap", "A long, low endurance racer with the driver shut in under a bubble and the engine under the fin. The fastest thing down a long straight, and heavy in the tight stuff.")
T = racer(k, "w_racing", "w_racing", 3, 12, width=4)
arches(k, T, (3, 13), PURPLE)
(k.add("p_plate_4x4", 8, T, 1, colour=PURPLE)
    .add("p_bonnet_4x4_lime_stripe", 8, T + 1, 1, colour=PURPLE)
    .pair("p_brick_1x6", 8, T, 5, colour=PURPLE)
    .pair("p_plate_1x1", 8, T + 3, 5, colour=LIME)
    .pair("p_tile_1x4", 8, T + 3, 6, colour=LIME)
    .pair("p_plate_1x1", 8, T + 3, 10, colour=LIME)
    .add("racing_wheel", 9, T, 5)
    .add("s_lay_down_seat", 9, T, 6)
    .add("p_tile_1x2", 9, T, 10, rot=1, colour=DARK)
    .add("d_canopy", 8, T + 4, 5))
# Side pods in the gap between the arches, on plates under the chassis.
for z in (7, 9):
    k.pair("p_plate_2x3", 6, T - 2, z, rot=1, colour=DARK)
(k.pair("p_plate_2x4", 6, T - 1, 7, colour=DARK)
    .pair("p_brick_2x4", 6, T, 7, colour=PURPLE)
    .pair("p_tile_2x4", 6, T + 3, 7, colour=LIME)
    .add("engine_hybrid", 9, T, 11, colour=DARK)
    .add("p_fin_cover_4x6", 8, T, 11, colour=PURPLE))

# 29. A beach buggy: a short rounded nose, a roll hoop and the engine out
# in the open at the back.
k = kart("dune_bug", "Dune Bug", "A light beach buggy with its engine out the back. It bounces about on the road and floats over sand and grass.")
T = racer(k, "w_offroad", "w_offroad", 1, 8, arches=0, width=4, rims=WHITE)
(k.add("p_curve_4x4", 8, T, 0, colour=TEAL)
    .add("steering_wheel", 9, T, 4)
    .add("s_racing_seat", 9, T, 5)
    .pair("p_brick_1x3", 8, T, 4, colour=TEAL)
    .pair("p_tile_1x3", 8, T + 3, 4, colour=WHITE)
    .add("d_roll_hoop", 8, T, 7, colour=DARK)
    .add("engine_small", 9, T, 7, colour=SILVER)
    .add("p_tile_2x2", 9, T + 3, 7, colour=TEAL))


# Trucks.

def fenders(k, wheel_z, top):
    """A truck mudguard over each wheel of a pair whose middle is at
    `wheel_z`, on a chassis 4 wide, their plates on studs `top` plates up."""
    y = top * PLATE - 12
    k.fine("d_truck_fender", 6 * STUD, y, (wheel_z - 2) * STUD)
    k.fine("d_truck_fender", 11 * STUD, y, (wheel_z - 2) * STUD, rot=2)


# 11. A monster truck: a green body with a purple stripe up over huge wheels,
# a short pickup cab with lamps on the roof and a smooth bed behind.
k = kart("crusher", "Crusher", "A monster truck on huge wheels. It rolls over anything and doesn't mind the grass, but it's tall, so take the corners steady.")
T = racer(k, "w_monster", "w_monster", 2, 10, arches=0, width=4, rims=PURPLE)
(k.add("p_brick_2x4", 8, T, 2, colour=DARK).add("p_brick_2x4", 10, T, 2, colour=DARK)
    .add("engine_micro", 8, T, 6, colour=SILVER).add("p_brick_1x2", 8, T, 8, colour=DARK)
    .add("engine_diesel", 9, T, 6, colour=SILVER)
    .add("p_brick_2x2", 8, T, 10, colour=DARK).add("p_brick_2x2", 10, T, 10, colour=DARK)
    .add("p_plate_4x6", 8, T + 3, 0, colour=DARK)
    .add("p_plate_4x8", 8, T + 3, 6, colour=DARK))
B = T + 4
(k.add("p_plate_4x4", 8, B, 0, colour=LIME)
    .add("p_bonnet_4x4", 8, B + 1, 0, colour=LIME)
    .pair("p_brick_1x4", 8, B, 4, colour=LIME)
    .pair("p_plate_1x4", 8, B + 3, 4, colour=PURPLE)
    .add("steering_wheel", 9, B, 4)
    .add("s_racing_seat", 9, B, 5)
    .add("p_cab_4x4", 8, B + 4, 4, colour=LIME)
    .add("d_light_1x1", 9, B + 10, 6, colour=YELLOW).add("d_light_1x1", 10, B + 10, 6, colour=YELLOW)
    .pair("p_brick_1x6", 8, B, 8, colour=LIME)
    .add("p_brick_2x4", 9, B, 8, colour=LIME).add("p_brick_2x2", 9, B, 12, colour=LIME)
    .add("p_plate_4x6", 8, B + 3, 8, colour=PURPLE)
    .add("p_tile_2x6", 8, B + 4, 8, colour=LIME).add("p_tile_2x6", 10, B + 4, 8, colour=LIME))

# 12. A big rig cab racer: a tall cab behind a bonnet and grille, stacks
# behind the cab and a fifth wheel at the back. It's built by hand, so the
# back wheels sit far enough back for the stacks.
k = kart("long_haul", "Long Haul", "A big rig with the trailer left behind. Heavy and slow to get going, then hard to stop, and it shoves everyone out of the way.")
base = radius("w_slick") - 4
for z in (1, 10):
    k.fine("p_kart_axle_plate_4", 7 * STUD, base, z * STUD, colour=DARK)
    k.pair_fine("w_slick", 8 * STUD - fine_size("w_slick")[0], 0, (z + 1) * STUD - fine_size("w_slick")[2] / 2)
(k.fine("p_plate_4x6", 8 * STUD, base + PLATE, STUD, colour=DARK)
    .fine("p_plate_4x6", 8 * STUD, base + PLATE, 7 * STUD, colour=DARK)
    .fine("p_plate_2x2", 9 * STUD, base, 6 * STUD, colour=DARK))
T = (base + 2 * PLATE) / PLATE
(k.pair("p_brick_1x4", 8, T, 0, colour=BLUE)
    .add("d_hot_rod_grille", 9, T - 1, 0)
    .add("p_brick_2x2", 9, T, 2, colour=DARK)
    .add("p_plate_2x3", 9, T + 3, 1, colour=BLUE))
fenders(k, 2, T + 3)
(k.add("p_bonnet_4x4", 8, T + 4, 0, colour=BLUE)
    .pair("p_plate_2x4", 7, T, 4, colour=WHITE)
    .pair("p_plate_1x4", 7, T + 1, 4, colour=BLUE)
    .add("steering_wheel", 9, T, 4)
    .add("s_racing_seat", 9, T, 5)
    .add("p_truck_cab_6x4", 7, T + 2, 4, colour=BLUE)
    .add("p_curve_4x4", 8, T + 10, 4, colour=WHITE)
    .add("p_tile_1x4", 8, T + 13, 7, rot=1, colour=WHITE)
    .pair("d_exhaust_stack", 8, T, 8)
    .add("engine_hybrid", 9, T, 8, colour=SILVER)
    .add("p_round_tile_2x2", 9, T + 3, 9, colour=SILVER)
    .pair("p_brick_1x2", 8, T, 10, colour=DARK))
fenders(k, 11, T + 3)

# 13. A trophy truck: white with a red stripe and a number on the doors, big
# knobbly tires under black mudguards, lamps on the roof, a roll bar behind the
# cab and a spare wheel in the back.
k = kart("desert_pro", "Desert Pro", "A desert racer on big knobbly tires. Fast over the rough stuff and happy on the road too.")
T = racer(k, "w_truck", "w_truck", 1, 10, arches=0, width=4)
(k.pair("p_brick_1x4", 8, T, 0, colour=WHITE)
    .add("p_brick_2x4", 9, T, 0, colour=WHITE)
    .pair("p_plate_1x1", 8, T + 3, 0, colour=WHITE).pair("p_plate_1x1", 8, T + 3, 3, colour=WHITE)
    .add("p_plate_2x4", 9, T + 3, 0, colour=WHITE)
    .add("p_bonnet_4x4_red_stripe", 8, T + 4, 0, colour=WHITE)
    .pair("p_brick_1x2", 8, T, 4, colour=WHITE)
    .add("d_number_brick", 8, T, 6).add("d_number_brick", 11, T, 6, rot=2)
    .pair("p_brick_1x2", 8, T, 7, colour=WHITE)
    .pair("p_plate_1x4", 8, T + 3, 4, colour=RED)
    .add("steering_wheel", 9, T, 4)
    .add("s_racing_seat", 9, T, 5)
    .add("p_cab_4x4", 8, T + 4, 4, colour=WHITE)
    .add("d_light_1x1", 9, T + 10, 6, colour=YELLOW).add("d_light_1x1", 10, T + 10, 6, colour=YELLOW)
    .add("d_roll_bar", 8, T + 3, 8)
    .pair("p_brick_1x2", 8, T, 10, colour=WHITE)
    .add("engine_v8", 9, T, 8, colour=SILVER)
    .add("p_round_brick_2x2", 9, T + 3, 10, colour=DARK)
    .add("p_round_tile_2x2", 9, T + 6, 10, colour=SILVER)
    .pair("p_plate_1x1", 8, T + 3, 11, colour=WHITE)
    .pair("p_tile_1x2", 8, T + 4, 10, colour=WHITE))
fenders(k, 2, T + 3)
fenders(k, 10, T + 3)

# 14. A six wheeler: a tall orange truck cab over the front wheels and a grey
# bed over two axles at the back with a load on it. It's built by hand for the
# third axle.
k = kart("six_pack", "Six Pack", "A truck with two axles at the back. Steady and strong, and it grips like nothing else, but it's slow to turn.")
base = radius("w_truck") - 4
for z in (1, 6, 10):
    k.fine("p_kart_axle_plate_4", 7 * STUD, base, z * STUD, colour=DARK)
    k.pair_fine("w_truck", 8 * STUD - fine_size("w_truck")[0], 0, (z + 1) * STUD - fine_size("w_truck")[2] / 2, colour=ORANGE)
(k.fine("p_plate_4x6", 8 * STUD, base + PLATE, STUD, colour=DARK)
    .fine("p_plate_4x6", 8 * STUD, base + PLATE, 7 * STUD, colour=DARK))
T = (base + 2 * PLATE) / PLATE
(k.pair("p_brick_1x6", 8, T, 1, colour=ORANGE)
    .add("d_spotlights", 9, T, 1, colour=DARK)
    .add("p_plate_1x2", 9, T + 3, 1, rot=1, colour=ORANGE)
    .add("steering_wheel", 9, T, 2)
    .add("s_racing_seat", 9, T, 3)
    .add("engine_big", 9, T, 5, colour=GREY)
    .pair("p_brick_1x6", 8, T, 7, colour=GREY)
    .add("p_brick_2x4", 9, T, 8, colour=GREY)
    .add("p_brick_1x2", 9, T, 12, rot=1, colour=GREY)
    .add("p_brick_2x4", 9, T + 3, 8, colour=ORANGE)
    .add("p_tile_2x4", 9, T + 6, 8, colour=ORANGE))
fenders(k, 2, T + 3)
fenders(k, 7, T + 3)
fenders(k, 11, T + 3)
(k.pair("p_plate_1x3", 8, T + 3, 3, colour=ORANGE)
    .add("p_tile_1x4", 8, T + 4, 1, rot=1, colour=ORANGE)
    .add("p_truck_cab_4x4", 8, T + 4, 2, colour=ORANGE))


# 30. A tow truck: a yellow cab, a bed with a boom leaning out the back and
# a hook on its cable.
k = kart("tow_boss", "Tow Boss", "A tow truck with a boom and hook on the back. Heavy and tough, and it barges through a crowd.")
T = racer(k, "w_truck", "w_truck", 1, 12, arches=0, width=4)
(k.pair("p_brick_1x4", 8, T, 0, colour=YELLOW)
    .add("p_brick_2x4", 9, T, 0, colour=YELLOW)
    .pair("p_plate_1x1", 8, T + 3, 0, colour=YELLOW).pair("p_plate_1x1", 8, T + 3, 3, colour=YELLOW)
    .add("p_plate_2x4", 9, T + 3, 0, colour=YELLOW)
    .add("p_bonnet_4x4", 8, T + 4, 0, colour=YELLOW)
    .pair("p_brick_1x4", 8, T, 4, colour=YELLOW)
    .pair("p_plate_1x4", 8, T + 3, 4, colour=DARK)
    .add("steering_wheel", 9, T, 4)
    .add("s_racing_seat", 9, T, 5)
    .add("p_cab_4x4", 8, T + 4, 4, colour=YELLOW)
    .add("d_light_bar", 8, T + 10, 6, colour=ORANGE)
    .add("engine_v8", 9, T, 8, colour=GREY)
    .pair("p_brick_1x4", 8, T, 8, colour=YELLOW)
    .pair("p_brick_1x2", 8, T, 12, colour=YELLOW)
    .add("p_brick_2x2", 9, T, 12, colour=DARK)
    .pair("p_plate_1x3", 8, T + 3, 8, colour=YELLOW)
    .pair("p_plate_1x1", 8, T + 3, 13, colour=YELLOW)
    .add("p_plate_2x6", 9, T + 3, 8, colour=DARK)
    .pair("p_tile_1x3", 8, T + 4, 8, colour=YELLOW)
    .pair("p_tile_1x1", 8, T + 4, 13, colour=YELLOW)
    .add("p_tile_2x2", 9, T + 4, 8, colour=DARK)
    .add("d_tow_boom", 9, T + 4, 10, colour=GREY))
fenders(k, 2, T + 3)
fenders(k, 12, T + 3)

# 31. A rock crawler: tall on huge wheels, a lime bonnet out front, an
# open cage with lamps and the engine out back over the back wheels, which
# need the weight to push.
k = kart("rock_crawler", "Rock Crawler", "A rock crawler up on huge wheels. Slow, but it doesn't care what's under it.")
T = racer(k, "w_monster", "w_monster", 2, 10, arches=0, width=4, rims=YELLOW)
(k.add("p_brick_2x4", 9, T, 1, colour=LIME)
    .pair("p_brick_1x4", 8, T, 1, colour=LIME)
    .add("p_plate_4x4", 8, T + 3, 1, colour=LIME)
    .add("p_bonnet_4x4", 8, T + 4, 1, colour=LIME)
    .add("d_roll_cage_4x4", 8, T, 5, colour=DARK)
    .add("d_light_1x1", 8.5, T + 11.8, 7, colour=YELLOW).add("d_light_1x1", 9.5, T + 11.8, 7, colour=YELLOW).add("d_light_1x1", 10.5, T + 11.8, 7, colour=YELLOW)
    .add("steering_wheel", 9, T, 5)
    .add("s_racing_seat", 9, T, 6)
    .pair("p_tile_1x2", 8, T, 6, colour=LIME)
    .add("engine_big", 9, T, 9, colour=SILVER)
    .pair("p_brick_1x3", 8, T, 9, colour=LIME))

# 32. A short fire engine: a red car cab, a locker behind with a ladder
# on a post reaching forward over the cab.
k = kart("fire_chief", "Fire Chief", "A short fire engine with a ladder on top. Strong off the line, and steady once it's going.")
T = racer(k, "w_truck", "w_truck", 1, 10, arches=0, width=4)
(k.pair("p_brick_1x4", 8, T, 0, colour=RED)
    .add("p_brick_2x4", 9, T, 0, colour=RED)
    .pair("p_plate_1x1", 8, T + 3, 0, colour=RED).pair("p_plate_1x1", 8, T + 3, 3, colour=RED)
    .add("p_plate_2x4", 9, T + 3, 0, colour=RED)
    .add("p_bonnet_4x4", 8, T + 4, 0, colour=RED)
    .pair("p_brick_1x4", 8, T, 4, colour=RED)
    .pair("p_plate_1x4", 8, T + 3, 4, colour=WHITE)
    .add("steering_wheel", 9, T, 4)
    .add("s_racing_seat", 9, T, 5)
    .add("p_cab_4x4", 8, T + 4, 4, colour=RED)
    .add("d_light_1x1", 9, T + 10, 6, colour=BLUE).add("d_light_1x1", 10, T + 10, 6, colour=BLUE)
    .add("engine_hybrid", 9, T, 8, colour=SILVER)
    .pair("p_brick_1x3", 8, T, 8, colour=RED)
    .add("p_plate_2x4", 9, T + 3, 8, colour=RED)
    .pair("p_plate_1x1", 8, T + 3, 8, colour=RED).pair("p_plate_1x1", 8, T + 3, 11, colour=RED)
    .pair("p_brick_1x4", 8, T + 4, 8, colour=RED)
    .add("p_brick_2x4", 9, T + 4, 8, colour=RED)
    .pair("p_tile_1x4", 8, T + 7, 8, colour=WHITE)
    .add("p_tile_2x2", 9, T + 7, 8, colour=WHITE)
    .add("d_fire_ladder", 9, T + 7, 2))
fenders(k, 2, T + 3)
fenders(k, 10, T + 3)


MID = WIDTH / 2


# The bikes and trikes. Their parts are modelled in each one's own space
# (see the end of tools/parts/library.py): x across from the middle, y up from
# the ground and z back from the front axle, in the fine unit. Each part goes
# down with its corner where it was modelled, so these corners match the ones
# in library.py. The front axle is `za` back in the build area.

def bike(key, name, about, za, parts, wheels):
    """`parts` are (part, corner, colour). `wheels` are (wheel, axle z,
    rims, across): one wheel in the middle, or a pair `across` either side
    of the middle (from the middle to its inside face)."""
    k = kart(key, name, about)
    for part, (x, y, z), colour in parts:
        k.fine(part, MID + x, y, za + z, colour=colour)
    for wheel, z, rims, across in wheels:
        w, h = fine_size(wheel)[0], fine_size(wheel)[1]
        r = h / 2
        if across:
            k.pair_fine(wheel, MID - across - w, 0, za + z - r, colour=rims)
        else:
            k.fine(wheel, MID - w / 2, 0, za + z - r, colour=rims)
    return k


# 15. A superbike in green with a white stripe and a number.
bike("streak", "Streak", "A superbike, low and faired in. Very fast and quick to flick about, but it can't hold a bend like a kart and it gets knocked about.", 30,
     [("b_frame_superbike", (-20, 16, 16), DARK), ("b_body_superbike", (-21, 17, 27), KART_GREEN), ("b_nose_superbike", (-21, 39, -26), KART_GREEN),
      ("b_fork_sport", (-25, 20.4, -10), None)],
     [("w_scooter", 0, None, 0), ("w_scooter", 140, None, 0)])

# 16. A scrambler in orange with a white number, up high on knobbly wheels.
bike("scrambler", "Scrambler", "A dirt bike up on big knobbly wheels. It rides over grass and bumps better than anything, but it's slow to turn on tarmac.", 45,
     [("b_frame_scrambler", (-19, 20, 12), DARK), ("b_body_scrambler", (-14, 51, 21), ORANGE), ("b_fork_dirt_small", (-27, 26.4, -10), ORANGE)],
     [("w_scrambler", 0, None, 0), ("w_scrambler", 144, None, 0)])

# 17. A little scooter in light blue and cream.
bike("zippy", "Zippy", "A little scooter on little wheels. Quick off the line and easy to flick about, but it runs out of puff on the straights.", 30,
     [("b_frame_scooter_small", (-17, 16, 11), DARK), ("b_body_scooter", (-21, 18, 23), "#6db3e8"), ("b_fork_scooter_small", (-25, 16.4, -10), "#6db3e8")],
     [("w_scooter_small", 0, None, 0), ("w_scooter_small", 104, None, 0)])

# 18. A chopper with a long fork, a blue tank and a sissy bar.
bike("long_fork", "Long Fork", "A chopper with its fork way out in front and the rider sat low. Fast on the straights and steady, but it turns like a bus.", 10,
     [("b_frame_chopper_long", (-22, 20, 36), DARK), ("b_tank_chopper", (-14, 71, 59), BLUE), ("b_fender_chopper", (-20, 18, 173), None),
      ("b_sissy_bar", (-20, 62, 157), None), ("b_fork_chopper_long", (-27, 20.4, -10), None)],
     [("w_scooter", 0, None, 0), ("w_racing", 200, None, 0)])

# 19. A reverse trike: two wheels in front under cycle wings, one behind.
k = bike("twin_nose", "Twin Nose", "A reverse trike with two wheels in front and one behind. It holds a bend nearly like a kart and still leans into it.", 45,
         [("b_frame_reverse_trike", (-55, 19, -21), DARK), ("b_nose_reverse_trike", (-27, 29, -43), ORANGE),
          ("b_tail_reverse_trike", (-23, 41, 117), ORANGE), ("b_quad_bars", (-20, 52, 52), None)],
         [("w_kart_tread", 0, None, 34), ("w_kart_tread", 140, None, 0)])
k.pair_fine("b_wing_trike_left", MID - 57, 20, 45 - 28, colour=ORANGE)

# 20. A chopper trike with a yellow rounded body over the back wheels.
bike("sunday_trike", "Sunday Trike", "A chopper trike with a long fork and a big rounded body on the back. Steady and comfy, but slow to turn and heavy to stop.", 10,
     [("b_frame_chopper_trike", (-62, 20, 36), DARK), ("b_tank_chopper", (-14, 71, 59), YELLOW), ("b_body_chopper_trike", (-31, 36, 173), YELLOW),
      ("b_sissy_bar", (-20, 62, 157), None), ("b_fork_chopper_long", (-27, 20.4, -10), None)],
     [("w_scooter", 0, None, 0), ("w_racing", 200, None, 30)])

# 21. A little pink trike with a mint box on the back.
k = bike("tiddler", "Tiddler", "A little electric trike with a box on the back. Slow but very steady, and easy for anyone to drive.", 30,
         [("b_frame_delta_trike", (-45, 16, 11), DARK), ("b_body_delta_trike", (-47, 18, 23), None), ("b_fork_scooter_small", (-25, 16.4, -10), "#e86a9a")],
         [("w_scooter_small", 0, None, 0), ("w_scooter_small", 104, None, 32)])
k.fine("b_box_delta_trike", MID - 20, 42, 30 + 94)


# 33. A cafe racer in red with a white stripe, a long tank, a hump behind
# the seat and a round lamp.
bike("ton_up", "Ton Up", "A café racer, low with a long tank and a round lamp. Quick on smooth road, and its treaded tires keep it going in the wet.", 30,
     [("b_frame_cafe", (-20, 16, 16), DARK), ("b_body_cafe", (-15, 44, 34), RED), ("b_fork_cafe", (-25, 20.4, -10), None)],
     [("w_street", 0, None, 0), ("w_street", 140, None, 0)])

# 34. A supermoto in white with red, a dirt bike on road wheels.
bike("kerb_hopper", "Kerb Hopper", "A supermoto, a dirt bike on road tires. Good on a bit of everything and easy to flick about.", 45,
     [("b_frame_scrambler", (-19, 20, 12), DARK), ("b_body_supermoto", (-14, 53, 21), WHITE), ("b_fork_dirt_small", (-27, 26.4, -10), RED)],
     [("w_supermoto", 0, None, 0), ("w_supermoto", 144, None, 0)])

# 35. An electric bike in white with lime stripes.
bike("spark", "Spark", "An electric bike with a battery where the engine would be. Loads of pull, but not much top speed.", 30,
     [("b_frame_electric", (-20, 16, 16), DARK), ("b_body_electric", (-19, 18, 29), WHITE), ("b_fork_sport", (-25, 20.4, -10), None)],
     [("w_street", 0, None, 0), ("w_street", 140, None, 0)])

# 36. A sports trike: two wide wheels in front under wide wings, a low red
# pointed nose and a tail with a lip.
k = bike("arrowhead", "Arrowhead", "A sports trike with two wide wheels in front and one behind. Low and very steady, and it holds a bend well.", 45,
         [("b_frame_reverse_trike", (-55, 19, -21), DARK), ("b_nose_arrowhead", (-26, 29, -47), RED),
          ("b_tail_arrowhead", (-23, 41, 117), RED), ("b_quad_bars", (-20, 52, 52), None)],
         [("w_kart_wide", 0, None, 34), ("w_kart_wide", 140, None, 0)])
k.pair_fine("b_wing_wide_left", MID - 73, 20, 45 - 28, colour=RED)

# 37. A delivery trike: a little trike in green with a load box and a
# yellow canopy over the rider.
k = bike("tuk_tuk", "Tuk Tuk", "A little delivery trike with a canopy over the top. Slow, but it nips round corners.", 30,
         [("b_frame_delta_trike", (-45, 16, 11), DARK), ("b_body_delta_trike", (-47, 18, 23), KART_GREEN), ("b_fork_scooter_small", (-25, 16.4, -10), KART_GREEN)],
         [("w_scooter_small", 0, None, 0), ("w_scooter_small", 104, None, 32)])
k.fine("b_canopy_tuk_tuk", MID - 31, 42, 30 + 15, colour=YELLOW)


# The quads, laid out like the bikes from the same numbers as in library.py:
# (wheel radius, wheel width, wheelbase, the wheels' outside face across,
# half width of the bodies, top of the bodies, top of the saddle). The rider
# sits 28 in front of the back wheel's arch with quad bars on the tank.

QUADS = {"zipper": (22.4, 32, 120, 68, 50, 56, 64),
         "mudlark": (33.6, 32, 140, 74, 52, 75, 84),
         "flat_track": (24, 36, 120, 72, 54, 56, 66),
         "dust_devil": (22.4, 32, 132, 72, 54, 54, 62),
         "pip": (22.4, 32, 108, 66, 42, 52, 60),
         "bogtrotter": (22.4, 32, 112, 68, 52, 62, 70)}
# A third axle this far behind the second, for a six wheeler.
QUAD_EXTRA = {"bogtrotter": 56}
# How far a bull bar reaches in front of the front body.
QUAD_BAR = {"bogtrotter": 6}


def quad(key, part_key, name, about, colour, wheel, rims):
    R, ww, wb, xo, hw, yt, ys = QUADS[part_key]
    zs = wb - R - 28
    return bike(key, name, about, 40,
                [("b_frame_quad_" + part_key, (-xo, R - 6, -14), DARK), ("b_quad_front_" + part_key, (-hw, R + 6, -R - 8 - QUAD_BAR.get(part_key, 0)), colour),
                 ("b_quad_back_" + part_key, (-hw, R + 6, wb - R - 8), colour), ("b_quad_bars", (-20, ys - 8, zs - 48), None)],
                [(wheel, z, rims, xo - ww) for z in [0, wb] + ([wb + QUAD_EXTRA[part_key]] if part_key in QUAD_EXTRA else [])])


# 22. A sport quad in blue with a white stripe and studs on the back.
quad("zipper", "zipper", "Zipper", "A sport quad, quick and nimble. It sits flat in the bends like a kart and handles grass better than one.",
     "#1f7fd6", "w_quad", None)

# 23. A tall green mud quad on big knobbly wheels with racks front and back.
quad("mudlark_quad", "mudlark", "Mudlark", "A mud quad up on big knobbly wheels, with racks front and back. Slow on tarmac but happy anywhere off it.",
     "#5fa83a", "w_offroad", ORANGE)

# 24. A low yellow racing quad on wide wheels.
quad("flat_track", "flat_track", "Flat Track", "A low racing quad on wide grippy wheels. Fast and sharp in the bends, but it doesn't like the grass.",
     YELLOW, "w_kart_wide", GREY)


# 38. A long orange desert quad with a black stripe and a number.
quad("dust_devil", "dust_devil", "Dust Devil", "A long sport quad with a big engine, the fastest of the quads. It sits flat in the bends and doesn't mind the dirt.",
     ORANGE, "w_quad", DARK)

# 39. A little pink quad for kids.
quad("pip", "pip", "Pip", "A kids' mini quad, tiny and light. It turns on the spot, but there isn't much to it on the straights.",
     "#e86a9a", "w_quad", WHITE)

# 40. A farm quad on six wheels with a bull bar in front and a rack behind.
quad("bogtrotter", "bogtrotter", "Bogtrotter", "A farm quad on six wheels with a bull bar and a rack. Slow, but it grips on anything.",
     "#c9a227", "w_quad", GREY)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k in karts:
        k.save()
    print("Wrote %d to %s" % (len(karts), os.path.normpath(OUT)))
