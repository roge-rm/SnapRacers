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

    def wheels(self, part, z, y=0, x_left=None):
        """A pair of wheels on the chassis sides, the left one ending at x 7.
        An old wheel's z is its corner. A new wheel's is the middle of the
        stud its hub clips onto."""
        w = turned_size(part, 0)[0] / STUD
        x = 7 - w if x_left is None else x_left
        if new_wheel(part):
            radius = fine_size(part)[2] / 2
            return self.pair_fine(part, x * STUD, y * PLATE, z * STUD - radius, 0)
        return self.pair(part, x, y, z)

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
GREEN = "#237841"
LIME = "#a4bd46"
MUD = "#694030"
RUST = "#7b2e2f"
PURPLE = "#6b3fa0"
TAN = "#d7c599"


def radius(wheel):
    return fine_size(wheel)[1] / 2


def chassis(k, front, back, z0, length, colour, extra_front=()):
    """A kart's chassis: an axle plate at the front and back with the wheels
    on their pins, and 6 wide plates along the top of both. When the back
    wheels are bigger, plates on the front axle plate bring it level.
    `extra_front` puts more axles of front wheels further back, for the
    Six-wheeler. Returns the top of the chassis, in plates."""
    level = max(radius(front), radius(back)) - 4
    axles = [(front, z0)] + [(front, z) for z in extra_front] + [(back, z0 + length - 2)]
    for wheel, z in axles:
        base = radius(wheel) - 4
        k.fine("p_kart_axle_plate", 6 * STUD, base, z * STUD, colour=DARK)
        k.pair_fine(wheel, 7 * STUD - turned_size(wheel, 0)[0], 0, z * STUD + STUD - fine_size(wheel)[2] / 2)
        y = base + PLATE
        while y < level + PLATE - 0.01:
            k.fine("p_plate_2x6", 7 * STUD, y, z * STUD, rot=1, colour=DARK)
            y += PLATE
    z = z0
    for size in {6: [6], 8: [8], 10: [10], 12: [12], 20: [12, 8]}[length]:
        k.fine("p_plate_6x%d" % size, 7 * STUD, level + PLATE, z * STUD, colour=colour)
        z += size
    return (level + 2 * PLATE) / PLATE


# 1. The one everyone starts with.
k = kart("starter", "Starter", "A bit of everything. It's a good kart to learn on and to build from.")
T = chassis(k, "w_kart", "w_kart_wide", 7, 10, SILVER)
(k.add("p_nose_4x6", 8, T, 4, colour=RED)
    .pair("p_curve_1x3", 7, T, 7, colour=YELLOW)
    .add("steering_wheel", 9, T, 10)
    .add("s_seat", 9, T, 11)
    .pair("p_curve_2x6", 7, T, 10, colour=RED)
    .add("engine_small", 9, T, 14)
    .add("ducktail", 7, T + 3, 15, colour=YELLOW)
    .pair("d_taillight_1x2", 7, T + 5, 15)
    .pair("p_tile_1x2", 7, T, 16, rot=1, colour=DARK))

# 2. As light as a kart can be.
k = kart("featherlight", "Featherlight", "Light and low, with skinny wheels at the front, handlebars for quick hands and a little rotary engine that revs and revs.")
T = chassis(k, "w_scooter", "w_kart", 7, 10, WHITE)
(k.add("p_nose_4x6", 8, T, 4, colour=BLUE)
    .pair("p_tile_1x2", 7, T, 7, colour=BLUE)
    .add("handlebars", 8, T, 10)
    .add("s_racing_seat", 9, T, 11)
    .pair("p_curve_1x4", 7, T, 11, colour=BLUE)
    .add("engine_rotary", 9, T, 14)
    .add("p_curve_2x2", 9, T + 2, 14, rot=2, colour=BLUE)
    .pair("p_tile_1x2", 7, T, 15, colour=WHITE))

