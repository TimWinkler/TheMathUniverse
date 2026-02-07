extends PanelContainer

## Info panel that displays details about a selected math node.

signal closed

var _current_node: MathTypes.MathNode = null

@onready var title_label: Label = %TitleLabel
@onready var level_label: Label = %LevelLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var details_container: VBoxContainer = %DetailsContainer
@onready var keywords_label: Label = %KeywordsLabel
@onready var close_button: Button = %CloseButton
@onready var difficulty_label: Label = %DifficultyLabel


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close)


func show_node(math_node: MathTypes.MathNode) -> void:
	_current_node = math_node
	visible = true

	title_label.text = math_node.node_name

	# Level badge
	match math_node.level:
		"domain":
			level_label.text = "GALAXY"
		"subdomain":
			level_label.text = "STAR SYSTEM"
		"topic":
			level_label.text = "PLANET"
	level_label.add_theme_color_override("font_color", math_node.color)

	# Description
	description_label.text = math_node.description

	# Flavor text
	flavor_label.text = math_node.flavor if not math_node.flavor.is_empty() else ""
	flavor_label.visible = not math_node.flavor.is_empty()

	# Difficulty stars
	if math_node.difficulty > 0:
		var stars := ""
		for i in range(5):
			stars += "★" if i < math_node.difficulty else "☆"
		difficulty_label.text = "Difficulty: " + stars
		difficulty_label.visible = true
	else:
		difficulty_label.visible = false

	# Keywords
	if math_node.keywords.size() > 0:
		keywords_label.text = "Keywords: " + ", ".join(math_node.keywords)
		keywords_label.visible = true
	else:
		keywords_label.visible = false

	# Show connections
	_show_connections(math_node)


func _show_connections(math_node: MathTypes.MathNode) -> void:
	# Clear existing connection labels
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
		var arrow := " → " if edge.from_id == math_node.id else " ← "
		var type_str := ""
		match edge.edge_type:
			"prerequisite":
				type_str = "[prereq]"
			"prepares":
				type_str = "[prepares]"
			"bridges":
				type_str = "[bridges]"
		lbl.text = "  %s %s%s %s" % [type_str, arrow, other_node.node_name, ""]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", other_node.color.lightened(0.3))
		details_container.add_child(lbl)


func _on_close() -> void:
	visible = false
	_current_node = null
	emit_signal("closed")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("escape"):
		_on_close()
		get_viewport().set_input_as_handled()
