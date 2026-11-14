class_name DropKeeper
extends Node

## Keeps track of what karts drop in a race (marbles, spikes, walls and piles
## of bricks) and decides when each one goes:
## - once the leader has come round and driven past it, so the kart in front
##   meets it too, the one who dropped it included;
## - once karts have worn it away: each kart through a patch of marbles or
##   spikes scatters part of it, and the bricks of a pile a kart hits go;
## - when there are more than MOST on the course, oldest first;
## - after BACKSTOP seconds whatever happens.
## Each drop is known by its kart's grid slot and how many things that kart
## has dropped (see key_of()), which is the same on every device. Online only
## the host decides, and sends each change to the clients as a [key, state]
## pair (see NetRace), so everyone sees the same items. Outside a race there's
## no keeper and each item just goes after BACKSTOP seconds by itself.

const MOST := 10
## Piles of bricks are loose bodies, which phones can't take many of.
const MOST_PILES := BrickPile.MOST_AT_ONCE / BrickPile.COUNT
const BACKSTOP := 90.0
## Seconds between checks. Karts are checked along the line they drove since
## the last one, so a fast kart isn't missed.
const CHECK_EVERY := 0.2
## How far past an item the leader has to be before it goes, in metres.
const PAST := 5.0
## Karts through a patch of marbles or spikes before it's all gone.
const WEAR_HITS := 3
## How far past a kart's sides it still scatters a patch or hits a brick, in
## metres.
const REACH := 0.4
## A kart that moved further than this between checks was put back on the
## track, so it didn't drive through anything.
const JUMP := 40.0
## A kart further than this from a pile's first brick, in metres, is too far
## to hit any of it, so its bricks aren't looked at one by one.
const PILE_REACH := 12.0
## Seconds a brick a kart hit still tumbles before it shrinks away.
const BRICK_LINGER := 0.6
## A drop's state: how many karts have been through a patch, the bricks hit
## out of a pile as bits, or GONE once it's fading out.
const GONE := -1

enum { TRAP, WALL, PILE }


class Item:
	var key := 0
	var kind := TRAP
	var nodes: Array[Node3D] = []
	var born := 0.0
	## The leader's race distance once it's driven past this, or -1.
	var pass_at := -1.0
	var state := 0
	var hit_by: Array[Kart] = []


## The course and who's racing, for the leader and the karts.
var track: TrackPath
var racers: Array = []
## Whether this device decides when items go. Online only the host does.
var deciding := true
## Called with a PackedInt32Array of [key, state] pairs this decided, online.
var send := Callable()

var _items: Array[Item] = []
var _by_key := {}
## States that came from the host before the drop itself arrived here.
var _early := {}
var _clock := 0.0
var _check_in := 0.0
## Where each kart was at the last check.
var _was := {}
var _outbox := PackedInt32Array()


static func key_of(from: Kart) -> int:
	return from.grid_slot * 65536 + from.drops


## The keeper in this tree, or null outside a race.
static func find(tree: SceneTree) -> DropKeeper:
	return tree.get_first_node_in_group("drop_keeper") as DropKeeper if tree != null else null


func _init() -> void:
	name = "DropKeeper"


func _ready() -> void:
	add_to_group("drop_keeper")


## Takes on an item that's just come into the world. A pile's bricks come one
## at a time under the same key.
func add(node: Node3D, key: int) -> void:
	var item: Item = _by_key.get(key)
	if item == null:
		item = Item.new()
		item.key = key
		item.kind = PILE if node is BrickPile else (WALL if node is BrickWall else TRAP)
		item.born = _clock
		item.pass_at = _pass_point(node.global_position, key)
		_items.append(item)
		_by_key[key] = item
		if deciding:
			_cap()
	item.nodes.append(node)
	if _early.has(key):
		var state: int = _early[key]
		_early.erase(key)
		_apply(item, state)
	elif item.state != 0 and item.kind == PILE:
		# A brick that arrived after its pile was hit.
		_apply(item, item.state, true)


## How many items are on the course now.
func count() -> int:
	return _items.size()


## The state of the item with this key, or GONE when there's none.
func state_of(key: int) -> int:
	var item: Item = _by_key.get(key)
	return item.state if item != null else GONE


## Changes from the host, as [key, state] pairs.
func take_changes(changes: PackedInt32Array) -> void:
	for i in range(0, changes.size() - 1, 2):
		var key := changes[i]
		var item: Item = _by_key.get(key)
		if item != null:
			_apply(item, changes[i + 1])
		else:
			_early[key] = changes[i + 1]


## Where the leader will be in the race once it's come round and driven past
## the spot, from the spot's place along the track's spine. Splits share the
## spine, so it works on them too.
func _pass_point(at: Vector3, key: int) -> float:
	if track == null or racers.is_empty():
		return -1.0
	var lead := -INF
	var lead_offset := 0.0
	var hint := -1.0
	for racer in racers:
		if racer.progress == null:
			continue
		var distance: float = racer.progress.distance()
		if distance > lead:
			lead = distance
			lead_offset = racer.progress.offset
		if is_instance_valid(racer.kart) and racer.kart.grid_slot == key / 65536:
			hint = racer.offset
	if lead == -INF:
		return -1.0
	var offset := track.offset_of(at, hint) if hint >= 0.0 else track.offset_of(at)
	return lead + fposmod(offset - lead_offset, track.length)


