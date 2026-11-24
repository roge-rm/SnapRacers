#!/usr/bin/env python3
"""Makes the driver pieces: one OBJ per piece per colour region in
characters/meshes, data/characters/pieces_made.json listing them, and
data/characters/clipping.json, how much the pieces go into each other in the
rig's poses.

  uv run --with manifold3d --with numpy tools/characters/make_characters.py

Each mesh is in its bone's own space (see figure.py), so the rig puts it on
its bone as it is. Left and right pieces are both made here, never mirrored.
After making them, run the Godot import (tools/run-tests.sh does it first
thing). A mesh that came out empty once stays marked broken in Godot until
its .obj.import file is deleted.
"""

import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "parts"))

import arms  # noqa: E402
import backs  # noqa: E402
import beards  # noqa: E402
import figure as F  # noqa: E402
import hair  # noqa: E402
import headgear  # noqa: E402
import legs  # noqa: E402
import necks  # noqa: E402
import torsos  # noqa: E402
from kit import save_obj, union  # noqa: E402
from manifold3d import CrossSection, JoinType, Manifold  # noqa: E402
from shapes import GAP, SEGMENTS, apply, ball, rbox, tube  # noqa: E402

GAME = F.GAME
MESHES = "characters/meshes"
OUT = os.path.join(GAME, "data", "characters", "pieces_made.json")
CLIPPING = os.path.join(GAME, "data", "characters", "clipping.json")
# The pieces of the bare figure.

def hips():
    """One block, with a groove down the front and under it where the legs
    split, and no seam on the sides."""
    w, d = 0.38, F.TORSO_DEPTH
    block = rbox(-w * 0.5, 0.0, -d * 0.5, w * 0.5, F.HIPS_TOP, d * 0.5, 0.022)
    groove = Manifold.cube([0.006, 0.055, 0.012]).translate([-0.003, -0.01, -d * 0.5 - 0.008])
    under = Manifold.cube([0.006, 0.012, d + 0.02]).translate([-0.003, -0.008, -d * 0.5 - 0.01])
    return block - groove - under


def torso(grow=0.0):
    """The torso, or with `grow` the space around it pieces are kept out of
    (see torsos.base)."""
    return torsos.base(grow)


def neck(grow=0.0):
    """A slim post in the collar, which the head sits on."""
    top = F.HIPS_TOP + F.TORSO_HEIGHT
    head_bottom = F.NECK_Y + 0.015
    r = 0.043 + grow
    return Manifold.cylinder(head_bottom - top, r, r, SEGMENTS * 2).rotate([-90.0, 0.0, 0.0]).translate([0.0, top, 0.0])


def head_local_placed(turn=0.0, lean=None):
    """The head bone's transform in the upper body's space, turned by `turn`
    radians, then leant with the upper body if given."""
    c, s_ = math.cos(turn), math.sin(turn)
    b = np.array([[c, 0.0, s_], [0.0, 1.0, 0.0], [-s_, 0.0, c]]) * F.HEAD_SCALE
    m = np.hstack([b, np.array([[0.0], [F.HEAD_Y], [0.0]])])
    return F.compose(lean, m) if lean is not None else m


def face_zone():
    """In the head's own space, the front of the face hair keeps out of."""
    a = math.radians(hair.FACE_ANGLE)
    pts = [(0.0, 0.0), (0.4 * math.sin(-a), -0.4 * math.cos(a)), (0.0, -0.4), (0.4 * math.sin(a), -0.4 * math.cos(a))]
    wedge = CrossSection([pts])
    if wedge.area() <= 0.0:
        wedge = CrossSection([list(reversed(pts))])
    # The section is x across and z along; extrude goes up its third axis.
    solid = wedge.extrude(hair.FACE_TOP + 0.2).rotate([90.0, 0.0, 0.0])
    return solid.translate([0.0, hair.FACE_TOP, 0.0]) - head_local(0.0, 40)


def features():
    """In the head's own space, where the eyes, brows and mouth are printed
    in every mood, which beards keep clear of."""
    eyes = Manifold.cube([0.15, 0.08, 0.2]).translate([-0.075, -0.012, -0.3])
    mouth = Manifold.cylinder(0.2, 1.0, 1.0, 32).scale([0.04, 0.028, 1.0]).translate([0.0, -0.038, -0.3])
    return (eyes + mouth) - head_local(0.0, 40)


def head(grow=0.0):
    """The head the game makes (MeshKit.rounded_cylinder, scaled up), in the
    upper body's space, for keeping pieces out of it. It's round, so turning
    doesn't move it."""
    r, h, edge = F.HEAD_RADIUS * F.HEAD_SCALE + grow, F.HEAD_HEIGHT * F.HEAD_SCALE + grow * 2.0, 0.035 * F.HEAD_SCALE + grow
    section = CrossSection([[(-r, -h * 0.5), (r, -h * 0.5), (r, h * 0.5), (-r, h * 0.5)]])
    section = section.offset(-edge, JoinType.Round, 2.0, 32).offset(edge, JoinType.Round, 2.0, 32)
    section = section ^ CrossSection.square([1.0, 1.0]).translate([0.0, -0.5])
    return section.revolve(SEGMENTS * 2).rotate([-90.0, 0.0, 0.0]).translate([0.0, F.HEAD_Y, 0.0])


def head_local(grow=0.0, segments=SEGMENTS * 2):
    """The head in its own space, before it's scaled up, grown by `grow`."""
    r, h, edge = F.HEAD_RADIUS + grow, F.HEAD_HEIGHT + grow * 2.0, 0.035 + grow
    section = CrossSection([[(-r, -h * 0.5), (r, -h * 0.5), (r, h * 0.5), (-r, h * 0.5)]])
    section = section.offset(-edge, JoinType.Round, 2.0, 32).offset(edge, JoinType.Round, 2.0, 32)
    section = section ^ CrossSection.square([1.0, 1.0]).translate([0.0, -0.5])
    return section.revolve(segments).rotate([-90.0, 0.0, 0.0])


def stud(grow=0.0, segments=SEGMENTS * 2):
    """The stud on top of the head, in the head's own space before it's
    scaled up, or grown by `grow`."""
    w, h = 0.054 + grow, 0.04 + grow
    section = CrossSection([[(-w, 0.0), (w, 0.0), (w, h), (-w, h)]])
    section = section.offset(-0.008, JoinType.Round, 2.0, 32).offset(0.008, JoinType.Round, 2.0, 32)
    section = section ^ CrossSection.square([1.0, 1.0]).translate([0.0, 0.004])
    return section.revolve(segments).rotate([-90.0, 0.0, 0.0]).translate([0.0, F.HEAD_HEIGHT * 0.5 - 0.006, 0.0])


SHOE_LINE = -F.LEG_LENGTH + 0.045
# Where the colour bands of a leg change, as shares of its length from the
# hip, for shorts, socks and boots.
BAND_CUTS = [0.4, 0.55, 0.65]


def leg_standing(side):
    """A leg standing: a block a little narrower at the ankle, with the toe
    turned forward."""
    x = F.LEG_X * F.side_sign(side)
    r = 0.022
    top, bottom = -0.004, -F.LEG_LENGTH
    corners = []
    for y, half in ((top - r, 0.085 - r), (bottom + r, 0.079 - r)):
        for sx in (-1, 1):
            for z in (-0.065 + r, 0.065 - r):
                corners.append(ball((x + sx * half, y, z), r).scale([1, 1, 1]))
    shin = Manifold.batch_hull(corners)
    toe = rbox(x - 0.079, bottom, -0.135, x + 0.079, bottom + 0.062, -0.02, 0.022)
    return shin + toe


