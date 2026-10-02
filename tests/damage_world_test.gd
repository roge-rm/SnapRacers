extends Node

## Scenery breaking (WorldDamage). A small prop comes down whole, a big one
## gets a hole where it's hit and the rest stays up and solid, and a tire stack
## loses its top tire but keeps its bottom one. A flag flaps until it's
## knocked down, and fans cheer as a kart goes by. Then in a race, a kart driven
## into a marshal post knocks it down and keeps going.
##
##   tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/damage_world_test.tscn

var failures := 0
var host: Node


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## How many of a group's bricks are still standing.
static func standing(damage: WorldDamage, group: int) -> int:
	return damage.groups[group].pieces.filter(func(p): return damage._instances[p[0]][p[1]][0].basis.get_scale() != Vector3.ZERO).size()


static func solid_shapes(damage: WorldDamage, group: int) -> int:
	return damage.groups[group].shapes.filter(func(s): return is_instance_valid(s) and not s.disabled and s.is_inside_tree()).size()


func _ready() -> void:
	print("-- Breaking")
	var kit := SceneryKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	kit.box(Vector3(0, 0, 40), Vector3(40, 0.2, 40), Props.GREEN, SceneryKit.BRICK, true)
	kit.begin("broadleaf", true)
	Props.add(kit, "broadleaf", Vector3(0, 0.2, 0), rng)
	kit.done()
	kit.begin("house", false)
	Props.add(kit, "house", Vector3(20, 0.2, 0), rng)
	kit.done()
	kit.begin("tires", false, true)
	Props.barrier_stack(kit, Vector3(-10, 0.2, 0), Props.RED)
	kit.done()
	var stand := Node3D.new()
	add_child(stand)
	var damage := kit.build(stand)
	await frames(2)
	check(damage.groups.size() == 3, "each prop's a group (%d)" % damage.groups.size())
	var tree_bricks := standing(damage, 0)
	damage.break_at(0, Vector3(0, 1, -0.3), Vector3(0, 0, 20))
	await frames(2)
	check(standing(damage, 0) == 0 and solid_shapes(damage, 0) == 0, "a small prop comes down whole (%d bricks, %d solid)" % [standing(damage, 0), solid_shapes(damage, 0)])
	check(damage.rubble_count().x >= tree_bricks, "and its bricks fly off as rubble (%d)" % damage.rubble_count().x)

	var house_solid := solid_shapes(damage, 1)
	var before := damage.rubble_count().x
	damage.break_at(1, Vector3(17, 1.2, -2.5), Vector3(0, 0, 15))
	await frames(3)
	var rubble := damage.rubble_count().x - before
	check(rubble > 0 and rubble < 40, "a big prop loses only the bricks around the hit (%d)" % rubble)
	check(standing(damage, 1) > 0 and solid_shapes(damage, 1) > house_solid, "and the rest still stands, solid (%d bricks, %d solid)" % [standing(damage, 1), solid_shapes(damage, 1)])
	var space := get_viewport().world_3d.direct_space_state
	var probe := PhysicsPointQueryParameters3D.new()
	probe.collision_mask = Kart.LAYER_WORLD
	probe.position = Vector3(17, 1.2, -2.3)
	var in_hole := space.intersect_point(probe).filter(func(h): return h.collider.get_meta("breakable", null) == damage)
	probe.position = Vector3(22, 1.2, 0)
	var in_wall := space.intersect_point(probe).filter(func(h): return h.collider.get_meta("breakable", null) == damage)
	check(in_hole.is_empty() and not in_wall.is_empty(), "there's room in the hole, and the rest is solid")

	var tires := standing(damage, 2)
	damage.break_at(2, Vector3(-10, 0.5, -0.4), Vector3(0, 0, 10))
	await frames(2)
	check(standing(damage, 2) == tires - 1, "a tire stack loses its top tire (%d of %d)" % [standing(damage, 2), tires])
	damage.break_at(2, Vector3(-10, 0.5, -0.4), Vector3(0, 0, 25))
	damage.break_at(2, Vector3(-10, 0.5, -0.4), Vector3(0, 0, 25))
	await frames(2)
	check(standing(damage, 2) == 1 and solid_shapes(damage, 2) == 1, "but however hard it's hit, the bottom one stays, still soft and solid")
	await frames(120)
	var moving := damage.rubble_count()
	check(moving.x == moving.y and moving.x <= WorldDamage.MOST_MOVING, "the rubble can all move, up to %d (%s)" % [WorldDamage.MOST_MOVING, moving])
	for i in 200:
		damage._fly("box", Transform3D(Basis.from_scale(Vector3.ONE * 0.5), Vector3(0, 5 + i * 0.1, 0)), Props.RED, SceneryKit.BRICK, Vector3.ZERO)
	await frames(2)
	moving = damage.rubble_count()
	check(moving.y == WorldDamage.MOST_MOVING and moving.x > moving.y, "past that the oldest stop moving and stay where they are (%s)" % moving)
	damage.queue_free()
	await frames(2)

	print("-- Moving and watching")
	kit = SceneryKit.new()
	kit.box(Vector3(0, 0, 40), Vector3(40, 0.2, 40), Props.GREEN, SceneryKit.BRICK, true)
	kit.begin("flag", true)
	Props.flag(kit, Vector3(0, 0.2, 0), Props.RED)
	kit.done()
	kit.begin("fans", false)
	Props.fan_line(kit, Vector3(10, 0.2, 0), 0, rng)
	kit.done()
	damage = kit.build(stand)
	await frames(2)
	check(damage._movers.size() == 1, "the flag moves (%d moving)" % damage._movers.size())
	var flag_was: Transform3D = damage._movers[0][0]
	await frames(30)
	check(not damage._movers[0][0].is_equal_approx(flag_was), "and flaps about")
	var crowds := damage.get_children().filter(func(n): return n is Crowd)
	check(crowds.size() == 1 and crowds[0]._phases.size() >= 4, "there are fans behind the fence (%d)" % (crowds[0]._phases.size() if not crowds.is_empty() else 0))
	if not crowds.is_empty():
		var bunch: Dictionary = crowds[0]._bunches.values()[0]
		check(is_equal_approx(bunch.cheer, Crowd.AT_REST), "they wait quietly")
		var passing := Node3D.new()
		passing.add_to_group("karts")
		add_child(passing)
		passing.global_position = Vector3(10, 0.2, -8)
		await frames(60)
		check(bunch.cheer > 0.9, "they cheer when a kart comes by (%.2f)" % bunch.cheer)
		passing.global_position = Vector3(300, 0, 0)
		await frames(150)
		check(bunch.cheer < Crowd.AT_REST + 0.01, "and calm down once it's gone (%.2f)" % bunch.cheer)
		passing.queue_free()
	damage.break_at(0, Vector3(0, 1, -0.1), Vector3(0, 0, 20))
	await frames(4)
	check(damage._movers[0][0].basis.get_scale() == Vector3.ZERO, "a flag knocked down goes with its pole")
	damage.queue_free()
	await frames(2)

	print("-- In a race")
	host = Node.new()
	add_child(host)
	Game.start(host, false)
	var was_kart = Game.settings.get_value("race", "kart", Game.OWN_KART)
	Game.settings.set_value("race", "kart", Game.OWN_KART)
	Game.start_practice(Tracks.path_of("peach_pit"))
	var race: Race = null
	while race == null:
		await get_tree().process_frame
		for child in host.get_children():
			if child is Race:
				race = child
	while not race.started:
		await frames(10)
	var scenery := WorldDamage.in_tree(get_tree())
	check(scenery != null, "the course's scenery can break")
	# Something small beside the road to drive into: a marshal post if there's
	# one, or a billboard or a tree.
	var target := -1
	for wanted in ["marshal_post", "billboard", ""]:
		for g in scenery.groups.size():
			if scenery.is_small(g) and (wanted == "" or scenery.groups[g].name == wanted) and solid_shapes(scenery, g) > 0:
				target = g
				break
		if target >= 0:
			break
	check(target >= 0, "there's something small to hit (%s)" % (scenery.groups[target].name if target >= 0 else "nothing"))
	if target >= 0:
		var post: CollisionShape3D = scenery.groups[target].shapes[0]
		var aim := post.global_position
		var kart := race.player.kart
		var from := Vector3(aim.x, aim.y, aim.z) + Vector3(0, 0, -9)
		kart.global_transform = Transform3D(Basis.looking_at(Vector3(0, 0, 1)), from + Vector3.UP * 0.3)
		kart.linear_velocity = Vector3(0, 0, 22)
		kart.angular_velocity = Vector3.ZERO
		var broke := [false]
		kart.broke_scenery.connect(func(_g, _at, _v): broke[0] = true)
		await frames(50)
		check(broke[0] and standing(scenery, target) == 0, "a kart driven into it knocks it down")
		check(kart.linear_velocity.length() > 8.0, "and keeps going (%.0f m/s)" % kart.linear_velocity.length())
		check(scenery.rubble_count().x > 0, "and leaves its bricks lying about (%d)" % scenery.rubble_count().x)
	Game.settings.set_value("race", "kart", was_kart)
	race.leave()
	await frames(4)
	print("All world damage checks passed." if failures == 0 else "%d world damage checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
