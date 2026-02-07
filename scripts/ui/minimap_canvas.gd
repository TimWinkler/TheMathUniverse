class_name MinimapCanvas
extends Control

## Custom Control that draws a 2D top-down projection of the 3D universe.
## Colored dots for discovered nodes, grey for adjacent, hidden nodes invisible.
## White diamond for the player ship. Click to fly camera to that world position.

signal world_position_clicked(world_pos: Vector3)

var _universe: UniverseManager
var _player_ship: Node3D
var _world_bounds: Rect2 = Rect2(-200, -200, 400, 400)  # XZ bounds
var _padding := 10.0


func setup(universe: UniverseManager, player_ship: Node3D) -> void:
	_universe = universe
	_player_ship = player_ship
	_compute_world_bounds()


func _compute_world_bounds() -> void:
	if DataLoader.graph == null:
		return
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for node in DataLoader.graph.nodes.values():
		min_x = min(min_x, node.position.x)
		max_x = max(max_x, node.position.x)
		min_z = min(min_z, node.position.z)
		max_z = max(max_z, node.position.z)
	var margin := 20.0
	_world_bounds = Rect2(min_x - margin, min_z - margin, max_x - min_x + margin * 2, max_z - min_z + margin * 2)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.1, 0.8))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.3, 0.4, 0.5), false, 1.0)

	if _universe == null or DataLoader.graph == null:
		return

	# Draw connections between discovered nodes
	for node in DataLoader.graph.nodes.values():
		if not DiscoveryManager.is_discovered(node.id):
			continue
		var pos := _world_to_minimap(node.position)
		var state := DiscoveryManager.get_state(node.id)
		if state != "discovered":
			continue

		# Draw edges from this node
		var neighbors := DataLoader.graph.get_neighbors(node.id)
		for nid in neighbors:
			if DiscoveryManager.is_discovered(nid):
				var other = DataLoader.graph.get_node(nid)
				if other:
					var other_pos := _world_to_minimap(other.position)
					draw_line(pos, other_pos, Color(0.3, 0.3, 0.4, 0.3), 1.0)

	# Draw nodes
	for node in DataLoader.graph.nodes.values():
		var state := DiscoveryManager.get_state(node.id)
		if state == "hidden":
			continue

		var pos := _world_to_minimap(node.position)
		var dot_size := 2.0
		var color := Color(0.4, 0.4, 0.4, 0.5)  # grey for adjacent

		if state == "discovered":
			color = node.color
			match node.level:
				"domain":
					dot_size = 5.0
				"subdomain":
					dot_size = 3.0
				"topic":
					dot_size = 2.0

		draw_circle(pos, dot_size, color)

	# Draw player ship as white diamond
	if _player_ship:
		var ship_pos := _world_to_minimap(_player_ship.global_position)
		var d := 5.0
		var diamond := PackedVector2Array([
			ship_pos + Vector2(0, -d),
			ship_pos + Vector2(d, 0),
			ship_pos + Vector2(0, d),
			ship_pos + Vector2(-d, 0),
		])
		draw_colored_polygon(diamond, Color.WHITE)


func _world_to_minimap(world_pos: Vector3) -> Vector2:
	var usable := size - Vector2(_padding * 2, _padding * 2)
	var nx := (world_pos.x - _world_bounds.position.x) / _world_bounds.size.x
	var nz := (world_pos.z - _world_bounds.position.y) / _world_bounds.size.y
	return Vector2(
		_padding + nx * usable.x,
		_padding + nz * usable.y
	)


func _minimap_to_world(minimap_pos: Vector2) -> Vector3:
	var usable := size - Vector2(_padding * 2, _padding * 2)
	var nx := (minimap_pos.x - _padding) / usable.x
	var nz := (minimap_pos.y - _padding) / usable.y
	return Vector3(
		_world_bounds.position.x + nx * _world_bounds.size.x,
		0.0,
		_world_bounds.position.y + nz * _world_bounds.size.y
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos := _minimap_to_world(event.position)
		world_position_clicked.emit(world_pos)
		accept_event()
