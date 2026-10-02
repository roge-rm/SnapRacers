class_name FacePrint
extends RefCounted

## Paints a brick figure face onto a texture that wraps around the head, the way a
## toy figure's face is printed. A face is eyes, brows, a mouth and sometimes
## extras like freckles (see FACES), with any facial hair printed underneath in
## its own colour.
##
## They're meant to be cute, with big eyes set low and wide apart, a big shine
## and a little one in each, rosy cheeks on nearly every face and small mouths.
##
## A face can also be painted in a mood (see MOODS), which swaps its eyes,
## brows or mouth for a moment, like blinking, looking surprised when they're
## hit or happy when they pass someone.
##
## Each feature is a shape measured in metres on the head's surface, drawn with
## a soft edge so it stays smooth up close, and only painted over its own small
## patch so even a face with a beard is quick to make.

const WIDE := 512
const TALL := 256
const INK := Color("#1b1b1b")
const LIPS := Color("#c4283c")
const CHEEKS := Color("#f08c8c")

## The moods a face can be painted in.
const MOODS := ["blink", "surprised", "happy", "laugh", "cross"]

## What each face is made of: [eyes, brows, mouth, extras].
const FACES := {
	"smile": ["dots", "", "smile", []],
	"grin": ["dots", "", "grin", []],
	"determined": ["dots", "determined", "flat", []],
	"cheeky": ["wink", "raised_left", "smirk", []],
	"freckles": ["dots", "", "smile", ["freckles"]],
	"shades": ["shades", "", "smile", []],
	"excited": ["dots", "raised", "open", []],
	"frown": ["dots", "sad", "frown", []],
	"smirk": ["dots", "raised_left", "smirk", []],
	"sleepy": ["sleepy", "", "small", []],
	"surprised": ["round", "raised", "o", []],
	"angry": ["dots", "angry", "gritted", []],
	"lashes": ["lashes", "thin", "lipstick", []],
	"blush": ["dots", "", "smile", ["blush"]],
	"glasses": ["glasses", "", "smile", []],
	"tongue": ["wink", "", "tongue", []],
	"fangs": ["dots", "angry", "fangs", []],
	"scar": ["dots", "determined", "flat", ["scar"]],
	"big_eyes": ["big", "", "smile", []],
	"laughing": ["closed", "raised", "laugh", []],
	"nervous": ["dots", "sad", "wobbly", ["sweat"]],
	"monocle": ["dots", "raised_left", "small", ["monocle"]],
}


## The face texture for this face, skin, and facial hair in its colour, in a
## mood or its own look.
static func paint(style: String, skin: Color, radius: float, height: float, beard := "none", beard_colour := INK, mood := "") -> ImageTexture:
	return ImageTexture.create_from_image(paint_image(style, skin, radius, height, beard, beard_colour, mood))


## The same as an Image, which is safe to make on another thread.
static func paint_image(style: String, skin: Color, radius: float, height: float, beard := "none", beard_colour := INK, mood := "") -> Image:
	var image := Image.create_empty(WIDE, TALL, true, Image.FORMAT_RGBA8)
	image.fill(skin)
	var across := WIDE / (TAU * radius) # pixels per metre around the head
	var up := TALL / height # pixels per metre up it
	for shape in _beard(beard, beard_colour) + _shapes(style, mood):
		_draw(image, shape, across, up)
	image.generate_mipmaps()
	return image


## Whether this face looks any different in this mood. Shades hide the eyes,
## so they never blink, and closed eyes are already closed.
static func changes(style: String, mood: String) -> bool:
	var eyes: String = FACES.get(style, FACES.smile)[0]
	if mood == "blink":
		return eyes != "shades" and eyes != "closed"
	return MOODS.has(mood)


## Paints one shape, [distance function, colour, patch], blending its soft
## edge into what's already there.
static func _draw(image: Image, shape: Array, across: float, up: float) -> void:
	var patch: Rect2 = shape[2].grow(0.004)
	var colour: Color = shape[1]
	var x0 := clampi(int(WIDE * 0.5 + patch.position.x * across), 0, WIDE - 1)
	var x1 := clampi(int(WIDE * 0.5 + patch.end.x * across) + 1, 0, WIDE - 1)
	var y0 := clampi(int(TALL * 0.5 - patch.end.y * up), 0, TALL - 1)
	var y1 := clampi(int(TALL * 0.5 - patch.position.y * up) + 1, 0, TALL - 1)
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var p := Vector2((px + 0.5 - WIDE * 0.5) / across, (TALL * 0.5 - py - 0.5) / up)
			var d: float = shape[0].call(p)
			var cover := clampf(0.5 - d * across, 0.0, 1.0) * colour.a
			if cover > 0.0:
				image.set_pixel(px, py, image.get_pixel(px, py).lerp(Color(colour, 1.0), cover))


