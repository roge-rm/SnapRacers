class_name Graphics
extends RefCounted

## How much the game draws, for slower phones. High is everything. Medium and
## Low draw the 3D view at a lower resolution (the menus and the race's
## words stay sharp), smooth no edges, cut the shadows short or leave them
## out, leave out some far off scenery, the crowd and the studs, fade the
## rest of the scenery in nearer, let less rain and snow fall, throw headlight beams only from nearby karts (Low
## only from yours) and make fewer drift sparks and boost flames (Low no tire
## smoke). Nothing you could drive into is ever left out, so it
## races the same whatever anyone picks.

const LEVELS := ["low", "medium", "high"]
const DEFAULT := "high"
const NAMES := {"low": "Low", "medium": "Medium", "high": "High"}

const SETTINGS := {
	"high": {"scale": 1.0, "smooth": true, "shadows": 1.0, "scenery": 1.0, "falling": 1.0, "crowd": true, "studs": true, "beams": 40.0, "drift_fx": 1.0, "drift_smoke": true, "far": 180.0},
	"medium": {"scale": 0.85, "smooth": false, "shadows": 0.5, "scenery": 0.6, "falling": 0.6, "crowd": true, "studs": true, "beams": 16.0, "drift_fx": 0.6, "drift_smoke": true, "far": 150.0},
	"low": {"scale": 0.6, "smooth": false, "shadows": 0.0, "scenery": 0.3, "falling": 0.35, "crowd": false, "studs": false, "beams": 0.0, "drift_fx": 0.35, "drift_smoke": false, "far": 100.0},
}

## The level the game's set to, from the settings (see Game.graphics()).
static var level := DEFAULT


static func value(key: String) -> Variant:
	return SETTINGS.get(level, SETTINGS[DEFAULT])[key]


## Sets a view to draw its 3D at this level: its resolution and edge
## smoothing. The race's own words and buttons are drawn on top at full
## resolution.
static func apply_to(view: Viewport) -> void:
	view.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	view.scaling_3d_scale = value("scale")
	view.msaa_3d = Viewport.MSAA_2X if value("smooth") else Viewport.MSAA_DISABLED
	RenderingServer.global_shader_parameter_set("studs_on", 1.0 if value("studs") else 0.0)


## How far shadows reach, from how far they would at High. 0 for none.
static func shadows() -> float:
	return value("shadows")


## How far off, in metres, far-off scenery and the crowd have faded out. They
## fade in over the last stretch before it (see BrickShaders.fading()).
static func far() -> float:
	return value("far")


## How far another kart's headlight beam still draws, in metres. 0 is only
## the kart this camera is following. The glowing lenses stay on either way.
static func beams() -> float:
	return value("beams")


## Whether this far-off thing, which nothing can drive into, gets drawn. The
## same spot always gives the same answer, so it doesn't come and go.
static func draws_far(at: Vector3) -> bool:
	var share: float = value("scenery")
	if share >= 1.0:
		return true
	var h := absi(hash(Vector2i(roundi(at.x), roundi(at.z)))) % 1000
	return h < share * 1000.0
