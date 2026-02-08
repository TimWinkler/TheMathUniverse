class_name MinimapCanvas
extends Control

## Custom Control that draws a 2D top-down projection of the 3D universe.
## Colored dots for discovered nodes, grey for adjacent, hidden nodes invisible.
## White diamond for the player ship. Click to fly camera to that world position.
## Press N to toggle tree view: drill-down grid showing domain > subdomain > topic.

signal world_position_clicked(world_pos: Vector3)

enum MinimapMode { POSITION, TREE }

var _universe: UniverseManager
var _player_ship: Node3D
var _world_bounds: Rect2 = Rect2(-200, -200, 400, 400)  # XZ bounds
var _padding := 10.0

# Tree view state
var _mode: MinimapMode = MinimapMode.POSITION
var _tree_parent_id: String = ""  # "" = root (show domains), domain_id = show subdomains, sub_id = show topics
var _tree_node_rects: Array = []  # Array of {id: String, rect: Rect2}
var _back_rect: Rect2 = Rect2()
var _has_back := false


func setup(universe: UniverseManager, player_ship: Node3D) -> void:
	_universe = universe
	_player_ship = player_ship
	_compute_world_bounds()


func toggle_mode() -> void:
	if _mode == MinimapMode.POSITION:
		_mode = MinimapMode.TREE
		_tree_parent_id = ""
	else:
		_mode = MinimapMode.POSITION
	queue_redraw()


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

	if _mode == MinimapMode.POSITION:
		_draw_position_map()
	else:
		_draw_tree_map()

	# Mode indicator in top-right corner
	var mode_text := "POS" if _mode == MinimapMode.POSITION else "TREE"
	var font = ThemeDB.fallback_font
	var font_size := 8
	var text_width := font.get_string_size(mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(size.x - text_width - 4, 10), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.5, 0.5, 0.6, 0.7))


func _draw_position_map() -> void:
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


func _draw_tree_map() -> void:
	_tree_node_rects.clear()
	_has_back = false

	var font = ThemeDB.fallback_font
	var header_size := 10
	var label_size := 8
	var header_h := 20.0
	var grid_top := header_h + 4.0

	# Header: back arrow + title
	if _tree_parent_id == "":
		draw_string(font, Vector2(6, 14), "Domains", HORIZONTAL_ALIGNMENT_LEFT, -1, header_size, Color(0.7, 0.8, 1.0))
	else:
		# Draw back arrow as "< "
		var arrow_text := "< "
		var arrow_width := font.get_string_size(arrow_text, HORIZONTAL_ALIGNMENT_LEFT, -1, header_size).x
		draw_string(font, Vector2(6, 14), arrow_text, HORIZONTAL_ALIGNMENT_LEFT, -1, header_size, Color(0.6, 0.7, 0.9))
		_back_rect = Rect2(0, 0, arrow_width + 10, header_h)
		_has_back = true

		var parent_node = DataLoader.graph.get_node(_tree_parent_id)
		if parent_node:
			draw_string(font, Vector2(6 + arrow_width, 14), parent_node.node_name, HORIZONTAL_ALIGNMENT_LEFT, int(size.x - arrow_width - 12), header_size, parent_node.color)

	# Separator line
	draw_line(Vector2(4, header_h), Vector2(size.x - 4, header_h), Color(0.3, 0.3, 0.4, 0.5), 1.0)

	# Get children to display
	var children: Array = []
	if _tree_parent_id == "":
		for d in DataLoader.graph.domains:
			children.append(d)
	else:
		children = DataLoader.graph.get_children(_tree_parent_id)

	if children.is_empty():
		draw_string(font, Vector2(6, grid_top + 16), "(empty)", HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(0.4, 0.4, 0.5))
		return

	# Sort children alphabetically
	children.sort_custom(func(a, b): return a.node_name.naturalnocasecmp_to(b.node_name) < 0)

	# Calculate grid layout
	var count := children.size()
	var cols := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(cols))
	var usable_w := size.x - _padding * 2
	var usable_h := size.y - grid_top - _padding
	var cell_w := usable_w / float(cols)
	var cell_h := usable_h / float(rows)
	var circle_r = min(cell_w, cell_h) * 0.28

	for i in range(count):
		var node: MathTypes.MathNode = children[i]
		var col := i % cols
		var row := i / cols
		var cx := _padding + col * cell_w + cell_w * 0.5
		var cy := grid_top + row * cell_h + cell_h * 0.4

		var color := node.color
		var is_discovered := DiscoveryManager.is_discovered(node.id)

		# Dim undiscovered nodes
		if not is_discovered:
			color = Color(0.3, 0.3, 0.35, 0.6)

		# Draw filled circle
		draw_circle(Vector2(cx, cy), circle_r, color)

		# Draw ring on expandable nodes (domains/subdomains that have children)
		var has_children := not DataLoader.graph.get_children(node.id).is_empty()
		if has_children:
			_draw_circle_arc(Vector2(cx, cy), circle_r + 2, Color(0.7, 0.8, 1.0, 0.5), 1.0)

		# Draw label below circle
		var label_text := _truncate_name(node.node_name, 12)
		var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		var lx := cx - tw * 0.5
		var ly = cy + circle_r + 11
		var label_color := color.lightened(0.3) if is_discovered else Color(0.4, 0.4, 0.5, 0.7)
		draw_string(font, Vector2(lx, ly), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, label_color)

		# Discovery progress for domains/subdomains
		if has_children and is_discovered:
			var child_list = DataLoader.graph.get_children(node.id)
			var disc_count := 0
			for c in child_list:
				if DiscoveryManager.is_discovered(c.id):
					disc_count += 1
			var pct_text := "%d/%d" % [disc_count, child_list.size()]
			var ptw := font.get_string_size(pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
			draw_string(font, Vector2(cx - ptw * 0.5, cy + 4), pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.7))

		# Store clickable rect
		var rect := Rect2(cx - cell_w * 0.5, cy - cell_h * 0.4, cell_w, cell_h)
		_tree_node_rects.append({id = node.id, rect = rect})


func _draw_circle_arc(center: Vector2, radius: float, color: Color, width: float) -> void:
	var segments := 24
	var prev := center + Vector2(radius, 0)
	for i in range(1, segments + 1):
		var angle := float(i) / float(segments) * TAU
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(prev, point, color, width)
		prev = point


func _truncate_name(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 2) + ".."


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
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	if _mode == MinimapMode.POSITION:
		var world_pos := _minimap_to_world(event.position)
		world_position_clicked.emit(world_pos)
		accept_event()
	else:
		_handle_tree_click(event.position)
		accept_event()


func _handle_tree_click(pos: Vector2) -> void:
	# Check back arrow
	if _has_back and _back_rect.has_point(pos):
		_navigate_back()
		return

	# Check node rects
	for entry in _tree_node_rects:
		if entry.rect.has_point(pos):
			var node = DataLoader.graph.get_node(entry.id)
			if node == null:
				return

			# If it has children, drill down
			var has_children := not DataLoader.graph.get_children(entry.id).is_empty()
			if has_children:
				_tree_parent_id = entry.id
				queue_redraw()
			else:
				# Leaf node: fly to its 3D position
				world_position_clicked.emit(node.position)
			return


func _navigate_back() -> void:
	if _tree_parent_id == "":
		return
	var parent_node = DataLoader.graph.get_node(_tree_parent_id)
	if parent_node and parent_node.parent_id != "":
		_tree_parent_id = parent_node.parent_id
	else:
		_tree_parent_id = ""
	queue_redraw()