## The face's features in drawing order.
static func _shapes(style: String, mood := "") -> Array:
	var parts: Array = FACES.get(style, FACES.smile)
	var eyes: String = parts[0]
	var brows: String = parts[1]
	var mouth: String = parts[2]
	var extras: Array = parts[3].duplicate()
	# Glasses are frames over ordinary eyes, so they stay on whatever the
	# eyes do.
	if eyes == "glasses":
		eyes = "dots"
		extras.append("frames")
	if not extras.has("blush") and eyes != "shades":
		extras.append("blush")
	var hidden := eyes == "shades"
	match mood:
		"blink":
			if not hidden:
				eyes = "closed"
		"surprised":
			if not hidden and eyes != "big":
				eyes = "round"
			brows = "raised"
			mouth = "o"
		"happy":
			if mouth != "fangs":
				mouth = "grin"
			if brows in ["angry", "sad", "determined"]:
				brows = ""
		"laugh":
			if not hidden:
				eyes = "closed"
			brows = "raised"
			mouth = "laugh"
		"cross":
			brows = "determined"
			mouth = "flat"
	var out := []
	out.append_array(_extras(extras, true))
	out.append_array(_eyes(eyes))
	out.append_array(_brows(brows))
	# A small mouth, a little closer to the eyes.
	for shape in _mouth(mouth):
		out.append(_scaled(shape, Vector2(0.0, -0.03), 0.72, Vector2(0.0, 0.004)))
	out.append_array(_extras(extras, false))
	return out


## A shape made `scale` times the size around `centre`, then moved.
static func _scaled(shape: Array, centre: Vector2, scale: float, move: Vector2) -> Array:
	var d: Callable = shape[0]
	var patch: Rect2 = shape[2]
	var at := centre + move
	return [
		func(p: Vector2) -> float: return d.call(centre + (p - at) / scale) * scale,
		shape[1],
		Rect2(at + (patch.position - centre) * scale, patch.size * scale),
	]


static func _eyes(kind: String) -> Array:
	var out := []
	var y := 0.02
	match kind:
		"shades":
			out.append(_box(Vector2(0.0, 0.022), Vector2(0.07, 0.017), 0.012, INK))
			out.append(_box(Vector2(0.035, 0.03), Vector2(0.02, 0.004), 0.003, Color(1, 1, 1, 0.7)))
			return out
		"closed":
			for side in [-1.0, 1.0]:
				out.append(_arc(Vector2(0.045 * side, 0.006), 0.016, deg_to_rad(20.0), deg_to_rad(160.0), 0.003, INK))
			return out
		"big":
			for side in [-1.0, 1.0]:
				out.append(_ellipse(Vector2(0.038 * side, y + 0.004), Vector2(0.021, 0.027), Color.WHITE))
				out.append(_ring(Vector2(0.038 * side, y + 0.004), Vector2(0.021, 0.027), 0.002, INK))
				out.append(_ellipse(Vector2(0.034 * side, y), Vector2(0.01, 0.014), INK))
				out.append(_circle(Vector2(0.034 * side + 0.004, y + 0.006), 0.003, Color.WHITE))
			return out
	var gap := 0.045
	y = 0.012
	for side in [-1.0, 1.0]:
		if kind == "wink" and side > 0.0:
			out.append(_arc(Vector2(gap * side, y - 0.006), 0.014, deg_to_rad(20.0), deg_to_rad(160.0), 0.0026, INK))
			continue
		var size := Vector2(0.018, 0.023) if kind != "round" else Vector2(0.019, 0.019)
		if kind == "sleepy":
			# Heavy lids, so only the bottom half of each eye shows.
			var at := Vector2(gap * side, y)
			out.append(_custom(func(p): return maxf(_ellipse_d(p, at, size), p.y - at.y - 0.002), Rect2(at - size, size * 2.0), INK))
			out.append(_segment(at + Vector2(-0.021, 0.003), at + Vector2(0.021, 0.003), 0.003, INK))
			continue
		out.append(_ellipse(Vector2(gap * side, y), size, INK))
		# A big shine and a little one, which is most of what makes eyes cute.
		out.append(_circle(Vector2(gap * side + 0.006, y + 0.008), 0.0065, Color.WHITE))
		out.append(_circle(Vector2(gap * side - 0.005, y - 0.008), 0.0026, Color.WHITE))
		match kind:
			"lashes":
				for k in 3:
					var a := deg_to_rad(110.0 - k * 25.0) if side < 0.0 else deg_to_rad(70.0 + k * 25.0)
					var from := Vector2(gap * side, y) + Vector2(cos(a), sin(a)) * size.y
					out.append(_segment(from, from + Vector2(cos(a), sin(a)) * 0.008, 0.0016, INK))
	return out


