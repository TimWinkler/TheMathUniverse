extends PanelContainer

## Chat overlay — bottom-left, semi-transparent.
## Enter key focuses input, sends message via RPC.
## Auto-hides in single-player mode.

@onready var chat_log: RichTextLabel = %ChatLog
@onready var chat_input: LineEdit = %ChatInput
@onready var send_button: Button = %SendButton


func _ready() -> void:
	send_button.pressed.connect(_on_send_pressed)
	chat_input.text_submitted.connect(_on_text_submitted)

	# Hide in single-player
	if not NetworkManager.is_online:
		visible = false
		return

	# System messages for join/leave
	NetworkManager.player_connected.connect(_on_player_joined)
	NetworkManager.player_disconnected.connect(_on_player_left)

	_add_system_message("Connected to game.")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("chat"):
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()


func _on_send_pressed() -> void:
	_send_message()


func _on_text_submitted(_text: String) -> void:
	_send_message()


func _send_message() -> void:
	var text := chat_input.text.strip_edges()
	if text.is_empty():
		return
	chat_input.text = ""
	var sender := NetworkManager.local_player_name
	_receive_chat_message.rpc(sender, text)


@rpc("any_peer", "reliable", "call_local")
func _receive_chat_message(sender_name: String, message: String) -> void:
	# Look up sender color from peer
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	var color := NetworkManager.get_player_color(sender_id)
	var color_hex := color.to_html(false)
	chat_log.append_text("[color=#%s]%s:[/color] %s\n" % [color_hex, sender_name, message])


func _add_system_message(text: String) -> void:
	chat_log.append_text("[color=#888888]* %s[/color]\n" % text)


func _on_player_joined(peer_id: int) -> void:
	# Wait for registration
	await get_tree().create_timer(0.5).timeout
	var pname := NetworkManager.get_player_name(peer_id)
	_add_system_message("%s joined the game." % pname)


func _on_player_left(peer_id: int) -> void:
	var pname := NetworkManager.get_player_name(peer_id)
	_add_system_message("%s left the game." % pname)