def leg_regions(solid):
    """Cuts a standing leg into its colour bands and the foot."""
    foot_zone = Manifold.cube([1.0, SHOE_LINE + 1.0, 2.0]).translate([-0.5, -1.0, -1.0])
    toe_zone = Manifold.cube([1.0, 1.0, 1.0]).translate([-0.5, -F.LEG_LENGTH - 0.5, -1.067])
    foot = solid ^ (foot_zone + toe_zone)
    rest = solid - (foot_zone + toe_zone)
    cuts = [0.0] + [-F.LEG_LENGTH * c for c in BAND_CUTS] + [SHOE_LINE]
    out = {}
    for k in range(len(cuts) - 1):
        slab = Manifold.cube([1.0, cuts[k] - cuts[k + 1], 2.0]).translate([-0.5, cuts[k + 1], -1.0])
        if k == 0:
            slab = Manifold.cube([1.0, 1.0, 2.0]).translate([-0.5, cuts[1], -1.0])
        out["b%d" % k] = rest ^ slab
    out["foot"] = foot
    return out


def seated_from_standing():
    """Turns a standing leg forward so it sticks straight out, its back on
    the seat."""
    b = F.rot_x(math.pi * 0.5)
    return np.hstack([b, np.array([[0.0], [0.065], [0.0]])])


def leg_keepout():
    """What a seated leg is cut back from: the hips and the bottom of the
    torso, as they are and leant forward astride (in the legs' own astride
    space), so the leg comes out in front of them."""
    hip = rbox(-0.2, -0.02, -F.TORSO_DEPTH * 0.5 - GAP, 0.2, F.HIPS_TOP + 0.002, F.TORSO_DEPTH * 0.5, 0.02)
    body = Manifold.cube([0.5, 0.5, F.TORSO_DEPTH + GAP]).translate([-0.25, F.HIPS_TOP - 0.002, -F.TORSO_DEPTH * 0.5 - GAP])
    straight = hip + body
    lean = F.upper_lean(-math.radians(F.ASTRIDE_LEAN))
    legs = F.legs_astride()
    to_legs = np.hstack([legs[:, :3].T, (-legs[:, :3].T @ legs[:, 3]).reshape(3, 1)])
    astride = apply(hip, to_legs) + apply(body, F.compose(to_legs, lean))
    return straight + astride


def arm(side):
    """One piece from the rounded shoulder down to the fixed bend at the
    elbow and on to the wrist, thicker at the shoulder. Its end has a socket
    the hand's wrist goes into."""
    s = F.side_sign(side)
    elbow = F.elbow(side)
    d = F.forearm_dir(side)
    end = F.wrist(side) - d * 0.013
    shoulder = ball((0.017 * s, -0.004, 0.0), 0.047, 20)
    knee = ball(elbow, 0.042, 20)
    # The forearm goes forward from the elbow before it turns in to the
    # wrist, so it clears the front corner of the torso.
    mid = elbow + (F.wrist(side) - elbow) * 0.6
    mid[0] = elbow[0]
    bend = ball(mid, 0.039, 20)
    cuff = tube(end - d * 0.012, end, 0.037, 0.035, 20)
    solid = Manifold.batch_hull([shoulder, knee]) + Manifold.batch_hull([knee, bend]) + Manifold.batch_hull([bend, cuff])
    socket = tube(end - d * 0.026, end + d * 0.01, 0.0215, 0.0215, 16)
    return solid - socket


def arm_regions(side, solid):
    """Cuts an arm into the shoulder (a short sleeve's length), the upper arm
    and the forearm."""
    elbow = F.elbow(side)
    d = F.forearm_dir(side)
    upper_dir = elbow / np.linalg.norm(elbow)
    n = upper_dir + d
    n /= np.linalg.norm(n)
    fore = solid.trim_by_plane(list(n), float(n.dot(elbow)))
    upper = solid.trim_by_plane(list(-n), -float(n.dot(elbow)))
    shoulder = upper.trim_by_plane([0.0, 1.0, 0.0], -0.055)
    return {"shoulder": shoulder, "upper": upper.trim_by_plane([0.0, -1.0, 0.0], 0.055), "fore": fore}


def hand(side):
    """A fat C shaped hand around its grip, the hole along z and the gap away
    from the wrist (+y), with the wrist that plugs into the arm."""
    outer, inner, half = 0.042, 0.02, 0.0215
    section = CrossSection([[(inner, -half), (outer, -half), (outer, half), (inner, half)]])
    section = section.offset(-0.007, JoinType.Round, 2.0, 12).offset(0.007, JoinType.Round, 2.0, 12)
    ring = section.revolve(32, 280.0).rotate([0.0, 0.0, -50.0])
    stub = tube((0.0, 0.034, 0.0), (0.0, F.HAND_SIZE + 0.03, 0.0), 0.019, 0.019, 20)
    return ring + stub


# Making them.

def rel(path):
    return "res://%s/%s" % (MESHES, path)


def save_shown(solid, path, sharp=35.0):
    """Writes a region as an OBJ file like kit.save_obj, but only the faces
    that show (see torsos.keep), leaving out the cuts between regions.
    Returns how many triangles it has."""
    solid = solid.calculate_normals(0, sharp)
    mesh = solid.to_mesh()
    props = np.asarray(mesh.vert_properties)
    tris = np.asarray(mesh.tri_verts)
    runs = np.asarray(mesh.run_index) // 3
    ids = np.asarray(mesh.run_original_id)
    shown = np.zeros(len(tris), bool)
    for k in range(len(ids)):
        if int(ids[k]) in torsos.SURFACE:
            shown[runs[k]:runs[k + 1]] = True
    tris = tris[shown]
    used = np.unique(tris)
    index = np.full(len(props), -1, np.int64)
    index[used] = np.arange(len(used))
    lines = []
    for p in props[used]:
        lines.append("v %.5f %.5f %.5f" % (p[0], p[1], p[2]))
    for p in props[used]:
        n = p[3:6]
        length = math.sqrt(float(np.dot(n, n))) or 1.0
        lines.append("vn %.4f %.4f %.4f" % (n[0] / length, n[1] / length, n[2] / length))
    for t in index[tris]:
        a, b, c = int(t[0]) + 1, int(t[1]) + 1, int(t[2]) + 1
        lines.append("f %d//%d %d//%d %d//%d" % (a, a, b, b, c, c))
    text = "\n".join(lines) + "\n"
    if text in _written:
        return _written[text], 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)
    _written[text] = path
    return path, len(tris)


def solid_shown_tris(path):
    with open(path) as f:
        return [line for line in f if line.startswith("f ")]


# Meshes saved so far by their text, so a region the same as one saved
# already, like a bare hand, uses that file.
_written = {}


def save_regions(name, regions, made, shown=False, counts=None):
    """Saves each region of a piece and returns their paths by region. With
    `shown`, only the faces that show are saved, and `counts` gets how many
    triangles."""
    out = {}
    for region, solid in regions.items():
        if solid.is_empty() or solid.volume() < 1e-9:
            continue
        file = "%s_%s.obj" % (name, region)
        if shown:
            path, n = save_shown(solid, os.path.join(GAME, MESHES, file))
            if counts is not None:
                counts[0] += len(solid_shown_tris(path))
            file = os.path.relpath(path, os.path.join(GAME, MESHES))
        else:
            n = save_obj(solid, (0.0, 0.0, 0.0), os.path.join(GAME, MESHES, file), 35.0)
            if counts is not None:
                counts[0] += n
        made[0] += n
        out[region] = rel(file)
    return out


def box_of(solids):
    lo = np.full(3, np.inf)
    hi = np.full(3, -np.inf)
    for s in solids:
        b = s.bounding_box()
        lo = np.minimum(lo, b[:3])
        hi = np.maximum(hi, b[3:])
    return [round(float(v), 4) for v in list(lo) + list(hi)]


