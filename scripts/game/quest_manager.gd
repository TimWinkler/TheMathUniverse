extends Node

## Autoload that manages quest progression. Loads quest definitions from JSON,
## tracks active/completed quests, and checks conditions on each discovery.

signal quest_activated(quest_id: String, quest_name: String, description: String)
signal quest_completed(quest_id: String, quest_name: String, reward_text: String)
signal quest_progress_updated(quest_id: String, current: int, target: int)

var _quest_defs: Dictionary = {}  # quest_id -> quest definition dict
var _chain_defs: Array = []       # chain definitions in order
var _standalone_defs: Array = []  # standalone quest definitions
var _active_quests: Dictionary = {}    # quest_id -> true
var _completed_quests: Dictionary = {} # quest_id -> timestamp
var _chain_progress: Dictionary = {}   # chain_id -> index of current quest


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_load_quests()
	_activate_initial_quests()
	DiscoveryManager.node_discovered.connect(_on_node_discovered)


func _load_quests() -> void:
	var data = _read_json("res://data/quests.json")
	if data == null:
		push_warning("[QuestManager] Could not load quests.json")
		return

	# Load chains
	var chains: Array = data.get("chains", [])
	for chain in chains:
		_chain_defs.append(chain)
		var quests: Array = chain.get("quests", [])
		for quest in quests:
			quest["chain_id"] = chain["id"]
			_quest_defs[quest["id"]] = quest

	# Load standalone quests
	var standalones: Array = data.get("standalone", [])
	for quest in standalones:
		quest["chain_id"] = ""
		_standalone_defs.append(quest)
		_quest_defs[quest["id"]] = quest

	print("[QuestManager] Loaded %d quests (%d chains, %d standalone)" % [
		_quest_defs.size(), _chain_defs.size(), _standalone_defs.size()])


func _activate_initial_quests() -> void:
	# Activate first quest in each chain (if not already completed)
	for chain in _chain_defs:
		var quests: Array = chain.get("quests", [])
		if quests.is_empty():
			continue
		_chain_progress[chain["id"]] = 0
		# Find the first uncompleted quest in this chain
		for i in range(quests.size()):
			var qid: String = quests[i]["id"]
			if _completed_quests.has(qid):
				_chain_progress[chain["id"]] = i + 1
				continue
			_activate_quest(qid)
			break

	# Activate all standalone quests (if not completed)
	for quest in _standalone_defs:
		var qid: String = quest["id"]
		if not _completed_quests.has(qid):
			_activate_quest(qid)


func _activate_quest(quest_id: String) -> void:
	if _active_quests.has(quest_id) or _completed_quests.has(quest_id):
		return
	_active_quests[quest_id] = true
	var quest: Dictionary = _quest_defs.get(quest_id, {})
	quest_activated.emit(quest_id, quest.get("name", ""), quest.get("description", ""))


func _on_node_discovered(_node_id: String) -> void:
	_check_all_active()


func _check_all_active() -> void:
	var to_complete: Array[String] = []
	for quest_id in _active_quests:
		var quest: Dictionary = _quest_defs.get(quest_id, {})
		if _check_quest_condition(quest):
			to_complete.append(quest_id)

	for quest_id in to_complete:
		_complete_quest(quest_id)

	# Also emit progress updates for remaining active quests
	for quest_id in _active_quests:
		var quest: Dictionary = _quest_defs.get(quest_id, {})
		var progress := _get_quest_progress(quest)
		var target := _get_quest_target(quest)
		quest_progress_updated.emit(quest_id, progress, target)


func _check_quest_condition(quest: Dictionary) -> bool:
	var qtype: String = quest.get("type", "")
	match qtype:
		"discover_count":
			return _check_discover_count(quest)
		"discover_all_children":
			return _check_discover_all_children(quest)
		"domain_count":
			return _check_domain_count(quest)
		"domain_percentage":
			return _check_domain_percentage(quest)
		"discover_all":
			return _check_discover_all()
		"timed_discovery":
			return _check_timed_discovery(quest)
		"discover_specific":
			return _check_discover_specific(quest)
	return false


