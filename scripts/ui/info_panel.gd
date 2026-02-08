extends PanelContainer

## Info panel that displays details about a selected math node.
## Shows discovery state: undiscovered teasers for adjacent nodes,
## full info + discovery badge for discovered nodes.

signal closed

var _current_node: MathTypes.MathNode = null
var _slide_tween: Tween = null
var _resources_label: RichTextLabel = null

# Offscreen / onscreen horizontal offsets (panel anchored to right edge)
const _OFFSET_LEFT_VISIBLE := -380.0
const _OFFSET_RIGHT_VISIBLE := -20.0
const _OFFSET_LEFT_HIDDEN := 20.0
const _OFFSET_RIGHT_HIDDEN := 20.0

@onready var title_label: Label = %TitleLabel
@onready var level_label: Label = %LevelLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var details_container: VBoxContainer = %DetailsContainer
@onready var keywords_label: Label = %KeywordsLabel
@onready var close_button: Button = %CloseButton
@onready var difficulty_label: Label = %DifficultyLabel
@onready var discovery_status_label: Label = %DiscoveryStatusLabel
@onready var discover_button: Button = %DiscoverButton


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close)
	discover_button.pressed.connect(_on_discover_pressed)
	discover_button.visible = false
	discovery_status_label.visible = false

	# Create resources label after DetailsContainer
	_resources_label = RichTextLabel.new()
	_resources_label.bbcode_enabled = true
	_resources_label.fit_content = true
	_resources_label.scroll_active = false
	_resources_label.add_theme_font_size_override("normal_font_size", 12)
	_resources_label.visible = false
	details_container.get_parent().add_child(_resources_label)
	details_container.get_parent().move_child(_resources_label, details_container.get_index() + 1)
	_resources_label.meta_clicked.connect(_on_resource_clicked)

	DataLoader.resource_level_changed.connect(_on_resource_level_changed)


func show_node(math_node: MathTypes.MathNode) -> void:
	_current_node = math_node
	if not visible:
		_slide_in()
	else:
		# Already visible — just update content, no re-slide
		pass

	var state := DiscoveryManager.get_state(math_node.id)

	if state == "adjacent":
		_show_adjacent_node(math_node)
	else:
		_show_discovered_node(math_node)


func _show_adjacent_node(math_node: MathTypes.MathNode) -> void:
	title_label.text = "???"

	match math_node.level:
		"domain":
			level_label.text = "UNKNOWN GALAXY"
		"subdomain":
			level_label.text = "UNKNOWN STAR SYSTEM"
		"topic":
			level_label.text = "UNKNOWN PLANET"
	level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))

	description_label.text = "This region of space has not been explored yet. Venture closer to discover its secrets..."
	flavor_label.visible = false
	difficulty_label.visible = false
	keywords_label.visible = false
	discovery_status_label.visible = false

	discover_button.visible = true
	discover_button.text = "Discover"

	# Hide resources for undiscovered nodes
	if _resources_label:
		_resources_label.visible = false

	# Clear connections
	for child in details_container.get_children():
		child.queue_free()


func _show_discovered_node(math_node: MathTypes.MathNode) -> void:
	title_label.text = math_node.node_name

	match math_node.level:
		"domain":
			level_label.text = "GALAXY"
		"subdomain":
			level_label.text = "STAR SYSTEM"
		"topic":
			level_label.text = "PLANET"
	level_label.add_theme_color_override("font_color", math_node.color)

	description_label.text = math_node.description

	# Flavor text
	flavor_label.text = math_node.flavor if not math_node.flavor.is_empty() else ""
	flavor_label.visible = not math_node.flavor.is_empty()

	# Difficulty stars
	if math_node.difficulty > 0:
		var stars := ""
		for i in range(5):
			stars += "#" if i < math_node.difficulty else "-"
		difficulty_label.text = "Difficulty: [%s] %d/5" % [stars, math_node.difficulty]
		difficulty_label.visible = true
	else:
		difficulty_label.visible = false

	# Keywords
	if math_node.keywords.size() > 0:
		keywords_label.text = "Keywords: " + ", ".join(math_node.keywords)
		keywords_label.visible = true
	else:
		keywords_label.visible = false

	# Discovery status
	var timestamp := DiscoveryManager.get_discovery_timestamp(math_node.id)
	if timestamp > 0:
		var dt := Time.get_datetime_dict_from_unix_time(int(timestamp))
		discovery_status_label.text = "Discovered: %04d-%02d-%02d %02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]
		discovery_status_label.visible = true
	else:
		discovery_status_label.visible = false

	discover_button.visible = false

	# Show connections
	_show_connections(math_node)

	# Show learning resources
	_show_resources(math_node)