def make():
    made = [0]
    pieces = {}
    solids = {}

    def piece(name, bone, regions, **extra):
        entry = {"bone": bone, "offset": [0.0, 0.0, 0.0], "regions": save_regions(name, regions, made), "box": box_of(regions.values())}
        entry.update(extra)
        pieces[name] = entry
        solids[name] = union(list(regions.values()))
        print("made", name)

    piece("hips", "legs", {"main": hips()})
    keepout = leg_keepout()
    seat = seated_from_standing()
    for side, name in ((0, "leg_l"), (1, "leg_r")):
        standing = leg_regions(leg_standing(side))
        seated = {k: apply(v, seat) - keepout for k, v in standing.items()}
        entry_seated = save_regions(name + "_seated", seated, made)
        piece(name, "legs", standing, seated={"regions": entry_seated, "box": box_of(seated.values())})
        solids[name + "_seated"] = union(list(seated.values()))
        for ride in ("astride", "forward"):
            solids[name + "_" + ride] = legs.ride(solids[name + "_seated"], side, ride, 0.13) - keepout
    piece("torso", "upper", {"main": torso()})
    piece("neck", "upper", {"skin": neck()})
    piece("stud", "head", {"skin": stud()})
    for side, suffix in ((0, "l"), (1, "r")):
        piece("arm_" + suffix, "arm_" + suffix, arm_regions(side, arm(side)))
        piece("hand_" + suffix, "hand_" + suffix, {"main": hand(side)})

    # What's worn, by slot and style. Each is cut back from the figure's
    # pieces on its bone, a hairline off them.
    styles = {"neck": {}}
    style_solids = {}
    upper_keepout = torso(GAP) + neck(GAP) + head(GAP)
    for style, make_style in necks.STYLES.items():
        regions = {k: v - upper_keepout for k, v in make_style().items()}
        entry = {"bone": "upper", "regions": save_regions("neck_" + style, regions, made), "box": box_of(regions.values())}
        if style in necks.METAL:
            entry["metallic"] = necks.METAL[style]
        styles["neck"][style] = entry
        style_solids["neck " + style] = union(list(regions.values()))
        print("made neck", style)

    # Hair and raised facial hair, on the head, cut back from it and its
    # stud. Hair has a cut version for under a hat.
    styles["hair"] = {}
    styles["facial_hair"] = {}
    # Kept a little coarse, so the lobes cut back from it stay light.
    head_keepout = head_local(GAP + 0.001, 24) + stud(GAP + 0.001, 24)
    sizes = {}
    length_solids = {}
    for style, make_style in hair.STYLES.items():
        regions = {k: (v - head_keepout).simplify(0.0018) for k, v in make_style().items()}
        whole = union(list(regions.values()))
        cut = hair.cut(regions, style in hair.LENGTHS)
        cut_whole = union(list(cut.values()))
        reach = hair.radius_profile(cut_whole, 0.004)[0]
        profile, top = hair.radius_profile(whole)
        entry = {"bone": "head", "regions": save_regions("hair_" + style, regions, made), "box": box_of(regions.values()), "top": top, "radius_at": profile}
        entry["cut"] = {
            "regions": save_regions("hair_%s_cut" % style, cut, made), "box": box_of(cut.values()),
            "top": hair.CUT_Y, "radius": round(max([r for y, r in reach if y >= hair.CUT_Y - hair.CUT_BAND - 0.001] or [0.0]), 4),
        }
        if style in hair.LENGTHS:
            # The length down the back, on the upper body, in each pose.
            parts = {}
            for pose, pose_regions in hair.length(style).items():
                pose_regions = {k: v.simplify(0.0004) - upper_keepout for k, v in pose_regions.items()}
                name = "hair_%s_length" % style + ("" if pose == "standing" else "_" + pose)
                key = "length" if pose == "standing" else "length_" + pose
                entry[key] = {"bone": "upper", "regions": save_regions(name, pose_regions, made), "box": box_of(pose_regions.values())}
                parts[pose] = union(list(pose_regions.values()))
            length_solids[style] = parts
            print("made hair", style, "length", ", ".join("%s %d" % (p, v.num_tri()) for p, v in parts.items()), "triangles")
        styles["hair"][style] = entry
        style_solids["hair " + style] = whole
        style_solids["hair %s cut" % style] = cut_whole
        sizes["hair " + style] = (whole.num_tri(), cut_whole.num_tri())
        print("made hair", style, whole.num_tri(), "triangles,", cut_whole.num_tri(), "cut")
    for style, make_style in beards.STYLES.items():
        regions = {k: (v - head_keepout).simplify(0.0008) for k, v in make_style().items()}
        whole = union(list(regions.values()))
        entry = {"bone": "head", "regions": save_regions("facial_hair_" + style, regions, made), "box": box_of(regions.values())}
        styles["facial_hair"][style] = entry
        style_solids["facial_hair " + style] = whole
        sizes["facial_hair " + style] = (whole.num_tri(), 0)
        print("made facial hair", style, whole.num_tri(), "triangles")
    total = sum(a + b for a, b in sizes.values())
    biggest = max(sizes, key=lambda k: sizes[k][0])
    print("hair and facial hair: %d triangles in all, the biggest %s at %d" % (total, biggest, sizes[biggest][0]))

    # Headgear, on the head. Hats over cut hair are also kept out of the band
    # the cut hair fills; what's worn on the hair is fitted to each hairdo.
    styles["headgear"] = {}
    gear = {}
    hat_keepout = head_keepout + Manifold.cylinder(0.3, headgear.INNER - 0.0005, headgear.INNER - 0.0005, 64).rotate([-90.0, 0.0, 0.0]).translate([0.0, headgear.BAND_TOP - 0.3, 0.0])
    bare = head_local(0.0, 40) + stud()
    gear_sizes = {}
    for style, make_style in headgear.STYLES.items():
        mode = headgear.HAIR[style]
        keep = hat_keepout if mode == "cut" else head_keepout
        fits = {}
        if style in headgear.BANDS:
            # One for each hairdo, kept off it, saved as variants "on_<hair>"
            # with the bare head's as the piece itself.
            made_on = {}
            for h in ["none"] + list(hair.STYLES):
                hair_solid = None if h == "none" else style_solids["hair " + h]
                on = headgear.Surface(bare if hair_solid is None else bare + hair_solid)
                cut_from = keep if hair_solid is None else keep + hair_solid
                made_on[h] = {k: v.simplify(0.0016) - cut_from for k, v in make_style(on).items()}
            regions = made_on["none"]
            entry = {"bone": "head", "hair": mode, "regions": save_regions("headgear_" + style, regions, made), "box": box_of(regions.values())}
            for h in hair.STYLES:
                entry["on_" + h] = {"regions": save_regions("headgear_%s_on_%s" % (style, h), made_on[h], made), "box": box_of(made_on[h].values())}
            fits = {h: union(list(r.values())) for h, r in made_on.items()}
            whole = fits["none"]
            gear_sizes[style] = max(sum(v.num_tri() for v in r.values()) for r in made_on.values())
        else:
            regions = {k: (v - keep).simplify(0.0016) for k, v in make_style().items()}
            whole = union(list(regions.values()))
            entry = {"bone": "head", "hair": mode, "regions": save_regions("headgear_" + style, regions, made), "box": box_of(regions.values())}
            gear_sizes[style] = sum(v.num_tri() for v in regions.values())
        if style in headgear.FIT:
            kind = headgear.FIT[style]
            fits["none"] = headgear.fit_to(whole, bare, kind)
            for h in hair.STYLES:
                fits[h] = headgear.fit_to(whole, bare + style_solids["hair " + h], kind)
            missing = [k for k, v in fits.items() if v is None]
            if missing:
                raise SystemExit("headgear %s doesn't fit on %s" % (style, missing))
            entry["fit"] = {k: [round(float(x), 4) for x in v] for k, v in fits.items()}
        styles["headgear"][style] = entry
        gear[style] = (whole, fits)
        print("made headgear", style, mode, gear_sizes[style], "triangles")
    biggest = max(gear_sizes, key=gear_sizes.get)
    print("headgear: %d triangles in all, the biggest %s at %d" % (sum(gear_sizes.values()), biggest, gear_sizes[biggest]))

    # Torsos, on the upper body, printed in colour regions on the torso.
    styles["torso"] = {}
    torso_solids = {}
    tri_sizes = {}
    plain = torso().volume()
    for style, make_style in torsos.STYLES.items():
        regions = make_style()
        counts = [0]
        entry = {"bone": "upper", "regions": save_regions("torso_" + style, regions, made, True, counts), "box": box_of(regions.values())}
        if style in torsos.METAL:
            entry["metallic"] = torsos.METAL[style]
        styles["torso"][style] = entry
        whole = union(list(regions.values()))
        torso_solids[style] = (whole, abs(whole.volume() - plain) > 1e-8)
        tri_sizes["torso " + style] = counts[0]
        print("made torso", style, counts[0], "triangles")

    # Arms, a piece for each side and its hand. Regions the same as one made
    # already share its file, so old files are cleared first.
    for old in os.listdir(os.path.join(GAME, MESHES)):
        if old.startswith("arms_") and old.endswith(".obj"):
            os.remove(os.path.join(GAME, MESHES, old))
    styles["arms"] = {}
    arm_solids = {}
    flags_by_style = arms.settings()
    keepouts = [arm_keepout(side) for side in (0, 1)]
    bare_hands = [torsos.keep(hand(side)) for side in (0, 1)]
    for style, flags in flags_by_style.items():
        entry = {}
        parts = {}
        raised_any = False
        for side, suffix in ((0, "l"), (1, "r")):
            bare_arm = torsos.keep(arm(side))
            regions, raised, hand_regions = arms.make(side, bare_arm, bare_hands[side], flags)
            for region, solid in raised.items():
                solid = torsos.keep(solid - keepouts[side])
                if solid.is_empty():
                    continue
                raised_any = True
                regions[region] = regions[region] + solid if region in regions else solid
            counts, hand_counts = [0], [0]
            arm_entry = {"bone": "arm_" + suffix, "regions": save_regions("arms_%s_%s" % (style, suffix), regions, made, True, counts), "box": box_of(regions.values())}
            hand_entry = {"bone": "hand_" + suffix, "regions": save_regions("arms_%s_hand_%s" % (style, suffix), hand_regions, made, True, hand_counts), "box": box_of(hand_regions.values())}
            if side == 0:
                entry.update(arm_entry)
            else:
                entry["arm_r"] = arm_entry
            entry["hand_" + suffix] = hand_entry
            parts["arm_" + suffix] = union(list(regions.values()))
            parts["hand_" + suffix] = union(list(hand_regions.values()))
            tri_sizes["arm %s %s" % (style, suffix)] = counts[0]
            tri_sizes["hand %s %s" % (style, suffix)] = hand_counts[0]
        if flags.get("metal"):
            entry["metallic"] = 0.5
        styles["arms"][style] = entry
        arm_solids[style] = (parts, raised_any)
        print("made arms", style, tri_sizes["arm %s l" % style], "triangles an arm,", tri_sizes["hand %s l" % style], "a hand")
    # Legs: the hips, on the rig, and each leg standing, seated and astride,
    # on the legs bone. Old files are cleared first, as with the arms.
    for old in os.listdir(os.path.join(GAME, MESHES)):
        if old.startswith("legs_") and old.endswith(".obj"):
            os.remove(os.path.join(GAME, MESHES, old))
    styles["legs"] = {}
    leg_solids = {}
    shown_keepout = torsos.keep(leg_keepout())
    for style in legs.STYLES:
        made_style = legs.make(style, hips(), shown_keepout)
        counts = [0]
        hip_regions = made_style["hips"]
        entry = {"bone": "hips", "regions": save_regions("legs_%s_hips" % style, hip_regions, made, True, counts), "box": box_of(hip_regions.values())}
        tri_sizes["hips " + style] = counts[0]
        parts = {"hips": union(list(hip_regions.values()))}
        for pose in legs.POSES:
            for side, suffix in ((0, "l"), (1, "r")):
                regions = made_style[(pose, side)]
                counts = [0]
                entry["%s_%s" % (pose, suffix)] = {"bone": "legs", "regions": save_regions("legs_%s_%s_%s" % (style, pose, suffix), regions, made, True, counts), "box": box_of(regions.values())}
                tri_sizes["leg %s %s %s" % (style, pose, suffix)] = counts[0]
                parts[(pose, side)] = union(list(regions.values()))
        if style in legs.METAL:
            entry["metallic"] = legs.METAL[style]
        styles["legs"][style] = entry
        leg_solids[style] = parts
        print("made legs", style, max(v for k, v in tri_sizes.items() if k.startswith("leg %s " % style)), "triangles a leg,", tri_sizes["hips " + style], "the hips")
    # Back pieces, on the upper body, in each pose: cut back from the torso,
    # the neck, the head and every neck piece, and seated, reclined and
    # astride from the seats and saddle they lean against. Old files are
    # cleared first, as with the arms.
    for old in os.listdir(os.path.join(GAME, MESHES)):
        if old.startswith("back_") and old.endswith(".obj"):
            os.remove(os.path.join(GAME, MESHES, old))
    styles["back"] = {}
    back_solids = {}
    neck_worn = [torsos.keep(v) for k, v in style_solids.items() if k.startswith("neck ")]
    back_keepout = torso(GAP) + neck(GAP) + head(GAP)
    seat_keepouts = {pose: torsos.keep(seats_in_upper(pose, GAP)) for pose in ("seated", "reclined", "astride")}
    for style in backs.STYLES:
        made_style = backs.make(style)
        entry = {"bone": "upper"}
        parts = {}
        for pose in backs.POSES:
            whole = union(list(made_style[pose].values()))
            # Only what it meets, so the cuts stay light.
            hits = [n for n in neck_worn if _boxes_meet(whole, n) and (whole ^ n).volume() > 1e-10]
            if pose in seat_keepouts and (whole ^ seat_keepouts[pose]).volume() > 1e-10:
                hits.append(seat_keepouts[pose])
            cut = back_keepout + union(hits) if hits else back_keepout
            regions = {k: v.simplify(0.0004) - cut for k, v in made_style[pose].items()}
            regions = {k: v for k, v in regions.items() if not v.is_empty() and v.volume() > 1e-9}
            counts = [0]
            name = "back_%s" % style if pose == "standing" else "back_%s_%s" % (style, pose)
            shape = {"regions": save_regions(name, regions, made, True, counts), "box": box_of(regions.values())}
            if pose == "standing":
                entry.update(shape)
            else:
                entry[pose] = shape
            tri_sizes["back %s %s" % (style, pose)] = counts[0]
            parts[pose] = union(list(regions.values()))
        if style in backs.METAL:
            entry["metallic"] = backs.METAL[style]
        styles["back"][style] = entry
        back_solids[style] = parts
        print("made back", style, ", ".join("%s %d" % (p, tri_sizes["back %s %s" % (style, p)]) for p in backs.POSES), "triangles")
    for kind in ("torso", "arm", "hand", "hips", "leg", "back"):
        mine = {k: v for k, v in tri_sizes.items() if k.split(" ")[0] == kind}
        biggest = max(mine, key=mine.get)
        print("%s: %d triangles in all, the biggest %s at %d" % (kind, sum(mine.values()), biggest, mine[biggest]))
    over = [k for k, v in tri_sizes.items() if v > 1500]
    if over:
        raise SystemExit("over 1,500 triangles: %s" % over)

    apart = clipping(solids, style_solids, gear, torso_solids, arm_solids, leg_solids, back_solids, length_solids)
    for style, pieces_apart in apart.items():
        styles["hair"][style]["apart"] = pieces_apart

    data = {
        "_comment": "Made by tools/characters/make_characters.py, so change the pieces there. Meshes are in their bone's own space, in metres. 'figure' is the bare figure; 'styles' are the remodelled styles by slot and style. A style's regions are coloured: main in its own colour (shiny metal if it has 'metallic'), dark and light a shade of it, the rest from 'colours' as colour and metallic. Hair has 'top', how high it reaches, and 'radius_at', how far out it reaches at heights up the head, in the head's own space before it's scaled up, for fitting what sits on it, and 'cut', the version under a hat: cut flat at 'top' and kept within 'radius' of the middle for the band under that. Headgear has 'hair', what's shown under it: the cut hair, the full hair or none ('hidden'). Bands worn on the hair have a variant 'on_<hair>' made for each hairdo, their own regions for none; the rest worn on the hair have 'fit', by hairdo ('none' for none), how it's placed to sit on it: [scale across, scale up, lift, move back], scaled from the middle of the head. Torsos are on the upper body. Legs are the hips, on the rig ('hips'), with each leg in each pose as 'standing_l', 'seated_r', 'astride_l', 'forward_r' (astride with the feet forward on a chopper's pegs) and so on, on the legs bone. Arms are the left arm, with 'arm_r', 'hand_l' and 'hand_r' each on its own 'bone'. Long hair has its length down the back on the upper body, 'length' standing with 'length_seated', 'length_reclined' and 'length_astride' like the back pieces, and 'apart', the neck pieces, back pieces and headgear it doesn't fit with, which leave the length off. Back pieces are on the upper body standing, with 'seated' (in an upright seat), 'reclined' (lying back in a lay-down seat) and 'astride' variants; their 'clear' region is the piece's colour, see through. A 'skin' region is in the driver's skin.",
        "colours": {**necks.COLOURS, **headgear.COLOURS, **torsos.COLOURS, **legs.COLOURS, **backs.COLOURS},
        "figure": pieces,
        "styles": styles,
    }
    with open(OUT, "w") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")
    print("%d pieces, %d triangles in all" % (len(pieces), made[0]))


