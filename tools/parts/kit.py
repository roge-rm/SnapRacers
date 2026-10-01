"""The building blocks for modelling parts.

Everything is in metres, on the game's grid: a stud is 0.25 m across and a
plate 0.1 m high, so a brick is 0.3 m. A part is modelled with the front left
bottom corner of its box at the origin, x across, y up and z toward the back
(the front is -z, the way the game faces). Shapes are manifold3d solids, so
they can be added together and cut out of each other.
"""

import math
import os

import numpy as np
from manifold3d import CrossSection, Manifold

STUD = 0.25
PLATE = 0.1
BRICK = 0.3
FINE = 0.0125  # the game's fine unit: a stud is 20 and a plate 8
STUD_RADIUS = 0.075
STUD_HEIGHT = 0.05
# A hairline gap all round, so parts sitting side by side read as separate.
GAP = 0.002
# How round the edges of a part are.
EDGE = 0.008
ROUND = 20  # sides on a round part


def box(x0, y0, z0, x1, y1, z1, edge=EDGE):
    """A box from one corner to the other, with its edges rounded a little."""
    x0, y0, z0 = x0 + GAP, y0 + GAP * 0.5, z0 + GAP
    x1, y1, z1 = x1 - GAP, y1 - GAP * 0.5, z1 - GAP
    if edge <= 0:
        return Manifold.cube([x1 - x0, y1 - y0, z1 - z0]).translate([x0, y0, z0])
    r = min(edge, (x1 - x0) * 0.45, (y1 - y0) * 0.45, (z1 - z0) * 0.45)
    ball = Manifold.sphere(r, 8)
    corners = [ball.translate([x, y, z]) for x in (x0 + r, x1 - r) for y in (y0 + r, y1 - r) for z in (z0 + r, z1 - r)]
    return Manifold.batch_hull(corners)


def cylinder(radius, height, axis="y", at=(0.0, 0.0, 0.0), sides=ROUND, radius_top=None):
    """A cylinder standing on `at`, along an axis."""
    c = Manifold.cylinder(height, radius, radius if radius_top is None else radius_top, sides)
    if axis == "x":
        c = c.rotate([0, 90, 0])
    elif axis == "y":
        c = c.rotate([-90, 0, 0])
    elif axis == "-z":
        c = c.rotate([180, 0, 0])
    return c.translate(list(at))


def _anticlockwise(points):
    """The same outline, going round anticlockwise, which is the way an
    outline (and not a hole) has to go."""
    area = 0.0
    for k in range(len(points)):
        x0, y0 = points[k]
        x1, y1 = points[(k + 1) % len(points)]
        area += x0 * y1 - x1 * y0
    return list(points) if area > 0 else list(reversed(points))


def profile_x(points, x0, x1):
    """A side view, as (z, y) points going round, pushed out across from x0
    to x1."""
    section = CrossSection([_anticlockwise([(-z, y) for z, y in points])])
    solid = section.extrude(x1 - x0)
    # The extrusion runs along z with the section in x and y, so turn it
    # round: the extrusion is our x, section y is our y, and section x is
    # minus our z (which keeps it a turn and not a mirror image).
    return solid.transform(np.array([[0, 0, 1, x0], [0, 1, 0, 0], [-1, 0, 0, 0]], dtype=float))


def plan_y(points, y0, y1):
    """A top view, as (x, z) points going round, pushed up from y0 to y1."""
    section = CrossSection([_anticlockwise([(x, -z) for x, z in points])])
    solid = section.extrude(y1 - y0)
    # Section x is our x, section y is minus our z, extrusion z is our y.
    return solid.transform(np.array([[1, 0, 0, 0], [0, 0, 1, y0], [0, -1, 0, 0]], dtype=float))


def studs(cells, top, sides=12):
    """Studs on top of a part at height `top`, one in each (x, z) stud cell."""
    out = []
    for i, k in cells:
        out.append(cylinder(STUD_RADIUS, STUD_HEIGHT, "y", ((i + 0.5) * STUD, top - 0.001, (k + 0.5) * STUD), sides))
    return union(out)


def union(parts):
    parts = [p for p in parts if p is not None]
    if not parts:
        return Manifold()
    return Manifold.batch_boolean(parts, manifold_op_add())


def manifold_op_add():
    from manifold3d import OpType
    return OpType.Add


def cut(solid, *holes):
    for h in holes:
        solid = solid - h
    return solid


def grid_cells(across, along):
    return [(i, k) for i in range(across) for k in range(along)]


def save_obj(solid, size, path, sharp=40.0):
    """Writes the part as an OBJ file, centred on the middle of its box (that's
    how the game places parts), with smooth shading except across edges
    sharper than `sharp` degrees."""
    solid = solid.translate([-size[0] * 0.5, -size[1] * 0.5, -size[2] * 0.5])
    solid = solid.calculate_normals(0, sharp)
    mesh = solid.to_mesh()
    props = np.asarray(mesh.vert_properties)
    tris = np.asarray(mesh.tri_verts)
    lines = []
    for p in props:
        lines.append("v %.5f %.5f %.5f" % (p[0], p[1], p[2]))
    for p in props:
        n = p[3:6]
        length = math.sqrt(float(np.dot(n, n))) or 1.0
        lines.append("vn %.4f %.4f %.4f" % (n[0] / length, n[1] / length, n[2] / length))
    for t in tris:
        a, b, c = int(t[0]) + 1, int(t[1]) + 1, int(t[2]) + 1
        lines.append("f %d//%d %d//%d %d//%d" % (a, a, b, b, c, c))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    return len(tris)


def fine(v):
    """Metres to the game's fine unit, rounded off."""
    return [round(x / FINE, 3) for x in v]
