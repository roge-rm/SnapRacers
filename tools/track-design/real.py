import json, math, subprocess, sys
name = sys.argv[1]
pick = json.load(open("picks.json"))[name]
lines = [l for l in json.load(open(name + ".json")) if l["id"] in pick]
pts = [p for l in lines for p in l["points"]]
xs, ys = [p[0] for p in pts], [p[1] for p in pts]
minx, miny = min(xs), min(ys)
size = 700
sc = (size - 80) / max(max(xs) - minx, max(ys) - miny)
X = lambda v: 40 + (v - minx) * sc
Y = lambda v: 40 + (v - miny) * sc
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="white"/>' % (size, size)]
# 16 m grid at the game's scale (0.62), so I can count tiles.
g = 16 / 0.62
x = minx
while x < max(xs):
    svg.append('<line x1="%.1f" y1="0" x2="%.1f" y2="%d" stroke="#eee"/>' % (X(x), X(x), size)); x += g
y = miny
while y < max(ys):
    svg.append('<line x1="0" y1="%.1f" x2="%d" y2="%.1f" stroke="#eee"/>' % (Y(y), size, Y(y))); y += g
for l in lines:
    p = l["points"]
    svg.append('<polyline points="%s" fill="none" stroke="#c4281c" stroke-width="5"/>' % " ".join("%.1f,%.1f" % (X(a), Y(b)) for a, b in p))
    for i in range(0, len(p) - 1, max(1, len(p) // 14)):
        (ax, ay), (bx, by) = p[i], p[i + 1]
        mx, my, d = (ax + bx) / 2, (ay + by) / 2, math.hypot(bx - ax, by - ay) or 1
        ux, uy = (bx - ax) / d, (by - ay) / d
        svg.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="black"/>' % (X(mx) + ux * 9, Y(my) + uy * 9, X(mx) - uy * 5, Y(my) + ux * 5, X(mx) + uy * 5, Y(my) - ux * 5))
    svg.append('<circle cx="%.1f" cy="%.1f" r="8" fill="#0d69ab"/>' % (X(p[0][0]), Y(p[0][1])))
svg.append('<text x="10" y="24" font-size="20" font-family="sans-serif">%s, %.0f m real (grid = one game tile at 0.62 scale)</text>' % (name, sum(l["length"] for l in lines)))
svg.append("</svg>")
open(name + "_real.svg", "w").write("\n".join(svg))
subprocess.run(["convert", name + "_real.svg", name + "_real.png"], check=True, stderr=subprocess.DEVNULL)