# Clipping.

# Rests the rig puts the hands in, as targets in the rig's space (see
# CharacterRig.rest_hands()).
STANDING_REST = [tuple(F.STANDING_REST[0]), tuple(F.STANDING_REST[1])]
SEATED_REST = [tuple(F.SEATED_REST[0]), tuple(F.SEATED_REST[1])]
# More than this many cubic centimetres into each other counts as clipping.
LIMIT_CM3 = 0.05


def posed(solids, seated, astride=False, swings=None, along=(0.0, 0.0, -1.0)):
    """The pieces placed for a pose, in the rig's space."""
    lean = F.upper_lean(-math.radians(F.ASTRIDE_LEAN) if astride else 0.0)
    out = {"hips": solids["hips"], "torso": apply(solids["torso"], lean), "neck": apply(solids["neck"], lean)}
    legs = F.legs_astride() if astride else np.hstack([np.eye(3), np.zeros((3, 1))])
    for name in ("leg_l", "leg_r"):
        out[name] = apply(solids[name + leg_pose(seated, astride)], legs)
    for side, suffix in ((0, "l"), (1, "r")):
        angle, spread = swings[side]
        arm_m, hand_m = F.arm_pose(side, angle, spread, along)
        out["arm_" + suffix] = apply(solids["arm_" + suffix], F.compose(lean, arm_m))
        out["hand_" + suffix] = apply(solids["hand_" + suffix], F.compose(lean, hand_m))
    return out


