#!/usr/bin/env python3
"""Builds the stock karts in data/karts/stock, one JSON file each.

The karts are written out part by part here instead of by hand in the JSON,
because most parts come in pairs, one on each side. `pair()` puts a part down
and its mirror image across the middle of the kart, the same way Mirror does in
the garage.

The build area is 20 studs across, 30 plates high and 24 studs long, and the
kart faces toward -Z (the low end of the third number). A position is the
corner of the part nearest the origin, in [stud, plate, stud]. Rot is quarter
turns.

Run it from anywhere, then check them with:
  tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/report.gd
"""

import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
PARTS = json.load(open(os.path.join(ROOT, "data", "parts.json")))["parts"]
OUT = os.path.join(ROOT, "data", "karts", "stock")
WIDTH = 20


def size_of(part, rot):
    s = PARTS[part]["size"]
    return (s[2], s[1], s[0]) if rot % 2 else tuple(s)


class Kart:
    def __init__(self, key, name, about):
        self.key = key
        self.name = name
        self.about = about
        self.parts = []

    def add(self, part, x, y, z, rot=0, colour=None):
        entry = {"id": part, "at": [x, y, z], "rot": rot}
        if colour:
            entry["color"] = colour
        self.parts.append(entry)
        return self

    def pair(self, part, x, y, z, rot=0, colour=None):
        """Puts a part down on the left and its mirror image on the right."""
        self.add(part, x, y, z, rot, colour)
        sx = size_of(part, (4 - rot) % 4)[0]
        twin = PARTS[part].get("mirror", part)
        self.add(twin, WIDTH - x - sx, y, z, (4 - rot) % 4, colour)
        return self

    def wheels(self, part, z, y=0, x_left=None):
        """A pair of wheels on the chassis sides, the left one ending at x 7."""
        w = size_of(part, 0)[0]
        return self.pair(part, 7 - w if x_left is None else x_left, y, z)

    def save(self):
        data = {"name": self.name, "about": self.about, "parts": self.parts}
        lines = ",\n".join("\t\t" + json.dumps(p) for p in self.parts)
        text = '{\n\t"name": %s,\n\t"about": %s,\n\t"parts": [\n%s\n\t]\n}\n' % (json.dumps(data["name"]), json.dumps(data["about"], ensure_ascii=False), lines)
        with open(os.path.join(OUT, self.key + ".json"), "w") as f:
            f.write(text)


karts = []


def kart(key, name, about):
    k = Kart(key, name, about)
    karts.append(k)
    return k


# 1. The one everyone starts with. It's the old starter kart.
(kart("starter", "Starter", "A bit of everything. It's a good kart to learn on and to build from.")
    .add("plate_6x10", 7, 2, 7)
    .add("wheel_small", 6, 0, 8).add("wheel_small", 13, 0, 8)
    .add("wheel_small_wide", 5, 0, 13).add("wheel_small_wide", 13, 0, 13)
    .add("brick_1x6", 7, 3, 7, 1)
    .add("brick_1x2", 7, 3, 8).add("brick_1x2", 12, 3, 8)
    .add("seat", 9, 3, 11)
    .add("engine_small", 9, 3, 14)
    .add("brick_2x2", 7, 3, 14).add("brick_2x2", 11, 3, 14)
    .add("spoiler_6", 7, 6, 15)
    .add("turbo", 9, 3, 8)
    .add("steering_wheel", 9, 3, 10))

# 2. As light as a kart can be, with the driver lying down.
BLUE = "#0d69ab"
(kart("featherlight", "Featherlight", "Light and low, with tiny wheels at the front and handlebars for quick hands. It darts about but there's not much push.")
    .add("plate_6x10", 7, 2, 7, colour="#f2f3f2")
    .wheels("wheel_tiny", 8).wheels("wheel_small", 13)
    .add("slope_4x2", 8, 3, 7, colour=BLUE)
    .add("handlebars", 8, 3, 10)
    .add("bucket_seat", 9, 3, 11)
    .add("engine_micro", 9, 3, 15)
    .pair("curve_2x4", 7, 3, 11, colour=BLUE)
    .add("spring", 11, 3, 15))