# 3. Heavy, flat fronted and hard to push around.
k = kart("bruiser", "Bruiser", "A heavy slab with a diesel and a ram. Slow to get going, but it shoves everyone else out of the way.")
T = chassis(k, "wheel_big_wide", "wheel_big_wide", 6, 10, GREY)
(k.add("ram_plate", 7, T, 6)
    .pair("d_light_1x1", 7, T + 3, 6)
    .pair("p_brick_2x4", 7, T, 7, colour=RUST)
    .pair("ballast", 7, T + 3, 7, colour=RUST)
    .pair("p_curve_2x2", 7, T + 6, 7, colour=RUST)
    .pair("p_curve_2x2", 7, T + 3, 9, rot=2, colour=RUST)
    .add("steering_wheel", 9, T, 9)
    .add("s_seat", 9, T, 10)
    .add("engine_diesel", 8, T, 12)
    .pair("p_curve_1x2", 7, T, 12, rot=2, colour=RUST)
    .pair("d_exhaust", 7, T, 14))

# 4. A long dragster, with skinny wheels up front and slicks at the back.
k = kart("slingshot", "Slingshot", "A dragster with the driver lying down, a V8 in the back and big slicks right at the tail. It's heavy and nothing turns worse, but it's quick down a straight.")
T = chassis(k, "w_scooter", "w_slick", 3, 20, BLACK)
(k.add("p_nose_4x6", 8, T, 0, colour=ORANGE)
    .add("p_tile_2x6", 9, T, 6, colour=ORANGE)
    .pair("p_curve_2x6", 7, T, 6, colour=ORANGE)
    .pair("p_curve_2x4", 7, T, 12, colour=BLACK)
    .add("yoke", 9, T, 14)
    .add("s_lay_down_seat", 9, T, 15)
    .pair("p_tile_2x2", 7, T, 16, colour=ORANGE)
    .add("engine_v8", 9, T, 19)
    .pair("d_exhaust", 7, T, 19)
    .add("rear_wing_6x2", 7, T + 3, 21, colour=ORANGE))

# 5. Smooth all over, for top speed.
k = kart("streamliner", "Streamliner", "Faired in from nose to tail with the driver lying down under a bubble. The fastest thing on a long straight, and a handful in the corners.")
T = chassis(k, "w_kart", "w_kart_wide", 6, 12, SILVER)
(k.add("p_nose_4x6", 8, T, 3, colour=WHITE)
    .add("p_brick_1x1", 8, T, 9, colour=WHITE).add("p_brick_1x1", 11, T, 9, colour=WHITE)
    .add("p_brick_1x1", 8, T, 14, colour=WHITE).add("p_brick_1x1", 11, T, 14, colour=WHITE)
    .add("d_canopy", 8, T + 3, 9)
    .add("racing_wheel", 9, T, 10)
    .add("s_lay_down_seat", 9, T, 11)
    .pair("p_curve_1x4", 7, T, 9, colour=WHITE)
    .pair("p_tile_1x2", 7, T, 13, colour=WHITE)
    .add("engine_rotary", 9, T, 15)
    .add("p_curve_2x2", 9, T + 2, 15, rot=2, colour=WHITE)
    .pair("p_curve_2x2", 7, T, 15, rot=2, colour=WHITE))

# 6. For grass and dirt.
k = kart("mudlark", "Mudlark", "Knobbly tires and a diesel, sitting up high. It's slow on the road and happy anywhere else.")
T = chassis(k, "w_offroad", "w_offroad", 7, 10, MUD)
(k.add("p_nose_4x6", 8, T, 4, colour=LIME)
    .pair("d_light_1x1", 7, T, 7)
    .pair("p_curve_1x2", 7, T, 8, colour=LIME)
    .add("steering_wheel", 9, T, 10)
    .add("s_seat", 9, T, 11)
    .pair("p_curve_2x2", 7, T, 10, colour=LIME)
    .pair("d_exhaust", 7, T, 12)
    .add("engine_diesel", 8, T, 13))

