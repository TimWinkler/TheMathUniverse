extends Node

## Saves and loads game state to user://save.json.

const SAVE_PATH := "user://save.json"


func save_game() -> void:
	# Skip saving if online and not the server
	if NetworkManager.is_online and not multiplayer.is_server():
		return

	var data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"discovered": DiscoveryManager._discovered.duplicate(),
		"adjacent": DiscoveryManager._adjacent.duplicate(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] Could not open save file for writing")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] Could not open save file for reading")
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[SaveManager] JSON parse error: " + json.get_error_message())
		return false

	var data = json.data
	if data == null or not data is Dictionary:
		return false

	var discovered: Dictionary = {}
	var adjacent: Dictionary = {}

	# Restore discovered nodes
	var disc_data = data.get("discovered", {})
	for key in disc_data:
		discovered[key] = float(disc_data[key])

	# Restore adjacent nodes
	var adj_data = data.get("adjacent", {})
	for key in adj_data:
		adjacent[key] = true

	DiscoveryManager.restore_state(discovered, adjacent)
	print("[SaveManager] Loaded save: %d discovered, %d adjacent" % [discovered.size(), adjacent.size()])
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
