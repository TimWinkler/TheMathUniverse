class_name ConnectionLine
extends MeshInstance3D

## Visual connection between two math nodes using ImmediateMesh.

var from_id: String
var to_id: String
var edge_type: String
var line_color: Color = Color(1, 1, 1, 0.3)


func setup(p_from_pos: Vector3, p_to_pos: Vector3, p_color: Color, p_type: String) -> void:
	edge_type = p_type
	line_color = p_color

	# Build the line geometry
	var im := ImmediateMesh.new()
	mesh = im

	var direction := p_to_pos - p_from_pos
	var length := direction.length()
	if length < 0.01:
		return

	# Create a thin quad strip (two triangles) for the connection
	var dir_norm := direction.normalized()
	# Find a perpendicular vector for width
	var up := Vector3.UP
	if abs(dir_norm.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var side := dir_norm.cross(up).normalized()

	var width := 0.08
	match edge_type:
		"prerequisite":
			width = 0.1
		"prepares":
			width = 0.06
		"bridges":
			width = 0.12

	var half := side * width

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# Triangle 1
	im.surface_set_color(line_color)
	im.surface_add_vertex(p_from_pos - half)
	im.surface_set_color(line_color)
	im.surface_add_vertex(p_from_pos + half)
	im.surface_set_color(line_color)
	im.surface_add_vertex(p_to_pos + half)
	# Triangle 2
	im.surface_set_color(line_color)
	im.surface_add_vertex(p_from_pos - half)
	im.surface_set_color(line_color)
	im.surface_add_vertex(p_to_pos + half)
	im.surface_set_color(line_color)
	im.surface_add_vertex(p_to_pos - half)
	im.surface_end()

	_apply_material()


func _apply_material() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = line_color
	mat.emission_enabled = true
	mat.emission = line_color
	mat.emission_energy_multiplier = 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true

	match edge_type:
		"prerequisite":
			mat.albedo_color.a = 0.5
			mat.emission_energy_multiplier = 1.0
		"prepares":
			mat.albedo_color.a = 0.25
			mat.emission_energy_multiplier = 0.5
		"bridges":
			mat.albedo_color.a = 0.4
			mat.emission_energy_multiplier = 0.8

	material_override = mat
