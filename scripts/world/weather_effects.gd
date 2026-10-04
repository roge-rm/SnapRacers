class_name WeatherEffects
extends Node3D

## What the weather does around a race besides the sky and the road: rain,
## snow or dust falling, the sound of it, and in a storm, lightning that
## lights everything up for a moment and the thunder after it.

## The sound of each weather, all the way through the race.
const SOUNDS := {"rain": "loop/rain", "storm": "loop/storm", "snow": "loop/gale", "dust": "loop/gale"}
const VOLUME := {"rain": -8.0, "storm": -5.0, "snow": -12.0, "dust": -7.0}
## How long between flashes of lightning, in seconds, and how long the
## thunder takes to reach you.
const FLASH_EVERY := [6.0, 14.0]
const THUNDER_AFTER := [0.4, 2.0]
## How bright a flash makes the sun and the soft light everywhere.
const FLASH := 4.0

var _lights: SkyAndSun.Lights
var _rng := RandomNumberGenerator.new()
var _next_flash := 0.0
## Time since the flash began, or below 0 between flashes.
var _flashing := -1.0
var _thunder_in := -1.0


func _init(conditions: Conditions, lights: SkyAndSun.Lights) -> void:
	_lights = lights
	_rng.seed = conditions.seed
	if conditions.indoor:
		return
	var falling := Precipitation.for_weather(conditions.weather)
	if falling != null:
		add_child(falling)
	if SOUNDS.has(conditions.weather) and Sounds.audible() and not Sounds.hushed:
		var sound := AudioStreamPlayer.new()
		sound.stream = Sounds.stream(SOUNDS[conditions.weather])
		sound.volume_db = VOLUME[conditions.weather]
		sound.bus = Sounds.EFFECTS_BUS
		sound.autoplay = true
		sound.finished.connect(sound.play)
		add_child(sound)
	if conditions.weather == "storm" and lights != null:
		_next_flash = _rng.randf_range(FLASH_EVERY[0], FLASH_EVERY[1]) * 0.5
	else:
		set_process(false)


func _process(delta: float) -> void:
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in < 0.0:
			Sounds.play("fx/thunder", -2.0, _rng.randf_range(0.85, 1.1))
	if _flashing >= 0.0:
		_flashing += delta
		# Two quick flashes, then it fades back.
		var bright := 0.0
		if _flashing < 0.08:
			bright = 1.0
		elif _flashing < 0.16:
			bright = 0.2
		elif _flashing < 0.22:
			bright = 0.8
		elif _flashing < 0.6:
			bright = 0.8 * (1.0 - (_flashing - 0.22) / 0.38)
		else:
			_flashing = -1.0
		_light(bright)
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_flashing = 0.0
		_thunder_in = _rng.randf_range(THUNDER_AFTER[0], THUNDER_AFTER[1])
		_next_flash = _rng.randf_range(FLASH_EVERY[0], FLASH_EVERY[1])


func _light(bright: float) -> void:
	_lights.sun.light_energy = _lights.sun_energy * (1.0 + (FLASH - 1.0) * bright)
	_lights.environment.ambient_light_energy = _lights.ambient_energy * (1.0 + 1.5 * bright)
