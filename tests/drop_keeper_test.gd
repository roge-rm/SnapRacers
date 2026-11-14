extends SceneTree

## Dropped things stay until the leader's driven past them, karts wear them
## down, there are never more than DropKeeper.MOST, and online the host
## decides and the clients follow.
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/drop_keeper_test.gd
## Race won't load in a -s test, so a stand-in for its Racer with what the
## keeper reads.
class Entrant:
	var kart: Kart
	var offset := 0.0
	var progress: RaceProgress


class Runner:
	extends Node
	var failures := 0
	## Out of the way, so it drives through nothing.
	const AWAY := Vector3(0, 500, 0)

	func check(ok: bool, what: String) -> void:
		print(("  ok    " if ok else "  FAIL  ") + what)
		if not ok:
			failures += 1

	func frames(count: int) -> void:
		for i in count:
			await get_tree().physics_frame

	## Long enough for the keeper to look again.
	func a_check() -> void:
		await frames(int(DropKeeper.CHECK_EVERY * 60.0) + 2)

	func racer(slot: int, track: TrackPath, offset: float) -> Entrant:
		var kart := Kart.new()
		kart.build(KartDesign.load_file("res://data/karts/stock/crusher.json"), Kart.default_driver())
		kart.freeze = true
		kart.position = AWAY + Vector3(slot * 10, 0, 0)
		kart.grid_slot = slot
		add_child(kart)
		var one := Entrant.new()
		one.kart = kart
		one.offset = offset
		if track != null:
			one.progress = RaceProgress.new(track.length, 3, offset)
			one.progress.laps = 0
		return one

	func keeper(track: TrackPath, racers: Array) -> DropKeeper:
		var it := DropKeeper.new()
		it.track = track
		it.racers = racers
		add_child(it)
		return it

	func trap_at(at: Vector3, key: int, kind := "marbles") -> BrickTrap:
		var trap := BrickTrap.new(kind, key)
		trap.drop_key = key
		trap.position = at
		add_child(trap)
		return trap

	func gone(node: Node) -> bool:
		return not is_instance_valid(node) or node.is_queued_for_deletion() or node._left <= BrickTrap.SHRINK_TIME

	func clear(nodes: Array) -> void:
		for node in nodes:
			if is_instance_valid(node):
				node.queue_free()
		await frames(2)

	func _leader() -> void:
		var track := TrackPath.load_file("res://data/tracks/hairpin_hall.json")
		var lead := racer(0, track, 100.0)
		var second := racer(1, track, 50.0)
		var it := keeper(track, [lead, second])
		# Dropped by the kart in second, behind it.
		var behind := trap_at(track.point_at(45.0), 1 * 65536)
		# Dropped by the leader, just behind it.
		var own := trap_at(track.point_at(95.0), 0)
		await a_check()
		check(not gone(behind) and not gone(own), "dropped things stay while the leader's ahead of them")
		lead.progress.laps = 1
		lead.progress.offset = 40.0
		await a_check()
		check(not gone(behind), "a trap stays until the leader comes round to it")
		lead.progress.offset = 45.0 + DropKeeper.PAST + 2.0
		await a_check()
		check(gone(behind), "and goes once the leader's driven past it")
		check(not gone(own), "the leader's own trap is still there")
		lead.progress.offset = 95.0 + DropKeeper.PAST + 2.0
		await a_check()
		check(gone(own), "until the leader comes round and passes it again")
		await clear([it, behind, own, lead.kart, second.kart])

	func _wear() -> void:
		var ground := StaticBody3D.new()
		ground.collision_layer = Kart.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(100, 2, 100)
		shape.shape = box
		shape.position.y = -1.0
		ground.add_child(shape)
		add_child(ground)
		var karts: Array = []
		for slot in 4:
			karts.append(racer(slot, null, 0.0))
		var it := keeper(null, karts)
		for kind in ["marbles", "spikes"]:
			var trap := trap_at(Vector3(0, 0.01, 0), 7 * 65536 + (0 if kind == "marbles" else 1), kind)
			await a_check()
			var full := trap.reach_across()
			for n in 3:
				var kart: Kart = karts[n].kart
				kart.global_position = Vector3(0.5 * n, 0.4, 12)
				await a_check()
				kart.global_position = Vector3(0.5 * n, 0.4, -12)
				await a_check()
				if n == 0:
					check(trap.reach_across() < full and trap.reach_across() > 0.0 and not gone(trap), "%s shrink when one kart drives through (%.1f m from %.1f)" % [kind, trap.reach_across(), full])
					var was := trap.reach_across()
					kart.global_position = Vector3(0, 0.4, 12)
					await a_check()
					check(trap.reach_across() == was, "and the same kart again doesn't wear them more")
				kart.global_position = AWAY
				await a_check()
			check(gone(trap), "%s are gone after %d karts" % [kind, DropKeeper.WEAR_HITS])
			await clear([trap])
		# A pile laid along x, and a kart down the middle of it.
		var bricks: Array[BrickPile] = []
		for i in 9:
			var brick := BrickPile.new()
			brick.drop_key = 9 * 65536
			brick.drop_index = i
			brick.freeze = true
			brick.position = Vector3(i - 4.0, 0.3, 0)
			add_child(brick)
			bricks.append(brick)
		var through: Kart = karts[3].kart
		through.global_position = Vector3(0, 0.4, 10)
		await a_check()
		through.global_position = Vector3(0, 0.4, -10)
		await a_check()
		var hit := bricks.filter(func(b: BrickPile) -> bool: return b._left < INF)
		check(hit.size() >= 1 and hit.size() <= 4 and hit.has(bricks[4]), "a kart through a pile takes the bricks it hits (%d of 9)" % hit.size())
		await frames(int((DropKeeper.BRICK_LINGER + BrickPile.SHRINK_TIME) * 60.0) + 4)
		check(not is_instance_valid(bricks[4]) and is_instance_valid(bricks[0]), "they go a moment later and the rest stay")
		await clear(Array(bricks) + karts.map(func(r): return r.kart) + [it, ground])

	func _cap() -> void:
		var it := keeper(null, [])
		var traps: Array = []
		for i in DropKeeper.MOST + 2:
			traps.append(trap_at(Vector3(i * 10, 0, 50), 20 * 65536 + i))
		await frames(1)
		check(it.count() == DropKeeper.MOST, "at most %d dropped things at once (%d)" % [DropKeeper.MOST, it.count()])
		check(gone(traps[0]) and gone(traps[1]) and not gone(traps[2]), "the oldest go first")
		var piles: Array = []
		for p in DropKeeper.MOST_PILES + 1:
			for i in 2:
				var brick := BrickPile.new()
				brick.drop_key = 21 * 65536 + p
				brick.drop_index = i
				brick.freeze = true
				brick.position = Vector3(p * 10, 0, 80 + i)
				add_child(brick)
				piles.append(brick)
		await frames(1)
		check(it.state_of(21 * 65536) == DropKeeper.GONE and piles[0]._left <= BrickPile.SHRINK_TIME and piles[1]._left <= BrickPile.SHRINK_TIME, "past %d piles the oldest pile goes" % DropKeeper.MOST_PILES)
		check(it.count() == DropKeeper.MOST, "still %d in all" % it.count())
		var last: BrickTrap = traps[-1]
		it._clock += DropKeeper.BACKSTOP + 1.0
		await a_check()
		check(gone(last) and it.count() == 0, "anything still there after %.0f s goes" % DropKeeper.BACKSTOP)
		await clear(traps + piles + [it])
		var loose := BrickTrap.new()
		check(loose._left == DropKeeper.BACKSTOP, "outside a race a trap goes after %.0f s by itself" % DropKeeper.BACKSTOP)
		loose.free()

	## The host's keeper decides, and the client's only does what it's told.
	func _online() -> void:
		var client := DropKeeper.new()
		client.deciding = false
		var host := keeper(null, [])
		host.send = client.take_changes
		add_child(client)
		var made := {}
		for side in [host, client]:
			var list: Array = []
			for i in 3:
				var trap := BrickTrap.new("marbles", i)
				trap.position = Vector3(i * 10, 0, -50)
				add_child(trap)
				list.append(trap)
			made[side] = list
		# The host's word on the last one gets to the client before its drop.
		host.add(made[host][2], 30 * 65536 + 2)
		made[host][2]._left = INF
		for i in 2:
			for side in [host, client]:
				made[side][i]._left = INF
				side.add(made[side][i], 30 * 65536 + i)
		host._decide(host._by_key[30 * 65536], 2)
		host._decide(host._by_key[30 * 65536 + 1], DropKeeper.GONE)
		host._decide(host._by_key[30 * 65536 + 2], DropKeeper.GONE)
		client._clock += DropKeeper.BACKSTOP * 2.0
		await a_check()
		check(made[client][0].reach_across() == made[host][0].reach_across() and made[client][0].reach_across() < BrickTrap.KINDS.marbles.across, "a client wears a trap down as the host says")
		check(gone(made[client][1]) and not gone(made[client][0]), "and lets one go when the host says, not on its own clock")
		client.add(made[client][2], 30 * 65536 + 2)
		check(gone(made[client][2]), "word that comes before the drop is kept until it arrives")
		await clear(made[host] + made[client] + [host, client])

	## The AI goes by how big a worn patch is now.
	func _ai_sees_wear() -> void:
		var one := racer(6, null, 0.0)
		var kart := one.kart
		var full: float = BrickTrap.KINDS.marbles.across
		# Off to the side, where the full patch reaches the kart's line but
		# half of it doesn't.
		var side := full * 0.75 + kart.width() * 0.5
		var trap := BrickTrap.new("marbles", 3)
		trap.position = kart.position + Vector3(side, 0, -6)
		add_child(trap)
		await frames(2)
		var ai := AIDriver.new()
		ai.kart = kart
		check(trap.half_size() == Vector2(full, BrickTrap.KINDS.marbles.along), "a new patch is full size")
		check(AIGadgetTactics._hazard_ahead(ai, 20.0), "the AI sees a full patch in its way")
		trap.wear_to(2, DropKeeper.WEAR_HITS)
		check(is_equal_approx(trap.half_size().x, full * 0.5) and trap.half_size().y < BrickTrap.KINDS.marbles.along, "worn, it's smaller (%.2f by %.2f m)" % [trap.half_size().x, trap.half_size().y])
		check(not AIGadgetTactics._hazard_ahead(ai, 20.0), "and the AI sees it's out of its way now")
		ai.free()
		await clear([trap, kart])

	## Once the leader's finished the next kart still racing decides, and
	## online the client follows the host.
	func _leader_finishes() -> void:
		var track := TrackPath.load_file("res://data/tracks/hairpin_hall.json")
		var lead := racer(0, track, 100.0)
		var second := racer(1, track, 50.0)
		lead.progress.laps = 2
		second.progress.laps = 2
		var host := keeper(track, [lead, second])
		var client := DropKeeper.new()
		client.deciding = false
		add_child(client)
		host.send = client.take_changes
		var made := {}
		for side in [host, client]:
			var list: Array = []
			# Behind the kart in second, and just ahead of it, dropped by the leader.
			for at in [45.0, 70.0]:
				var trap := BrickTrap.new("marbles", int(at))
				trap.position = track.point_at(at)
				add_child(trap)
				list.append(trap)
			made[side] = list
			for i in 2:
				made[side][i]._left = INF
				side.add(made[side][i], 40 * 65536 + i)
		var behind: BrickTrap = made[host][0]
		var ahead: BrickTrap = made[host][1]
		await a_check()
		check(not gone(behind) and not gone(ahead), "both wait for the leader")
		lead.progress.finished = true
		await a_check()
		check(not gone(behind) and not gone(ahead), "when the leader finishes they're still there")
		second.progress.offset = 70.0 + DropKeeper.PAST + 2.0
		await a_check()
		check(gone(ahead) and not gone(behind), "and go once the next kart still racing has driven past")
		check(gone(made[client][1]) and not gone(made[client][0]), "on the client too, as the host says")
		second.progress.finished = true
		await a_check()
		check(gone(behind) and gone(made[client][0]), "once everyone's finished the rest go")
		await clear(made[host] + made[client] + [host, client, lead.kart, second.kart])

	## A brick the host says is hit gets knocked on a client, where it was
	## still lying, before it goes.
	func _pile_online() -> void:
		var one := racer(5, null, 0.0)
		var client := DropKeeper.new()
		client.deciding = false
		client.racers = [one]
		add_child(client)
		var host := keeper(null, [])
		host.send = client.take_changes
		var made := {}
		for side in [host, client]:
			var list: Array = []
			for i in 4:
				var brick := BrickPile.new()
				brick.drop_index = i
				brick.freeze = true
				brick.position = one.kart.position + Vector3(i - 1.5, 0, -3)
				add_child(brick)
				list.append(brick)
			made[side] = list
			for brick in list:
				brick._left = INF
				side.add(brick, 41 * 65536)
		host._decide(host._by_key[41 * 65536], 1 << 2)
		await a_check()
		var bricks: Array = made[client]
		var hit: BrickPile = bricks[2]
		var away: Vector3 = (hit.global_position - one.kart.global_position).slide(Vector3.UP)
		check(not hit.freeze and hit.linear_velocity.slide(Vector3.UP).dot(away) > 0.0, "a client knocks the brick the host says was hit, away from the kart")
		check(hit._left < INF and bricks[0].freeze and bricks[0]._left == INF, "it goes a moment later and the rest lie still")
		await clear(made[host] + made[client] + [host, client, one.kart])

	func _ready() -> void:
		await _leader()
		await _wear()
		await _cap()
		await _online()
		await _ai_sees_wear()
		await _leader_finishes()
		await _pile_online()
		print("All drop keeper checks passed." if failures == 0 else "%d drop keeper checks failed." % failures)
		get_tree().quit(1 if failures > 0 else 0)


func _initialize() -> void:
	root.add_child(Runner.new())