func _check_discover_count(quest: Dictionary) -> bool:
	var target = quest.get("target", 1)
	var filter: String = quest.get("filter", "any")

	if filter == "percentage":
		var total := DiscoveryManager.get_total_count()
		if total == 0:
			return false
		var pct := float(DiscoveryManager.get_discovery_count()) / float(total)
		return pct >= target

	if filter == "topic":
		return DiscoveryManager.get_topic_discovery_count() >= int(target)

	if filter == "cross_domain":
		return _count_cross_domain_discoveries() >= int(target)

	# "any" — all nodes
	return DiscoveryManager.get_discovery_count() >= int(target)


func _check_discover_all_children(quest: Dictionary) -> bool:
	var target_level: String = quest.get("target_level", "subdomain")
	if DataLoader.graph == null:
		return false
	for node in DataLoader.graph.nodes.values():
		if node.level != target_level:
			continue
		var children = DataLoader.graph.get_children(node.id)
		if children.is_empty():
			continue
		var all_discovered := true
		for child in children:
			if not DiscoveryManager.is_discovered(child.id):
				all_discovered = false
				break
		if all_discovered:
			return true
	return false


func _check_domain_count(quest: Dictionary) -> bool:
	var target: int = quest.get("target", 1)
	return DiscoveryManager.get_domains_with_discoveries() >= target


func _check_domain_percentage(quest: Dictionary) -> bool:
	var target_pct: float = quest.get("target", 1.0)
	var count_needed: int = quest.get("count", 1)
	var specific_domain: String = quest.get("domain", "")

	if not specific_domain.is_empty():
		return DiscoveryManager.get_domain_progress(specific_domain) >= target_pct

	# Count how many domains meet the target percentage
	var met := 0
	if DataLoader.graph:
		for domain in DataLoader.graph.domains:
			if DiscoveryManager.get_domain_progress(domain.id) >= target_pct:
				met += 1
	return met >= count_needed


func _check_discover_all() -> bool:
	var total := DiscoveryManager.get_total_count()
	return total > 0 and DiscoveryManager.get_discovery_count() >= total


func _check_timed_discovery(quest: Dictionary) -> bool:
	var target: int = quest.get("target", 30)
	var time_limit: float = quest.get("time_limit_minutes", 15.0)
	return DiscoveryManager.get_topic_discovery_count() >= target and DiscoveryManager.get_elapsed_minutes() <= time_limit


func _check_discover_specific(quest: Dictionary) -> bool:
	var nodes: Array = quest.get("nodes", [])
	for nid in nodes:
		if not DiscoveryManager.is_discovered(nid):
			return false
	return true


func _complete_quest(quest_id: String) -> void:
	if _completed_quests.has(quest_id):
		return
	_active_quests.erase(quest_id)
	_completed_quests[quest_id] = Time.get_unix_time_from_system()

	var quest: Dictionary = _quest_defs.get(quest_id, {})
	quest_completed.emit(quest_id, quest.get("name", ""), quest.get("reward_text", ""))
	print("[QuestManager] Completed: %s" % quest.get("name", quest_id))

	# Advance chain
	var chain_id: String = quest.get("chain_id", "")
	if not chain_id.is_empty():
		_advance_chain(chain_id)

	# Auto-save
	if not NetworkManager.is_online or multiplayer.is_server():
		SaveManager.save_game()


func _advance_chain(chain_id: String) -> void:
	if not _chain_progress.has(chain_id):
		return
	var idx: int = _chain_progress[chain_id] + 1
	_chain_progress[chain_id] = idx

	for chain in _chain_defs:
		if chain["id"] != chain_id:
			continue
		var quests: Array = chain.get("quests", [])
		if idx < quests.size():
			_activate_quest(quests[idx]["id"])
		break


