extends Node

## Main scene — bootstraps the universe and connects UI.

@onready var universe: UniverseManager = $Universe
@onready var info_panel: PanelContainer = $UI/InfoPanel
@onready var hud: CanvasLayer = $UI/HUD


func _ready() -> void:
	# Wait for universe to finish loading
	await get_tree().process_frame
	await get_tree().process_frame

	# Connect signals
	universe.node_selected.connect(_on_node_selected)

	var cam := universe.camera_controller
	if cam:
		cam.node_hovered.connect(_on_node_hovered)
		cam.node_unhovered.connect(_on_node_unhovered)

	print("[Main] The Math Universe is ready!")


func _on_node_selected(math_node: MathTypes.MathNode) -> void:
	info_panel.show_node(math_node)


func _on_node_hovered(node_id: String) -> void:
	hud.show_hover(node_id)


func _on_node_unhovered(node_id: String) -> void:
	hud.clear_hover(node_id)
