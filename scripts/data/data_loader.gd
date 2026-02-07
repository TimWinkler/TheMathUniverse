extends Node

## Autoload singleton that loads all math data from JSON files.

var graph: MathTypes.MathGraph

var domain_files: Array[String] = [
	"res://data/algebra.json",
	"res://data/analysis.json",
	"res://data/geometry.json",
	"res://data/number-theory.json",
	"res://data/probability.json",
	"res://data/topology.json",
	"res://data/combinatorics.json",
	"res://data/logic.json",
	"res://data/discrete-math.json",
	"res://data/differential-equations.json",
	"res://data/optimization.json",
	"res://data/applied-math.json",
	"res://data/category-theory.json",
]


func _ready() -> void:
	graph = MathTypes.MathGraph.new()
	_load_domains_index()
	for file_path in domain_files:
		_load_domain_file(file_path)
	print("[DataLoader] Loaded %d nodes, %d edges" % [graph.nodes.size(), graph.edges.size()])


func _load_domains_index() -> void:
	var data = _read_json("res://data/domains.json")
	if data == null:
		return

	# Load cross-domain edges
	var cross_edges: Array = data.get("cross_domain_edges", [])
	for edge_data in cross_edges:
		var edge := MathTypes.MathEdge.new(
			edge_data["from"],
			edge_data["to"],
			edge_data.get("type", "bridges"),
			edge_data.get("label", "")
		)
		graph.edges.append(edge)


func _load_domain_file(file_path: String) -> void:
	var data = _read_json(file_path)
	if data == null:
		push_warning("[DataLoader] Could not load: " + file_path)
		return

	var domain_id: String = data["domain"]
	var domain_info: Dictionary = _get_domain_info(domain_id)
	var domain_color := Color(domain_info.get("color", "#ffffff"))

	# Create domain node
	var domain_node := MathTypes.MathNode.new(domain_id, domain_info.get("name", domain_id), "domain")
	domain_node.domain = domain_id
	domain_node.parent_id = ""
	domain_node.description = domain_info.get("description", "")
	domain_node.importance = domain_info.get("importance", 5)
	domain_node.difficulty = 0
	domain_node.flavor = domain_info.get("flavor", "")
	domain_node.color = domain_color
	graph.nodes[domain_id] = domain_node
	graph.domains.append(domain_node)

	# Load subdomains
	var subdomains: Array = data.get("subdomains", [])
	for sub_data in subdomains:
		var sub_id: String = sub_data["id"]
		var sub_node := MathTypes.MathNode.new(sub_id, sub_data["name"], "subdomain")
		sub_node.domain = domain_id
		sub_node.parent_id = domain_id
		sub_node.description = sub_data.get("description", "")
		sub_node.importance = sub_data.get("importance", 5)
		sub_node.difficulty = sub_data.get("difficulty", 1)
		sub_node.flavor = sub_data.get("flavor", "")
		sub_node.color = domain_color
		graph.nodes[sub_id] = sub_node

		# Load topics within subdomain
		var topics: Array = sub_data.get("topics", [])
		for topic_data in topics:
			var topic_id: String = topic_data["id"]
			var topic_node := MathTypes.MathNode.new(topic_id, topic_data["name"], "topic")
			topic_node.domain = domain_id
			topic_node.parent_id = sub_id
			topic_node.description = topic_data.get("description", "")
			topic_node.importance = topic_data.get("importance", 5)
			topic_node.difficulty = topic_data.get("difficulty", 1)
			topic_node.flavor = topic_data.get("flavor", "")
			topic_node.color = domain_color

			var kw_array: Array = topic_data.get("keywords", [])
			for kw in kw_array:
				topic_node.keywords.append(str(kw))

			graph.nodes[topic_id] = topic_node

	# Load edges within domain
	var edges: Array = data.get("edges", [])
	for edge_data in edges:
		var edge := MathTypes.MathEdge.new(
			edge_data["from"],
			edge_data["to"],
			edge_data.get("type", "prerequisite"),
			edge_data.get("label", "")
		)
		graph.edges.append(edge)


func _get_domain_info(domain_id: String) -> Dictionary:
	var data = _read_json("res://data/domains.json")
	if data == null:
		return {}
	var domains_arr: Array = data.get("domains", [])
	for d in domains_arr:
		if d["id"] == domain_id:
			return d
	return {}


func _read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_warning("[DataLoader] File not found: " + file_path)
		return null
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("[DataLoader] Could not open: " + file_path)
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[DataLoader] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return null
	return json.data