func _physics_process(delta: float) -> void:
	_clock += delta
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	for i in range(_items.size() - 1, -1, -1):
		var item := _items[i]
		for j in range(item.nodes.size() - 1, -1, -1):
			if not is_instance_valid(item.nodes[j]):
				item.nodes.remove_at(j)
		if item.nodes.is_empty():
			_forget(item)
	if deciding:
		check()
		if not _outbox.is_empty():
			if send.is_valid():
				send.call(_outbox.duplicate())
			_outbox.clear()
	for racer in racers:
		if is_instance_valid(racer.kart):
			_was[racer.kart] = racer.kart.global_position


## Decides what goes now. The host or a race on its own does this.
func check() -> void:
	var lead := -INF
	for racer in racers:
		if racer.progress != null:
			lead = maxf(lead, racer.progress.distance())
	for i in range(_items.size() - 1, -1, -1):
		var item := _items[i]
		if _clock - item.born > BACKSTOP or (item.pass_at >= 0.0 and lead >= item.pass_at + PAST):
			_decide(item, GONE)
		elif item.kind != WALL:
			_wear(item)


func _wear(item: Item) -> void:
	for racer in racers:
		var kart: Kart = racer.kart
		if not is_instance_valid(kart) or not _was.has(kart) or kart.ghost_left > 0.0 or kart.shield_left > 0.0:
			continue
		var from: Vector3 = _was[kart]
		var to := kart.global_position
		if from.distance_squared_to(to) > JUMP * JUMP:
			continue
		var wide := kart.width() * 0.5 + REACH
		if item.kind == TRAP:
			if item.hit_by.has(kart) or not _crossed(item.nodes[0], from, to, wide):
				continue
			item.hit_by.append(kart)
			_decide(item, GONE if item.state + 1 >= WEAR_HITS else item.state + 1)
			if item.state == GONE:
				return
		elif _near(item.nodes[0].global_position, from, to, PILE_REACH):
			var state := item.state
			for brick in item.nodes:
				var index: int = brick.drop_index
				if state & (1 << index) == 0 and _near(brick.global_position, from, to, wide):
					state |= 1 << index
			if state != item.state:
				_decide(item, state)


## Whether a kart going from `from` to `to` ran over the patch.
static func _crossed(trap: BrickTrap, from: Vector3, to: Vector3, wide: float) -> bool:
	var inside := trap.global_transform.affine_inverse()
	var a := inside * from
	var b := inside * to
	var across := trap.reach_across() + wide
	var along := trap.reach_along() + wide
	var p := Vector2(a.x / across, a.z / along)
	var d := Vector2(b.x / across, b.z / along) - p
	var t := 0.0
	if d.length_squared() > 0.000001:
		t = clampf(-p.dot(d) / d.length_squared(), 0.0, 1.0)
	if (p + d * t).length_squared() > 1.0:
		return false
	var high := lerpf(a.y, b.y, t)
	return high > -1.0 and high < 2.0


## Whether a kart going from `from` to `to` came within `wide` of `at`.
static func _near(at: Vector3, from: Vector3, to: Vector3, wide: float) -> bool:
	var d := to - from
	var t := 0.0
	if d.length_squared() > 0.000001:
		t = clampf((at - from).dot(d) / d.length_squared(), 0.0, 1.0)
	return at.distance_squared_to(from + d * t) < wide * wide


## Past MOST_PILES piles the oldest pile goes, and past MOST items the
## oldest item. It's called as each one comes, so one of each is enough.
func _cap() -> void:
	var piles := 0
	for item in _items:
		if item.kind == PILE:
			piles += 1
	if piles > MOST_PILES:
		for item in _items:
			if item.kind == PILE:
				_decide(item, GONE)
				break
	if _items.size() > MOST:
		_decide(_items[0], GONE)


func _decide(item: Item, state: int) -> void:
	_apply(item, state)
	_outbox.append(item.key)
	_outbox.append(state)


func _apply(item: Item, state: int, again := false) -> void:
	if state == GONE:
		for node in item.nodes:
			if is_instance_valid(node):
				node.fade()
		item.state = GONE
		_forget(item)
		return
	if item.kind == TRAP:
		if state > item.state:
			item.state = state
			for node in item.nodes:
				node.wear_to(state, WEAR_HITS)
	elif item.kind == PILE:
		var hit := state & ~item.state if not again else state
		item.state |= state
		for brick in item.nodes:
			if is_instance_valid(brick) and hit & (1 << brick.drop_index) != 0:
				brick.fade(BRICK_LINGER)


func _forget(item: Item) -> void:
	_items.erase(item)
	if _by_key.get(item.key) == item:
		_by_key.erase(item.key)
