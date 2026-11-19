class_name CourseLamps
extends RefCounted

## Lighting a course at night. Real lamps would each mean drawing everything
## near them again, too slow for a phone, so instead the pool of light under
## every lamp is painted once into a map of the course seen from above. The
## road, the ground and the scenery each look up how lit they are there (see
## BrickShaders), but only below the lamp, so a bridge's underside or a roof
## above a lamp stays dark.

## How far a lamp's light reaches, in metres, and how bright it is.
const REACH := 34.0
const BRIGHTNESS := 1.0
## The map holds light up to this bright, where pools overlap. The shaders
## scale it back up (see BrickShaders).
const MOST := 2.0
## The warm white of the lamps.
const COLOUR := Color("#ffe6c0")
## The map's size in pixels, and how far past the outermost lamps it reaches.
const SIZE := 256
const MARGIN := 30.0
## The lamps' height is kept in the map as a fraction of this.
const HIGHEST := 64.0


## The map, and where it is: [x, z of its corner, 1 / its width, 1 / its
## depth], for the shaders. Null with no lamps. `colours` gives the colour of
## any lamp that isn't COLOUR, by its index in `lamps`.
static func light_map(lamps: Array[Vector3], colours := {}) -> Array:
	if lamps.is_empty():
		return []
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for lamp in lamps:
		low = low.min(Vector2(lamp.x, lamp.z))
		high = high.max(Vector2(lamp.x, lamp.z))
	low -= Vector2.ONE * MARGIN
	high += Vector2.ONE * MARGIN
	var span := high - low
	var per_pixel := maxf(span.x, span.y) / SIZE
	var light := PackedFloat32Array()
	light.resize(SIZE * SIZE)
	var tops := PackedFloat32Array()
	tops.resize(SIZE * SIZE)
	# Where coloured lamps reach, the colour is the mix of the lamps there,
	# weighted by how much light each gives.
	var tints := {}
	var reach := ceili(REACH / per_pixel)
	for n in lamps.size():
		var lamp := lamps[n]
		var tint: Color = colours.get(n, COLOUR)
		var cx := int((lamp.x - low.x) / per_pixel)
		var cy := int((lamp.z - low.y) / per_pixel)
		for y in range(maxi(cy - reach, 0), mini(cy + reach + 1, SIZE)):
			for x in range(maxi(cx - reach, 0), mini(cx + reach + 1, SIZE)):
				var d := Vector2(x - cx, y - cy).length() * per_pixel
				if d >= REACH:
					continue
				var i := y * SIZE + x
				# Bright under the lamp and right across the road, fading
				# out towards the edge of the pool.
				var fall := 1.0 - (d / REACH) * (d / REACH)
				if not colours.is_empty():
					var mix: Color = tints.get(i, Color(0.0, 0.0, 0.0, 0.0))
					tints[i] = mix + Color(tint.r, tint.g, tint.b, 1.0) * fall * fall
				light[i] = minf(light[i] + fall * fall * BRIGHTNESS, MOST)
				tops[i] = maxf(tops[i], lamp.y)
	var bytes := PackedByteArray()
	bytes.resize(SIZE * SIZE * 4)
	for i in SIZE * SIZE:
		var colour := COLOUR
		if tints.has(i):
			var mix: Color = tints[i]
			colour = Color(mix.r / mix.a, mix.g / mix.a, mix.b / mix.a)
		bytes[i * 4] = int(colour.r * light[i] / MOST * 255.0)
		bytes[i * 4 + 1] = int(colour.g * light[i] / MOST * 255.0)
		bytes[i * 4 + 2] = int(colour.b * light[i] / MOST * 255.0)
		bytes[i * 4 + 3] = int(clampf(tops[i] / HIGHEST, 0.0, 1.0) * 255.0)
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, bytes)
	var size := Vector2(per_pixel * SIZE, per_pixel * SIZE)
	return [ImageTexture.create_from_image(image), Vector4(low.x, low.y, 1.0 / size.x, 1.0 / size.y)]


## Lights the course around these lamps, for the shaders.
static func light(lamps: Array[Vector3], colours := {}) -> void:
	var made := light_map(lamps, colours)
	if made.is_empty():
		RenderingServer.global_shader_parameter_set("lamp_area", Vector4.ZERO)
		return
	RenderingServer.global_shader_parameter_set("lamp_map", made[0])
	RenderingServer.global_shader_parameter_set("lamp_area", made[1])