# 7. Three wheels and a battery.
k = kart("trike", "Trike", "One wheel at the front and an electric motor at the back. Light and eager, and tippy if you push it.")
(k.add("plate_2x4", 7, 3, 4, colour=WHITE).add("plate_2x4", 11, 3, 4, colour=WHITE)
    .add("wheel_small_wide", 9, 0, 4)
    .pair("p_tile_2x2", 7, 4, 4, colour=TEAL))
k.fine("p_kart_axle_plate", 6 * STUD, 24, 15 * STUD, colour=DARK)
k.pair_fine("w_racing", 7 * STUD - 28, 0, 16 * STUD - 28)
k.add("p_plate_6x10", 7, 4, 7, colour=WHITE)
T = 5
(k.pair("p_curve_2x2", 7, T, 7, colour=TEAL)
    .add("handlebars", 8, T, 9)
    .add("s_racing_seat", 9, T, 10)
    .pair("p_curve_1x4", 7, T, 10, colour=TEAL)
    .add("electric_big", 9, T, 13)
    .add("p_curve_2x2", 9, T + 2, 14, rot=2, colour=TEAL)
    .pair("p_curve_2x2", 7, T, 14, rot=2, colour=WHITE)
    .pair("p_tile_1x2", 7, T, 16, rot=1, colour=TEAL))

# 8. Four little wheels steering at the front.
k = kart("six_wheeler", "Six-wheeler", "Four small wheels steer at the front, so it grips like nothing else, with a low flat four at the back.")
T = chassis(k, "w_kart", "w_kart_wide", 4, 12, BLACK, extra_front=(7,))
(k.add("p_nose_4x6", 8, T, 1, colour=GREEN)
    .pair("p_curve_1x3", 7, T, 4, colour=GREEN)
    .pair("p_curve_2x6", 7, T, 7, colour=GREEN)
    .add("steering_wheel", 9, T, 10)
    .add("s_seat", 9, T, 11)
    .add("engine_flat4", 8, T, 13)
    .pair("p_tile_1x2", 7, T, 13, colour=GREEN)
    .add("spoiler_6", 7, T + 2, 14, colour=YELLOW))

# 9. Huge wheels.
k = kart("monster", "Monster", "Monster wheels and a hybrid engine. It rolls over everything, and over itself if you corner too hard.")
T = chassis(k, "wheel_monster", "wheel_monster", 6, 10, DARK)
(k.add("p_slope_2x2", 7, T, 6, colour=PURPLE).add("p_slope_2x2", 9, T, 6, colour=PURPLE).add("p_slope_2x2", 11, T, 6, colour=PURPLE)
    .pair("d_light_1x1", 7, T + 3, 7)
    .pair("p_brick_2x2", 7, T, 8, colour=PURPLE)
    .pair("p_curve_2x2", 7, T + 3, 8, colour=PURPLE)
    .add("steering_wheel", 9, T, 9)
    .add("s_seat", 9, T, 10)
    .pair("p_curve_2x2", 7, T, 10, colour=PURPLE)
    .add("engine_hybrid", 9, T, 12)
    .pair("p_round_brick_2x2", 7, T, 12, colour=PURPLE)
    .pair("p_curve_2x2", 7, T, 14, rot=2, colour=PURPLE))

# 10. Pushed along by a jet.
k = kart("rocket", "Rocket", "A jet engine, slicks and wings. Slow off the line, then very, very fast, and it keeps pushing on the grass.")
T = chassis(k, "wheel_slick", "wheel_slick", 7, 10, WHITE)
(k.add("front_wing_6x2", 7, T, 7, colour=RED)
    .add("p_nose_4x6", 8, T + 1, 4, colour=RED)
    .pair("p_curve_2x4", 7, T, 10, colour=WHITE)
    .add("steering_wheel", 9, T, 10)
    .add("s_racing_seat", 9, T, 11)
    .add("jet", 9, T, 14)
    .pair("p_curve_2x2", 7, T, 14, rot=2, colour=RED)
    .add("rear_wing_6x2", 7, T + 3, 16, colour=RED))

