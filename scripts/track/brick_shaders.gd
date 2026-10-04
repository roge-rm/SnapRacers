class_name BrickShaders
extends RefCounted

## The shaders that make the track look like it's built from bricks. They draw
## tile seams on the road, studs on the curbs, wall tops and the baseplate
## ground, and courses of bricks on the walls, the road's edges and the
## pillars. It's all drawn by the shader instead of modelled, so a whole track
## stays cheap enough for a phone. The studs fade out in the distance, where
## they'd only shimmer.
##
## Each shader is made once and kept (see TrackBuilder.shader_for) so the
## phone only ever compiles it once.

const STUD := 0.25 # stud spacing, in metres
const STUD_RADIUS := 0.3 # of the spacing
const BRICK_HEIGHT := 0.3
const BRICK_LENGTH := 1.0 # a 1x4 brick

## Shared bits for seams, a hash so each tile is a little different, and
## studs.
const COMMON := """
// From the race's weather (see SkyAndSun): how wet the road is and how much
// snow lies about, from 0 to 1, and whether the lamps are on.
global uniform float wet;
global uniform float snow;
global uniform float lamps_on;
// The lamps' light seen from above (see CourseLamps), and where that map is:
// its corner's x and z, then one over its width and depth.
global uniform sampler2D lamp_map;
global uniform vec4 lamp_area;
const vec3 SNOW = vec3(0.82, 0.85, 0.9);

// How much lamp light falls here, at night, below the lamp it comes from.
vec3 lamp_light(vec3 at) {
	if (lamps_on < 0.5 || lamp_area.z <= 0.0) {
		return vec3(0.0);
	}
	vec2 uv = (at.xz - lamp_area.xy) * lamp_area.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec3(0.0);
	}
	vec4 l = texture(lamp_map, uv);
	float top = l.a * 64.0;
	return l.rgb * (1.0 - smoothstep(top - 1.0, top + 0.5, at.y));
}

float seam(float coord, float period, float width) {
	float f = fract(coord / period) * period;
	float d = min(f, period - f);
	float aa = fwidth(coord);
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + aa, d);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth blotches from 0 to 1, for where snow has settled.
float blotches(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Studs on a flat surface. Each has a lighter round top, a darker ring around
// its edge, and a small shadow on the side away from the sun. p is in metres.
vec3 studs(vec2 p, vec3 col) {
	vec2 uv = p / 0.25;
	vec2 fw = fwidth(uv);
	float blur = max(fw.x, fw.y);
	float detail = clamp(1.0 - blur * 3.0, 0.0, 1.0);
	if (detail <= 0.0) {
		return col;
	}
	vec2 c = fract(uv) - 0.5;
	float r = 0.3;
	float edge = max(blur, 0.02);
	float d = length(c);
	float top = 1.0 - smoothstep(r - edge, r + edge, d);
	float ds = length(c - vec2(0.08, 0.1));
	float shadow = (1.0 - smoothstep(r - edge, r + edge, ds)) * (1.0 - top);
	float ring = smoothstep(r - 0.07, r, d) * top;
	vec3 lit = col;
	lit *= mix(1.0, 0.72, shadow * detail);
	lit = mix(lit, col * 1.15, top * detail * 0.85);
	lit *= mix(1.0, 0.86, ring * detail);
	return lit;
}
"""

## For the track itself. UV is (distance along the track, across or up the
## surface) in metres, UV2.x says which surface this is, and COLOR its colour.
const TRACK := """
shader_type spatial;
varying vec3 world;
""" + COMMON + """
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float kind = UV2.x;
	vec2 p = UV;
	// It has to be rough, or the sky's reflection turns everything blue.
	float rough = 0.8;
	if (kind < 0.5 || kind > 4.5) {
		// The road is smooth 2x4 tiles, staggered, each a little different.
		// Its white edge lines are the same tiles, painted.
		float row = floor(p.y / 0.5);
		float along = p.x + mod(row, 2.0) * 0.5;
		col *= 0.94 + 0.12 * hash(vec2(floor(along), row));
		float s = max(seam(p.y, 0.5, 0.014), seam(along, 1.0, 0.014));
		col *= 1.0 - 0.5 * s;
		rough = 0.85;
		// Wet, it's darker and shines. In snow it's been cleared, so it's wet
		// with only a few flecks of snow left.
		col *= mix(1.0, 0.62, wet);
		rough = mix(rough, 0.25, wet);
		col = mix(col, SNOW, snow * 0.7 * smoothstep(0.78, 0.95, blotches(p * 0.6)));
	} else if (kind < 1.5) {
		// The curbs are smooth blocks with ridges across them, which catch the
		// light, and a seam where one block meets the next.
		float ridge = fract(p.x / 0.6);
		col *= 0.82 + 0.28 * smoothstep(0.0, 0.5, ridge) * (1.0 - smoothstep(0.5, 1.0, ridge));
		col *= 1.0 - 0.45 * seam(p.x, 1.2, 0.02);
		col = mix(col, SNOW, snow * 0.45);
	} else if (kind < 3.5) {
		// The walls and the road's edges are staggered courses of 1x4 bricks.
		// Wall bricks alternate red and white.
		float course = floor(p.y / 0.3);
		float along = p.x + mod(course, 2.0) * 0.5;
		vec2 brick = vec2(floor(along), course);
		if (kind > 2.5 && mod(brick.x + course, 2.0) > 0.5) {
			col = pow(vec3(0.95), vec3(2.2));
		}
		col *= 0.95 + 0.08 * hash(brick);
		float s = max(seam(p.y, 0.3, 0.012), seam(along, 1.0, 0.012));
		col *= 1.0 - 0.45 * s;
	} else {
		// The top of a wall has studs, under any snow.
		col = mix(studs(p, col), SNOW, snow * 0.95);
	}
	ALBEDO = col;
	// Under a lamp the dark road needs a little more than its own colour
	// lit, or it hardly shows.
	vec3 lamp = lamp_light(world);
	EMISSION = col * lamp + lamp * 0.2;
	ROUGHNESS = rough;
	SPECULAR = mix(0.25, 0.5, wet);
}
"""

