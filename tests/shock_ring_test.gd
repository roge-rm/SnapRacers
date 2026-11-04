extends SceneTree

## A fast kart stays inside the outgoing wave long enough to see it from
## first person. The effect keeps its world origin, reach and short life.

func _initialize() -> void:
	var ring := ShockRing.new()
	root.add_child(ring)
	ring.set_process(false)
	ring.position = Vector3(4.0, 0.3, 5.0)
	var origin := ring.position
	var failed := false
	for age in [0.08, 0.16]:
		ring._process(age - ring._age)
		var ahead: bool = ring._wall.scale.z > 45.0 * age + 0.5
		print(("  ok    " if ahead else "  FAIL  ") + "the outgoing wall is ahead of a fast first person camera at %.2f s" % age)
		failed = failed or not ahead
	ring._process(0.6 - ring._age)
	var bounded := ring.position == origin and ring._wall.scale.z <= ring.reach
	print(("  ok    " if bounded else "  FAIL  ") + "the effect keeps its origin and stays within its reach")
	failed = failed or not bounded
	ring._process(ShockRing.TIME - ring._age)
	var gone := ring.is_queued_for_deletion()
	print(("  ok    " if gone else "  FAIL  ") + "the effect ends after its usual short life")
	failed = failed or not gone
	print("Shock ring checks passed." if not failed else "Shock ring checks failed.")
	quit(1 if failed else 0)
