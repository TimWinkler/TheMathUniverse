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
var _discovery_state: String = "discovered"  # "hidden", "adjacent", "discovered"
var _original_color: Color = Color.WHITE
var _original_glow: float = 1.5

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D
@onready var collision: CollisionShape3D = $StaticBody3D/CollisionShape3D


func setup(p_math_node: MathTypes.MathNode) -> void:
	math_node = p_math_node
	node_id = p_math_node.id
	node_color = p_math_node.color
	_original_color = p_math_node.color
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
		_original_glow = intensity


func _process(delta: float) -> void:
	# Smooth scale transitions
	scale = scale.lerp(_target_scale, delta * 8.0)


func set_hovered(is_hovered: bool) -> void:
	if _discovery_state == "hidden":
		return
	_is_hovered = is_hovered
	if is_hovered:
		_target_scale = _base_scale * 1.2
		if label_3d and _discovery_state == "discovered":
			label_3d.visible = true
		emit_signal("hovered", node_id)
	else:
		_target_scale = _base_scale
		if label_3d and node_level == "topic":
			label_3d.visible = false
		emit_signal("unhovered", node_id)


func on_click() -> void:
	if _discovery_state == "hidden":
		return
	emit_signal("clicked", node_id)


## Set fog of war state: "hidden", "adjacent", or "discovered"
func set_discovery_state(state: String, animate: bool = false) -> void:
	_discovery_state = state

	match state:
		"hidden":
			_apply_hidden_state()
		"adjacent":
			_apply_adjacent_state(animate)
		"discovered":
			_apply_discovered_state(animate)


func _apply_hidden_state() -> void:
	visible = false
	if collision:
		collision.disabled = true


func _apply_adjacent_state(animate: bool) -> void:
	visible = true
	if collision:
		collision.disabled = false

	# Grey silhouette, dim glow
	if mesh_instance:
		var mat = mesh_instance.get_surface_override_material(0) as ShaderMaterial
		if mat:
			var grey := Color(0.3, 0.3, 0.4)
			if animate:
				var tween := create_tween()
				tween.tween_method(func(c: Color): mat.set_shader_parameter("base_color", c),
					mat.get_shader_parameter("base_color"), grey, 0.5)
				tween.parallel().tween_method(func(v: float): mat.set_shader_parameter("glow_intensity", v),
					mat.get_shader_parameter("glow_intensity"), 0.3, 0.5)
			else:
				mat.set_shader_parameter("base_color", grey)
				mat.set_shader_parameter("glow_intensity", 0.3)
				mat.set_shader_parameter("pulse_amount", 0.02)

	# Hide label for adjacent nodes
	if label_3d:
		label_3d.visible = false


func _apply_discovered_state(animate: bool) -> void:
	visible = true
	if collision:
		collision.disabled = false

	if mesh_instance:
		var mat = mesh_instance.get_surface_override_material(0) as ShaderMaterial
		if mat:
			if animate:
				var tween := create_tween()
				tween.tween_method(func(c: Color): mat.set_shader_parameter("base_color", c),
					mat.get_shader_parameter("base_color"), _original_color, 0.5)
				tween.parallel().tween_method(func(v: float): mat.set_shader_parameter("glow_intensity", v),
					mat.get_shader_parameter("glow_intensity"), _original_glow, 0.5)
			else:
				mat.set_shader_parameter("base_color", _original_color)
				mat.set_shader_parameter("glow_intensity", _original_glow)

	# Restore label visibility
	if label_3d:
		label_3d.modulate = _original_color
		label_3d.visible = node_level != "topic"

	# Restore material pulse
	_restore_pulse()


func _restore_pulse() -> void:
	if mesh_instance == null:
		return
	var mat = mesh_instance.get_surface_override_material(0) as ShaderMaterial
	if mat == null:
		return
	match node_level:
		"domain":
			mat.set_shader_parameter("pulse_speed", 0.8)
			mat.set_shader_parameter("pulse_amount", 0.2)
		"subdomain":
			mat.set_shader_parameter("pulse_speed", 1.2)
			mat.set_shader_parameter("pulse_amount", 0.1)
		"topic":
			mat.set_shader_parameter("pulse_speed", 1.5)
			mat.set_shader_parameter("pulse_amount", 0.08)


## Play a flash animation when a node is first discovered
func play_discovery_animation() -> void:
	var tween := create_tween()
	# Scale burst: 0 -> 1.5 -> 1
	tween.tween_property(self, "scale", _base_scale * 1.5, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", _base_scale, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	# White flash on material
	if mesh_instance:
		var mat = mesh_instance.get_surface_override_material(0) as ShaderMaterial
		if mat:
			var flash_tween := create_tween()
			flash_tween.tween_method(func(c: Color): mat.set_shader_parameter("base_color", c),
				Color.WHITE, _original_color, 0.6)
			flash_tween.parallel().tween_method(func(v: float): mat.set_shader_parameter("glow_intensity", v),
				_original_glow * 3.0, _original_glow, 0.8)

	_spawn_discovery_particles()


func _spawn_discovery_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 32
	particles.lifetime = 1.2
	particles.explosiveness = 0.9

	# Particle material
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 2.0
	mat.damping_max = 4.0

	# Color: domain color fading out
	var gradient := Gradient.new()
	gradient.set_color(0, Color(_original_color, 1.0))
	gradient.set_color(1, Color(_original_color, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Scale: shrink to zero
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = curve
	mat.scale_curve = scale_curve

	particles.process_material = mat

	# Tiny sphere mesh for each particle
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 8
	sphere.rings = 4
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = _original_color
	sphere_mat.emission_enabled = true
	sphere_mat.emission = _original_color
	sphere_mat.emission_energy_multiplier = 3.0
	sphere.material = sphere_mat
	particles.draw_pass_1 = sphere

	# Add to parent so scale burst on self doesn't affect particles
	get_parent().add_child(particles)
	particles.global_position = global_position

	# Auto-free after lifetime + buffer
	var timer := get_tree().create_timer(particles.lifetime + 0.5)
	timer.timeout.connect(particles.queue_free)
