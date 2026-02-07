class_name MathTypes

## Represents a single node in the math universe graph.
class MathNode:
	var id: String
	var node_name: String
	var level: String  # "domain", "subdomain", "topic"
	var domain: String
	var parent_id: String
	var description: String
	var keywords: Array[String]
	var importance: int  # 1-10
	var difficulty: int  # 1-5
	var flavor: String
	var color: Color

	# Runtime state
	var discovered_by: Dictionary = {}  # player_id -> timestamp
	var first_discoverer: String = ""
	var position: Vector3 = Vector3.ZERO
	var scene_node: Node3D = null

	func _init(p_id: String = "", p_name: String = "", p_level: String = "topic") -> void:
		id = p_id
		node_name = p_name
		level = p_level


## Represents an edge between two math nodes.
class MathEdge:
	var from_id: String
	var to_id: String
	var edge_type: String  # "prerequisite", "prepares", "bridges"
	var label: String

	func _init(p_from: String = "", p_to: String = "", p_type: String = "prerequisite", p_label: String = "") -> void:
		from_id = p_from
		to_id = p_to
		edge_type = p_type
		label = p_label


## The complete graph of all math nodes and edges.
class MathGraph:
	var nodes: Dictionary = {}  # id -> MathNode
	var edges: Array[MathEdge] = []
	var domains: Array[MathNode] = []

	func get_node(id: String) -> MathNode:
		return nodes.get(id, null)

	func get_children(parent_id: String) -> Array[MathNode]:
		var children: Array[MathNode] = []
		for node in nodes.values():
			if node.parent_id == parent_id:
				children.append(node)
		return children

	func get_edges_for(node_id: String) -> Array[MathEdge]:
		var result: Array[MathEdge] = []
		for edge in edges:
			if edge.from_id == node_id or edge.to_id == node_id:
				result.append(edge)
		return result

	func get_neighbors(node_id: String) -> Array[String]:
		var result: Array[String] = []
		for edge in edges:
			if edge.from_id == node_id:
				result.append(edge.to_id)
			elif edge.to_id == node_id:
				result.append(edge.from_id)
		return result