static func _brows(kind: String) -> Array:
	var out := []
	match kind:
		"determined":
			for side in [-1.0, 1.0]:
				out.append(_segment(Vector2(0.022 * side, 0.043), Vector2(0.058 * side, 0.052), 0.0035, INK))
		"angry":
			for side in [-1.0, 1.0]:
				out.append(_segment(Vector2(0.02 * side, 0.04), Vector2(0.058 * side, 0.055), 0.0042, INK))
		"sad":
			for side in [-1.0, 1.0]:
				out.append(_segment(Vector2(0.022 * side, 0.052), Vector2(0.058 * side, 0.042), 0.003, INK))
		"raised":
			for side in [-1.0, 1.0]:
				out.append(_arc(Vector2(0.04 * side, 0.04), 0.02, deg_to_rad(40.0), deg_to_rad(140.0), 0.0028, INK))
		"raised_left":
			out.append(_arc(Vector2(-0.04, 0.042), 0.02, deg_to_rad(30.0), deg_to_rad(150.0), 0.003, INK))
		"thin":
			for side in [-1.0, 1.0]:
				out.append(_arc(Vector2(0.04 * side, 0.036), 0.02, deg_to_rad(55.0), deg_to_rad(125.0), 0.0018, INK))
	return out


static func _mouth(kind: String) -> Array:
	var out := []
	match kind:
		"grin":
			out.append(_custom(func(p): return maxf(p.distance_to(Vector2.ZERO) - 0.05, p.y + 0.012), Rect2(-0.05, -0.05, 0.1, 0.04), INK))
			out.append(_custom(func(p): return maxf(p.distance_to(Vector2.ZERO) - 0.046, maxf(p.y + 0.014, -p.y - 0.026)), Rect2(-0.046, -0.026, 0.092, 0.013), Color.WHITE))
		"flat":
			out.append(_segment(Vector2(-0.025, -0.03), Vector2(0.025, -0.03), 0.003, INK))
		"smirk":
			out.append(_arc(Vector2(0.01, 0.0), 0.04, deg_to_rad(215.0), deg_to_rad(330.0), 0.003, INK))
		"open":
			out.append(_custom(func(p): return maxf(p.distance_to(Vector2(0.0, -0.012)) - 0.036, p.y + 0.018), Rect2(-0.036, -0.048, 0.072, 0.03), INK))
			out.append(_ellipse(Vector2(0.0, -0.04), Vector2(0.018, 0.007), LIPS))
		"frown":
			out.append(_arc(Vector2(0.0, -0.06), 0.035, deg_to_rad(40.0), deg_to_rad(140.0), 0.003, INK))
		"small":
			out.append(_arc(Vector2(0.0, -0.005), 0.025, deg_to_rad(235.0), deg_to_rad(305.0), 0.0028, INK))
		"o":
			out.append(_ellipse(Vector2(0.0, -0.032), Vector2(0.01, 0.013), INK))
		"gritted":
			out.append(_box(Vector2(0.0, -0.032), Vector2(0.03, 0.011), 0.004, INK))
			out.append(_box(Vector2(0.0, -0.032), Vector2(0.027, 0.008), 0.003, Color.WHITE))
			for k in 5:
				out.append(_segment(Vector2(-0.018 + k * 0.009, -0.04), Vector2(-0.018 + k * 0.009, -0.024), 0.001, INK))
			out.append(_segment(Vector2(-0.027, -0.032), Vector2(0.027, -0.032), 0.001, INK))
		"lipstick":
			out.append(_custom(func(p): return maxf(p.distance_to(Vector2(0.0, 0.02)) - 0.05, -(p.distance_to(Vector2(0.0, 0.03)) - 0.05)), Rect2(-0.035, -0.035, 0.07, 0.02), LIPS))
		"tongue":
			out.append(_arc(Vector2(0.0, 0.025), 0.05, deg_to_rad(210.0), deg_to_rad(330.0), 0.003, INK))
			out.append(_custom(func(p): return maxf(_ellipse_d(p, Vector2(0.012, -0.034), Vector2(0.011, 0.013)), p.y + 0.024), Rect2(0.001, -0.047, 0.022, 0.023), LIPS))
		"fangs":
			out.append(_custom(func(p): return maxf(p.distance_to(Vector2.ZERO) - 0.05, p.y + 0.012), Rect2(-0.05, -0.05, 0.1, 0.04), INK))
			for k in 6:
				var x := -0.035 + k * 0.014
				var tip := Vector2(x, -0.03)
				out.append(_custom(func(p): return _triangle(p, Vector2(x - 0.006, -0.0135), Vector2(x + 0.006, -0.0135), tip), Rect2(x - 0.006, -0.03, 0.012, 0.017), Color.WHITE))
		"laugh":
			out.append(_custom(func(p): return maxf(p.distance_to(Vector2(0.0, 0.0)) - 0.045, p.y + 0.01), Rect2(-0.045, -0.045, 0.09, 0.035), INK))
			out.append(_ellipse(Vector2(0.0, -0.036), Vector2(0.022, 0.008), LIPS))
		"wobbly":
			for k in 4:
				var a := Vector2(-0.028 + k * 0.014, -0.03 + (0.004 if k % 2 == 0 else -0.004))
				var b := Vector2(-0.014 + k * 0.014, -0.03 + (-0.004 if k % 2 == 0 else 0.004))
				out.append(_segment(a, b, 0.0025, INK))
		_:
			out.append(_arc(Vector2(0.0, 0.025), 0.05, deg_to_rad(210.0), deg_to_rad(330.0), 0.003, INK))
	return out