def leg_pose(seated, astride):
    """The bare figure's leg solid's suffix for a pose. `astride` is False
    or how the legs ride (see figure.RIDES)."""
    if astride:
        return "_" + astride
    return "_seated" if seated else ""


def inverse(m):
    r = m[:, :3].T
    return np.hstack([r, (-r @ m[:, 3]).reshape(3, 1)])


_lower = []


def lower_body():
    """The hips and the legs standing, seated and seated astride, in the
    rig's space."""
    if not _lower:
        keepout = leg_keepout()
        seat = seated_from_standing()
        standing = union([union(list(leg_regions(leg_standing(side)).values())) for side in (0, 1)])
        seated = union([union([apply(v, seat) - keepout for v in leg_regions(leg_standing(side)).values()]) for side in (0, 1)])
        riding = union([legs.ride(apply(v, seat), side, ride, 0.13) - keepout for side in (0, 1)
                        for ride in ("astride", "forward") for v in leg_regions(leg_standing(side)).values()])
        _lower.extend([hips(), standing, seated, apply(riding, F.legs_astride())])
    return _lower


def arm_keepout(side):
    """In the arm's own space, where the torso, hips and legs are as the arm
    swings through every pose, for cutting raised bits on the arms back
    from."""
    hip, standing, seated, astride_legs = lower_body()
    body = torso(GAP)
    rest_standing = F.swing_to(side, STANDING_REST[side])[0]
    rest_seated = F.swing_to(side, SEATED_REST[side])[0]
    angles = [rest_standing - 0.08 + 0.04 * k for k in range(5)] + [rest_seated] + [math.radians(d) for d in range(39, 127, 3)] + [math.pi * 0.6]
    placed = []
    for a in angles:
        inv = inverse(F.arm_pose(side, a, 0.0)[0])
        placed += [apply(body, inv), apply(hip + standing + seated, inv)]
    lean = F.upper_lean(-math.radians(F.ASTRIDE_LEAN))
    for d in range(48, 108, 3):
        arm_m = F.arm_pose(side, math.radians(d), 0.3)[0]
        placed.append(apply(body, inverse(arm_m)))
        placed.append(apply(hip + astride_legs, inverse(F.compose(lean, arm_m))))
    return union(placed)


PAIRS = [
    ("hips", "leg_l"), ("hips", "leg_r"), ("leg_l", "leg_r"), ("torso", "leg_l"), ("torso", "leg_r"),
    ("torso", "arm_l"), ("torso", "arm_r"), ("hips", "arm_l"), ("hips", "arm_r"),
    ("torso", "hand_l"), ("torso", "hand_r"), ("hips", "hand_l"), ("hips", "hand_r"),
    ("leg_l", "hand_l"), ("leg_r", "hand_r"), ("leg_l", "arm_l"), ("leg_r", "arm_r"),
    ("arm_l", "hand_l"), ("arm_r", "hand_r"), ("torso", "neck"),
]


# What each worn style is checked against: the pieces on its own bone, which
# don't move against it, and the ones that swing past it.
STYLE_STILL = {"neck": ["torso", "neck", "head"]}
STYLE_MOVING = {"neck": ["arm_l", "arm_r", "hand_l", "hand_r"]}


HEAD_SLOTS = ("hair", "facial_hair")
# How far the head turns: glancing at a kart alongside, looking about
# standing and looking into a turn.
HEAD_TURNS = [0.0, 0.15, 0.3, 0.35, 0.5, 0.8, 1.05, 1.3]


def signed(turns):
    return [t * sign for t in turns for sign in ((1.0, -1.0) if t else (1.0,))]


def _boxes_meet(a, b):
    ba, bb = a.bounding_box(), b.bounding_box()
    return all(ba[i] <= bb[i + 3] and bb[i] <= ba[i + 3] for i in range(3))


def place_arms(parts, astride, swings, along):
    """An arm style's arms and hands placed for a pose, in the rig's space."""
    lean = F.upper_lean(-math.radians(F.ASTRIDE_LEAN) if astride else 0.0)
    out = {}
    for side, suffix in ((0, "l"), (1, "r")):
        angle, spread = swings[side]
        arm_m, hand_m = F.arm_pose(side, angle, spread, along)
        out["arm_" + suffix] = apply(parts["arm_" + suffix], F.compose(lean, arm_m))
        out["hand_" + suffix] = apply(parts["hand_" + suffix], F.compose(lean, hand_m))
    return out


