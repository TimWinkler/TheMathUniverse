extends Control

## Lobby UI — name entry, host/join, player list, game start.

@onready var name_input: LineEdit = %NameInput
@onready var color_picker: ColorPickerButton = %ColorPicker
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var solo_button: Button = %SoloButton
@onready var start_button: Button = %StartButton
@onready var address_input: LineEdit = %AddressInput
@onready var port_input: LineEdit = %PortInput
@onready var join_panel: VBoxContainer = %JoinPanel
@onready var connect_button: Button = %ConnectButton
@onready var status_label: Label = %StatusLabel
@onready var player_list: VBoxContainer = %PlayerList
@onready var disconnect_button: Button = %DisconnectButton

var _in_lobby := false


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	solo_button.pressed.connect(_on_solo_pressed)
	start_button.pressed.connect(_on_start_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	color_picker.color = Color(0.6, 0.75, 0.9)
	join_panel.visible = false
	start_button.visible = false
	disconnect_button.visible = false
	status_label.text = ""

	NetworkManager.player_list_changed.connect(_update_player_list)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.game_started.connect(_on_game_started)


func _on_host_pressed() -> void:
	_apply_local_settings()
	var port := int(port_input.text) if not port_input.text.is_empty() else NetworkManager.DEFAULT_PORT
	var err := NetworkManager.host_game(port)
	if err == OK:
		status_label.text = "Hosting on port %d..." % port
		_enter_lobby_state()
		start_button.visible = true
	else:
		status_label.text = "Failed to host."


func _on_join_pressed() -> void:
	join_panel.visible = not join_panel.visible


func _on_connect_pressed() -> void:
	_apply_local_settings()
	var address := address_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var port := int(port_input.text) if not port_input.text.is_empty() else NetworkManager.DEFAULT_PORT
	var err := NetworkManager.join_game(address, port)
	if err == OK:
		status_label.text = "Connecting to %s:%d..." % [address, port]
	else:
		status_label.text = "Failed to connect."


func _on_solo_pressed() -> void:
	NetworkManager.is_online = false
	SceneTransition.change_scene("res://scenes/main.tscn")


func _on_start_pressed() -> void:
	NetworkManager.start_game()


func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_game()
	_exit_lobby_state()
	status_label.text = "Disconnected."


func _on_connection_succeeded() -> void:
	status_label.text = "Connected!"
	_enter_lobby_state()


func _on_connection_failed(reason: String) -> void:
	status_label.text = "Connection failed: %s" % reason


func _on_server_disconnected() -> void:
	status_label.text = "Server disconnected."
	_exit_lobby_state()


func _on_game_started() -> void:
	SceneTransition.change_scene("res://scenes/main.tscn")


func _apply_local_settings() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Explorer"
	NetworkManager.local_player_name = player_name
	NetworkManager.local_ship_color = color_picker.color


func _enter_lobby_state() -> void:
	_in_lobby = true
	host_button.disabled = true
	join_button.disabled = true
	solo_button.disabled = true
	join_panel.visible = false
	disconnect_button.visible = true


func _exit_lobby_state() -> void:
	_in_lobby = false
	host_button.disabled = false
	join_button.disabled = false
	solo_button.disabled = false
	start_button.visible = false
	disconnect_button.visible = false


func _update_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()

	for peer_id in NetworkManager.players:
		var info = NetworkManager.players[peer_id]
		var lbl := Label.new()
		var pname = info.get("player_name", "Unknown")
		var host_tag := " (Host)" if info.get("is_host", false) else ""
		lbl.text = "%s%s" % [pname, host_tag]
		var c = info.get("ship_color", [0.6, 0.75, 0.9])
		lbl.add_theme_color_override("font_color", Color(c[0], c[1], c[2]))
		lbl.add_theme_font_size_override("font_size", 18)
		player_list.add_child(lbl)