## Extras on the face. The ones that go under the eyes and mouth (like
## cheeks) are drawn first.
static func _extras(extras: Array, under: bool) -> Array:
	var out := []
	for extra in extras:
		match [extra, under]:
			["blush", true]:
				for side in [-1.0, 1.0]:
					out.append(_ellipse(Vector2(0.07 * side, -0.01), Vector2(0.02, 0.012), Color(CHEEKS, 0.6)))
			["freckles", false]:
				for side in [-1.0, 1.0]:
					for k in 3:
						out.append(_circle(Vector2((0.05 + (k % 2) * 0.012) * side, -0.008 - k * 0.007), 0.0028, Color("#a86f4c")))
			["scar", false]:
				out.append(_segment(Vector2(-0.055, 0.045), Vector2(-0.028, -0.008), 0.0022, Color("#8a4a3a")))
				for k in 3:
					var at := Vector2(-0.051 + k * 0.009, 0.036 - k * 0.018)
					out.append(_segment(at + Vector2(-0.005, -0.002), at + Vector2(0.005, 0.002), 0.0016, Color("#8a4a3a")))
			["sweat", false]:
				out.append(_custom(func(p): return minf(p.distance_to(Vector2(0.075, 0.035)) - 0.007, _triangle(p, Vector2(0.069, 0.037), Vector2(0.081, 0.037), Vector2(0.075, 0.056))), Rect2(0.068, 0.028, 0.014, 0.029), Color("#8fd3f4")))
			["frames", false]:
				for side in [-1.0, 1.0]:
					out.append(_ring(Vector2(0.045 * side, 0.012), Vector2(0.027, 0.027), 0.0026, INK))
				out.append(_segment(Vector2(-0.018, 0.016), Vector2(0.018, 0.016), 0.0022, INK))
			["monocle", false]:
				out.append(_ring(Vector2(0.045, 0.012), Vector2(0.027, 0.027), 0.0028, Color("#c9a227")))
				out.append(_segment(Vector2(0.07, 0.0), Vector2(0.076, -0.06), 0.0012, Color("#c9a227")))
	return out


