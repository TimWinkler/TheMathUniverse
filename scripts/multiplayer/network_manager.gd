extends Node

## Manages WebSocket multiplayer connections, player registry, and game state sync.
## Autoload singleton — host-authoritative model.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_list_changed()
signal connection_succeeded()
signal connection_failed(reason: String)
signal server_disconnected()
signal game_started()

const DEFAULT_PORT := 9050

var is_online := false
var is_host_flag := false
var players: Dictionary = {}  # peer_id (int) -> PlayerInfo dict

# PlayerInfo keys: "peer_id", "player_name", "ship_color", "is_host"

var local_player_name := "Explorer"
var local_ship_color := Color(0.6, 0.75, 0.9)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_warning("[NetworkManager] Failed to create server: %s" % error_string(err))
		connection_failed.emit("Failed to create server: %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host_flag = true

	# Register host as player
	var host_info := _make_player_info(1, local_player_name, local_ship_color, true)
	players[1] = host_info
	player_list_changed.emit()

	print("[NetworkManager] Hosting on port %d" % port)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var url := "ws://%s:%d" % [address, port]
	var err := peer.create_client(url)
	if err != OK:
		push_warning("[NetworkManager] Failed to connect: %s" % error_string(err))
		connection_failed.emit("Failed to connect: %s" % error_string(err))
		return err

	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host_flag = false

	print("[NetworkManager] Connecting to %s" % url)
	return OK


func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	is_online = false
	is_host_flag = false
	player_list_changed.emit()
	print("[NetworkManager] Disconnected")


func start_game() -> void:
	if not is_host_flag:
		return
	_begin_game.rpc()


func _make_player_info(peer_id: int, player_name: String, ship_color: Color, is_host: bool) -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_name": player_name,
		"ship_color": [ship_color.r, ship_color.g, ship_color.b],
		"is_host": is_host,
	}


func get_player_color(peer_id: int) -> Color:
	var info = players.get(peer_id)
	if info and info.has("ship_color"):
		var c = info["ship_color"]
		return Color(c[0], c[1], c[2])
	return Color(0.6, 0.75, 0.9)


func get_player_name(peer_id: int) -> String:
	var info = players.get(peer_id)
	if info and info.has("player_name"):
		return info["player_name"]
	return "Unknown"


# --- Signal handlers ---

func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Peer connected: %d" % peer_id)
	player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Peer disconnected: %d" % peer_id)
	players.erase(peer_id)
	player_disconnected.emit(peer_id)
	player_list_changed.emit()


func _on_connected_to_server() -> void:
	print("[NetworkManager] Connected to server as peer %d" % multiplayer.get_unique_id())
	connection_succeeded.emit()
	# Send our info to the server
	_register_player.rpc_id(1, local_player_name, [local_ship_color.r, local_ship_color.g, local_ship_color.b])


func _on_connection_failed() -> void:
	print("[NetworkManager] Connection failed")
	is_online = false
	connection_failed.emit("Connection failed")


func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected")
	players.clear()
	is_online = false
	is_host_flag = false
	player_list_changed.emit()
	server_disconnected.emit()


# --- RPCs ---

@rpc("any_peer", "reliable")
func _register_player(player_name: String, ship_color_arr: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var color := Color(ship_color_arr[0], ship_color_arr[1], ship_color_arr[2])
	var info := _make_player_info(sender_id, player_name, color, false)
	players[sender_id] = info
	print("[NetworkManager] Registered player: %s (peer %d)" % [player_name, sender_id])

	# Broadcast full player list to everyone
	var serialized := _serialize_players()
	_sync_player_list.rpc(serialized)
	player_list_changed.emit()


@rpc("authority", "reliable", "call_local")
func _sync_player_list(serialized: Array) -> void:
	players.clear()
	for entry in serialized:
		var peer_id: int = int(entry["peer_id"])
		players[peer_id] = entry
	player_list_changed.emit()


@rpc("authority", "reliable", "call_local")
func _begin_game() -> void:
	print("[NetworkManager] Game starting!")
	game_started.emit()


func _serialize_players() -> Array:
	var result: Array = []
	for peer_id in players:
		result.append(players[peer_id])
	return result


# --- Late-joiner game state sync ---

func request_game_state() -> void:
	if is_online and not is_host_flag:
		_request_game_state.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_game_state() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var discovered = DiscoveryManager._discovered.duplicate()
	var adjacent = DiscoveryManager._adjacent.duplicate()
	# Convert to serializable format
	var disc_arr: Array = []
	for key in discovered:
		disc_arr.append([key, discovered[key]])
	var adj_arr: Array = []
	for key in adjacent:
		adj_arr.append(key)
	_receive_game_state.rpc_id(sender_id, disc_arr, adj_arr)


@rpc("authority", "reliable")
func _receive_game_state(disc_arr: Array, adj_arr: Array) -> void:
	var discovered: Dictionary = {}
	for entry in disc_arr:
		discovered[entry[0]] = entry[1]
	var adjacent: Dictionary = {}
	for node_id in adj_arr:
		adjacent[node_id] = true
	DiscoveryManager.restore_state(discovered, adjacent)
	print("[NetworkManager] Received game state: %d discovered, %d adjacent" % [discovered.size(), adjacent.size()])
