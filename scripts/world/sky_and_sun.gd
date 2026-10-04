class_name SkyAndSun
extends RefCounted

## The sky and the sun (or the moon), for any scene that needs lighting. On
## its own it's the same bright daytime look everywhere. A race passes its
## Conditions, and the sky, the sun and the soft light everywhere follow the
## time of day, with the weather laid over the top.

## How each time of day looks: where the sun is (how far down it points and
## which way), its colour and strength, the sky's colours and how far to
## take the course's own sky towards them, the soft light everywhere, and the
## shadows. At night the "sun" is the moon, dimmer and bluer, with fainter
## shadows that don't reach as far.
const TIMES := {
	"morning": {"pitch": -24.0, "yaw": 80.0, "colour": "#ffd9b0", "energy": 0.95, "top": "#7fa6d8", "horizon": "#ffd6ae", "mix": 0.55, "ambient": 0.55},
	"day": {"pitch": -55.0, "yaw": 35.0, "colour": "#ffffff", "energy": 1.1, "top": "#3d7fd6", "horizon": "#b9d6f2", "mix": 0.0, "ambient": 0.6},
	"evening": {"pitch": -18.0, "yaw": -100.0, "colour": "#ffb066", "energy": 1.0, "top": "#4f72b8", "horizon": "#ffb878", "mix": 0.6, "ambient": 0.5},
	"dusk": {"pitch": -8.0, "yaw": -110.0, "colour": "#ff7a50", "energy": 0.45, "top": "#2c3a66", "horizon": "#e07a5a", "mix": 0.9, "ambient": 0.35},
	"night": {"pitch": -40.0, "yaw": 150.0, "colour": "#9fb4ff", "energy": 0.25, "top": "#070b1a", "horizon": "#1a2440", "mix": 1.0, "ambient": 0.45, "ambient_colour": "#4a5a80", "shadow_opacity": 0.5, "shadow_reach": 40.0},
}
## The grey of a cloudy sky, and how far the weather takes the sky to it.
const OVERCAST := Color("#8a939e")
const CLOUDY := {"rain": 0.92, "storm": 1.0, "snow": 0.85}
## How much darker a cloudy sky is than a clear one.
const GLOOM := {"rain": 0.8, "storm": 0.6, "snow": 1.05}
## How much of the sun gets through the clouds.
const SUN_THROUGH := {"rain": 0.3, "storm": 0.2, "snow": 0.45, "fog": 0.6, "dust": 0.5}
## How thick the fog is, and its colour, if not the sky's at the horizon.
const FOG := {"fog": 0.02, "storm": 0.008, "rain": 0.004, "snow": 0.006, "dust": 0.025}
const DUST := Color("#c8a070")


## What a scene's lighting is made of, so something like a lightning flash
## can brighten it for a moment and put it back.
class Lights:
	var environment: Environment
	var sun: DirectionalLight3D
	var sun_energy := 1.0
	var ambient_energy := 0.6


## Pass a backdrop colour for an indoor scene like the garage. The sky still
## lights things, but you see the plain colour behind them. A track's theme
## can pass its own sky colours, top and horizon, as colour strings. Indoors,
## pass the colour of the lights, so the soft light everywhere is that and not
## the blue of the sky. A race passes its conditions too.
static func add_to(parent: Node, shadow_distance := 60.0, backdrop := Color.TRANSPARENT, sky_colours: Array = [], lights := Color.TRANSPARENT, conditions: Conditions = null) -> Lights:
	var top := Color(sky_colours[0]) if sky_colours.size() > 0 else Color("#3d7fd6")
	var horizon := Color(sky_colours[1]) if sky_colours.size() > 1 else Color("#b9d6f2")
	var look: Dictionary = TIMES.day
	var weather := "clear"
	if conditions != null and not conditions.indoor and lights.a <= 0.0:
		look = TIMES[conditions.time]
		weather = conditions.weather
	top = top.lerp(Color(look.top), look.mix)
	horizon = horizon.lerp(Color(look.horizon), look.mix)
	# Clouds grey the sky over, keeping it as dark as the time of day.
	var cloudy: float = CLOUDY.get(weather, 0.0)
	if cloudy > 0.0:
		var gloom: float = GLOOM.get(weather, 1.0)
		top = top.lerp(OVERCAST * gloom * top.get_luminance() / OVERCAST.get_luminance(), cloudy)
		horizon = horizon.lerp(OVERCAST * gloom * horizon.get_luminance() / OVERCAST.get_luminance(), cloudy)
	if weather == "dust":
		var dust := DUST * clampf(horizon.get_luminance() * 1.4, 0.15, 1.0)
		top = top.lerp(dust, 0.7)
		horizon = horizon.lerp(dust, 0.85)

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_horizon_color = horizon
	# Below the horizon, which you only see from up high past the edge of the
	# ground, fade to a soft grey instead of the default dark brown.
	sky_material.ground_bottom_color = horizon.darkened(0.3)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	if backdrop.a > 0.0:
		env.background_mode = Environment.BG_COLOR
		env.background_color = backdrop
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Under cloud the light comes from all over the sky instead of the sun.
	env.ambient_light_energy = look.ambient + (0.1 if cloudy > 0.0 else 0.0)
	if look.has("ambient_colour"):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(look.ambient_colour)
	if lights.a > 0.0:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = lights
		env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var thickness: float = FOG.get(weather, 0.0)
	if thickness > 0.0:
		env.fog_enabled = true
		env.fog_density = thickness
		env.fog_light_color = horizon
		env.fog_sky_affect = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(look.pitch, look.yaw, 0.0)
	sun.light_color = Color(look.colour)
	if weather == "dust":
		sun.light_color = sun.light_color.lerp(Color("#ffb070"), 0.5)
	sun.light_energy = look.energy * SUN_THROUGH.get(weather, 1.0)
	# Heavy cloud leaves no real shadows, which saves drawing them too.
	sun.shadow_enabled = weather not in ["rain", "storm"] and Graphics.shadows() > 0.0
	sun.shadow_opacity = look.get("shadow_opacity", 1.0) * (0.6 if cloudy > 0.0 or weather in ["fog", "dust"] else 1.0)
	sun.directional_shadow_max_distance = minf(shadow_distance, look.get("shadow_reach", shadow_distance)) * maxf(Graphics.shadows(), 0.1)
	parent.add_child(sun)

	# What the world's shaders need to know: how wet the road is, how much
	# snow lies about and whether the lamps are on (see BrickShaders). Every
	# scene sets them, so the garage after a rainy race is dry again.
	var lit := conditions if conditions != null and lights.a <= 0.0 else Conditions.clear_day()
	RenderingServer.global_shader_parameter_set("wet", lit.wet())
	RenderingServer.global_shader_parameter_set("snow", lit.snow())
	RenderingServer.global_shader_parameter_set("lamps_on", 1.0 if lit.dark() else 0.0)

	var made := Lights.new()
	made.environment = env
	made.sun = sun
	made.sun_energy = sun.light_energy
	made.ambient_energy = env.ambient_light_energy
	return made
