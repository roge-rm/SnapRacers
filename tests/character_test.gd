extends SceneTree

## Builds every driver piece, baked a mesh a bone, checks the figure made in
## tools/characters matches the rig and doesn't clip, checks the roster, and
## checks that drivers really do hold the steering wheel and follow it
## around.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/character_test.gd


class Runner:
	extends Node

	var failures := 0
	var tick := 0
	var kart: Kart
	var loose: Kart

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	## How far a hand's middle is from the body's blocks (hips, torso and
	## legs), in the rig's own space.
	func clearance(hand: Vector3, sitting: bool) -> float:
		var R := CharacterRig
		var boxes := [
			AABB(Vector3(-0.19, 0.0, -R.TORSO_DEPTH * 0.5), Vector3(0.38, R.HIPS_TOP, R.TORSO_DEPTH)),
			AABB(Vector3(-R.TORSO_BOTTOM_WIDTH * 0.5, R.HIPS_TOP, -R.TORSO_DEPTH * 0.5), Vector3(R.TORSO_BOTTOM_WIDTH, R.TORSO_HEIGHT, R.TORSO_DEPTH)),
		]
		for sign in [-1.0, 1.0]:
			if sitting:
				boxes.append(AABB(Vector3(sign * R.LEG_X - 0.085, 0.0, -R.LEG_LENGTH), Vector3(0.17, 0.13, R.LEG_LENGTH)))
			else:
				boxes.append(AABB(Vector3(sign * R.LEG_X - 0.085, -R.LEG_LENGTH, -0.065), Vector3(0.17, R.LEG_LENGTH, 0.13)))
		var nearest := INF
		for box in boxes:
			var inside: Vector3 = hand.clamp(box.position, box.end)
			nearest = minf(nearest, hand.distance_to(inside))
		return nearest

	## How many pieces of headgear aren't touching the head or anything that
	## is, by their boxes in the head's space.
	func loose_headgear(rig: CharacterRig) -> int:
		var R := CharacterRig
		var head := AABB(Vector3(-R.HEAD_RADIUS, -R.HEAD_HEIGHT * 0.5, -R.HEAD_RADIUS), Vector3(R.HEAD_RADIUS * 2.0, R.HEAD_HEIGHT, R.HEAD_RADIUS * 2.0)).grow(0.004)
		var boxes := []
		for node in rig._head.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = rig._head.global_transform.affine_inverse() * node.global_transform * node.mesh.get_aabb()
			boxes.append(box.grow(0.002))
		var joined := {}
		var todo := []
		for i in boxes.size():
			if boxes[i].intersects(head):
				joined[i] = true
				todo.append(i)
		while not todo.is_empty():
			var i: int = todo.pop_back()
			for j in boxes.size():
				if not joined.has(j) and boxes[i].intersects(boxes[j]):
					joined[j] = true
					todo.append(j)
		return boxes.size() - joined.size()

	## The same for what's on the torso (the torso's prints, and what's on the
	## neck and back), joined to the torso's block.
	func loose_on_torso(rig: CharacterRig) -> int:
		var R := CharacterRig
		var torso := AABB(Vector3(-R.TORSO_BOTTOM_WIDTH * 0.5, R.HIPS_TOP, -R.TORSO_DEPTH * 0.5), Vector3(R.TORSO_BOTTOM_WIDTH, R.TORSO_HEIGHT + 0.03, R.TORSO_DEPTH)).grow(0.004)
		var boxes := []
		for node in rig.upper().get_children():
			if node is MeshInstance3D:
				boxes.append((node.transform * node.mesh.get_aabb()).grow(0.002))
		var joined := {}
		var todo := []
		for i in boxes.size():
			if boxes[i].intersects(torso):
				joined[i] = true
				todo.append(i)
		while not todo.is_empty():
			var i: int = todo.pop_back()
			for j in boxes.size():
				if not joined.has(j) and boxes[i].intersects(boxes[j]):
					joined[j] = true
					todo.append(j)
		return boxes.size() - joined.size()

	func hand_at(rig: CharacterRig, side: int) -> Vector3:
		return rig._hand[side].global_position

	func _ready() -> void:
		add_child(TestTrack.new())

		# The meshes made in tools/characters are for this rig, and they all
		# loaded with something in them.
		var mismatches := CharacterRig.figure_mismatches()
		check(mismatches.is_empty(), "figure.json matches the rig %s" % [mismatches])
		var empty := []
		var figure: Dictionary = CharacterMesh.made().get("figure", {})
		for piece in figure:
			for sitting in [false, true]:
				var regions := CharacterMesh.figure_regions(piece, sitting)
				for region in regions:
					var mesh: Mesh = regions[region]
					if mesh == null or mesh.get_surface_count() == 0 or mesh.get_aabb().size.length() < 0.01:
						empty.append("%s %s" % [piece, region])
		check(figure.size() >= 10 and empty.is_empty(), "the figure's %d pieces all load %s" % [figure.size(), empty])

		# Every neck piece is made in tools/characters, and its meshes load.
		var missing := []
		for style in CharacterDesign.styles("neck"):
			if style == "none":
				continue
			var entry := CharacterMesh.style("neck", style)
			if entry.is_empty():
				missing.append(style)
				continue
			for region in entry.regions:
				var mesh := CharacterMesh.mesh(entry.regions[region])
				if mesh == null or mesh.get_surface_count() == 0:
					missing.append("%s %s" % [style, region])
		check(missing.is_empty(), "every neck piece is made and loads %s" % [missing])

		# Every hairdo and its cut version for under hats, and the raised
		# facial hair, are made in tools/characters and load.
		missing = []
		var raised := ["full", "long", "braided", "sideburns"]
		for slot in ["hair", "facial_hair"]:
			for style in CharacterDesign.styles(slot):
				if style == "none" or (slot == "facial_hair" and not style in raised):
					continue
				var entry := CharacterMesh.style(slot, style)
				var shapes := [entry.get("regions", {})]
				if slot == "hair":
					shapes.append(entry.get("cut", {}).get("regions", {}))
				for regions in shapes:
					if regions.is_empty():
						missing.append("%s %s" % [slot, style])
					for region in regions:
						var mesh := CharacterMesh.mesh(regions[region])
						if mesh == null or mesh.get_surface_count() == 0:
							missing.append("%s %s %s" % [slot, style, region])
		check(missing.is_empty() and CharacterDesign.styles("hair").size() >= 20 and CharacterDesign.styles("facial_hair").size() >= 20,
				"every hairdo, its cut version and the raised facial hair are made and load %s" % [missing])

		# Every piece of headgear is made in tools/characters and loads, says
		# what hair shows under it, and what's worn on the hair is made for
		# or fits every hairdo.
		missing = []
		for style in CharacterDesign.styles("headgear"):
			if style == "none":
				continue
			var entry := CharacterMesh.style("headgear", style)
			var regions: Dictionary = entry.get("regions", {})
			if regions.is_empty() or not entry.get("hair", "") in ["cut", "hidden", "full"]:
				missing.append(style)
			for region in regions:
				var mesh := CharacterMesh.mesh(regions[region])
				if mesh == null or mesh.get_surface_count() == 0:
					missing.append("%s %s" % [style, region])
			if entry.get("hair", "") == "full":
				for hair in CharacterDesign.styles("hair"):
					var made_on: Dictionary = entry.get("on_" + str(hair), {})
					if not made_on.is_empty():
						for region in made_on.get("regions", {}):
							var on_mesh := CharacterMesh.mesh(made_on.regions[region])
							if on_mesh == null or on_mesh.get_surface_count() == 0:
								missing.append("%s on %s %s" % [style, hair, region])
					elif not entry.get("fit", {}).has(hair) and not (hair == "none" and entry.has("on_short")):
						missing.append("%s on %s" % [style, hair])
		check(missing.is_empty() and CharacterDesign.styles("headgear").size() >= 20, "every piece of headgear is made and loads %s" % [missing])

		# Every torso and arm style is made in tools/characters and loads,
		# each arm and hand on its own bone.
		missing = []
		for slot in ["torso", "arms"]:
			for style in CharacterDesign.styles(slot):
				var entry := CharacterMesh.style(slot, style)
				var shapes := {"": entry}
				if slot == "arms":
					for part in ["arm_r", "hand_l", "hand_r"]:
						shapes[part] = entry.get(part, {})
				for part in shapes:
					var regions: Dictionary = shapes[part].get("regions", {})
					if regions.is_empty():
						missing.append("%s %s %s" % [slot, style, part])
					for region in regions:
						var mesh := CharacterMesh.mesh(regions[region])
						if mesh == null or mesh.get_surface_count() == 0:
							missing.append("%s %s %s %s" % [slot, style, part, region])
				if slot == "arms" and (entry.get("bone", "") != "arm_l" or entry.get("arm_r", {}).get("bone", "") != "arm_r" or entry.get("hand_r", {}).get("bone", "") != "hand_r"):
					missing.append("%s on the wrong bones" % style)
		check(missing.is_empty() and CharacterDesign.styles("torso").size() >= 20 and CharacterDesign.styles("arms").size() >= 20,
				"every torso and arm style is made and loads %s" % [missing])

		# Every leg style is made in tools/characters and loads: the hips on
		# the rig and each leg standing, seated and astride on the legs bone.
		missing = []
		for style in CharacterDesign.styles("legs"):
			var entry := CharacterMesh.style("legs", style)
			var shapes := {"": entry}
			for pose in ["standing", "seated", "astride"]:
				for side in ["l", "r"]:
					shapes["%s_%s" % [pose, side]] = entry.get("%s_%s" % [pose, side], {})
			for part in shapes:
				var regions: Dictionary = shapes[part].get("regions", {})
				if regions.is_empty():
					missing.append("%s %s" % [style, part])
				for region in regions:
					var mesh := CharacterMesh.mesh(regions[region])
					if mesh == null or mesh.get_surface_count() == 0:
						missing.append("%s %s %s" % [style, part, region])
				if part != "" and shapes[part].get("bone", "") != "legs":
					missing.append("%s %s on the wrong bone" % [style, part])
			if entry.get("bone", "") != "hips":
				missing.append("%s hips on the wrong bone" % style)
		check(missing.is_empty() and CharacterDesign.styles("legs").size() >= 20, "every leg style is made and loads %s" % [missing])

		# Every back piece is made in tools/characters and loads, standing,
		# seated, reclined and astride, all on the upper body, and a rig
		# wears the shape for how it sits.
		missing = []
		for style in CharacterDesign.styles("back"):
			if style == "none":
				continue
			var entry := CharacterMesh.style("back", style)
			var shapes := {"": entry}
			for pose in ["seated", "reclined", "astride"]:
				shapes[pose] = entry.get(pose, {})
			for part in shapes:
				var regions: Dictionary = shapes[part].get("regions", {})
				if regions.is_empty():
					missing.append("%s %s" % [style, part])
				for region in regions:
					var mesh := CharacterMesh.mesh(regions[region])
					if mesh == null or mesh.get_surface_count() == 0:
						missing.append("%s %s %s" % [style, part, region])
			if entry.get("bone", "") != "upper":
				missing.append("%s on the wrong bone" % style)
		check(missing.is_empty() and CharacterDesign.styles("back").size() >= 20, "every back piece is made and loads %s" % [missing])
		var wearing := []
		for way in [[false, false, 0.0, ""], [true, false, 0.0, "seated"], [true, false, 0.4, "seated"], [true, false, 1.0, "reclined"], [true, true, 0.0, "astride"]]:
			var rig := CharacterRig.new(CharacterDesign.new(), way[0])
			rig.astride = way[1]
			rig.recline = way[2]
			if rig.back_variant() != way[3]:
				wearing.append("%s wanted, %s worn" % [way[3], rig.back_variant()])
			rig.free()
		check(wearing.is_empty(), "the rig wears the back piece's shape for how it sits %s" % [wearing])

		# How far the figure's pieces go into each other in the rig's poses,
		# measured in tools/characters on the real meshes.
		var report = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/clipping.json"))
		var fresh: bool = typeof(report) == TYPE_DICTIONARY
		if fresh:
			var made_for: Dictionary = report.get("figure", {})
			for name in CharacterMesh.figure():
				if name != "_comment" and str(made_for.get(name)) != str(CharacterMesh.figure()[name]):
					fresh = false
		check(fresh, "the clipping report is for this figure")
		if fresh:
			var clips := []
			for overlap in report.overlaps:
				if overlap.cm3 > report.limit_cm3:
					clips.append("%s: %s into %s %.2f cm3" % [overlap.pose, overlap.a, overlap.b, overlap.cm3])
			check(clips.is_empty() and report.poses.size() >= 10, "nothing clips in %d poses (worst %.3f cm3) %s" % [report.poses.size(), report.worst_cm3, clips])
			var unchecked := []
			for style in CharacterMesh.made().get("styles", {}).get("neck", {}):
				if not report.get("styles", []).has("neck " + style):
					unchecked.append(style)
			check(unchecked.is_empty(), "the clipping report checks every neck piece %s" % [unchecked])
			unchecked = []
			for slot in ["hair", "facial_hair"]:
				for style in CharacterMesh.made().get("styles", {}).get(slot, {}):
					var names := ["%s %s" % [slot, style]]
					if slot == "hair":
						names.append("hair %s cut" % style)
					for name in names:
						if not report.get("styles", []).has(name):
							unchecked.append(name)
			check(unchecked.is_empty(), "the clipping report checks every hairdo, cut version and raised facial hair %s" % [unchecked])
			unchecked = []
			for slot in ["torso", "arms"]:
				for style in CharacterMesh.made().get("styles", {}).get(slot, {}):
					if not report.get("styles", []).has("%s %s" % [slot, style]):
						unchecked.append("%s %s" % [slot, style])
			check(unchecked.is_empty() and report.has("raised"), "the clipping report checks every torso and arm style %s" % [unchecked])
			unchecked = []
			for style in CharacterMesh.made().get("styles", {}).get("legs", {}):
				if not report.get("styles", []).has("legs " + style):
					unchecked.append(style)
			check(unchecked.is_empty(), "the clipping report checks every leg style %s" % [unchecked])
			unchecked = []
			for style in CharacterMesh.made().get("styles", {}).get("back", {}):
				if not report.get("styles", []).has("back " + style):
					unchecked.append(style)
			for seat in ["driver's seat", "bucket seat", "racing seat", "lay-down seat", "saddle"]:
				if not report.get("seats", []).has(seat):
					unchecked.append(seat)
			check(unchecked.is_empty(), "the clipping report checks every back piece against the seats %s" % [unchecked])
			# Every piece of headgear against every hairdo it shows: the cut
			# version under a hat, the full one under what's worn on the hair.
			unchecked = []
			var checked: Dictionary = report.get("headgear_hair", {})
			for style in CharacterMesh.made().get("styles", {}).get("headgear", {}):
				if not report.get("styles", []).has("headgear " + style):
					unchecked.append(style)
				var under := CharacterRig.hair_under(style)
				if under == "hidden":
					continue
				for hair in CharacterMesh.made().styles.hair:
					var name: String = "hair %s cut" % hair if under == "cut" else "hair " + hair
					if not checked.get(style, []).has(name):
						unchecked.append("%s / %s" % [style, name])
			check(unchecked.is_empty(), "the clipping report checks every headgear against every hairdo under it %s" % [unchecked])
			var showing := []
			for spot in report.get("uncovered", []):
				showing.append("%s over %s at %s" % [spot.headgear, spot.hair, spot.degrees])
			check(report.has("uncovered") and showing.is_empty(), "every hat covers the top edge of the cut hair under it %s" % [showing])

		# Every style of every piece builds, sitting and standing, baked into
		# a mesh a bone, with the face on its own.
		var built := 0
		var most_calls := 0
		var bones_short := []
		var started := Time.get_ticks_usec()
		for slot in CharacterDesign.SLOTS:
			for style in CharacterDesign.styles(slot):
				var who := CharacterDesign.load_file("res://data/characters/roster/racer.json")
				who.set_piece(slot, style)
				for sitting in [true, false]:
					var rig := CharacterRig.new(who, sitting)
					add_child(rig)
					var meshes := rig.find_children("*", "MeshInstance3D", true, false)
					var calls := 0
					for node in meshes:
						calls += node.mesh.get_surface_count()
					most_calls = maxi(most_calls, calls)
					var on := {}
					for node in meshes:
						if node.name == "Baked":
							on[node.get_parent()] = true
					var wanted := [rig, rig.upper(), rig.head(), rig._arm[0], rig._arm[1], rig._hand[0], rig._hand[1]]
					var all_on := wanted.all(func(n): return on.has(n))
					if meshes.size() <= 9 and all_on:
						built += 1
					elif bones_short.size() < 5:
						bones_short.append("%s %s (%d meshes)" % [slot, style, meshes.size()])
					rig.queue_free()
		var styles := 0
		for slot in CharacterDesign.SLOTS:
			styles += CharacterDesign.styles(slot).size()
		check(built == styles * 2, "every piece builds sitting and standing, a mesh a bone (%d of %d) %s" % [built, styles * 2, bones_short])
		check(most_calls <= 24, "a driver is at most %d surfaces to draw" % most_calls)
		print("  (built %d drivers in %.0f ms, %.1f ms each)" % [styles * 2, (Time.get_ticks_usec() - started) / 1000.0, (Time.get_ticks_usec() - started) / 1000.0 / (styles * 2)])

		# The same driver again is the same bake, not a new one.
		var again_who := CharacterDesign.load_file("res://data/characters/roster/racer.json")
		var first := CharacterRig.new(again_who, true)
		add_child(first)
		var second := CharacterRig.new(again_who.duplicate_design(), true)
		add_child(second)
		check(first.upper().get_node("Baked").mesh == second.upper().get_node("Baked").mesh, "a driver built twice is baked once")
		# The same driver in an upright seat and lying back wears a different back piece.
		var caped := again_who.duplicate_design()
		caped.set_piece("back", "cape")
		var upright := CharacterRig.new(caped, true)
		add_child(upright)
		var lying := CharacterRig.new(caped.duplicate_design(), true)
		lying.recline = 1.0
		add_child(lying)
		check(upright.upper().get_node("Baked").mesh != lying.upper().get_node("Baked").mesh, "lying back is baked with the back piece's own shape")
		for r in [upright, lying]:
			r.free()
		# Astride, the legs are a bone of their own, swung down.
		var rider := CharacterRig.new(again_who, true)
		rider.astride = true
		add_child(rider)
		check(rider.legs() != rider and rider.legs().has_node("Baked") and rider.has_node("Baked"), "astride, the legs are baked on their own bone")
		for r in [first, second, rider]:
			r.queue_free()

		# Every driver on the roster builds.
		var roster_ok := 0
		var roster_files := DirAccess.get_files_at("res://data/characters/roster")
		for file in roster_files:
			var rig := CharacterRig.new(CharacterDesign.load_file("res://data/characters/roster/" + file), true)
			add_child(rig)
			roster_ok += 1 if rig.upper().has_node("Baked") else 0
			rig.queue_free()
		check(roster_ok == roster_files.size(), "every driver on the roster builds (%d)" % roster_ok)

		# Every piece of headgear, hair, neckwear and backwear is joined on, to
		# the head or the torso or to another piece that is. Nothing floats.
		var floating := []
		for slot in ["headgear", "hair", "neck", "back"]:
			for style in CharacterDesign.styles(slot):
				if style == "none":
					continue
				var who := CharacterDesign.load_file("res://data/characters/roster/racer.json")
				who.set_piece("headgear", "none")
				who.set_piece(slot, style)
				var rig := CharacterRig.new(who, false)
				rig.bake = false
				add_child(rig)
				var loose := loose_headgear(rig) if slot in ["headgear", "hair"] else loose_on_torso(rig)
				if loose > 0:
					floating.append("%s %s (%d)" % [slot, style, loose])
				rig.queue_free()
		check(floating.is_empty(), "every hat, hairdo, neck and back piece is joined on %s" % [floating])

		# Resting hands never go into the body. Brick toys don't pass through
		# themselves.
		for sitting in [false, true]:
			var who := CharacterDesign.load_file("res://data/characters/roster/racer.json")
			var rig := CharacterRig.new(who, sitting)
			add_child(rig)
			var worst := INF
			for side in 2:
				worst = minf(worst, clearance(rig.hand_position(side), sitting))
			check(worst >= 0.035, "%s, the hands rest clear of the body (%.3f m from it)" % ["sitting" if sitting else "standing", worst])
			rig.queue_free()

		# Clapping, the hands meet in front without going into each other or
		# the body. Sulking, they slump forward with the hands still clear.
		var clapper := CharacterRig.new(CharacterDesign.load_file("res://data/characters/roster/racer.json"), false)
		clapper.lively = true
		clapper.idle = false
		add_child(clapper)
		clapper.set_process(false)
		clapper.clap(INF)
		var nearest := INF
		var furthest := 0.0
		var off_body := INF
		for i in 90:
			clapper._process(1.0 / 60.0)
			var apart := clapper.hand_position(0).distance_to(clapper.hand_position(1))
			nearest = minf(nearest, apart)
			furthest = maxf(furthest, apart)
			for side in 2:
				off_body = minf(off_body, clearance(clapper.hand_position(side), false))
		check(nearest > CharacterRig.HAND_SIZE and nearest < CharacterRig.HAND_SIZE * 1.4 and furthest > nearest + 0.08, "clapping, the hands meet and part (%.3f to %.3f m apart)" % [nearest, furthest])
		check(off_body >= 0.1, "out in front, clear of the body (%.3f m from it)" % off_body)
		clapper.sulk(INF)
		for i in 60:
			clapper._process(1.0 / 60.0)
		var slumped := clapper.upper().transform.basis.y.z
		off_body = INF
		for side in 2:
			off_body = minf(off_body, clearance(clapper.hand_position(side), false))
		check(slumped < -0.1 and is_equal_approx(clapper._turn_in[0], 0.0), "sulking, they slump forward (%.2f)" % slumped)
		check(off_body >= 0.035, "with the hands clear of the body (%.3f m from it)" % off_body)
		clapper.queue_free()

		# Holding something up, the hands are clear of the head and hair, the
		# held thing sits upright in the right hand, and letting go hands it back.
		var in_head := []
		for file in DirAccess.get_files_at("res://data/characters/roster"):
			if not file.ends_with(".json"):
				continue
			var holder := CharacterRig.new(CharacterDesign.load_file("res://data/characters/roster/" + file), false)
			add_child(holder)
			var prop := Node3D.new()
			holder.hold(prop, Vector3(-0.1, 0.0, 0.0), true)
			var head_box := AABB()
			var first_box := true
			for shown in holder.head().find_children("*", "MeshInstance3D", true, false):
				var b: AABB = holder.global_transform.affine_inverse() * shown.global_transform * shown.get_aabb()
				head_box = b if first_box else head_box.merge(b)
				first_box = false
			for side in 2:
				var hand := holder.hand_position(side)
				# The left one's up high cheering, the right one beside the head.
				if head_box.grow(CharacterRig.HAND_SIZE * 0.5).has_point(hand) or (side == 0 and hand.y < CharacterRig.HEAD_Y):
					in_head.append("%s %d" % [file, side])
			if holder.to_local(prop.to_global(Vector3(-0.1, 0.0, 0.0))).distance_to(holder.hand_position(1)) > 0.001:
				in_head.append("%s held off the hand" % file)
			if holder.to_global(holder.hand_position(1)).distance_to(holder.head().global_position) < 0.25:
				in_head.append("%s held too near the head" % file)
			if prop.global_transform.basis.y.normalized().y < 0.9:
				in_head.append("%s held tipped over" % file)
			if holder.let_go() != prop or prop.get_parent() != null or holder.held() != null:
				in_head.append("%s still holding" % file)
			prop.free()
			holder.queue_free()
		check(in_head.is_empty(), "holding something up, the hands are clear of every roster driver's head and it's upright in the right hand %s" % [in_head])

		# The roster.
		var classes := {}
		var names := []
		for file in DirAccess.get_files_at("res://data/characters/roster"):
			if file.ends_with(".json"):
				var who := CharacterDesign.load_file("res://data/characters/roster/" + file)
				names.append(who.name)
				classes[who.weight_class()] = true
		check(names.size() == 15, "fifteen drivers on the roster %s" % [names])
		check(classes.size() == 3, "light, medium and heavy are all there %s" % [classes.keys()])

		var racer := CharacterDesign.load_file("res://data/characters/roster/racer.json")
		var again := CharacterDesign.from_dict(racer.to_dict())
		check(again.to_dict() == racer.to_dict(), "a driver saves and loads the same")
		check(CharacterDesign.well_formed(racer.to_dict()), "a saved driver is well formed for the network")
		var odd := [{ "hair": "spiky" }, { "hair": { "style": 3 } }, { "torso": { "color": "not a colour" } }, { "name": [] }]
		check(odd.all(func(bad: Dictionary) -> bool: return not CharacterDesign.well_formed(bad)), "a driver with odd pieces from the network is turned away")
		var tread := CharacterDesign.load_file("res://data/characters/roster/tread.json")
		var pip := CharacterDesign.load_file("res://data/characters/roster/pip.json")
		check(tread.weight_class() == "Heavy" and pip.weight_class() == "Light", "Tread is heavy (%.0f kg) and Pip is light (%.0f kg)" % [tread.mass(), pip.mass()])

		# A kart has to have something to steer with.
		var no_wheel := KartDesign.load_file("res://tests/data/legacy/starter.json")
		no_wheel.parts = no_wheel.parts.filter(func(p): return PartCatalog.get_part(p.id).kind != "steering")
		check(no_wheel.problems().has("It needs a steering wheel or handlebars in front of the seat."), "a kart with no steering wheel says so")

		# A heavy driver and a light one make different karts.
		var design := KartDesign.load_file("res://tests/data/legacy/starter.json")
		kart = Kart.new()
		kart.build(design, tread)
		kart.transform = Transform3D(Basis.IDENTITY, Vector3(60.0, 0.05, 100.0))
		add_child(kart)
		var light := Kart.new()
		light.build(design, pip)
		check(kart.mass - light.mass > 15.0, "a heavy driver makes a heavier kart (%.0f against %.0f kg)" % [kart.mass, light.mass])
		light.free()
		loose = Kart.new()
		loose.build(design, racer)
		loose.transform = Transform3D(Basis.IDENTITY, Vector3(80.0, 0.05, 100.0))
		add_child(loose)

	func _physics_process(_delta: float) -> void:
		tick += 1
		match tick:
			30:
				var rig: CharacterRig = kart._rig
				var wheel: SteeringVisual = kart._steering
				check(rig != null and wheel != null, "the kart has a driver and a steering wheel")
				var grips := wheel.grips(0.0)
				var left: Vector3 = wheel.global_transform * grips[0]
				var right: Vector3 = wheel.global_transform * grips[1]
				check(hand_at(rig, 0).distance_to(left) < 0.03 and hand_at(rig, 1).distance_to(right) < 0.03, "the hands are on the wheel (%.3f and %.3f m off)" % [hand_at(rig, 0).distance_to(left), hand_at(rig, 1).distance_to(right)])
				kart.controls.throttle = 0.4
				kart.controls.steer = 1.0
				# Knock the steering wheel off the other kart.
				for i in loose.design.parts.size():
					if loose.design.parts[i].id == "steering_wheel":
						var one: Array[int] = [i]
						loose.lose_parts(one)
				loose.controls.throttle = 0.4
				loose.controls.steer = 1.0
			90:
				kart._pose_driver()
				var rig: CharacterRig = kart._rig
				var wheel: SteeringVisual = kart._steering
				var amount := kart.steer_angle / Kart.MAX_STEER
				check(amount > 0.3, "steering right turns the front wheels (%.2f of full lock)" % amount)
				var grips := wheel.grips(amount)
				var left: Vector3 = wheel.global_transform * grips[0]
				check(hand_at(rig, 0).distance_to(left) < 0.03, "and the hands follow the wheel around (%.3f m off)" % hand_at(rig, 0).distance_to(left))
				var straight: Vector3 = wheel.global_transform * wheel.grips(0.0)[0]
				check(left.distance_to(straight) > 0.04, "which really has turned (the left hand moved %.2f m)" % left.distance_to(straight))
				# Brick figure arms only swing forward and back at the shoulder.
				for side in 2:
					var across: Vector3 = rig._arm[side].basis.x
					check(absf(across.x) > 0.999, "arm %d only swings at the shoulder (%s)" % [side, across])
				check(loose._steering == null and absf(loose.steer_angle) < 0.001, "with its steering wheel knocked off, a kart can't steer")
				print("All character checks passed." if failures == 0 else "%d character checks failed." % failures)
				get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
