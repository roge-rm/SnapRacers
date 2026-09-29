class_name NetRace
extends Node

## The part of a race that happens over the network (see NetSession).
##
## Every kart belongs to one device: people's karts to their own phones, and
## the AI karts to the host. A device drives its own karts and sends where
## they are about twenty times a second. Everyone else's are remote karts
## (see Kart.remote), shown a tenth of a second behind their updates so
## there are always two to blend between, which keeps them smooth when
## updates arrive unevenly. If one's late, the kart carries on the way it was
## going for a moment.
##
## What happens to a kart is sent as it happens: parts coming off, repairs,
## resets and gadgets, so its wreckage, bubble and bricks show up everywhere.
## Only a kart's own device decides whether it was hit, so a brick that
## misses on one screen and hits on another hurts it once, where it counts.
##
## The host decides when karts finish, so everyone agrees on the order, and
## ends the race once everyone's home.

const SEND_EVERY := 0.05
## Bluetooth carries a lot less, so karts are sent half as often over it, and
## shown further behind to make up for it.
const SEND_EVERY_BLUETOOTH := 0.1
## How far behind its updates a remote kart is shown, in seconds.
const BEHIND := 0.1
## How long a remote kart carries on by itself when its updates stop.
const GUESS_FOR := 0.3
const BEHIND_BLUETOOTH := 0.2
## After the first person finishes, the race ends anyway after this long.
const WAIT_FOR_LAST := 90.0
const END_AFTER := 4.0

var race: Race
var session: NetSession
var setup: Dictionary
## Each kart's slot: the Racer, and who drives it.
var racers := {}
var owners := {}
## Updates for each remote kart: [when it came, state].
var _updates := {}
var _send_in := 0.0
var _clock := 0.0
var _first_home := -1.0
var _all_home := -1.0
var _ended := false
## Whether it's over Bluetooth.
var _slow := false


func _init(for_race: Race, for_session: NetSession) -> void:
	race = for_race
	session = for_session
	setup = session.setup
	name = "NetRace"


func add(slot: int, racer: Race.Racer, owner: int) -> void:
	racers[slot] = racer
	owners[slot] = owner
	var kart := racer.kart
	if owner != session.my_id():
		kart.remote = true
		_updates[slot] = []
		return
	kart.parts_lost.connect(func(indices: Array[int]) -> void: session.kart_event.rpc(slot, "lost", indices))
	kart.repaired.connect(func() -> void: session.kart_event.rpc(slot, "repaired", null))
	kart.was_reset.connect(func() -> void: session.kart_event.rpc(slot, "reset", null))
	kart.gadget_used.connect(func(kind: String) -> void: session.kart_event.rpc(slot, "gadget", kind))


func slot_of(racer: Race.Racer) -> int:
	for slot in racers:
		if racers[slot] == racer:
			return slot
	return -1


func _ready() -> void:
	_slow = session.multiplayer.multiplayer_peer is BluetoothPeer
	session.race_ready(self)


## The host says go: the countdown starts.
func go() -> void:
	race.net_go = true


func _physics_process(delta: float) -> void:
	_clock += delta
	_send_in -= delta
	if _send_in <= 0.0:
		_send_in = SEND_EVERY_BLUETOOTH if _slow else SEND_EVERY
		for slot in racers:
			if owners[slot] == session.my_id() and is_instance_valid(racers[slot].kart):
				session.kart_state.rpc(slot, racers[slot].kart.net_state())
	for slot in _updates:
		_show(slot)
	if session.is_host():
		_referee(delta)


func got_state(sender: int, slot: int, state: PackedFloat32Array) -> void:
	if owners.get(slot, -1) != sender or not _updates.has(slot) or state.size() < 13:
		return
	var list: Array = _updates[slot]
	list.append([_clock, state])
	while list.size() > 8:
		list.pop_front()