def head_clipping(head_styles, solids, neck_styles, poses, report, still_checks=True, raised_arms=None):
    """Hair and facial hair against the head, the stud, the face and each
    other on the head, and against the neck, the torso, every neck piece and
    the arms and hands as the head turns in every pose."""
    worst = 0.0

    def note(pose, a, b, volume):
        nonlocal worst
        worst = max(worst, volume)
        if volume > 0.001:
            report.append({"pose": pose, "a": a, "b": b, "cm3": round(volume, 4)})

    still = {"head": head_local(0.0, 40), "stud": stud(), "face": face_zone(), "features": features()}
    for style, solid in (head_styles.items() if still_checks else ()):
        slot = style.split(" ")[0]
        for b in ("head", "stud", "face" if slot == "hair" else "features"):
            note("any pose", style, b, (solid ^ still[b]).volume() * 1e6)
    hairs = [k for k in head_styles if k.startswith("hair ")]
    for beard in [k for k in head_styles if k.startswith("facial_hair ") and still_checks]:
        for h in hairs:
            if _boxes_meet(head_styles[beard], head_styles[h]):
                note("any pose", beard, h, (head_styles[beard] ^ head_styles[h]).volume() * 1e6)
    # Against what's on the upper body and the arms and hands in every pose,
    # as the head turns all the way either side.
    upper = {"torso": solids["torso"], "neck": solids["neck"]}
    upper.update(neck_styles)
    arms = []
    for name, seated, astride, swings, along in poses:
        lean = F.upper_lean(-math.radians(F.ASTRIDE_LEAN) if astride else 0.0)
        placed = posed(solids, seated, astride, swings, along)
        swung = {b: placed[b] for b in ("arm_l", "arm_r", "hand_l", "hand_r")}
        # Arm styles with raised bits, their arms only, as their hands are the
        # figure's.
        for style, parts in (raised_arms or {}).items():
            on = place_arms(parts, astride, swings, along)
            swung["arms %s arm_l" % style] = on["arm_l"]
            swung["arms %s arm_r" % style] = on["arm_r"]
        arms.append((name, lean, swung))

    def at_turn(solid, turn):
        found = []
        placed = apply(solid, head_local_placed(turn))
        for b, other in upper.items():
            if _boxes_meet(placed, other):
                found.append(("head turned %+.2f" % turn, b, (placed ^ other).volume() * 1e6))
        for name, lean, swung in arms:
            placed = apply(solid, head_local_placed(turn, lean))
            for b, other in swung.items():
                if _boxes_meet(placed, other):
                    found.append(("%s, head turned %+.2f" % (name, turn), b, (placed ^ other).volume() * 1e6))
        return found

    for style, solid in head_styles.items():
        for turn in HEAD_TURNS:
            for pose, b, v in at_turn(solid, turn) + (at_turn(solid, -turn) if turn else []):
                note(pose, style, b, v)
    return worst


def headgear_clipping(gear, head_styles, solids, neck_styles, poses, report, raised_arms=None):
    """Headgear against the head, the stud and the face, the hair shown under
    it (each hairdo's cut version under a hat, each full hairdo under what's
    fitted to it), the raised facial hair, and as the head turns, against
    the torso, the neck pieces and the arms and hands in every pose. Also
    where a hat leaves the cut hair's top edge showing."""
    worst = 0.0

    def note(pose, a, b, volume):
        nonlocal worst
        worst = max(worst, volume)
        if volume > 0.001:
            report.append({"pose": pose, "a": a, "b": b, "cm3": round(volume, 4)})

    still = {"head": head_local(0.0, 40), "stud": stud(), "face": face_zone()}
    hairs = [k[5:] for k in head_styles if k.startswith("hair ") and not k.endswith(" cut")]
    beards_made = [k for k in head_styles if k.startswith("facial_hair ")]
    checked = {}
    bare_spots = []
    tops = {}
    moving = {}
    for style, (whole, fits) in gear.items():
        name = "headgear " + style
        mode = headgear.HAIR[style]
        if mode == "full":
            if style in headgear.BANDS:
                worn = {h: fits[h] for h in ["none"] + hairs}
            else:
                worn = {h: headgear.placed(whole, fits[h]) for h in ["none"] + hairs}
        else:
            worn = {"": whole}
        for key, solid in worn.items():
            label = name if key == "" else "%s on %s" % (name, key)
            for b in ("head", "stud", "face"):
                note("any pose", label, b, (solid ^ still[b]).volume() * 1e6)
            for beard in beards_made:
                if _boxes_meet(solid, head_styles[beard]):
                    note("any pose", label, beard, (solid ^ head_styles[beard]).volume() * 1e6)
        if mode == "cut":
            reach = headgear.hat_reach(whole)
            checked[style] = []
            for h in hairs:
                cut = head_styles["hair %s cut" % h]
                checked[style].append("hair %s cut" % h)
                if _boxes_meet(whole, cut):
                    note("any pose", name, "hair %s cut" % h, (whole ^ cut).volume() * 1e6)
                if h not in tops:
                    tops[h] = headgear.hair_tops(cut)
                missed = headgear.uncovered(reach, tops[h])
                if missed:
                    bare_spots.append({"headgear": style, "hair": h, "degrees": missed})
        elif mode == "full":
            checked[style] = []
            for h in hairs:
                checked[style].append("hair " + h)
                note("any pose", "%s on %s" % (name, h), "hair " + h, (worn[h] ^ head_styles["hair " + h]).volume() * 1e6)
        else:
            checked[style] = []
        moving[name] = union(list(worn.values()))
    # As the head turns, every way it's worn at once.
    worst = max(worst, head_clipping(moving, solids, neck_styles, poses, report, still_checks=False, raised_arms=raised_arms))
    return worst, checked, bare_spots


# The seat under a seated driver, hips and legs, for the leg styles.
SEAT = Manifold.cube([0.7, 0.1, 0.6]).translate([-0.35, -0.1, -0.45])

# The kart seats as tools/parts/library.py makes them (_seat), with how far
# each leans the driver back: name, plates high, studs long, how far its
# back leans in degrees, how tall its back is, whether it has bolsters and
# the driver's recline in degrees (from data/parts.json).
SEATS = [
    ("driver's seat", 3, 2, 8.0, 0.3, False, 0.0),
    ("bucket seat", 2, 2, 25.0, 0.3, True, 25.0),
    ("racing seat", 2, 2, 15.0, 0.34, True, 15.0),
    ("lay-down seat", 1, 4, 62.0, 0.3, True, 55.0),
]


def seat_solid(seat, grow=0.0):
    """A seat in the rig's space, whose origin is the middle of the top of
    its cushion, grown by `grow`."""
    _, plates, along, rest_deg, back, bolsters, _ = seat
    g = grow
    w, h, l = 0.5, plates * 0.1, along * 0.25
    parts = [rbox(0.01 - g, -g, 0.01 - g, w - 0.01 + g, h + g, l - 0.01 + g, 0.025)]
    parts.append(rbox(0.02 - g, -g, -0.06 - g, w - 0.02 + g, back + g, g, 0.025).rotate([rest_deg, 0.0, 0.0]).translate([0.0, h - 0.02, l - 0.01]))
    if bolsters:
        for x in (0.0, w - 0.06):
            parts.append(rbox(x - g, h - 0.02 - g, 0.06 - g, x + 0.06 + g, h + 0.07 + g, l - 0.02 + g, 0.02))
    return union(parts).translate([-w * 0.5, -h, -l * 0.5])


def saddle_solid(grow=0.0):
    """A motorbike's seat and the tail rising behind it, in the rig's space,
    like the sports bike frame's."""
    g = grow
    seat = rbox(-0.2 - g, -0.1 - g, -0.29 - g, 0.2 + g, g, 0.29 + g, 0.03)
    tail = Manifold.hull_points([(x, y, z) for x in (-0.15 - g, 0.15 + g) for y, z in ((-0.1, 0.29), (g, 0.29), (0.025 - g, 0.76 + g), (0.1 + g, 0.76 + g))])
    return seat + tail


def seat_lean(seat):
    return F.upper_lean(math.radians(seat[6]))


def seats_in_upper(pose, grow=0.0):
    """Where the seats are in the upper body's space for a pose: every
    upright seat seated, the lay-down seat reclined and the saddle astride."""
    if pose == "astride":
        return apply(saddle_solid(grow), inverse(F.upper_lean(-math.radians(F.ASTRIDE_LEAN))))
    chosen = [s for s in SEATS if (s[6] > 40.0) == (pose == "reclined")]
    return union([apply(seat_solid(s, grow), inverse(seat_lean(s))) for s in chosen])


