class_name UniverseManager
extends Node3D

## Spawns and orchestrates all math nodes and connections in 3D space.

signal node_selected(math_node: MathTypes.MathNode)

const DomainScene := preload("res://scenes/nodes/domain_node.tscn")
const SubdomainScene := preload("res://scenes/nodes/subdomain_node.tscn")
const TopicScene := preload("res://scenes/nodes/topic_node.tscn")
const ConnectionScene := preload("res://scenes/nodes/connection.tscn")

var _node_instances: Dictionary = {}  # id -> MathNodeBase
var _connection_instances: Array[ConnectionLine] = []
var _layout: ForceLayout

@onready var nodes_container: Node3D = $Nodes
@onready var connections_container: Node3D = $Connections
@onready var camera_controller: CameraController = $CameraController


func _ready() -> void:
	# Wait a frame for DataLoader autoload to finish
	await get_tree().process_frame

	var graph := DataLoader.graph
	if graph == null or graph.nodes.is_empty():
		push_warning("[UniverseManager] No data loaded!")
		return

	# Fix RNG seed so all clients compute identical layout
	seed(42)

	# Run force-directed layout
	_layout = ForceLayout.new()
	_layout.simulate(graph, 100)

	# Spawn all nodes
	_spawn_nodes(graph)

	# Spawn connections
	_spawn_connections(graph)

	# Connect camera signals
	if camera_controller:
		camera_controller.node_clicked.connect(_on_node_clicked)

	# Try to load saved progress (only in single-player)
	if not NetworkManager.is_online:
		SaveManager.load_game()

	# Apply initial fog states
	_apply_all_fog_states()

	# Listen for new discoveries
	DiscoveryManager.node_discovered.connect(_on_node_discovered)

	print("[UniverseManager] Spawned %d nodes, %d connections" % [_node_instances.size(), _connection_instances.size()])


func _spawn_nodes(graph: MathTypes.MathGraph) -> void:
	for math_node in graph.nodes.values():
		var scene: PackedScene
		match math_node.level:
			"domain":
				scene = DomainScene
			"subdomain":
				scene = SubdomainScene
			"topic":
				scene = TopicScene
			_:
				continue

		var instance: MathNodeBase = scene.instantiate()
		nodes_container.add_child(instance)
		instance.setup(math_node)
		instance.clicked.connect(_on_node_instance_clicked)
		_node_instances[math_node.id] = instance
		math_node.scene_node = instance


func _spawn_connections(graph: MathTypes.MathGraph) -> void:
	for edge in graph.edges:
		var from_node: MathTypes.MathNode = graph.get_node(edge.from_id)
		var to_node: MathTypes.MathNode = graph.get_node(edge.to_id)
		if from_node == null or to_node == null:
			continue

		var conn: ConnectionLine = ConnectionScene.instantiate()
		connections_container.add_child(conn)
		conn.from_id = edge.from_id
		conn.to_id = edge.to_id

		# Color based on the "from" node's domain color, blended with "to"
		var color := from_node.color.lerp(to_node.color, 0.3)
		color.a = 0.3
		conn.setup(from_node.position, to_node.position, color, edge.edge_type)
		_connection_instances.append(conn)


func _apply_all_fog_states() -> void:
	for node_id in _node_instances:
		var instance: MathNodeBase = _node_instances[node_id]
		var state := DiscoveryManager.get_state(node_id)
		instance.set_discovery_state(state, false)

	_update_all_connections()


func _update_all_connections() -> void:
	for conn in _connection_instances:
		var from_discovered := DiscoveryManager.is_discovered(conn.from_id)
		var to_discovered := DiscoveryManager.is_discovered(conn.to_id)
		conn.set_visibility_state(from_discovered and to_discovered)


func _on_node_discovered(node_id: String) -> void:
	# Animate the discovered node
	var instance = _node_instances.get(node_id)
	if instance:
		instance.set_discovery_state("discovered", true)
		instance.play_discovery_animation()

	# Update neighbors to adjacent state (with animation)
	_update_neighbors_visual(node_id)

	# Update connection visibility
	_update_all_connections()


func _update_neighbors_visual(node_id: String) -> void:
	if DataLoader.graph == null:
		return

	# Graph edge neighbors
	var neighbors := DataLoader.graph.get_neighbors(node_id)
	for neighbor_id in neighbors:
		var neighbor_instance = _node_instances.get(neighbor_id)
		if neighbor_instance:
			var state := DiscoveryManager.get_state(neighbor_id)
			neighbor_instance.set_discovery_state(state, true)

	# Hierarchy children
	var children := DataLoader.graph.get_children(node_id)
	for child in children:
		var child_instance = _node_instances.get(child.id)
		if child_instance:
			var state := DiscoveryManager.get_state(child.id)
			child_instance.set_discovery_state(state, true)

	# Parent
	var math_node = DataLoader.graph.get_node(node_id)
	if math_node and not math_node.parent_id.is_empty():
		var parent_instance = _node_instances.get(math_node.parent_id)
		if parent_instance:
			var state := DiscoveryManager.get_state(math_node.parent_id)
			parent_instance.set_discovery_state(state, true)


func _on_node_clicked(node_id: String) -> void:
	_on_node_instance_clicked(node_id)


func _on_node_instance_clicked(node_id: String) -> void:
	var math_node := DataLoader.graph.get_node(node_id)
	if math_node == null:
		return

	# If adjacent, discover it on click
	if DiscoveryManager.is_adjacent(node_id):
		DiscoveryManager.discover_node(node_id)

	emit_signal("node_selected", math_node)


func get_node_instance(node_id: String) -> MathNodeBase:
	return _node_instances.get(node_id, null)


func get_all_node_instances() -> Dictionary:
	return _node_instances