## For the ground. It's a baseplate, studs and all, with faint seams where one
## baseplate meets the next.
const BASEPLATE := """
shader_type spatial;
// It's picked as sRGB and turned linear below, like the vertex colours. (The
// phone's renderer doesn't convert a source_color hint.)
uniform vec4 colour = vec4(0.18, 0.48, 0.2, 1.0);
varying vec3 world;
""" + COMMON + """
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = pow(colour.rgb, vec3(2.2));
	col = studs(world.xz, col);
	float s = max(seam(world.x, 8.0, 0.025), seam(world.z, 8.0, 0.025));
	col *= 1.0 - 0.3 * s;
	col *= mix(1.0, 0.85, wet);
	col = mix(col, SNOW, snow * (0.9 + 0.08 * blotches(world.xz * 0.2)));
	ALBEDO = col;
	EMISSION = col * lamp_light(world) * 0.9;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
"""

## For everything built of bricks around the track, like pillars, trees and
## buildings. It works in world space, so it suits things lined up with the
## stud grid. The colour comes from the instance, and the first number of the
## instance's custom data picks what kind of surface it is:
##   0 bricks, with studs on top and courses of bricks up the sides
##   1 a building, with rows of windows up the sides and a flat roof
##   2 smooth tiles with no studs, for roofs, signs and the like
##   3 glowing, for lava and lights
##   4 water, smooth and shiny with slow ripples
##   5 plain plastic, for parts that move
##   6 a lamp, which shines when it's dark
const BLOCK := """
shader_type spatial;
varying vec3 world;
varying vec3 world_normal;
varying flat float pattern;
""" + COMMON + """
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	pattern = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec3 col = pow(COLOR.rgb, vec3(2.2));
	float rough = 0.8;
	float spec = 0.25;
	bool top = world_normal.y > 0.7;
	bool side = !top && world_normal.y > -0.7;
	float across = abs(world_normal.x) > abs(world_normal.z) ? world.z : world.x;
	if (pattern < 0.5) {
		if (top) {
			col = studs(world.xz, col);
		} else if (side) {
			// Staggered courses of 1x2 bricks.
			float course = floor(world.y / 0.3);
			float along = across + mod(course, 2.0) * 0.25;
			col *= 0.95 + 0.08 * hash(vec2(course, floor(along / 0.5)));
			float s = max(seam(world.y, 0.3, 0.012), seam(along, 0.5, 0.012));
			col *= 1.0 - 0.45 * s;
		}
	} else if (pattern < 1.5) {
		if (side) {
			// A window every metre across and every 1.5 m up.
			vec2 cell = vec2(fract(across), fract(world.y / 1.5));
			float glass = step(0.18, cell.x) * step(cell.x, 0.82) * step(0.25, cell.y) * step(cell.y, 0.85);
			vec3 pane = pow(vec3(0.32, 0.45, 0.58), vec3(2.2)) * (0.8 + 0.4 * hash(floor(vec2(across, world.y / 1.5))));
			col = mix(col, pane, glass);
			rough = mix(rough, 0.2, glass);
			spec = mix(spec, 0.6, glass);
			// At night some of them have the lights on inside.
			float home = step(0.55, hash(floor(vec2(across, world.y / 1.5)) + 3.7));
			EMISSION += vec3(1.0, 0.72, 0.4) * 0.8 * glass * home * lamps_on;
		}
	} else if (pattern < 2.5) {
		col *= 1.0 - 0.3 * max(seam(across, 1.0, 0.012), seam(world.y, 1.0, 0.012));
		rough = 0.5;
	} else if (pattern < 3.5) {
		float flicker = 0.8 + 0.2 * sin(TIME * 2.0 + world.x * 0.4 + world.z * 0.3);
		EMISSION = col * 1.6 * flicker;
		rough = 0.9;
	} else if (pattern > 5.5) {
		// A lamp, which shines when it's dark.
		EMISSION = col * 2.5 * lamps_on;
		col *= mix(1.0, 0.6, lamps_on);
		rough = 0.4;
	} else if (pattern > 4.5) {
		// Plain plastic, for parts that move.
		rough = 0.5;
	} else {
		float wave = sin(world.x * 0.6 + TIME * 0.8) * sin(world.z * 0.5 - TIME * 0.6);
		col *= 0.85 + 0.15 * wave;
		rough = 0.12;
		spec = 0.6;
	}
	// Snow covers anything flat that isn't glowing or water, and dusts the
	// sides.
	if (pattern < 2.5 || (pattern > 4.5 && pattern < 5.5)) {
		col = mix(col, SNOW, snow * (top ? 0.95 : (side ? 0.2 : 0.0)));
	}
	EMISSION += col * lamp_light(world) * 0.9;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""
