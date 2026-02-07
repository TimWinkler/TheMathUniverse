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
	"galactic_tourist": {
		"name": "Galactic Tourist",
		"description": "Discover topics in 5 galaxies",
	},
	"polymath": {
		"name": "Polymath",
		"description": "Discover topics in 10 galaxies",
	},
	"speed_runner": {
		"name": "Speed Runner",
		"description": "Discover 20 topics in 10 minutes",
	},
	"cartographer": {
		"name": "The Cartographer",
		"description": "Discover 30% of the universe",
	},
	"quest_master": {
		"name": "Quest Master",
		"description": "Complete 10 quests",
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
	var domains_with := DiscoveryManager.get_domains_with_discoveries()

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
	if domains_with >= 3:
		_try_unlock("bridge_builder")

	# Galactic Tourist: discoveries in 5 domains
	if domains_with >= 5:
		_try_unlock("galactic_tourist")

	# Polymath: discoveries in 10 domains
	if domains_with >= 10:
		_try_unlock("polymath")

	# Speed Runner: 20 topics in 10 minutes
	if topic_count >= 20 and DiscoveryManager.get_elapsed_minutes() <= 10.0:
		_try_unlock("speed_runner")

	# Cartographer: 30% of all nodes (300+ nodes makes 50% very hard)
	if total_nodes > 0 and float(total_discovered) / float(total_nodes) >= 0.3:
		_try_unlock("cartographer")

	# Quest Master: 10 quests completed
	if QuestManager.get_completed_count() >= 10:
		_try_unlock("quest_master")

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