# 3. Heavy, flat fronted and hard to push around.
RUST = "#7b2e2f"
(kart("bruiser", "Bruiser", "A heavy slab with a diesel and a ram. Slow to get going, but it shoves everyone else out of the way.")
    .add("plate_6x10", 7, 3, 6, colour="#635f61")
    .wheels("wheel_big_wide", 6).wheels("wheel_big_wide", 12)
    .add("ram_plate", 7, 4, 6)
    .pair("brick_2x4", 7, 4, 7, colour=RUST)
    .add("steering_wheel", 9, 4, 9)
    .add("seat", 9, 4, 10)
    .add("engine_diesel", 8, 4, 12)
    .add("brick_dropper", 11, 4, 12)
    .pair("brick_2x2", 7, 7, 7, colour=RUST))

# 4. A dragster: long, with tiny wheels up front and slicks at the back.
ORANGE = "#da8540"
(kart("slingshot", "Slingshot", "A dragster with a V8 in the back. Nothing is quicker in a straight line, and nothing turns worse.")
    .add("plate_6x10", 7, 2, 4, colour="#1b2a34").add("plate_6x10", 7, 2, 14, colour="#1b2a34")
    .wheels("wheel_tiny", 4).wheels("wheel_slick", 20)
    .add("nose_2x2", 9, 3, 4, colour=ORANGE)
    .pair("slope_long_2x4", 7, 3, 4, colour=ORANGE)
    .pair("brick_2x4", 7, 3, 12, colour=ORANGE)
    .add("steering_wheel", 9, 3, 15)
    .add("bucket_seat", 9, 3, 16)
    .add("engine_v8", 9, 3, 19)
    .add("turbo", 7, 3, 19)
    .add("rear_wing_6x2", 7, 6, 21, colour=ORANGE))

# 5. Smooth all over, for top speed.
SILVER = "#a3a2a4"
(kart("streamliner", "Streamliner", "Faired in from nose to tail with the driver lying down behind the screen. The fastest thing on a long straight, and a handful in the corners.")
    .add("plate_6x10", 7, 2, 6, colour=SILVER).add("plate_2x4", 9, 2, 16, colour=SILVER)
    .wheels("wheel_small", 8).wheels("wheel_small", 13)
    .pair("wheel_fairing_1", 6, 2, 6, colour="#f2f3f2")
    .add("nose_4x4", 8, 3, 6, colour="#f2f3f2")
    .add("windscreen_2", 9, 6, 9)
    .add("yoke", 9, 3, 10)
    .add("lay_down_seat", 9, 3, 11)
    .pair("curve_2x4", 7, 3, 11, colour="#f2f3f2")
    .add("engine_small", 9, 3, 15)
    .add("nose_2x2", 9, 3, 18, rot=2, colour="#f2f3f2")
    .add("turbo", 7, 3, 15))

# 6. For grass and dirt.
MUD = "#694030"
(kart("mudlark", "Mudlark", "Knobbly tires and a diesel, sitting up high. It's slow on the road and happy anywhere else.")
    .add("plate_6x10", 7, 3, 7, colour=MUD)
    .wheels("wheel_knobbly", 7).wheels("wheel_knobbly", 13)
    .add("slope_4x2", 9, 4, 7, colour="#a4bd46")
    .add("spring", 7, 4, 7)
    .add("steering_wheel", 9, 4, 10)
    .add("seat", 9, 4, 11)
    .pair("brick_2x2", 7, 4, 10, colour="#a4bd46")
    .add("engine_diesel", 8, 4, 13)
    .add("repair_kit", 11, 4, 13))

