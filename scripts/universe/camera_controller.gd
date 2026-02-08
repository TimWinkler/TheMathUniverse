class_name CameraController
extends Node3D

## Orbit camera with zoom, pan, fly-to-node, and ship follow mode.

signal node_clicked(node_id: String)
signal node_hovered(node_id: String)
signal node_unhovered(node_id: String)

@export var orbit_speed := 0.005
@export var zoom_speed := 2.0
@export var pan_speed := 0.1
@export var min_distance := 5.0
@export var max_distance := 800.0
@export var fly_to_speed := 3.0
@export var initial_distance := 120.0
@export var follow_offset := Vector3(0, 8, 20)
@export var follow_smoothness := 4.0

var _orbit_angle_x := 0.3  # pitch
var _orbit_angle_y := 0.0  # yaw
var _distance: float
var _target_position := Vector3.ZERO
var _is_orbiting := false
var _is_panning := false
var _is_flying := false
var _fly_target := Vector3.ZERO
var _fly_target_distance := 30.0
var _last_hovered_id := ""
var _last_hovered_node: MathNodeBase = null

# Follow mode
var follow_target: Node3D = null
var _follow_mode := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_distance = initial_distance
	_update_camera_transform()


func set_follow_target(target: Node3D) -> void:
	follow_target = target
	_follow_mode = target != null
	if _follow_mode:
		_distance = 25.0
		_orbit_angle_x = 0.35


func _unhandled_input(event: InputEvent) -> void:
	# Orbit with right-click drag
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _is_orbiting:
			_orbit_angle_y -= motion.relative.x * orbit_speed
			_orbit_angle_x -= motion.relative.y * orbit_speed
			_orbit_angle_x = clamp(_orbit_angle_x, -PI * 0.45, PI * 0.45)
			_is_flying = false
			_update_camera_transform()
		elif _is_panning and not _follow_mode:
			var right := camera.global_transform.basis.x
			var up := camera.global_transform.basis.y
			_target_position -= right * motion.relative.x * pan_speed * (_distance * 0.01)
			_target_position += up * motion.relative.y * pan_speed * (_distance * 0.01)
			_is_flying = false
			_update_camera_transform()

	# Zoom with scroll
	if event.is_action_pressed("zoom_in"):
		_distance = max(_distance - zoom_speed * (_distance * 0.1), min_distance)
		_is_flying = false
		_update_camera_transform()
	elif event.is_action_pressed("zoom_out"):
		_distance = min(_distance + zoom_speed * (_distance * 0.1), max_distance)
		_is_flying = false
		_update_camera_transform()

	# Click to select node
	if event.is_action_pressed("click"):
		_raycast_click(event as InputEventMouseButton)

	# Home key
	if event.is_action_pressed("home"):
		if _follow_mode and follow_target:
			fly_to(follow_target.global_position, 25.0)
		else:
			fly_to(Vector3.ZERO, initial_distance)


func _process(delta: float) -> void:
	# Follow mode: track the ship (WASD moves ship, not camera)
	if _follow_mode and follow_target:
		if not _is_flying:
			_target_position = _target_position.lerp(follow_target.global_position, delta * follow_smoothness)
			_update_camera_transform()
		else:
			_target_position = _target_position.lerp(_fly_target, delta * fly_to_speed)
			_distance = lerp(_distance, _fly_target_distance, delta * fly_to_speed)
			_update_camera_transform()
			if _target_position.distance_to(_fly_target) < 0.5:
				_is_flying = false
	else:
		# Free camera mode: WASD pans the view
		var input_dir := Vector3.ZERO
		if Input.is_action_pressed("move_forward"):
			input_dir.z -= 1
		if Input.is_action_pressed("move_backward"):
			input_dir.z += 1
		if Input.is_action_pressed("move_left"):
			input_dir.x -= 1
		if Input.is_action_pressed("move_right"):
			input_dir.x += 1
		if Input.is_action_pressed("move_up"):
			input_dir.y += 1
		if Input.is_action_pressed("move_down"):
			input_dir.y -= 1

		if input_dir != Vector3.ZERO:
			_is_flying = false
			var cam_basis := camera.global_transform.basis
			var move := (cam_basis.x * input_dir.x + cam_basis.y * input_dir.y - cam_basis.z * input_dir.z).normalized()
			_target_position += move * pan_speed * _distance * 0.02 * 60.0 * delta
			_update_camera_transform()

		# Smooth fly-to animation
		if _is_flying:
			_target_position = _target_position.lerp(_fly_target, delta * fly_to_speed)
			_distance = lerp(_distance, _fly_target_distance, delta * fly_to_speed)
			_update_camera_transform()
			if _target_position.distance_to(_fly_target) < 0.5:
				_is_flying = false

	# Hover detection via raycast
	_raycast_hover()