## Facial hair, printed under the face's features in its own colour.
static func _beard(style: String, c: Color) -> Array:
	var out := []
	var moustache := func(width: float, depth: float, y := -0.008) -> Array:
		return [_custom(func(p): return minf(_ellipse_d(p, Vector2(-width * 0.45, y), Vector2(width * 0.55, depth)), _ellipse_d(p, Vector2(width * 0.45, y), Vector2(width * 0.55, depth))), Rect2(-width, y - depth, width * 2.0, depth * 2.0), c)]
	match style:
		"stubble":
			out.append(_custom(func(p): return _stubble(p), Rect2(-0.085, -0.1, 0.17, 0.09), Color(c, 0.45)))
		"pencil":
			out.append(_segment(Vector2(-0.024, -0.012), Vector2(0.024, -0.012), 0.0022, c))
		"big":
			out.append_array(moustache.call(0.04, 0.013))
		"handlebar":
			out.append_array(moustache.call(0.032, 0.009))
			for side in [-1.0, 1.0]:
				out.append(_arc(Vector2(0.05 * side, 0.0), 0.012, deg_to_rad(180.0 if side > 0.0 else -60.0), deg_to_rad(240.0 if side > 0.0 else 0.0), 0.003, c))
		"walrus":
			# Big and drooping, right down over the mouth.
			for side: float in [-1.0, 1.0]:
				out.append(_ellipse(Vector2(0.024 * side, -0.02), Vector2(0.034, 0.022), c))
		"zigzag":
			var points := [Vector2(-0.05, -0.004), Vector2(-0.035, -0.018), Vector2(-0.02, -0.006), Vector2(0.0, -0.016), Vector2(0.02, -0.006), Vector2(0.035, -0.018), Vector2(0.05, -0.004)]
			for k in points.size() - 1:
				out.append(_segment(points[k], points[k + 1], 0.0045, c))
		"goatee":
			out.append(_custom(func(p): return maxf(_ellipse_d(p, Vector2(0.0, -0.058), Vector2(0.03, 0.036)), p.y + 0.042), Rect2(-0.03, -0.094, 0.06, 0.052), c))
			out.append(_segment(Vector2(-0.02, -0.012), Vector2(0.02, -0.012), 0.004, c))
		"chinstrap":
			out.append(_custom(func(p): return absf(_ellipse_d(p, Vector2(0.0, -0.01), Vector2(0.09, 0.085))) - 0.006 if p.y < -0.01 else 1.0, Rect2(-0.1, -0.1, 0.2, 0.09), c))
		"full", "long", "braided":
			out.append(_custom(func(p): return maxf(_ellipse_d(p, Vector2(0.0, -0.03), Vector2(0.095, 0.085)), p.y + 0.005), Rect2(-0.095, -0.1, 0.19, 0.095), c))
			out.append_array(moustache.call(0.036, 0.011))
		"sideburns":
			for side in [-1.0, 1.0]:
				out.append(_box(Vector2(0.105 * side, 0.01), Vector2(0.012, 0.04), 0.005, c))
		"mutton":
			for side in [-1.0, 1.0]:
				out.append(_custom(func(p): return minf(_box_d(p, Vector2(0.1 * side, 0.01), Vector2(0.014, 0.04), 0.005), _ellipse_d(p, Vector2(0.075 * side, -0.035), Vector2(0.035, 0.028))), Rect2(-0.12 if side < 0.0 else 0.04, -0.065, 0.08, 0.12), c))
			out.append_array(moustache.call(0.03, 0.009))
		"fu_manchu":
			for side in [-1.0, 1.0]:
				out.append(_segment(Vector2(0.004 * side, -0.01), Vector2(0.03 * side, -0.014), 0.003, c))
				out.append(_segment(Vector2(0.03 * side, -0.014), Vector2(0.034 * side, -0.075), 0.0028, c))
		"horseshoe":
			out.append_array(moustache.call(0.032, 0.009))
			for side in [-1.0, 1.0]:
				out.append(_segment(Vector2(0.03 * side, -0.012), Vector2(0.032 * side, -0.07), 0.005, c))
		"short_beard":
			out.append(_custom(func(p): return maxf(_ellipse_d(p, Vector2(0.0, -0.035), Vector2(0.085, 0.07)), p.y + 0.012), Rect2(-0.085, -0.1, 0.17, 0.09), Color(c, 0.85)))
			out.append_array(moustache.call(0.03, 0.009))
		"soul_patch":
			out.append(_ellipse(Vector2(0.0, -0.05), Vector2(0.006, 0.007), c))
		"pointy":
			out.append(_custom(func(p): return _triangle(p, Vector2(-0.028, -0.045), Vector2(0.028, -0.045), Vector2(0.0, -0.098)), Rect2(-0.028, -0.098, 0.056, 0.053), c))
			out.append_array(moustache.call(0.032, 0.009))
		"moustache_beard":
			out.append_array(moustache.call(0.04, 0.012))
			out.append(_custom(func(p): return maxf(_ellipse_d(p, Vector2(0.0, -0.058), Vector2(0.038, 0.04)), p.y + 0.04), Rect2(-0.038, -0.098, 0.076, 0.058), c))
	return out


