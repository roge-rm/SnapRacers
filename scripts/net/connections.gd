class_name Connections
extends RefCounted

## The ways devices connect for a game, each giving NetSession a
## MultiplayerPeer to work over.
##
## Wi-Fi, a phone's hotspot, Wi-Fi Direct (once its group has formed) and a
## typed address are all ordinary IP networks, and use ENet. A web page can't
## use ENet, so browsers join a dedicated server over a WebSocket instead.
## Bluetooth isn't IP at all, and has a peer of its own (see BluetoothPeer).

## Hosts over ENet. Returns the peer, or null with the reason in `why`.
static func host_enet(port := NetSession.PORT, why: Array = []) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, NetSession.MOST_KARTS)
	if error != OK:
		why.append("I couldn't start a game on port %d. Is another game already running?" % port)
		return null
	return peer


## Joins a game at this address over ENet.
static func join_enet(address: String, port := NetSession.PORT, why: Array = []) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		why.append("I couldn't connect to %s." % address)
		return null
	return peer


## Joins a dedicated server over a WebSocket, which is all a web page can do.
## A page served over HTTPS can only open a secure one (wss).
static func join_websocket(url: String, why: Array = []) -> MultiplayerPeer:
	var peer := WebSocketMultiplayerPeer.new()
	var error := peer.create_client(url)
	if error != OK:
		why.append("I couldn't connect to %s." % url)
		return null
	return peer


## What someone typed to join a server over a WebSocket, as its URL. Without
## a port it's the server's WebSocket port, and the phones' port is taken to
## mean that too, since that's the one a server shows first. A page served
## over HTTPS can only use a secure one (wss), and one that isn't uses ws.
static func websocket_url(text: String) -> String:
	if text.contains("://"):
		return text
	var secure := true
	if OS.has_feature("web"):
		# If the page can't be asked, it's most likely on HTTPS.
		secure = str(JavaScriptBridge.eval("location.protocol", true)) != "http:"
	var parts := parse_address(text)
	var port: int = parts[1]
	if port == NetSession.PORT:
		port = DedicatedServer.WS_PORT
	return "%s://%s:%d" % ["wss" if secure else "ws", parts[0], port]


## Splits what someone typed into an address and a port. It can be an IP, a
## name, or either with :port on the end.
static func parse_address(text: String) -> Array:
	var address := text.strip_edges()
	var port := NetSession.PORT
	var colon := address.rfind(":")
	if colon > 0 and address.count(":") == 1:
		port = int(address.substr(colon + 1))
		address = address.substr(0, colon)
	return [address, port if port > 0 else NetSession.PORT]


## This device's addresses that others could reach it on, best first, with a
## normal Wi-Fi network, then a hotspot this phone is running, then Wi-Fi
## Direct's own.
static func my_addresses() -> Array[String]:
	var out: Array[String] = []
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		out.append(address)
	out.sort_custom(func(a: String, b: String) -> bool: return _rank(a) < _rank(b))
	return out


static func _rank(address: String) -> int:
	if address.begins_with("192.168.49."):
		return 3 # Wi-Fi Direct's group owner
	if address.begins_with("192.168.43.") or address.begins_with("10.") and address.ends_with(".1"):
		return 2 # a hotspot
	if address.begins_with("172.17.") or address.begins_with("172.18."):
		return 4 # Docker's own networks
	return 1
