class_name FacePrint
extends RefCounted

## Paints a minifig face onto a texture that wraps around the head, the way a
## real minifig's face is printed. It has two black eyes with a glint, a
## mouth, and brows or freckles or shades on some faces.
##
## Each feature is a shape measured in metres on the head's surface (across
## the face, around the curve, and up from the middle), drawn with a soft edge
## so it stays smooth up close. Only the face itself is painted pixel by
## pixel. The rest is filled with the skin colour in one go.

const WIDE := 512
const TALL := 256
const INK := Color("#1b1b1b")


static func paint(style: String, skin: Color, radius: float, height: float) -> ImageTexture:
	var image := Image.create(WIDE, TALL, true, Image.FORMAT_RGBA8)
	image.fill(skin)
	var across := WIDE / (TAU * radius) # pixels per metre around the head
	var up := TALL / height # pixels per metre up it
	var shapes := _shapes(style)
	# Only the patch the face is in.
	for py in range(int(TALL * 0.5 - 0.08 * up), int(TALL * 0.5 + 0.07 * up)):
		for px in range(int(WIDE * 0.5 - 0.1 * across), int(WIDE * 0.5 + 0.1 * across)):
			var s := (px + 0.5 - WIDE * 0.5) / across
			var y := (TALL * 0.5 - py - 0.5) / up
			var colour := skin
			for shape in shapes:
				var d: float = shape[0].call(Vector2(s, y))
				var cover := clampf(0.5 - d * across, 0.0, 1.0)
				if cover > 0.0:
					colour = colour.lerp(shape[1], cover)
			image.set_pixel(px, py, colour)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## The face's features in drawing order, each [distance function, colour].
## A distance function says how far a point is outside the shape, in metres,
## negative inside.
static func _shapes(style: String) -> Array:
	var out := []
	var eye_y := 0.02
	var wink := style == "cheeky"
	if style == "shades":
		out.append([func(p): return _box(p, Vector2(0.0, 0.022), Vector2(0.07, 0.017), 0.012), INK])
		out.append([func(p): return _box(p, Vector2(0.035, 0.03), Vector2(0.02, 0.004), 0.003), Color(1, 1, 1, 0.7)])
	else:
		for side in [-1.0, 1.0]:
			if wink and side > 0.0:
				out.append([func(p): return _arc(p, Vector2(0.04 * side, eye_y - 0.006), 0.012, deg_to_rad(20.0), deg_to_rad(160.0), 0.0022), INK])
				continue
			out.append([func(p): return _ellipse(p, Vector2(0.04 * side, eye_y), Vector2(0.011, 0.016)), INK])
			out.append([func(p): return _circle(p, Vector2(0.04 * side + 0.004, eye_y + 0.007), 0.0035), Color.WHITE])
	match style:
		"determined":
			for side in [-1.0, 1.0]:
				out.append([func(p): return _segment(p, Vector2(0.022 * side, 0.043), Vector2(0.058 * side, 0.052), 0.0035), INK])
			out.append([func(p): return _segment(p, Vector2(-0.025, -0.03), Vector2(0.025, -0.03), 0.003), INK])
		"cheeky":
			out.append([func(p): return _arc(p, Vector2(-0.04, 0.04), 0.02, deg_to_rad(30.0), deg_to_rad(150.0), 0.003), INK])
			out.append([func(p): return _arc(p, Vector2(0.01, 0.0), 0.04, deg_to_rad(215.0), deg_to_rad(330.0), 0.003), INK])
		"grin":
			out.append([func(p): return maxf(_circle(p, Vector2(0.0, 0.0), 0.05), p.y + 0.012), INK])
			out.append([func(p): return maxf(_circle(p, Vector2(0.0, 0.0), 0.046), maxf(p.y + 0.014, -p.y - 0.026)), Color.WHITE])
		"freckles":
			out.append([func(p): return _arc(p, Vector2(0.0, 0.025), 0.05, deg_to_rad(210.0), deg_to_rad(330.0), 0.003), INK])
			for side in [-1.0, 1.0]:
				for k in 3:
					out.append([func(p): return _circle(p, Vector2((0.05 + (k % 2) * 0.012) * side, -0.008 - k * 0.007), 0.0028), Color("#a86f4c")])
		_:
			out.append([func(p): return _arc(p, Vector2(0.0, 0.025), 0.05, deg_to_rad(210.0), deg_to_rad(330.0), 0.003), INK])
	return out


static func _circle(p: Vector2, centre: Vector2, radius: float) -> float:
	return p.distance_to(centre) - radius


static func _ellipse(p: Vector2, centre: Vector2, radii: Vector2) -> float:
	var q := (p - centre) / radii
	return (q.length() - 1.0) * minf(radii.x, radii.y)


static func _box(p: Vector2, centre: Vector2, half: Vector2, round: float) -> float:
	var q := (p - centre).abs() - half + Vector2(round, round)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - round


static func _segment(p: Vector2, a: Vector2, b: Vector2, half_width: float) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) - half_width


## A curved line, part of a circle around `centre` from one angle to the
## other (in radians, 0 pointing right, going counterclockwise), `half_width`
## thick on either side.
static func _arc(p: Vector2, centre: Vector2, radius: float, from: float, to: float, half_width: float) -> float:
	var q := p - centre
	var angle := fposmod(atan2(q.y, q.x), TAU)
	if angle >= from and angle <= to:
		return absf(q.length() - radius) - half_width
	var end_a := centre + Vector2(cos(from), sin(from)) * radius
	var end_b := centre + Vector2(cos(to), sin(to)) * radius
	return minf(p.distance_to(end_a), p.distance_to(end_b)) - half_width