def back_clipping(back_solids, solids, neck_styles, raised_torsos, raised_arms, leg_solids, poses, report, kind="back", skip=None):
    """Back pieces, in the variant made for each pose, against the torso,
    the neck, the head, every neck piece and raised torso, and in every pose
    the hips, every leg style, the arms and hands and the raised arms, and
    the seats: every upright seat seated, the lay-down seat lying back in it
    and the saddle astride. `kind` names them, and what's in `skip` (by
    style, what it isn't worn with) isn't checked."""
    worst = 0.0

    def note(pose, a, b, one, other):
        nonlocal worst
        if b in (skip or {}).get(a.split(" ")[1], ()) or not _boxes_meet(one, other):
            return
        volume = (one ^ other).volume() * 1e6
        worst = max(worst, volume)
        if volume > 0.001:
            report.append({"pose": pose, "a": a, "b": b, "cm3": round(volume, 4)})

    still = {"torso": solids["torso"], "neck": solids["neck"], "head": head()}
    still.update(neck_styles)
    still.update(raised_torsos)
    for style, parts in back_solids.items():
        for pose in backs.POSES:
            name = "%s %s" % (kind, style) if pose == "standing" else "%s %s %s" % (kind, style, pose)
            for b, other in still.items():
                note("any pose", name, b, parts[pose], other)
    lay = [s for s in SEATS if s[6] > 40.0][0]
    reclined = []
    for degrees in (45, 75, 100):
        a = math.radians(degrees)
        reclined.append(("reclined in the %s, arms swung %d degrees" % (lay[0], degrees), True, False, [(a, 0.0), (a, 0.0)], (0.0, 0.0, 1.0)))
    for name, seated, astride, swings, along in list(poses) + reclined:
        lying = name.startswith("reclined")
        kind = astride if astride else ("seated" if seated else "standing")
        variant = "reclined" if lying else ("astride" if astride else kind)
        lean = seat_lean(lay) if lying else F.upper_lean(-math.radians(F.ASTRIDE_LEAN) if astride else 0.0)
        legs_m = F.legs_astride() if astride else np.hstack([np.eye(3), np.zeros((3, 1))])
        others = {"hips": solids["hips"]}
        for leg in ("leg_l", "leg_r"):
            others[leg] = apply(solids[leg + leg_pose(seated, astride)], legs_m)
        for side, suffix in ((0, "l"), (1, "r")):
            angle, spread = swings[side]
            arm_m, hand_m = F.arm_pose(side, angle, spread, along)
            others["arm_" + suffix] = apply(solids["arm_" + suffix], F.compose(lean, arm_m))
            others["hand_" + suffix] = apply(solids["hand_" + suffix], F.compose(lean, hand_m))
        for style, parts in raised_arms.items():
            for suffix in ("l", "r"):
                side = 0 if suffix == "l" else 1
                angle, spread = swings[side]
                arm_m = F.arm_pose(side, angle, spread, along)[0]
                others["arms %s arm_%s" % (style, suffix)] = apply(parts["arm_" + suffix], F.compose(lean, arm_m))
        for style, parts in leg_solids.items():
            others["legs %s hips" % style] = parts["hips"]
            others["legs %s leg_l" % style] = apply(parts[(kind, 0)], legs_m)
            others["legs %s leg_r" % style] = apply(parts[(kind, 1)], legs_m)
        if lying:
            others[lay[0]] = seat_solid(lay)
        elif astride:
            others["saddle"] = saddle_solid()
        for style, parts in back_solids.items():
            label = "%s %s" % (kind, style) if variant == "standing" else "%s %s %s" % (kind, style, variant)
            placed = apply(parts[variant], lean)
            for b, other in others.items():
                note(name, label, b, placed, other)
            if name == "seated, hands resting":
                for seat in SEATS:
                    if seat[6] <= 40.0:
                        note("%s, in the %s" % (name, seat[0]), label, seat[0], apply(parts[variant], seat_lean(seat)), seat_solid(seat))
    return worst


def length_apart(lengths, style_solids, back_solids, gear, head_styles):
    """What each long hair's length doesn't fit with: the neck pieces, back
    pieces (in the same pose) and headgear (as the head turns) it goes
    into, as {hair: ["neck ...", "back ...", "headgear ..."]}. Against
    headgear only the length below the cap's lower edge counts, as its top
    is tucked up inside the cap, or inside a helmet hiding the hair."""
    out = {}
    for h, parts in lengths.items():
        found = set()
        shown = [p.trim_by_plane([0.0, -1.0, 0.0], -hair.NAPE_Y) for p in parts.values()]
        for name, solid in style_solids.items():
            if name.startswith("neck ") and any(_boxes_meet(p, solid) and (p ^ solid).volume() * 1e6 > 0.001 for p in parts.values()):
                found.add(name)
        for style, back in back_solids.items():
            if any(_boxes_meet(parts[pose], back[pose]) and (parts[pose] ^ back[pose]).volume() * 1e6 > 0.001 for pose in hair.LENGTH_POSES):
                found.add("back " + style)
        for style, (whole, fits) in gear.items():
            mode = headgear.HAIR[style]
            if mode == "full":
                worn = fits[h] if style in headgear.BANDS else headgear.placed(whole, fits[h])
            else:
                worn = whole
            for turn in HEAD_TURNS:
                if "headgear " + style in found:
                    break
                for sign in ((1.0, -1.0) if turn else (1.0,)):
                    placed = apply(worn, head_local_placed(turn * sign))
                    if any(_boxes_meet(placed, p) and (placed ^ p).volume() * 1e6 > 0.001 for p in shown):
                        found.add("headgear " + style)
                        break
        out[h] = sorted(found)
    return out


def length_cap_clipping(lengths, head_styles, report, shows):
    """Each long hair's length, in every pose, against its own cap and cut
    cap as the head turns all the way either side: below the cap's lower
    edge, how far it goes into the cap, and in `shows`, how much of its top
    tucked up inside the cap comes out of it."""
    worst = 0.0
    for h, parts in lengths.items():
        for cap_name in ("hair " + h, "hair %s cut" % h):
            for turn in signed(HEAD_TURNS):
                placed = apply(head_styles[cap_name], head_local_placed(turn))
                for pose, part in parts.items():
                    name = "hair %s length" % h + ("" if pose == "standing" else " " + pose)
                    below = part.trim_by_plane([0.0, -1.0, 0.0], -hair.NAPE_Y)
                    volume = (placed ^ below).volume() * 1e6 if _boxes_meet(placed, below) else 0.0
                    worst = max(worst, volume)
                    if volume > 0.001:
                        report.append({"pose": "%s, head turned %+.2f" % (pose, turn), "a": name, "b": cap_name, "cm3": round(volume, 4)})
                    # Above the cap's lower edge, give or take its simplifying.
                    tuck = part.trim_by_plane([0.0, 1.0, 0.0], hair.NAPE_Y + GAP + 0.002)
                    volume = (tuck - placed).volume() * 1e6
                    if volume > 0.001:
                        shows.append({"pose": "%s, head turned %+.2f" % (pose, turn), "a": name, "b": cap_name, "cm3": round(volume, 4)})
    return worst


