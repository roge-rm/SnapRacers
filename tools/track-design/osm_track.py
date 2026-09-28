#!/usr/bin/env python3
"""Draws the raceway ways OpenStreetMap has near a place, for looking at a
real kart circuit's shape.

Usage: osm_track.py <name> <lat> <lon> [radius_m]
Writes <name>.png (and <name>.json with the raw geometry in metres).
"""
import json, math, subprocess, sys, urllib.parse, urllib.request

name, lat, lon = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
radius = int(sys.argv[4]) if len(sys.argv) > 4 else 700
q = '[out:json][timeout:40];(way["highway"="raceway"](around:%d,%f,%f);way["sport"="karting"](around:%d,%f,%f););out geom;' % (radius, lat, lon, radius, lat, lon)
data = None
for server in ['https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter']:
    try:
        req = urllib.request.Request(server, data=urllib.parse.urlencode({'data': q}).encode(), headers={'User-Agent': 'SnapRacers-research/1.0'})
        data = json.load(urllib.request.urlopen(req, timeout=60))
        break
    except Exception as e:
        print('server failed', server, e)
if data is None:
    sys.exit(1)
ways = [e for e in data['elements'] if e.get('geometry')]
if not ways:
    print('no ways found')
    sys.exit(1)
k = 111320.0
lines = []
for w in ways:
    pts = [((g['lon'] - lon) * k * math.cos(math.radians(lat)), -(g['lat'] - lat) * k) for g in w['geometry']]
    length = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
    lines.append({'id': w['id'], 'tags': w.get('tags', {}), 'points': pts, 'length': length})
    print('way %d %s  %.0f m, %d points' % (w['id'], json.dumps(w.get('tags', {}))[:150], length, len(pts)))
json.dump(lines, open(name + '.json', 'w'))
xs = [p[0] for l in lines for p in l['points']]
ys = [p[1] for l in lines for p in l['points']]
minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
size = 800
scale = (size - 80) / max(maxx - minx, maxy - miny, 1)
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="white"/>' % (size, size)]
colours = ['#c4281c', '#0d69ab', '#237841', '#f2a000', '#7a3fa0', '#555555']
for i, l in enumerate(lines):
    d = ' '.join('%.1f,%.1f' % (40 + (x - minx) * scale, 40 + (y - miny) * scale) for x, y in l['points'])
    svg.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="6" stroke-linejoin="round"/>' % (d, colours[i % len(colours)]))
    x0, y0 = l['points'][0]
    svg.append('<circle cx="%.1f" cy="%.1f" r="7" fill="black"/>' % (40 + (x0 - minx) * scale, 40 + (y0 - miny) * scale))
    svg.append('<text x="%.1f" y="%.1f" font-size="14" fill="black">%d</text>' % (46 + (x0 - minx) * scale, 34 + (y0 - miny) * scale, i))
# A 100 m scale bar.
svg.append('<line x1="40" y1="%d" x2="%.1f" y2="%d" stroke="black" stroke-width="3"/><text x="40" y="%d" font-size="14">100 m</text>' % (size - 20, 40 + 100 * scale, size - 20, size - 26))
svg.append('</svg>')
open(name + '.svg', 'w').write('\n'.join(svg))
subprocess.run(['convert', name + '.svg', name + '.png'], check=True)
print('wrote', name + '.png')
