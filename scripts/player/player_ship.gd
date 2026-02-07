class_name PlayerShip
extends Node3D

## Player ship — a simple cone mesh that moves with WASD.
## Proximity to adjacent nodes triggers auto-discovery.
## Supports local (input-driven) and remote (network-interpolated) modes.

signal moved_near_node(node_id: String)

@export var move_speed := 30.0
@export var rotation_speed := 5.0
@export var discovery_radius := 8.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var is_local := true
var peer_id: int = 1

var _velocity := Vector3.ZERO
var _universe_manager: UniverseManager = null

# Remote interpolation
var _remote_target_pos := Vector3.ZERO
var _remote_target_rot := Vector3.ZERO

# Position broadcast timer
var _sync_timer := 0.0
const SYNC_INTERVAL := 0.05  # 20Hz


func _ready() -> void:
	_apply_material()


func set_universe_manager(um: UniverseManager) -> void:
	_universe_manager = um


func setup_remote(remote_peer_id: int, player_name: String, ship_color: Color) -> void:
	is_local = false
	peer_id = remote_peer_id
	_remote_target_pos = global_position
	_remote_target_rot = rotation

	# Apply remote player color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ship_color
	mat.emission_enabled = true
	mat.emission = ship_color.darkened(0.3)
	mat.emission_energy_multiplier = 2.0
	mat.metallic = 0.5
	mat.roughness = 0.3
	if mesh_instance:
		mesh_instance.material_override = mat

	# Add floating name label
	var label := Label3D.new()
	label.text = player_name
	label.font_size = 48
	label.modulate = ship_color.lightened(0.3)
	label.position = Vector3(0, 2.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _process(delta: float) -> void:
	if not is_local:
		_interpolate_remote(delta)
		return

	# Get input direction
	var input := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input.z -= 1
	if Input.is_action_pressed("move_backward"):
		input.z += 1
	if Input.is_action_pressed("move_left"):
		input.x -= 1
	if Input.is_action_pressed("move_right"):
		input.x += 1
	if Input.is_action_pressed("move_up"):
		input.y += 1
	if Input.is_action_pressed("move_down"):
		input.y -= 1

	if input != Vector3.ZERO:
		# Get camera direction for movement relative to view
		var camera := get_viewport().get_camera_3d()
		if camera:
			var cam_basis := camera.global_transform.basis
			var move_dir := (cam_basis.x * input.x + cam_basis.y * input.y - cam_basis.z * input.z).normalized()
			_velocity = _velocity.lerp(move_dir * move_speed, delta * 6.0)

			# Rotate ship to face movement direction
			var flat_dir := Vector3(move_dir.x, 0, move_dir.z)
			if flat_dir.length() > 0.1:
				var target_rot := Transform3D.IDENTITY.looking_at(-flat_dir, Vector3.UP)
				global_transform.basis = global_transform.basis.slerp(target_rot.basis, delta * rotation_speed)
	else:
		_velocity = _velocity.lerp(Vector3.ZERO, delta * 4.0)

	if _velocity.length() > 0.01:
		global_position += _velocity * delta
		_check_proximity()

	# Broadcast position to other players
	if NetworkManager.is_online:
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			var pos := global_position
			var rot := rotation
			_receive_position.rpc([pos.x, pos.y, pos.z], [rot.x, rot.y, rot.z])


func _interpolate_remote(delta: float) -> void:
	global_position = global_position.lerp(_remote_target_pos, delta * 12.0)
	rotation = rotation.lerp(_remote_target_rot, delta * 12.0)


@rpc("any_peer", "unreliable_ordered")
func _receive_position(pos_arr: Array, rot_arr: Array) -> void:
	if is_local:
		return
	_remote_target_pos = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
	_remote_target_rot = Vector3(rot_arr[0], rot_arr[1], rot_arr[2])


func _check_proximity() -> void:
	if _universe_manager == null:
		return

	var all_nodes := _universe_manager.get_all_node_instances()
	for node_id in all_nodes:
		if DiscoveryManager.is_adjacent(node_id):
			var instance: MathNodeBase = all_nodes[node_id]
			var dist := global_position.distance_to(instance.global_position)
			if dist < discovery_radius:
				DiscoveryManager.discover_node(node_id)
				moved_near_node.emit(node_id)


func _apply_material() -> void:
	if mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.75, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.55, 0.8)
	mat.emission_energy_multiplier = 2.0
	mat.metallic = 0.5
	mat.roughness = 0.3
	mesh_instance.material_override = mat