# 7. Three wheels and a battery.
TEAL = "#36aebf"
(kart("trike", "Trike", "One wheel at the front and an electric motor at the back. Light and eager, and tippy if you push it.")
    .add("plate_2x4", 7, 2, 4, colour="#f2f3f2").add("plate_2x4", 11, 2, 4, colour="#f2f3f2")
    .add("wheel_small_wide", 9, 0, 4)
    .add("plate_6x10", 7, 2, 9, colour="#f2f3f2")
    .pair("brick_2x4", 7, 3, 6, colour=TEAL)
    .add("handlebars", 8, 3, 10)
    .add("seat", 9, 3, 11)
    .wheels("wheel_small", 14)
    .add("electric_motor", 9, 3, 14)
    .add("magnet", 7, 3, 14)
    .add("turbo", 11, 3, 14))

# 8. Four little wheels steering at the front.
(kart("six_wheeler", "Six-wheeler", "Four small wheels steer at the front, so it grips like nothing else and never quite runs out of front end.")
    .add("plate_6x10", 7, 2, 4, colour="#1b2a34")
    .add("plate_2x4", 7, 2, 14, colour="#1b2a34").add("plate_2x4", 9, 2, 14, colour="#1b2a34").add("plate_2x4", 11, 2, 14, colour="#1b2a34")
    .wheels("wheel_small", 4).wheels("wheel_small", 7).wheels("wheel_small_wide", 15)
    .add("slope_4x2", 8, 3, 4, colour="#237841")
    .pair("brick_2x4", 7, 3, 12, colour="#237841")
    .add("steering_wheel", 9, 3, 11)
    .add("seat", 9, 3, 12)
    .add("engine_twin", 9, 3, 15)
    .add("spoiler_6", 7, 6, 15, colour="#f2cd37")
    .add("shield", 7, 3, 7)
    .add("brick_cannon", 11, 3, 7))

# 9. Huge wheels.
PURPLE = "#6b3fa0"
(kart("monster", "Monster", "Monster wheels and a big engine. It rolls over everything, and over itself if you corner too hard.")
    .add("plate_6x10", 7, 5, 6, colour="#1b1b1b")
    .wheels("wheel_monster", 5).wheels("wheel_monster", 13)
    .add("ram_plate", 7, 6, 6, colour=PURPLE)
    .pair("brick_2x4", 7, 6, 7, colour=PURPLE)
    .add("steering_wheel", 9, 6, 9)
    .add("seat", 9, 6, 10)
    .add("engine_big", 9, 6, 12)
    .pair("brick_2x2", 7, 6, 12, colour=PURPLE)
    .add("spring", 9, 6, 15))

# 10. Pushed along by a jet.
(kart("rocket", "Rocket", "A jet engine, slicks and wings. Slow off the line, then very, very fast, and it keeps pushing on the grass.")
    .add("plate_6x10", 7, 2, 7, colour="#f2f3f2")
    .wheels("wheel_slick", 7).wheels("wheel_slick", 14)
    .add("front_wing_6x2", 7, 3, 7, colour="#c4281c")
    .add("nose_2x2", 9, 4, 7, colour="#c4281c")
    .add("steering_wheel", 9, 3, 10)
    .add("bucket_seat", 9, 3, 11)
    .add("jet", 9, 3, 14)
    .add("rear_wing_6x2", 7, 6, 16, colour="#c4281c")
    .add("shield", 11, 3, 14))

# 11. A proper go-kart, all frame.
(kart("classic", "Classic", "A proper go-kart: a flat frame, a little engine off to one side and handlebars. Light, simple and quick in the twisty bits.")
    .add("plate_6x10", 7, 2, 7, colour="#f2cd37")
    .wheels("wheel_small", 8).wheels("wheel_small_wide", 14)
    .add("plate_2x4", 8, 3, 7, rot=1, colour="#1b1b1b")
    .add("handlebars", 8, 3, 10)
    .add("bucket_seat", 9, 3, 11)
    .add("engine_small", 11, 3, 13)
    .add("plate_2x4", 8, 3, 15, rot=1, colour="#1b1b1b")
    .add("spring", 7, 3, 13))