func fly_to(target: Vector3, distance: float = 30.0) -> void:
	_fly_target = target
	_fly_target_distance = distance
	_is_flying = true


func _update_camera_transform() -> void:
	if camera == null:
		return
	var offset := Vector3.ZERO
	offset.x = cos(_orbit_angle_x) * sin(_orbit_angle_y) * _distance
	offset.y = sin(_orbit_angle_x) * _distance
	offset.z = cos(_orbit_angle_x) * cos(_orbit_angle_y) * _distance
	camera.global_position = _target_position + offset
	camera.look_at(_target_position, Vector3.UP)


func _raycast_click(event: InputEventMouseButton) -> void:
	if camera == null or event == null:
		return
	var from := camera.project_ray_origin(event.position)
	var to := from + camera.project_ray_normal(event.position) * 1000.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	var result := space.intersect_ray(query)
	var node_base: MathNodeBase = null
	if result.size() > 0:
		var collider = result["collider"]
		node_base = collider.get_parent() as MathNodeBase

	# Fallback: screen-space proximity detection (physics raycast can fail in web exports)
	if node_base == null:
		node_base = _find_nearest_node_at_screen(event.position)

	if node_base:
		node_base.on_click()
		emit_signal("node_clicked", node_base.node_id)
		# Only fly camera to node in free-camera mode
		if not _follow_mode:
			var fly_dist := 15.0
			match node_base.node_level:
				"domain":
					fly_dist = 50.0
				"subdomain":
					fly_dist = 25.0
				"topic":
					fly_dist = 12.0
			fly_to(node_base.global_position, fly_dist)


func _raycast_hover() -> void:
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	var result := space.intersect_ray(query)
	var node_base: MathNodeBase = null

	if result.size() > 0:
		var collider = result["collider"]
		node_base = collider.get_parent() as MathNodeBase

	# Fallback: screen-space proximity detection
	if node_base == null:
		node_base = _find_nearest_node_at_screen(mouse_pos)

	if node_base:
		if _last_hovered_id != node_base.node_id:
			_clear_hover()
			node_base.set_hovered(true)
			_last_hovered_id = node_base.node_id
			_last_hovered_node = node_base
			emit_signal("node_hovered", node_base.node_id)
		return

	# Nothing hovered
	_clear_hover()


func _find_nearest_node_at_screen(screen_pos: Vector2) -> MathNodeBase:
	var um = get_parent() as UniverseManager
	if um == null:
		return null
	var best_node: MathNodeBase = null
	var best_dist := INF
	for instance in um.get_all_node_instances().values():
		var nb = instance as MathNodeBase
		if nb == null or not nb.visible:
			continue
		if camera.is_position_behind(nb.global_position):
			continue
		var sp := camera.unproject_position(nb.global_position)
		var dist := sp.distance_to(screen_pos)
		# Scale hit threshold by node level and zoom
		var threshold := 20.0
		match nb.node_level:
			"domain":
				threshold = 40.0
			"subdomain":
				threshold = 30.0
		if dist < threshold and dist < best_dist:
			best_dist = dist
			best_node = nb
	return best_node


func _clear_hover() -> void:
	if _last_hovered_id != "":
		if _last_hovered_node:
			_last_hovered_node.set_hovered(false)
		emit_signal("node_unhovered", _last_hovered_id)
		_last_hovered_id = ""
		_last_hovered_node = null