## Puts a remote kart where its updates say it was a moment ago.
func _show(slot: int) -> void:
	var list: Array = _updates[slot]
	if list.is_empty() or not is_instance_valid(racers[slot].kart):
		return
	var at := _clock - (BEHIND_BLUETOOTH if _slow else BEHIND)
	var before: Array = list[0]
	var after: Array = list[0]
	for u in list:
		if u[0] <= at:
			before = u
		else:
			after = u
			break
	var s: PackedFloat32Array = before[1]
	var pos := Vector3(s[0], s[1], s[2])
	var rot := Quaternion(s[3], s[4], s[5], s[6]).normalized()
	var vel := Vector3(s[7], s[8], s[9])
	var steer := s[10]
	if after != before and after[0] > before[0]:
		var t := clampf((at - before[0]) / (after[0] - before[0]), 0.0, 1.0)
		var e: PackedFloat32Array = after[1]
		pos = pos.lerp(Vector3(e[0], e[1], e[2]), t)
		rot = rot.slerp(Quaternion(e[3], e[4], e[5], e[6]).normalized(), t)
		vel = vel.lerp(Vector3(e[7], e[8], e[9]), t)
		steer = lerpf(steer, e[10], t)
	elif at > before[0]:
		# Nothing newer yet, so it carries on the way it was going.
		pos += vel * minf(at - before[0], GUESS_FOR)
	var last: PackedFloat32Array = list[-1][1]
	racers[slot].kart.show_net_state(Transform3D(Basis(rot), pos), vel, steer, last[11], int(last[12]))


func got_event(sender: int, slot: int, kind: String, data: Variant) -> void:
	if owners.get(slot, -1) != sender or not racers.has(slot):
		return
	var kart: Kart = racers[slot].kart
	if not is_instance_valid(kart):
		return
	match kind:
		"lost":
			var indices: Array[int] = []
			indices.assign(data)
			kart.lose_parts(indices)
		"repaired":
			kart.repair_now()
		"reset":
			Sounds.play_at("fx/reset", kart.sound)
		"gadget":
			var noise: String = Kart.GADGET_SOUNDS.get(str(data), "")
			if noise != "":
				Sounds.play_at(noise, kart.sound)
			match str(data):
				"shield":
					kart.show_net_state(kart.global_transform, kart.remote_velocity, kart.steer_angle, Kart.SHIELD_TIME, kart.studs)
				"cannon":
					race.add_child(BrickShot.fire(kart))
				"dropper":
					for brick in BrickPile.drop_behind(kart):
						race.add_child(brick)
				"oil":
					race.add_child(OilSlick.drop_behind(kart))


## The host's word that a kart's finished, and when.
func got_finish(slot: int, time: float) -> void:
	if not racers.has(slot):
		return
	var progress: RaceProgress = racers[slot].progress
	progress.finished = true
	progress.finish_time = time


## Someone's left: their karts go.
func forget(peer: int) -> void:
	for slot in owners.keys():
		if owners[slot] != peer:
			continue
		var racer: Race.Racer = racers[slot]
		race.racers.erase(racer)
		if is_instance_valid(racer.kart):
			racer.kart.queue_free()
		racers.erase(slot)
		owners.erase(slot)
		_updates.erase(slot)


## The host watches for karts finishing, and ends the race once all the
## people are home (or it's been going on long after the first of them).
func _referee(delta: float) -> void:
	if _ended or not race.started:
		return
	var people_home := true
	for slot in racers:
		var racer: Race.Racer = racers[slot]
		if racer.progress.finished and not racer.get_meta("told", false):
			racer.set_meta("told", true)
			session.finished.rpc(slot, racer.progress.finish_time)
		var human: bool = setup.entries[slot].get("human", false)
		if human:
			if racer.progress.finished and _first_home < 0.0:
				_first_home = race.time
			if not racer.progress.finished:
				people_home = false
	if people_home and _all_home < 0.0:
		_all_home = race.time
	var long_after := _first_home >= 0.0 and race.time - _first_home > WAIT_FOR_LAST
	if (_all_home >= 0.0 and race.time - _all_home > END_AFTER) or long_after:
		_ended = true
		session.end_race(race.standings().map(func(r): return r.name))