def clipping(solids, style_solids, gear, torso_solids, arm_solids, leg_solids, back_solids, lengths):
    """Everything against everything it can meet, in every pose. Torso and
    arm styles that are only printed have the figure's own shape, so only
    those with raised bits are checked apart. Every leg style is checked:
    its hips and legs against each other, the torso, the arms and hands, the
    raised torsos and arms, and sitting in a kart, the seat."""
    poses = []

    def rest(targets, astride=False):
        return [F.swing_to(side, targets[side], astride) for side in (0, 1)]

    poses.append(("standing, hands resting", False, False, rest(STANDING_REST), (0.0, 0.0, -1.0)))
    for sway in (-0.06, 0.06):
        swings = [(a + sway * (1 if side == 0 else -1), s) for side, (a, s) in enumerate(rest(STANDING_REST))]
        poses.append(("standing, arms swaying %+.2f" % sway, False, False, swings, (0.0, 0.0, -1.0)))
    poses.append(("seated, hands resting", True, False, rest(SEATED_REST), (0.0, 0.0, -1.0)))
    # Holding a wheel or bars anywhere from just over the lap to up high.
    for degrees in range(45, 121, 15):
        a = math.radians(degrees)
        poses.append(("seated, arms swung %d degrees" % degrees, True, False, [(a, 0.0), (a, 0.0)], (0.0, 0.0, 1.0)))
    for degrees in (55, 75, 100):
        a = math.radians(degrees)
        poses.append(("astride, arms swung %d degrees" % degrees, True, "astride", [(a, 0.3), (a, 0.3)], (0.0, 0.0, 1.0)))
        poses.append(("feet forward, arms swung %d degrees" % degrees, True, "forward", [(a, 0.3), (a, 0.3)], (0.0, 0.0, 1.0)))
    poses.append(("cheering", True, False, [(math.pi * 0.6, 0.0), (math.pi * 0.6, 0.0)], (0.0, 1.0, 0.0)))

    report = []
    worst = 0.0
    still = dict(solids)
    still["head"] = head()
    head_styles = {k: v for k, v in style_solids.items() if k.split(" ")[0] in HEAD_SLOTS}
    style_solids = {k: v for k, v in style_solids.items() if k not in head_styles}
    for style, solid in style_solids.items():
        for b in STYLE_STILL[style.split(" ")[0]]:
            volume = (solid ^ still[b]).volume() * 1e6
            worst = max(worst, volume)
            if volume > 0.001:
                report.append({"pose": "any pose", "a": style, "b": b, "cm3": round(volume, 4)})
    raised_torsos = {"torso " + k: whole for k, (whole, raised) in torso_solids.items() if raised}
    raised_arms = {k: parts for k, (parts, raised) in arm_solids.items() if raised}
    neck_names = list(style_solids)
    for style, solid in raised_torsos.items():
        for b in ["neck", "head"] + neck_names:
            other = still[b] if b in still else style_solids[b]
            if _boxes_meet(solid, other):
                volume = (solid ^ other).volume() * 1e6
                worst = max(worst, volume)
                if volume > 0.001:
                    report.append({"pose": "any pose", "a": style, "b": b, "cm3": round(volume, 4)})
    for name, seated, astride, swings, along in poses:
        placed = posed(solids, seated, astride, swings, along)
        pairs = list(PAIRS)
        lean = F.upper_lean(-math.radians(F.ASTRIDE_LEAN) if astride else 0.0)
        for style, solid in style_solids.items():
            placed[style] = apply(solid, lean)
            pairs += [(style, b) for b in STYLE_MOVING[style.split(" ")[0]]]
        for style, solid in raised_torsos.items():
            placed[style] = apply(solid, lean)
            pairs += [(style, b) for b in ("arm_l", "arm_r", "hand_l", "hand_r", "leg_l", "leg_r")]
        for style, parts in raised_arms.items():
            on = place_arms(parts, astride, swings, along)
            for suffix in ("l", "r"):
                a = "arms %s arm_%s" % (style, suffix)
                placed[a] = on["arm_" + suffix]
                pairs += [(a, b) for b in ["torso", "hips", "leg_l", "leg_r", "hand_" + suffix] + neck_names + list(raised_torsos)]
        legs_m = F.legs_astride() if astride else np.hstack([np.eye(3), np.zeros((3, 1))])
        kind = astride if astride else ("seated" if seated else "standing")
        placed["seat"] = SEAT
        movers = ["torso", "arm_l", "arm_r", "hand_l", "hand_r"] + list(raised_torsos) + ["arms %s arm_%s" % (a, sfx) for a in raised_arms for sfx in ("l", "r")]
        for style, parts in leg_solids.items():
            names = ["legs %s hips" % style, "legs %s leg_l" % style, "legs %s leg_r" % style]
            placed[names[0]] = parts["hips"]
            placed[names[1]] = apply(parts[(kind, 0)], legs_m)
            placed[names[2]] = apply(parts[(kind, 1)], legs_m)
            pairs += [(names[0], names[1]), (names[0], names[2]), (names[1], names[2])]
            for n in names:
                # The hips against the torso only when it isn't leaning
                # forward astride, where the figure's own hips meet it.
                pairs += [(n, b) for b in movers if not (astride and n == names[0] and b.startswith("torso"))]
                if kind == "seated":
                    pairs.append((n, "seat"))
        for a, b in pairs:
            if not _boxes_meet(placed[a], placed[b]):
                continue
            volume = (placed[a] ^ placed[b]).volume() * 1e6
            worst = max(worst, volume)
            if volume > 0.001:
                report.append({"pose": name, "a": a, "b": b, "cm3": round(volume, 4)})
    worst = max(worst, back_clipping(back_solids, solids, style_solids, raised_torsos, raised_arms, leg_solids, poses, report))
    # Long hair's length is checked like a back piece, but not against what
    # it's kept apart from.
    apart = length_apart(lengths, style_solids, back_solids, gear, head_styles)
    worst = max(worst, back_clipping(lengths, solids, style_solids, raised_torsos, raised_arms, leg_solids, poses, report, "hair_length", apart))
    shows = []
    worst = max(worst, length_cap_clipping(lengths, head_styles, report, shows))
    upper_styles = dict(style_solids, **raised_torsos)
    # Back pieces against the hair and headgear as the head turns, in every
    # pose they're made for.
    for style, parts in back_solids.items():
        upper_styles["back " + style] = parts["standing"]
        upper_styles["back %s seated" % style] = parts["seated"]
        upper_styles["back %s reclined" % style] = parts["reclined"]
    worst = max(worst, head_clipping(head_styles, solids, upper_styles, poses, report, raised_arms=raised_arms))
    gear_worst, checked, bare_spots = headgear_clipping(gear, head_styles, solids, upper_styles, poses, report, raised_arms)
    worst = max(worst, gear_worst)
    data = {
        "_comment": "Made by tools/characters/make_characters.py: how far the figure's pieces and the styles made there go into each other, in cubic centimetres, in the rig's poses. Only overlaps over 0.001 are listed. 'headgear_hair' lists the hair each headgear was checked against, and 'uncovered' where a hat leaves the top edge of the cut hair under it showing, in degrees round the head. Torso and arm styles that are only printed have the figure's own shape; those in 'raised' have raised bits and are checked on their own. Back pieces are checked in each pose in the variant made for it, and against every kart seat (seated, and reclined in the lay-down seat) and a motorbike's saddle and tail astride; 'seats' lists them. Long hair's length is checked like a back piece ('hair_length'), and against its own cap as the head turns, below the cap's lower edge; 'tuck_shows' is how much of the top of the length, tucked up inside the cap, comes out of it as the head turns, by hair and turn, over 0.001; 'apart' lists, for each, the neck pieces, back pieces and headgear it goes into, which the game doesn't wear with it.",
        "seats": [s[0] for s in SEATS] + ["saddle"],
        "figure": json.load(open(F.OUT)),
        "limit_cm3": LIMIT_CM3,
        "poses": [p[0] for p in poses],
        "styles": sorted(list(style_solids) + list(head_styles) + ["headgear " + k for k in gear] + ["torso " + k for k in torso_solids] + ["arms " + k for k in arm_solids] + ["legs " + k for k in leg_solids] + ["back " + k for k in back_solids] + ["hair %s length" % k for k in lengths]),
        "raised": sorted(list(raised_torsos) + ["arms " + k for k in raised_arms]),
        "headgear_hair": checked,
        "apart": apart,
        "uncovered": bare_spots,
        "worst_cm3": round(worst, 4),
        "overlaps": report,
        "tuck_shows": shows,
    }
    data["figure"].pop("_comment", None)
    with open(CLIPPING, "w") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")
    print("clipping: worst %.4f cm3 over %d poses" % (worst, len(poses)))
    for u in bare_spots:
        print("  UNCOVERED %s over hair %s at %s" % (u["headgear"], u["hair"], u["degrees"]))
    for r in report:
        flag = "CLIPS" if r["cm3"] > LIMIT_CM3 else "touch"
        print("  %s %-34s %s / %s %.4f cm3" % (flag, r["pose"], r["a"], r["b"], r["cm3"]))
    for r in shows:
        print("  tuck shows %-30s %s / %s %.4f cm3" % (r["pose"], r["a"], r["b"], r["cm3"]))
    for h, pieces in apart.items():
        print("  apart: %s length from %s" % (h, ", ".join(pieces) or "nothing"))
    return apart



if __name__ == "__main__":
    F.write()
    make()
