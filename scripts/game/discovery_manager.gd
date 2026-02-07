extends Node

## Tracks which nodes have been discovered by the player.
## Domains are always discovered. Everything else starts hidden.
## Discovering a node also reveals its neighbors as "adjacent" (clickable silhouettes).
## Network-aware: in multiplayer, discoveries route through the server.

signal node_discovered(node_id: String)
signal discovery_count_changed(count: int, total: int)

var _discovered: Dictionary = {}  # node_id -> timestamp (float)
var _adjacent: Dictionary = {}    # node_id -> true (visible but not yet discovered)
var _start_time: float = 0.0


func _ready() -> void:
	_start_time = Time.get_unix_time_from_system()
	# Wait for DataLoader to finish
	await get_tree().process_frame
	_init_domains()


func _init_domains() -> void:
	if DataLoader.graph == null:
		return
	# Auto-discover all domain nodes
	for domain in DataLoader.graph.domains:
		_discovered[domain.id] = Time.get_unix_time_from_system()
	# Mark domain children as adjacent
	for domain in DataLoader.graph.domains:
		_mark_neighbors_adjacent(domain.id)
	discovery_count_changed.emit(get_discovery_count(), get_total_count())


func discover_node(node_id: String) -> void:
	if is_discovered(node_id):
		return
	var math_node = DataLoader.graph.get_node(node_id)
	if math_node == null:
		return

	if NetworkManager.is_online:
		_request_discover_on_server.rpc_id(1, node_id, multiplayer.get_unique_id())
	else:
		_apply_discovery(node_id)


func _apply_discovery(node_id: String, discoverer_id: int = 1) -> void:
	if is_discovered(node_id):
		return

	_discovered[node_id] = Time.get_unix_time_from_system()
	_adjacent.erase(node_id)

	# Mark neighbors as adjacent
	_mark_neighbors_adjacent(node_id)

	node_discovered.emit(node_id)
	discovery_count_changed.emit(get_discovery_count(), get_total_count())

	# Auto-save only in single-player or on the server
	if not NetworkManager.is_online or multiplayer.is_server():
		SaveManager.save_game()


@rpc("any_peer", "reliable")
func _request_discover_on_server(node_id: String, discoverer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Validate: must be adjacent
	if not is_adjacent(node_id):
		return
	_apply_discovery(node_id, discoverer_id)
	_apply_discovery_on_client.rpc(node_id, discoverer_id)


@rpc("authority", "reliable")
func _apply_discovery_on_client(node_id: String, discoverer_id: int) -> void:
	_apply_discovery(node_id, discoverer_id)


func _mark_neighbors_adjacent(node_id: String) -> void:
	if DataLoader.graph == null:
		return

	# Graph edge neighbors
	var neighbors = DataLoader.graph.get_neighbors(node_id)
	for neighbor_id in neighbors:
		if not is_discovered(neighbor_id) and not is_adjacent(neighbor_id):
			_adjacent[neighbor_id] = true

	# Also mark children (parent-child hierarchy)
	var children = DataLoader.graph.get_children(node_id)
	for child in children:
		if not is_discovered(child.id) and not is_adjacent(child.id):
			_adjacent[child.id] = true

	# Mark parent as adjacent if not discovered
	var math_node = DataLoader.graph.get_node(node_id)
	if math_node and not math_node.parent_id.is_empty():
		if not is_discovered(math_node.parent_id) and not is_adjacent(math_node.parent_id):
			_adjacent[math_node.parent_id] = true


func is_discovered(node_id: String) -> bool:
	return _discovered.has(node_id)


func is_adjacent(node_id: String) -> bool:
	return _adjacent.has(node_id)


func get_state(node_id: String) -> String:
	if is_discovered(node_id):
		return "discovered"
	if is_adjacent(node_id):
		return "adjacent"
	return "hidden"


func get_discovery_count() -> int:
	return _discovered.size()


func get_total_count() -> int:
	if DataLoader.graph:
		return DataLoader.graph.nodes.size()
	return 0


func get_discovery_timestamp(node_id: String) -> float:
	return _discovered.get(node_id, 0.0)


func get_domain_progress(domain_id: String) -> float:
	if DataLoader.graph == null:
		return 0.0
	var total := 0
	var found := 0
	for node in DataLoader.graph.nodes.values():
		if node.domain == domain_id:
			total += 1
			if is_discovered(node.id):
				found += 1
	if total == 0:
		return 0.0
	return float(found) / float(total)


func get_elapsed_minutes() -> float:
	return (Time.get_unix_time_from_system() - _start_time) / 60.0


func get_domains_with_discoveries() -> int:
	var domains_found: Dictionary = {}
	for node_id in _discovered:
		var math_node = DataLoader.graph.get_node(node_id)
		if math_node and math_node.level == "topic":
			domains_found[math_node.domain] = true
	return domains_found.size()


func get_topic_discovery_count() -> int:
	var count := 0
	for node_id in _discovered:
		var math_node = DataLoader.graph.get_node(node_id)
		if math_node and math_node.level == "topic":
			count += 1
	return count


func restore_state(discovered_data: Dictionary, adjacent_data: Dictionary) -> void:
	_discovered = discovered_data
	_adjacent = adjacent_data
	discovery_count_changed.emit(get_discovery_count(), get_total_count())