func _count_cross_domain_discoveries() -> int:
	# Count discovered nodes that appear in cross-domain edges
	var cross_nodes: Dictionary = {}
	if DataLoader.graph:
		for edge in DataLoader.graph.edges:
			var from_node = DataLoader.graph.get_node(edge.from_id)
			var to_node = DataLoader.graph.get_node(edge.to_id)
			if from_node and to_node and from_node.domain != to_node.domain:
				cross_nodes[edge.from_id] = true
				cross_nodes[edge.to_id] = true
	var count := 0
	for nid in cross_nodes:
		if DiscoveryManager.is_discovered(nid):
			count += 1
	return count


func _get_quest_progress(quest: Dictionary) -> int:
	var qtype: String = quest.get("type", "")
	match qtype:
		"discover_count":
			var filter: String = quest.get("filter", "any")
			if filter == "percentage":
				var total := DiscoveryManager.get_total_count()
				if total == 0:
					return 0
				return int(float(DiscoveryManager.get_discovery_count()) / float(total) * 100.0)
			if filter == "topic":
				return DiscoveryManager.get_topic_discovery_count()
			if filter == "cross_domain":
				return _count_cross_domain_discoveries()
			return DiscoveryManager.get_discovery_count()
		"domain_count":
			return DiscoveryManager.get_domains_with_discoveries()
		"discover_all":
			return DiscoveryManager.get_discovery_count()
		"timed_discovery":
			return DiscoveryManager.get_topic_discovery_count()
		"domain_percentage":
			var specific_domain: String = quest.get("domain", "")
			if not specific_domain.is_empty():
				return int(DiscoveryManager.get_domain_progress(specific_domain) * 100.0)
			var met := 0
			if DataLoader.graph:
				for domain in DataLoader.graph.domains:
					if DiscoveryManager.get_domain_progress(domain.id) >= quest.get("target", 1.0):
						met += 1
			return met
		"discover_all_children":
			return 1 if _check_discover_all_children(quest) else 0
	return 0


func _get_quest_target(quest: Dictionary) -> int:
	var qtype: String = quest.get("type", "")
	match qtype:
		"discover_count":
			var filter: String = quest.get("filter", "any")
			if filter == "percentage":
				return 100  # percentage target
			return int(quest.get("target", 1))
		"domain_count":
			return int(quest.get("target", 1))
		"discover_all":
			return DiscoveryManager.get_total_count()
		"timed_discovery":
			return int(quest.get("target", 30))
		"domain_percentage":
			var specific_domain: String = quest.get("domain", "")
			if not specific_domain.is_empty():
				return 100
			return int(quest.get("count", 1))
		"discover_all_children":
			return 1
	return 1


## Returns the first active chain quest (for the tracker HUD widget).
func get_primary_active_quest() -> Dictionary:
	# Prefer chain quests over standalone
	for chain in _chain_defs:
		var quests: Array = chain.get("quests", [])
		for quest in quests:
			if _active_quests.has(quest["id"]):
				return quest
	# Fallback to first active standalone
	for quest in _standalone_defs:
		if _active_quests.has(quest["id"]):
			return quest
	return {}


func get_active_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id in _active_quests:
		var quest: Dictionary = _quest_defs.get(quest_id, {})
		if not quest.is_empty():
			result.append(quest)
	return result


func get_completed_quests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id in _completed_quests:
		var quest: Dictionary = _quest_defs.get(quest_id, {})
		if not quest.is_empty():
			result.append(quest)
	return result


func get_completed_count() -> int:
	return _completed_quests.size()


func get_total_quest_count() -> int:
	return _quest_defs.size()


## Save/load support
func get_save_data() -> Dictionary:
	return {
		"active_quests": _active_quests.keys(),
		"completed_quests": _completed_quests.duplicate(),
		"chain_progress": _chain_progress.duplicate(),
	}


func restore_save_data(data: Dictionary) -> void:
	_active_quests.clear()
	_completed_quests.clear()
	_chain_progress.clear()

	var completed = data.get("completed_quests", {})
	for key in completed:
		_completed_quests[key] = float(completed[key])

	var chain_prog = data.get("chain_progress", {})
	for key in chain_prog:
		_chain_progress[key] = int(chain_prog[key])

	# Re-activate quests
	_activate_initial_quests()


func _read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return null
	return json.data
