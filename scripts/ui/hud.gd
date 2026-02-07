extends CanvasLayer

## Heads-up display showing node count, hovered node name, and controls hint.

@onready var node_count_label: Label = %NodeCountLabel
@onready var hover_label: Label = %HoverLabel
@onready var controls_label: Label = %ControlsLabel

var _hovered_node_id: String = ""


func _ready() -> void:
	_update_node_count()
	hover_label.text = ""
	controls_label.text = "Right-drag: orbit | Scroll: zoom | WASD: move | Click: inspect | H: home | Esc: close"


func _update_node_count() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DataLoader.graph:
		var total := DataLoader.graph.nodes.size()
		var domains := DataLoader.graph.domains.size()
		node_count_label.text = "The Math Universe — %d nodes across %d galaxies" % [total, domains]


func show_hover(node_id: String) -> void:
	_hovered_node_id = node_id
	var math_node := DataLoader.graph.get_node(node_id)
	if math_node:
		hover_label.text = math_node.node_name
		hover_label.add_theme_color_override("font_color", math_node.color)


func clear_hover(node_id: String) -> void:
	if _hovered_node_id == node_id:
		hover_label.text = ""
		_hovered_node_id = ""
