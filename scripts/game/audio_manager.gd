extends Node

## Autoload that manages music and SFX playback.
## Uses graceful fallback: runs silently if audio assets are missing.
## Music crossfades, SFX uses a pool of AudioStreamPlayers.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const SFX_POOL_SIZE := 6
const CROSSFADE_DURATION := 2.0

var music_volume_db := 0.0
var sfx_volume_db := 0.0
var _is_muted := false

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index := 0


func _ready() -> void:
	# Create audio bus layout if buses don't exist
	_ensure_buses()

	# Create music players
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = MUSIC_BUS
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = MUSIC_BUS
	add_child(_music_player_b)

	_active_music_player = _music_player_a

	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_pool.append(player)

	# Connect to game signals for auto-SFX
	await get_tree().process_frame
	await get_tree().process_frame
	DiscoveryManager.node_discovered.connect(_on_node_discovered)
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	QuestManager.quest_completed.connect(_on_quest_completed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mute"):
		toggle_mute()
		get_viewport().set_input_as_handled()


func _ensure_buses() -> void:
	# Check if Music and SFX buses exist; if not, add them
	var bus_count := AudioServer.bus_count
	var has_music := false
	var has_sfx := false
	for i in range(bus_count):
		var name := AudioServer.get_bus_name(i)
		if name == MUSIC_BUS:
			has_music = true
		elif name == SFX_BUS:
			has_sfx = true

	if not has_music:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MUSIC_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

	if not has_sfx:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, SFX_BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func play_music(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return

	# Crossfade
	var old_player := _active_music_player
	var new_player := _music_player_b if _active_music_player == _music_player_a else _music_player_a
	_active_music_player = new_player

	new_player.stream = stream
	new_player.volume_db = -40.0
	new_player.play()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(new_player, "volume_db", music_volume_db, CROSSFADE_DURATION)
	if old_player.playing:
		tween.tween_property(old_player, "volume_db", -40.0, CROSSFADE_DURATION)
		tween.chain().tween_callback(old_player.stop)


func stop_music(fade_duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(_active_music_player, "volume_db", -40.0, fade_duration)
	tween.tween_callback(_active_music_player.stop)


func play_sfx(path: String, volume_offset_db: float = 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream == null:
		return

	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset_db
	player.play()


func toggle_mute() -> void:
	_is_muted = not _is_muted
	var master_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, _is_muted)
	print("[AudioManager] Muted: %s" % _is_muted)


func is_muted() -> bool:
	return _is_muted


func set_music_volume(db: float) -> void:
	music_volume_db = db
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


func set_sfx_volume(db: float) -> void:
	sfx_volume_db = db
	var idx := AudioServer.get_bus_index(SFX_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)


# Auto-SFX on game events
func _on_node_discovered(_node_id: String) -> void:
	play_sfx("res://assets/audio/sfx/discover.wav")


func _on_achievement_unlocked(_id: String, _name: String, _desc: String) -> void:
	play_sfx("res://assets/audio/sfx/achievement.wav")


func _on_quest_completed(_id: String, _name: String, _reward: String) -> void:
	play_sfx("res://assets/audio/sfx/quest_complete.wav")