# Shapes, as [distance function, colour, the patch it can be inside]. A
# distance function says how far a point is outside the shape, in metres,
# negative inside.

static func _custom(d: Callable, patch: Rect2, colour: Color) -> Array:
	return [d, colour, patch]


static func _circle(centre: Vector2, radius: float, colour: Color) -> Array:
	return [func(p): return p.distance_to(centre) - radius, colour, Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0)]


static func _ellipse(centre: Vector2, radii: Vector2, colour: Color) -> Array:
	return [func(p): return _ellipse_d(p, centre, radii), colour, Rect2(centre - radii, radii * 2.0)]


static func _ring(centre: Vector2, radii: Vector2, half_width: float, colour: Color) -> Array:
	return [func(p): return absf(_ellipse_d(p, centre, radii)) - half_width, colour, Rect2(centre - radii, radii * 2.0).grow(half_width)]


static func _box(centre: Vector2, half: Vector2, round: float, colour: Color) -> Array:
	return [func(p): return _box_d(p, centre, half, round), colour, Rect2(centre - half, half * 2.0)]


static func _segment(a: Vector2, b: Vector2, half_width: float, colour: Color) -> Array:
	var patch := Rect2(a, Vector2.ZERO).expand(b).grow(half_width)
	return [func(p): return _segment_d(p, a, b, half_width), colour, patch]


## A curved line, part of a circle around `centre` from one angle to the
## other (in radians, 0 pointing right, going counterclockwise), `half_width`
## thick on either side.
static func _arc(centre: Vector2, radius: float, from: float, to: float, half_width: float, colour: Color) -> Array:
	var d := func(p: Vector2) -> float:
		var q := p - centre
		var angle := fposmod(atan2(q.y, q.x), TAU)
		var a0 := fposmod(from, TAU)
		var a1 := a0 + (to - from)
		if (angle >= a0 and angle <= a1) or (angle + TAU >= a0 and angle + TAU <= a1):
			return absf(q.length() - radius) - half_width
		var end_a := centre + Vector2(cos(from), sin(from)) * radius
		var end_b := centre + Vector2(cos(to), sin(to)) * radius
		return minf(p.distance_to(end_a), p.distance_to(end_b)) - half_width
	return [d, colour, Rect2(centre - Vector2(radius, radius), Vector2(radius, radius) * 2.0).grow(half_width)]


static func _ellipse_d(p: Vector2, centre: Vector2, radii: Vector2) -> float:
	var q := (p - centre) / radii
	return (q.length() - 1.0) * minf(radii.x, radii.y)


static func _box_d(p: Vector2, centre: Vector2, half: Vector2, round: float) -> float:
	var q := (p - centre).abs() - half + Vector2(round, round)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - round


static func _segment_d(p: Vector2, a: Vector2, b: Vector2, half_width: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) - half_width


static func _triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var inside := Geometry2D.is_point_in_polygon(p, PackedVector2Array([a, b, c]))
	var edge := minf(_segment_d(p, a, b, 0.0), minf(_segment_d(p, b, c, 0.0), _segment_d(p, c, a, 0.0)))
	return -edge if inside else edge


## Stubble, little dots over the lower face where a beard would be.
static func _stubble(p: Vector2) -> float:
	if _ellipse_d(p, Vector2(0.0, -0.03), Vector2(0.085, 0.07)) > 0.0 or p.y > -0.004:
		return 1.0
	var cell := (p / 0.0045).floor()
	var noise := fposmod(sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453, 1.0)
	if noise < 0.55:
		return 1.0
	var middle := (cell + Vector2(0.5, 0.5)) * 0.0045
	return p.distance_to(middle) - 0.0011
