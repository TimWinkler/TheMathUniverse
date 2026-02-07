extends Node

## Achievement system that tracks and awards achievements based on discovery milestones.

signal achievement_unlocked(achievement_id: String, achievement_name: String, description: String)

const ACHIEVEMENTS := {
	"first_contact": {
		"name": "First Contact",
		"description": "Discover your first topic",
	},
	"curious_mind": {
		"name": "Curious Mind",
		"description": "Discover 10 topics",
	},
	"galaxy_explorer": {
		"name": "Galaxy Explorer",
		"description": "Fully explore one galaxy",
	},
	"bridge_builder": {
		"name": "Bridge Builder",
		"description": "Discover topics in 3+ galaxies",
	},
	"speed_runner": {
		"name": "Speed Runner",
		"description": "Discover 20 topics in 10 minutes",
	},
	"cartographer": {
		"name": "The Cartographer",
		"description": "Discover 50% of the universe",
	},
	"universal_mind": {
		"name": "Universal Mind",
		"description": "Discover everything",
	},
}

var _unlocked: Dictionary = {}  # achievement_id -> timestamp


func _ready() -> void:
	await get_tree().process_frame
	DiscoveryManager.node_discovered.connect(_on_node_discovered)


func _on_node_discovered(_node_id: String) -> void:
	_check_all()


func _check_all() -> void:
	var topic_count := DiscoveryManager.get_topic_discovery_count()
	var total_discovered := DiscoveryManager.get_discovery_count()
	var total_nodes := DiscoveryManager.get_total_count()

	# First Contact: discover 1 topic
	if topic_count >= 1:
		_try_unlock("first_contact")

	# Curious Mind: discover 10 topics
	if topic_count >= 10:
		_try_unlock("curious_mind")

	# Galaxy Explorer: 100% one domain
	if DataLoader.graph:
		for domain in DataLoader.graph.domains:
			if DiscoveryManager.get_domain_progress(domain.id) >= 1.0:
				_try_unlock("galaxy_explorer")
				break

	# Bridge Builder: discoveries in 3+ domains
	if DiscoveryManager.get_domains_with_discoveries() >= 3:
		_try_unlock("bridge_builder")

	# Speed Runner: 20 topics in 10 minutes
	if topic_count >= 20 and DiscoveryManager.get_elapsed_minutes() <= 10.0:
		_try_unlock("speed_runner")

	# Cartographer: 50% of all nodes
	if total_nodes > 0 and float(total_discovered) / float(total_nodes) >= 0.5:
		_try_unlock("cartographer")

	# Universal Mind: everything
	if total_nodes > 0 and total_discovered >= total_nodes:
		_try_unlock("universal_mind")


func _try_unlock(achievement_id: String) -> void:
	if _unlocked.has(achievement_id):
		return
	_unlocked[achievement_id] = Time.get_unix_time_from_system()
	var data: Dictionary = ACHIEVEMENTS[achievement_id]
	achievement_unlocked.emit(achievement_id, data["name"], data["description"])
	print("[Achievements] Unlocked: %s" % data["name"])


func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.has(achievement_id)


func get_unlocked_count() -> int:
	return _unlocked.size()


func get_total_count() -> int:
	return ACHIEVEMENTS.size()
