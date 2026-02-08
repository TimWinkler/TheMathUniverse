extends PanelContainer

## Bottom-right minimap panel. Toggle with M key.
## Shows a 2D top-down projection of the 3D universe.

@onready var map_canvas: MinimapCanvas = $MapCanvas

var _camera_controller: CameraController
var _player_ship: Node3D
var _is_visible := true


func setup(universe: UniverseManager, camera_controller: CameraController, player_ship: Node3D) -> void:
	_camera_controller = camera_controller
	_player_ship = player_ship
	map_canvas.setup(universe, player_ship)
	map_canvas.world_position_clicked.connect(_on_map_clicked)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_minimap"):
		_is_visible = not _is_visible
		visible = _is_visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_minimap_mode") and _is_visible:
		map_canvas.toggle_mode()
		get_viewport().set_input_as_handled()


func _on_map_clicked(world_pos: Vector3) -> void:
	if _camera_controller:
		# Move ship to clicked position so camera doesn't snap back in follow mode
		if _player_ship:
			_player_ship.global_position = world_pos
		_camera_controller.fly_to(world_pos)
