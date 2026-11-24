extends SceneTree

## Every drawer piece has its mirror or reverse in the drawer, except the named ones.

# Pieces with no pair on purpose.
const NO_PAIR := {
	"type=jump": "straight on, nothing to mirror",
	"type=crossing": "straight on, nothing to mirror",
	"type=split|length=2": "symmetric split",
	"type=split|length=3": "symmetric split",
	"type=split|length=4|island=38": "symmetric split",
	"type=jump_split|side=both": "symmetric split",
}

var failures := 0


func _initialize() -> void:
	var keys := {}
	for spec in TrackCatalogue.specs():
		keys[TrackCatalogue._spec_key(spec)] = true
	var missing := []
	for spec in TrackCatalogue.specs():
		var key := TrackCatalogue._spec_key(spec)
		if NO_PAIR.has(key):
			continue
		for other in _pairs(spec):
			if not keys.has(TrackCatalogue._spec_key(other)):
				missing.append("%s needs %s" % [key, TrackCatalogue._spec_key(other)])
	for line in missing:
		print("  FAIL  " + line)
	var ok := missing.is_empty()
	var stale := NO_PAIR.keys().filter(func(k): return not keys.has(k))
	print(("  ok    " if ok else "  FAIL  ") + "every drawer piece has its pair (%d missing)" % missing.size())
	print(("  ok    " if stale.is_empty() else "  FAIL  ") + "the no-pair list names real pieces")
	quit(0 if ok and stale.is_empty() else 1)


## The pieces that must also be in the drawer: left/right mirror, up/down reverse, hump heights.
func _pairs(spec: Dictionary) -> Array:
	var out := []
	for field in ["turn", "side"]:
		if spec.has(field) and spec[field] in ["left", "right"]:
			var m := spec.duplicate()
			m[field] = "right" if spec[field] == "left" else "left"
			out.append(m)
	if spec.has("rise"):
		var r := spec.duplicate()
		r.rise = -spec.rise
		out.append(r)
	if spec.type == "crest":
		for h in [1.5, 3.0]:
			var c := spec.duplicate()
			c.height = h
			out.append(c)
	return out
