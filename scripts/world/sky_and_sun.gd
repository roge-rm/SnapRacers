class_name SkyAndSun
extends RefCounted

## The same bright daytime sky and sun, for any scene that needs lighting.


## Pass a backdrop colour for an indoor scene like the garage. The sky still
## lights things, but you see the plain colour behind them.
static func add_to(parent: Node, shadow_distance := 60.0, backdrop := Color.TRANSPARENT) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#3d7fd6")
	sky_material.sky_horizon_color = Color("#b9d6f2")
	sky_material.ground_horizon_color = Color("#b9d6f2")
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