# 11. A proper go-kart, all frame.
k = kart("classic", "Classic", "A proper go-kart, with a nose cone, a little engine off to one side and handlebars. Light, simple and quick in the twisty bits.")
T = chassis(k, "w_kart", "w_kart_wide", 7, 10, YELLOW)
(k.add("p_nose_4x6", 8, T, 4, colour=DARK)
    .pair("p_tile_1x2", 7, T, 7, colour=DARK)
    .add("handlebars", 8, T, 10)
    .add("s_bucket_seat", 9, T, 11)
    .add("p_curve_1x4", 7, T, 10, colour=DARK).add("p_curve_1x3", 12, T, 10, colour=DARK)
    .add("engine_small", 11, T, 13)
    .add("d_exhaust", 12, T + 3, 13)
    .add("p_curve_2x2", 8, T, 15, rot=2, colour=DARK).add("p_tile_1x2", 10, T, 15, colour=DARK))

# 12. Wings everywhere.
k = kart("downforce", "Downforce", "Big wings front and back, and slicks at the back. The faster it goes the harder it grips, so it flies through fast corners.")
T = chassis(k, "w_kart", "wheel_slick", 7, 10, BLACK)
(k.add("front_wing_6x2", 7, T, 7, colour=YELLOW)
    .add("p_nose_4x6", 8, T + 1, 4, colour=BLACK)
    .pair("p_curve_2x6", 7, T, 10, colour=BLACK)
    .add("steering_wheel", 9, T, 10)
    .add("s_racing_seat", 9, T, 11)
    .add("engine_small", 9, T, 14)
    .add("rear_wing_6x2", 7, T + 3, 15, colour=YELLOW))

# 13. Bricks on bricks.
k = kart("brick_tank", "Brick Tank", "Thick armour all around and a diesel. It takes a beating and keeps going.")
T = chassis(k, "w_kart_wide", "w_kart_wide", 7, 10, GREY)
(k.pair("p_brick_2x4", 7, T, 7, colour=GREY)
    .pair("p_curve_2x4", 7, T + 3, 7, colour=GREY)
    .add("p_slope_2x2", 9, T, 7, colour=GREY)
    .add("d_light_1x1", 9, T + 3, 8).add("d_light_1x1", 10, T + 3, 8)
    .add("steering_wheel", 9, T, 10)
    .add("s_seat", 9, T, 11)
    .pair("p_brick_1x6", 7, T, 11, colour=GREY)
    .pair("p_tile_1x6", 7, T + 3, 11, colour=GREY)
    .add("engine_diesel", 9, T, 14))

# 14. The all rounder, with a battery.
k = kart("sparky", "Sparky", "An electric all rounder. Quick away from the line, and easy to drive.")
T = chassis(k, "w_kart", "w_kart_wide", 7, 10, WHITE)
(k.add("p_nose_4x6", 8, T, 4, colour=TEAL)
    .pair("p_curve_1x3", 7, T, 7, colour=WHITE)
    .add("racing_wheel", 9, T, 10)
    .add("s_seat", 9, T, 11)
    .pair("p_curve_2x4", 7, T, 10, colour=TEAL)
    .add("electric_motor", 9, T, 14)
    .add("p_curve_2x2", 9, T + 2, 14, rot=2, colour=TEAL)
    .pair("p_curve_2x2", 7, T, 14, rot=2, colour=WHITE))

# 15. Engine out front, big wheels out back.
k = kart("hot_rod", "Hot Rod", "A V8 out in front and big wheels at the back. Loud, heavy and very fast, if you can keep it pointing the right way.")
T = chassis(k, "w_kart", "wheel_big_wide", 5, 10, DARK)
(k.add("engine_v8", 9, T, 5)
    .pair("d_light_1x1", 7, T, 5)
    .pair("d_exhaust", 7, T, 6)
    .add("steering_wheel", 9, T, 10)
    .add("s_seat", 9, T, 11)
    .pair("p_curve_2x6", 7, T, 9, colour=RED)
    .add("ducktail", 7, T + 3, 13, colour=DARK))

