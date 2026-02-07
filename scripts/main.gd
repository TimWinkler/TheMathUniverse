extends Node

## Main scene — bootstraps the universe, player ship(s), and connects UI.
## Handles multiplayer ship spawning and late-joiner state sync.

const PlayerShipScene := preload("res://scenes/player/player_ship.tscn")

@onready var universe: UniverseManager = $Universe
@onready var info_panel: PanelContainer = $UI/InfoPanel
@onready var hud: CanvasLayer = $UI/HUD
@onready var minimap = $UI/Minimap

var _ships: Dictionary = {}  # peer_id -> PlayerShip


func _ready() -> void:
	# Wait for universe to finish loading
	await get_tree().process_frame
	await get_tree().process_frame

	# Connect signals
	universe.node_selected.connect(_on_node_selected)

	var cam := universe.camera_controller
	if cam:
		cam.node_hovered.connect(_on_node_hovered)
		cam.node_unhovered.connect(_on_node_unhovered)

	# Spawn ships
	if NetworkManager.is_online:
		_spawn_all_ships()
		NetworkManager.player_connected.connect(_on_player_connected)
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)

		# Late-joiner: request game state from server
		if not NetworkManager.is_host_flag:
			NetworkManager.request_game_state()
	else:
		_spawn_local_ship()

	# Start background music (runs silently if file missing)
	AudioManager.play_music("res://assets/audio/music/ambient.ogg")

	print("[Main] The Math Universe is ready!")


func _spawn_local_ship() -> void:
	var ship := _spawn_ship(1, true)
	# Apply local color in solo mode
	var cam := universe.camera_controller
	if cam:
		cam.set_follow_target(ship)
	_setup_minimap(ship)


func _spawn_all_ships() -> void:
	var my_id := multiplayer.get_unique_id()

	# Spawn local ship
	var local_ship := _spawn_ship(my_id, true)
	var local_color := NetworkManager.local_ship_color
	_apply_local_ship_color(local_ship, local_color)

	var cam := universe.camera_controller
	if cam:
		cam.set_follow_target(local_ship)
	_setup_minimap(local_ship)

	# Spawn remote ships for existing players
	for peer_id in NetworkManager.players:
		if peer_id != my_id:
			_spawn_ship(peer_id, false)


func _spawn_ship(peer_id: int, is_local: bool) -> PlayerShip:
	var ship: PlayerShip = PlayerShipScene.instantiate()
	ship.name = "Ship_%d" % peer_id
	universe.add_child(ship)
	ship.global_position = Vector3.ZERO
	ship.set_universe_manager(universe)
	ship.peer_id = peer_id

	if is_local:
		ship.is_local = true
	else:
		var pname := NetworkManager.get_player_name(peer_id)
		var pcolor := NetworkManager.get_player_color(peer_id)
		ship.setup_remote(peer_id, pname, pcolor)

	_ships[peer_id] = ship
	return ship


func _apply_local_ship_color(ship: PlayerShip, color: Color) -> void:
	if ship.mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color.darkened(0.2)
	mat.emission_energy_multiplier = 2.0
	mat.metallic = 0.5
	mat.roughness = 0.3
	ship.mesh_instance.material_override = mat


func _on_player_connected(peer_id: int) -> void:
	# Wait a moment for player registration to complete
	await get_tree().create_timer(0.5).timeout
	if not _ships.has(peer_id) and peer_id != multiplayer.get_unique_id():
		_spawn_ship(peer_id, false)


func _on_player_disconnected(peer_id: int) -> void:
	if _ships.has(peer_id):
		_ships[peer_id].queue_free()
		_ships.erase(peer_id)


func _on_server_disconnected() -> void:
	# Return to lobby
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_node_selected(math_node: MathTypes.MathNode) -> void:
	info_panel.show_node(math_node)


func _on_node_hovered(node_id: String) -> void:
	hud.show_hover(node_id)


func _on_node_unhovered(node_id: String) -> void:
	hud.clear_hover(node_id)


func _setup_minimap(player_ship: Node3D) -> void:
	if minimap and universe and universe.camera_controller:
		minimap.setup(universe, universe.camera_controller, player_ship)
