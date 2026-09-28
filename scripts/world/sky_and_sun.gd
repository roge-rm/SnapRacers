class_name SkyAndSun
extends RefCounted

## The same bright daytime sky and sun, for any scene that needs lighting.


## Pass a backdrop colour for an indoor scene like the garage. The sky still
## lights things, but you see the plain colour behind them. A track's theme
## can pass its own sky colours, top and horizon, as colour strings.
static func add_to(parent: Node, shadow_distance := 60.0, backdrop := Color.TRANSPARENT, sky_colours: Array = []) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(sky_colours[0]) if sky_colours.size() > 0 else Color("#3d7fd6")
	sky_material.sky_horizon_color = Color(sky_colours[1]) if sky_colours.size() > 1 else Color("#b9d6f2")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	# Below the horizon, which you only see from up high past the edge of the
	# ground, fade to a soft grey instead of the default dark brown.
	sky_material.ground_bottom_color = sky_material.sky_horizon_color.darkened(0.3)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	if backdrop.a > 0.0:
		env.background_mode = Environment.BG_COLOR
		env.background_color = backdrop
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = shadow_distance
	parent.add_child(sun)
