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
var _is_simulating := false
var _sim_steps_remaining := 0

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

	# Run force-directed layout
	_layout = ForceLayout.new()
	_layout.simulate(graph, 150)

	# Spawn all nodes
	_spawn_nodes(graph)

	# Spawn connections
	_spawn_connections(graph)

	# Connect camera signals
	if camera_controller:
		camera_controller.node_clicked.connect(_on_node_clicked)

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


func _on_node_clicked(node_id: String) -> void:
	_on_node_instance_clicked(node_id)


func _on_node_instance_clicked(node_id: String) -> void:
	var math_node := DataLoader.graph.get_node(node_id)
	if math_node:
		emit_signal("node_selected", math_node)


func get_node_instance(node_id: String) -> MathNodeBase:
	return _node_instances.get(node_id, null)
