class_name MathNodeBase
extends Node3D

## Base class for all math nodes (domain, subdomain, topic).

signal clicked(node_id: String)
signal hovered(node_id: String)
signal unhovered(node_id: String)

@export var node_id: String = ""
@export var node_color: Color = Color.WHITE
@export var node_level: String = "topic"  # "domain", "subdomain", "topic"

var math_node: MathTypes.MathNode
var _is_hovered: bool = false
var _target_scale: Vector3
var _base_scale: Vector3

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D
@onready var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D


func setup(p_math_node: MathTypes.MathNode) -> void:
	math_node = p_math_node
	node_id = p_math_node.id
	node_color = p_math_node.color
	node_level = p_math_node.level
	position = p_math_node.position

	# Scale based on level and importance
	var size_mult := 1.0
	match node_level:
		"domain":
			size_mult = 2.5 + p_math_node.importance * 0.1
		"subdomain":
			size_mult = 1.2 + p_math_node.importance * 0.05
		"topic":
			size_mult = 0.5 + p_math_node.importance * 0.05

	_base_scale = Vector3.ONE * size_mult
	_target_scale = _base_scale
	scale = _base_scale

	# Set label
	if label_3d:
		label_3d.text = p_math_node.node_name
		label_3d.modulate = node_color
		# Hide labels on topics by default (too cluttered)
		label_3d.visible = node_level != "topic"

	# Apply material color
	_apply_material()


func _apply_material() -> void:
	if mesh_instance == null:
		return
	var mat: ShaderMaterial = mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://shaders/star_glow.gdshader")
		mesh_instance.set_surface_override_material(0, mat)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("base_color", node_color)
		var intensity := 1.5
		match node_level:
			"domain":
				intensity = 3.0
				mat.set_shader_parameter("pulse_speed", 0.8)
				mat.set_shader_parameter("pulse_amount", 0.2)
			"subdomain":
				intensity = 2.0
				mat.set_shader_parameter("pulse_speed", 1.2)
				mat.set_shader_parameter("pulse_amount", 0.1)
			"topic":
				intensity = 1.5
				mat.set_shader_parameter("pulse_speed", 1.5)
				mat.set_shader_parameter("pulse_amount", 0.08)
		mat.set_shader_parameter("glow_intensity", intensity)


func _process(delta: float) -> void:
	# Smooth scale transitions
	scale = scale.lerp(_target_scale, delta * 8.0)


func set_hovered(hovered: bool) -> void:
	_is_hovered = hovered
	if hovered:
		_target_scale = _base_scale * 1.2
		if label_3d:
			label_3d.visible = true
		emit_signal("hovered", node_id)
	else:
		_target_scale = _base_scale
		if label_3d and node_level == "topic":
			label_3d.visible = false
		emit_signal("unhovered", node_id)


func on_click() -> void:
	emit_signal("clicked", node_id)