# 16. Rolls forever.
k = kart("soapbox", "Soapbox", "Tall thin wheels, a nose cone and a little rotary engine. Not much push, but hardly anything holds it back either.")
T = chassis(k, "wheel_big", "wheel_big", 5, 12, TAN)
(k.add("p_nose_4x6", 8, T, 2, colour=RED)
    .add("d_screen_2", 9, T, 8)
    .pair("p_curve_1x4", 7, T, 8, colour=RED)
    .add("racing_wheel", 9, T, 10)
    .add("s_lay_down_seat", 9, T, 11)
    .add("engine_rotary", 11, T, 13)
    .add("p_curve_2x2", 9, T, 15, rot=2, colour=RED))


# Bikes and trikes, built the way toy motorbikes are: a frame in one piece
# with the engine, tank, seat and swingarm in it, a fork with the bars on
# top, a wheel at each end and a fairing if it's a sports bike. They're built
# round the middle of the build area in the fine unit.

MID = WIDTH / 2
ZF = 80


def moto(key, name, about, frame, fork, wheel, colour, trim, fairing=False, back_wheel=None):
    k = kart(key, name, about)
    back_wheel = back_wheel or wheel
    r = radius(wheel)
    wide = 80 if frame == "b_frame_trike" else 0
    k.fine(frame, MID - 20 - wide, max(r - 4, 16), ZF, colour=colour)
    k.fine(fork, MID - 40, r - 3.6, ZF)
    k.fine(wheel, MID - fine_size(wheel)[0] / 2, 0, ZF + 10 - r)
    axle = [c for c in PARTS[frame]["connectors"] if c["type"] == "axle"][0]
    back = axle["at"][2]
    rb = radius(back_wheel)
    if wide:
        k.pair_fine(back_wheel, MID - 20 - wide, r - rb, ZF + back - rb)
    else:
        k.fine(back_wheel, MID - fine_size(back_wheel)[0] / 2, r - rb, ZF + back - rb)
    if fairing:
        k.fine("b_moto_fairing", MID - 20, 2 * r + 2, ZF - 30, colour=trim)
    return k


moto("superbike", "Superbike", "A light sports bike with a fairing and a twin. Quick away and quick to flick about, but it can't hold a bend like a kart, and it gets knocked about.",
     "b_frame_sport", "b_moto_fork", "w_moto", RED, WHITE, fairing=True)
moto("dirt_bike", "Dirt Bike", "Knobbly tires and a light little engine. Happy on grass and gravel and nimble in tight turns, but slow on the road.",
     "b_frame_dirt", "b_moto_fork_dirt", "w_moto_trail", YELLOW, BLACK)
moto("chopper", "Chopper", "Long and low with a big engine. It rumbles along at a fair old lick, but it's slow to turn.",
     "b_frame_cruiser", "b_moto_fork", "w_moto", DARK, SILVER)
moto("scooter", "Scooter", "Little wheels and a quiet electric motor. Nippy and quick off the line, but light enough to get bumped right off the road.",
     "b_frame_scooter", "b_moto_fork_scooter", "w_scooter", TEAL, WHITE)
moto("tourer", "Tourer", "A big touring trike with two wheels at the back. Steadier than a bike, and in no hurry to turn.",
     "b_frame_trike", "b_moto_fork", "w_moto", BLUE, SILVER)
moto("trikester", "Trikester", "A trike with a knobbly tire up front, a bike's front end and two wheels at the back. Good on gravel, and a bit of a handful on the road.",
     "b_frame_trike", "b_moto_fork_dirt", "w_moto_trail", ORANGE, BLACK, back_wheel="w_moto")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k in karts:
        k.save()
    print("Wrote %d to %s" % (len(karts), os.path.normpath(OUT)))