# 12. Wings everywhere.
(kart("downforce", "Downforce", "Big wings front and back, and slicks. The faster it goes the harder it grips, so it flies through fast corners.")
    .add("plate_6x10", 7, 2, 7, colour="#1b2a34")
    .wheels("wheel_slick", 7).wheels("wheel_slick", 14)
    .add("front_wing_6x2", 7, 3, 7, colour="#f2cd37")
    .add("slope_4x2", 8, 4, 7, colour="#1b2a34")
    .add("steering_wheel", 9, 3, 10)
    .add("seat", 9, 3, 11)
    .add("engine_small", 9, 3, 14)
    .add("rear_wing_6x2", 7, 6, 15, colour="#f2cd37")
    .add("turbo", 7, 3, 14)
    .add("shield", 11, 3, 14))

# 13. Bricks on bricks.
GREY = "#635f61"
(kart("brick_tank", "Brick Tank", "Two layers of bricks all around, a shield and a repair kit. It takes a beating and keeps going.")
    .add("plate_6x10", 7, 2, 7, colour=GREY)
    .wheels("wheel_small_wide", 8).wheels("wheel_small_wide", 13)
    .pair("brick_2x4", 7, 3, 7, colour=GREY)
    .pair("brick_2x4", 7, 6, 7, colour=GREY)
    .add("steering_wheel", 9, 3, 10)
    .add("seat", 9, 3, 11)
    .pair("brick_1x6", 7, 3, 11, colour=GREY)
    .add("shield", 7, 6, 11)
    .add("repair_kit", 11, 6, 11)
    .add("engine_twin", 9, 3, 14))

# 14. The all rounder, with a battery.
(kart("sparky", "Sparky", "An electric all rounder with a magnet for studs. Quick away from the line, and easy to drive.")
    .add("plate_6x10", 7, 2, 7, colour="#f2f3f2")
    .wheels("wheel_small", 8).wheels("wheel_small_wide", 13)
    .add("slope_2x2", 9, 3, 7, colour=TEAL)
    .pair("curve_2x4", 7, 3, 7, colour=TEAL)
    .add("steering_wheel", 9, 3, 10)
    .add("seat", 9, 3, 11)
    .add("electric_motor", 9, 3, 14)
    .add("magnet", 7, 3, 14)
    .add("turbo", 11, 3, 14))

# 15. Engine out front, big wheels out back.
(kart("hot_rod", "Hot Rod", "A V8 out in front and big wheels at the back. Loud, heavy and very fast, if you can keep it pointing the right way.")
    .add("plate_6x10", 7, 2, 5, colour="#1b1b1b")
    .wheels("wheel_small", 5).wheels("wheel_big_wide", 11)
    .add("engine_v8", 9, 3, 5)
    .add("turbo", 7, 3, 6)
    .add("brick_cannon", 11, 3, 5)
    .add("steering_wheel", 9, 3, 10)
    .add("seat", 9, 3, 11)
    .pair("brick_2x4", 7, 3, 11, colour="#c4281c"))

# 16. Rolls forever.
(kart("soapbox", "Soapbox", "Bicycle wheels, a nose cone and a tiny engine. Hardly any push, but hardly anything holds it back either.")
    .add("plate_6x10", 7, 4, 5, colour="#d7c599")
    .wheels("wheel_skinny", 5).wheels("wheel_skinny", 14)
    .add("nose_4x4", 8, 5, 5, colour="#c4281c")
    .add("windscreen_2", 9, 8, 8)
    .add("yoke", 9, 5, 9)
    .add("lay_down_seat", 9, 5, 10)
    .add("engine_micro", 11, 5, 13)
    .add("nose_2x2", 9, 5, 14, rot=2, colour="#c4281c")
    .add("spring", 7, 5, 13))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k in karts:
        k.save()
    print("Wrote %d karts to %s" % (len(karts), os.path.normpath(OUT)))
