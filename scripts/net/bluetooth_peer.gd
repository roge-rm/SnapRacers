class_name BluetoothPeer
extends MultiplayerPeerExtension

## A game over Bluetooth, looking to Godot like any other network, so the
## lobby and racing don't know the difference. The Android plugin does the
## sockets (see Bluetooth.kt), and hands packets over through NetPlugin.
##
## The host takes several players (Bluetooth allows up to seven), and each
## player's only link is to the host. Godot relays anything meant for another
## player through the host, the same as it does over ENet.
##
## Every packet starts with a byte saying what it is. A player learns their
## id from the host's first packet (HELLO), and everything after that is DATA,
## with the channel and transfer mode it was sent with.

const DATA := 0
const HELLO := 1

var hosting := false
var _plugin: NetPlugin
var _id := 0
## Players' links, when hosting. A link's number from the plugin is also the
## player's id, since they start at 2 and never repeat.
var _links := {}
## The link to the host, when joining.
var _host_link := -1
## Packets waiting to be read: [data, from, channel, mode].
var _queue: Array = []
var _target := 0
var _channel := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _refusing := false
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED


## Starts hosting, or null when Bluetooth can't.
static func host(plugin: NetPlugin) -> BluetoothPeer:
	if not plugin.has() or not plugin.android.bt_host():
		return null
	var peer := BluetoothPeer.new()
	peer.hosting = true
	peer._plugin = plugin
	peer._id = 1
	peer._status = MultiplayerPeer.CONNECTION_CONNECTED
	plugin.bluetooth = peer
	return peer


## Starts joining the host on this device (its Bluetooth address).
static func join(plugin: NetPlugin, device: String) -> BluetoothPeer:
	if not plugin.has() or not plugin.android.bt_join(device):
		return null
	var peer := BluetoothPeer.new()
	peer._plugin = plugin
	peer._status = MultiplayerPeer.CONNECTION_CONNECTING
	plugin.bluetooth = peer
	return peer


## Something the plugin's said about our links.
func got(event: Dictionary) -> void:
	match str(event.kind):
		"bt_connected":
			var link := int(event.peer)
			if hosting:
				if _refusing:
					_plugin.android.bt_disconnect(link)
					return
				_links[link] = true
				var hello := PackedByteArray([HELLO, 0, 0, 0, 0])
				hello.encode_u32(1, link)
				_plugin.android.bt_send(link, hello, true)
				peer_connected.emit(link)
			else:
				_host_link = link
		"bt_packet":
			var data: PackedByteArray = event.data
			if data.is_empty():
				return
			if data[0] == HELLO and not hosting and data.size() >= 5:
				_id = data.decode_u32(1)
				_status = MultiplayerPeer.CONNECTION_CONNECTED
				peer_connected.emit(1)
			elif data[0] == DATA and data.size() >= 3:
				var from := int(event.peer) if hosting else 1
				_queue.append([data.slice(3), from, data[1], data[2]])
		"bt_left":
			var link := int(event.peer)
			if hosting:
				if _links.erase(link):
					peer_disconnected.emit(link)
			elif link == _host_link:
				_host_link = -1
				if _status == MultiplayerPeer.CONNECTION_CONNECTED:
					peer_disconnected.emit(1)
				_status = MultiplayerPeer.CONNECTION_DISCONNECTED
		"bt_failed":
			if not hosting:
				_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _poll() -> void:
	if _plugin != null:
		_plugin.pump()


func _get_available_packet_count() -> int:
	return _queue.size()


func _get_max_packet_size() -> int:
	return 1 << 20


func _get_packet_script() -> PackedByteArray:
	return _queue.pop_front()[0] if not _queue.is_empty() else PackedByteArray()


func _get_packet_peer() -> int:
	return _queue[0][1] if not _queue.is_empty() else 0


func _get_packet_channel() -> int:
	return _queue[0][2] if not _queue.is_empty() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return _queue[0][3] if not _queue.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _put_packet_script(data: PackedByteArray) -> Error:
	var packet := PackedByteArray([DATA, _channel, _mode])
	packet.append_array(data)
	var reliable := _mode == MultiplayerPeer.TRANSFER_MODE_RELIABLE
	if not hosting:
		if _host_link >= 0:
			_plugin.android.bt_send(_host_link, packet, reliable)
		return OK
	for link in _links:
		if _target == 0 or _target == link or (_target < 0 and -_target != link):
			_plugin.android.bt_send(link, packet, reliable)
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
	return _id


func _is_server() -> bool:
	return hosting


func _is_server_relay_supported() -> bool:
	return true


func _set_refuse_new_connections(refuse: bool) -> void:
	_refusing = refuse


func _is_refusing_new_connections() -> bool:
	return _refusing


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _disconnect_peer(id: int, _now: bool) -> void:
	_plugin.android.bt_disconnect(id)


func _close() -> void:
	if _plugin != null:
		_plugin.android.bt_stop()
		if _plugin.bluetooth == self:
			_plugin.bluetooth = null
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_links.clear()
	_queue.clear()
