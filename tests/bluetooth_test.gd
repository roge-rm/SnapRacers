extends Node

## The Bluetooth game (BluetoothPeer), without Bluetooth: a pretend Android
## plugin passes packets between a host and two players, all in this one
## process, each with its own multiplayer. It checks what the real plugin
## can't be checked for on a PC: that players learn their ids, that RPCs get
## there both ways and from one player to another through the host, and that
## someone leaving is noticed.

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## The radio between the phones: which link on one phone is which on another.
class Air:
	var host: FakeAndroid
	## [player's plugin, the link's number on the host, on the player]
	var links: Array = []


## Stands in for the SnapRacersNet plugin, with just the Bluetooth part.
class FakeAndroid:
	var air: Air
	var events: Array = []
	var next_link := 2

	func poll() -> Dictionary:
		return events.pop_front() if not events.is_empty() else {}

	func bt_host() -> bool:
		air.host = self
		return true

	func bt_join(_device: String) -> bool:
		var on_host := air.host.next_link
		air.host.next_link += 1
		var here := next_link
		next_link += 1
		air.links.append([self, on_host, here])
		air.host.events.append({"kind": "bt_connected", "peer": on_host})
		events.append({"kind": "bt_connected", "peer": here})
		return true

	func bt_send(link: int, data: PackedByteArray, _reliable: bool) -> bool:
		for l in air.links:
			if self == air.host and l[1] == link:
				l[0].events.append({"kind": "bt_packet", "peer": l[2], "data": data})
			elif l[0] == self and l[2] == link:
				air.host.events.append({"kind": "bt_packet", "peer": l[1], "data": data})
		return true

	func bt_disconnect(link: int) -> void:
		for l in air.links.duplicate():
			if (self == air.host and l[1] == link) or (l[0] == self and l[2] == link):
				air.links.erase(l)
				air.host.events.append({"kind": "bt_left", "peer": l[1]})
				l[0].events.append({"kind": "bt_left", "peer": l[2]})

	func bt_stop() -> void:
		for l in air.links.duplicate():
			if self == air.host or l[0] == self:
				bt_disconnect(l[1] if self == air.host else l[2])


## The same node in each phone's tree, for RPCs to go between.
class Pinger extends Node:
	var heard: Array = []

	@rpc("any_peer", "call_remote", "reliable")
	func ping(text: String) -> void:
		heard.append([multiplayer.get_remote_sender_id(), text])

	@rpc("any_peer", "call_remote", "unreliable_ordered")
	func where(at: Vector3) -> void:
		heard.append([multiplayer.get_remote_sender_id(), at])


func phone(label: String, air: Air) -> Array:
	var root := Node.new()
	root.name = label
	add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	var plugin := NetPlugin.new()
	root.add_child(plugin)
	plugin.android = FakeAndroid.new()
	plugin.android.air = air
	var pinger := Pinger.new()
	pinger.name = "Pinger"
	root.add_child(pinger)
	return [root, api, plugin, pinger]


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var air := Air.new()
	var host := phone("Host", air)
	var one := phone("One", air)
	var two := phone("Two", air)

	var host_peer := BluetoothPeer.host(host[2])
	check(host_peer != null and host_peer.get_unique_id() == 1, "a phone can host over Bluetooth")
	host[1].multiplayer_peer = host_peer
	var joined := []
	host[1].peer_connected.connect(func(id: int) -> void: joined.append(id))

	var connected := [false, false]
	for i in 2:
		var player: Array = [one, two][i]
		var peer := BluetoothPeer.join(player[2], "00:11:22:33:44:55")
		player[1].multiplayer_peer = peer
		player[1].connected_to_server.connect(func() -> void: connected[i] = true)
	check(one[1].multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING, "a player's connecting until the host says who they are")
	await frames(10)
	check(connected[0] and connected[1], "both players connect")
	var ids := [one[1].get_unique_id(), two[1].get_unique_id()]
	check(ids[0] > 1 and ids[1] > 1 and ids[0] != ids[1], "each with their own id (%s)" % str(ids))
	check(joined.size() == 2 and ids[0] in joined and ids[1] in joined, "and the host sees them both come in")
	await frames(10)
	check(ids[1] in one[1].get_peers(), "players hear about each other through the host")

	one[3].ping.rpc_id(1, "hello host")
	host[3].ping.rpc("hello everyone")
	one[3].ping.rpc_id(ids[1], "hello two")
	two[3].where.rpc(Vector3(1, 2, 3))
	await frames(10)
	check(host[3].heard.has([ids[0], "hello host"]), "the host hears a player")
	check(one[3].heard.has([1, "hello everyone"]) and two[3].heard.has([1, "hello everyone"]), "both players hear the host")
	check(two[3].heard.has([ids[0], "hello two"]), "one player reaches the other, through the host")
	check(host[3].heard.has([ids[1], Vector3(1, 2, 3)]) and one[3].heard.has([ids[1], Vector3(1, 2, 3)]), "unreliable packets (like kart positions) get there too")

	var left := []
	host[1].peer_disconnected.connect(func(id: int) -> void: left.append(id))
	var gone := [false]
	one[1].server_disconnected.connect(func() -> void: gone[0] = true)
	two[1].multiplayer_peer.close()
	await frames(10)
	check(left == [ids[1]], "the host notices a player leaving")
	host[1].multiplayer_peer.close()
	await frames(10)
	check(gone[0], "and a player notices the host stopping")

	print("All Bluetooth checks passed." if failures == 0 else "%d Bluetooth checks failed." % failures)
	get_tree().quit(1 if failures > 0 else 0)
