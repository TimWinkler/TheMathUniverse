shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled;

uniform float star_size : hint_range(0.001, 0.1) = 0.02;
uniform float twinkle_speed : hint_range(0.0, 5.0) = 1.5;
uniform float brightness : hint_range(0.0, 3.0) = 1.0;

void vertex() {
	// Billboard: always face camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), (VIEW_MATRIX * MODEL_MATRIX[3]).xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize((VIEW_MATRIX * MODEL_MATRIX[3]).xyz), 0.0),
		VIEW_MATRIX * MODEL_MATRIX[3]
	);
}

void fragment() {
	float dist = length(UV - vec2(0.5));
	float alpha = smoothstep(0.5, 0.0, dist);

	// Twinkle
	float twinkle = 0.7 + 0.3 * sin(TIME * twinkle_speed + VERTEX.x * 100.0 + VERTEX.y * 73.0);

	ALBEDO = vec3(1.0) * brightness * twinkle;
	ALPHA = alpha * twinkle * 0.8;
}