func _show_connections(math_node: MathTypes.MathNode) -> void:
	for child in details_container.get_children():
		child.queue_free()

	var edges := DataLoader.graph.get_edges_for(math_node.id)
	if edges.is_empty():
		return

	var header := Label.new()
	header.text = "Connections:"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	details_container.add_child(header)

	for edge in edges:
		var other_id := edge.to_id if edge.from_id == math_node.id else edge.from_id
		var other_node := DataLoader.graph.get_node(other_id)
		if other_node == null:
			continue

		var lbl := Label.new()
		var arrow := " -> " if edge.from_id == math_node.id else " <- "
		var type_str := ""
		match edge.edge_type:
			"prerequisite":
				type_str = "[prereq]"
			"prepares":
				type_str = "[prepares]"
			"bridges":
				type_str = "[bridges]"

		var other_state := DiscoveryManager.get_state(other_id)
		var display_name := other_node.node_name if other_state == "discovered" else "???"
		lbl.text = "  %s %s%s" % [type_str, arrow, display_name]
		lbl.add_theme_font_size_override("font_size", 12)
		if other_state == "discovered":
			lbl.add_theme_color_override("font_color", other_node.color.lightened(0.3))
		else:
			lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		details_container.add_child(lbl)


func _on_discover_pressed() -> void:
	if _current_node and DiscoveryManager.is_adjacent(_current_node.id):
		DiscoveryManager.discover_node(_current_node.id)
		# Refresh the panel with discovered info
		_show_discovered_node(_current_node)


func _on_close() -> void:
	_slide_out()
	_current_node = null
	emit_signal("closed")


func _slide_in() -> void:
	if _slide_tween:
		_slide_tween.kill()
	# Start offscreen right
	offset_left = _OFFSET_LEFT_HIDDEN
	offset_right = _OFFSET_RIGHT_HIDDEN
	visible = true
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "offset_left", _OFFSET_LEFT_VISIBLE, 0.3)
	_slide_tween.parallel().tween_property(self, "offset_right", _OFFSET_RIGHT_VISIBLE, 0.3)


func _slide_out() -> void:
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "offset_left", _OFFSET_LEFT_HIDDEN, 0.3)
	_slide_tween.parallel().tween_property(self, "offset_right", _OFFSET_RIGHT_HIDDEN, 0.3)
	_slide_tween.tween_callback(func(): visible = false)


func _show_resources(math_node: MathTypes.MathNode) -> void:
	if _resources_label == null:
		return
	if math_node.resources.is_empty():
		_resources_label.visible = false
		return

	var level = DataLoader.resource_level
	var filtered: Array = []
	for res in math_node.resources:
		if res["level"] == level:
			filtered.append(res)

	if filtered.is_empty():
		_resources_label.visible = false
		return

	_resources_label.clear()
	_resources_label.push_color(Color(0.67, 0.67, 0.8))
	_resources_label.add_text("Learning Resources:\n")
	_resources_label.pop()
	for res in filtered:
		_resources_label.add_text("  ")
		_resources_label.push_meta(res["url"])
		_resources_label.push_color(Color(0.4, 0.7, 1.0))
		_resources_label.push_underline()
		_resources_label.add_text(res["title"])
		_resources_label.pop_all()
		_resources_label.add_text("\n")
	_resources_label.visible = true


func _on_resource_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _on_resource_level_changed(_level: String) -> void:
	if _current_node and visible:
		_show_resources(_current_node)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("escape"):
		_on_close()
		get_viewport().set_input_as_handled()
