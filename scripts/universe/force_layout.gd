class_name ForceLayout
extends RefCounted

## 3D force-directed graph layout.
## Positions nodes using repulsion between all nodes and attraction along edges.

const REPULSION_STRENGTH := 500.0
const ATTRACTION_STRENGTH := 0.02
const DAMPING := 0.85
const MIN_DISTANCE := 2.0
const MAX_VELOCITY := 5.0
const CONVERGENCE_THRESHOLD := 0.01

# Layout spacing per level
const DOMAIN_SPREAD := 120.0
const SUBDOMAIN_SPREAD := 40.0
const TOPIC_SPREAD := 12.0

var _velocities: Dictionary = {}  # node_id -> Vector3
var _iteration: int = 0


## Run initial placement (hierarchical) before force simulation.
func initial_placement(graph: MathTypes.MathGraph) -> void:
	var domain_count := graph.domains.size()
	if domain_count == 0:
		return

	# Place domains in a circle on the XZ plane
	for i in range(domain_count):
		var angle := (float(i) / domain_count) * TAU
		var domain := graph.domains[i]
		domain.position = Vector3(
			cos(angle) * DOMAIN_SPREAD,
			0.0,
			sin(angle) * DOMAIN_SPREAD
		)
		_velocities[domain.id] = Vector3.ZERO

		# Place subdomains around their domain
		var subdomains := graph.get_children(domain.id)
		var sub_count := subdomains.size()
		for j in range(sub_count):
			var sub_angle: float = angle + (float(j) / max(sub_count, 1)) * TAU * 0.4 - TAU * 0.2
			var sub := subdomains[j]
			sub.position = domain.position + Vector3(
				cos(sub_angle) * SUBDOMAIN_SPREAD,
				(randf() - 0.5) * 8.0,
				sin(sub_angle) * SUBDOMAIN_SPREAD
			)
			_velocities[sub.id] = Vector3.ZERO

			# Place topics around their subdomain
			var topics := graph.get_children(sub.id)
			var topic_count := topics.size()
			for k in range(topic_count):
				var topic_angle: float = sub_angle + (float(k) / max(topic_count, 1)) * TAU * 0.5 - TAU * 0.25
				var topic := topics[k]
				topic.position = sub.position + Vector3(
					cos(topic_angle) * TOPIC_SPREAD,
					(randf() - 0.5) * 5.0,
					sin(topic_angle) * TOPIC_SPREAD
				)
				_velocities[topic.id] = Vector3.ZERO


## Run one iteration of the force simulation. Returns max displacement.
func step(graph: MathTypes.MathGraph) -> float:
	_iteration += 1
	var forces: Dictionary = {}
	var nodes := graph.nodes

	# Initialize forces
	for id in nodes:
		forces[id] = Vector3.ZERO

	# Repulsion between all node pairs (Barnes-Hut would be better for large N)
	var node_ids := nodes.keys()
	var n := node_ids.size()
	for i in range(n):
		for j in range(i + 1, n):
			var id_a: String = node_ids[i]
			var id_b: String = node_ids[j]
			var a: MathTypes.MathNode = nodes[id_a]
			var b: MathTypes.MathNode = nodes[id_b]
			var delta := a.position - b.position
			var dist := delta.length()
			if dist < MIN_DISTANCE:
				delta = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
				dist = MIN_DISTANCE

			# Stronger repulsion for same-level nodes
			var level_mult := 1.0
			if a.level == b.level:
				level_mult = 1.5

			var force := delta.normalized() * (REPULSION_STRENGTH * level_mult / (dist * dist))
			forces[id_a] += force
			forces[id_b] -= force

	# Attraction along edges
	for edge in graph.edges:
		var a: MathTypes.MathNode = nodes.get(edge.from_id)
		var b: MathTypes.MathNode = nodes.get(edge.to_id)
		if a == null or b == null:
			continue
		var delta := b.position - a.position
		var dist := delta.length()
		if dist < 0.01:
			continue

		# Target distance depends on relationship
		var target_dist := TOPIC_SPREAD
		if a.level == "domain" or b.level == "domain":
			target_dist = SUBDOMAIN_SPREAD
		elif a.level == "subdomain" or b.level == "subdomain":
			target_dist = SUBDOMAIN_SPREAD * 0.7

		var force := delta.normalized() * ATTRACTION_STRENGTH * (dist - target_dist)
		forces[edge.from_id] += force
		forces[edge.to_id] -= force

	# Hierarchical attraction: children pulled toward parents
	for id in nodes:
		var node: MathTypes.MathNode = nodes[id]
		if node.parent_id.is_empty():
			continue
		var parent: MathTypes.MathNode = nodes.get(node.parent_id)
		if parent == null:
			continue
		var delta := parent.position - node.position
		var dist := delta.length()
		var target := SUBDOMAIN_SPREAD if node.level == "subdomain" else TOPIC_SPREAD
		if dist > 0.01:
			forces[id] += delta.normalized() * 0.05 * (dist - target)

	# Apply forces with damping
	var max_disp := 0.0
	for id in nodes:
		var node: MathTypes.MathNode = nodes[id]
		if not _velocities.has(id):
			_velocities[id] = Vector3.ZERO

		_velocities[id] = (_velocities[id] + forces[id]) * DAMPING
		# Clamp velocity
		if _velocities[id].length() > MAX_VELOCITY:
			_velocities[id] = _velocities[id].normalized() * MAX_VELOCITY

		# Domains move slower (more stable anchors)
		var speed_mult := 1.0
		if node.level == "domain":
			speed_mult = 0.3
		elif node.level == "subdomain":
			speed_mult = 0.6

		var displacement: Vector3 = _velocities[id] * speed_mult
		node.position += displacement
		max_disp = max(max_disp, displacement.length())

	return max_disp


## Run simulation until convergence or max iterations.
func simulate(graph: MathTypes.MathGraph, max_iterations: int = 100) -> void:
	initial_placement(graph)
	for i in range(max_iterations):
		var disp := step(graph)
		if disp < CONVERGENCE_THRESHOLD:
			print("[ForceLayout] Converged after %d iterations" % (i + 1))
			return
	print("[ForceLayout] Finished %d iterations (max reached)" % max_iterations)
