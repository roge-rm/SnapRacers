class_name MergedPeer
extends MultiplayerPeerExtension

## Several server peers acting as one, so the dedicated server can take
## phones over ENet and web pages over a WebSocket in the same game.
##
## Each player keeps the id the peer they came in on gave them (they're
## random, so two peers handing out the same one is vanishingly unlikely,
## and a joiner who'd clash is turned away). Packets from every peer queue up
## together, and each one goes out through whichever peer its player is on.

var peers: Array[MultiplayerPeer] = []
## Which peer each player is on.
var _owner := {}
## Packets waiting to be read: [data, from, channel, mode].
var _queue: Array = []
var _target := 0
var _channel := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _refusing := false
var _closed := false


func add(peer: MultiplayerPeer) -> void:
	peers.append(peer)
	peer.peer_connected.connect(func(id: int) -> void:
		if _owner.has(id):
			peer.disconnect_peer(id)
			return
		_owner[id] = peer
		peer_connected.emit(id))
	peer.peer_disconnected.connect(func(id: int) -> void:
		if _owner.get(id) == peer:
			_owner.erase(id)
			peer_disconnected.emit(id))


func _poll() -> void:
	for peer in peers:
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var from := peer.get_packet_peer()
			var channel := peer.get_packet_channel()
			var mode := peer.get_packet_mode()
			_queue.append([peer.get_packet(), from, channel, mode])


func _get_available_packet_count() -> int:
	return _queue.size()


func _get_max_packet_size() -> int:
	return 1 << 24


func _get_packet_script() -> PackedByteArray:
	return _queue.pop_front()[0] if not _queue.is_empty() else PackedByteArray()


func _get_packet_peer() -> int:
	return _queue[0][1] if not _queue.is_empty() else 0


func _get_packet_channel() -> int:
	return _queue[0][2] if not _queue.is_empty() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return _queue[0][3] if not _queue.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _put_packet_script(data: PackedByteArray) -> Error:
	for peer in peers:
		var target := _target
		if _target > 0:
			if _owner.get(_target) != peer:
				continue
		elif _target < 0 and _owner.get(-_target) == peer:
			# Everyone but that one, and that one's on this peer.
			target = _target
		peer.transfer_channel = _channel
		peer.transfer_mode = _mode
		peer.set_target_peer(target)
		peer.put_packet(data)
	return OK


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _get_unique_id() -> int:
	return 1


func _is_server() -> bool:
	return true


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(refuse: bool) -> void:
	_refusing = refuse
	for peer in peers:
		peer.refuse_new_connections = refuse


func _is_refusing_new_connections() -> bool:
	return _refusing


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return MultiplayerPeer.CONNECTION_DISCONNECTED if _closed else MultiplayerPeer.CONNECTION_CONNECTED


func _disconnect_peer(id: int, now: bool) -> void:
	var peer: MultiplayerPeer = _owner.get(id)
	if peer != null:
		peer.disconnect_peer(id, now)


func _close() -> void:
	for peer in peers:
		peer.close()
	_closed = true
