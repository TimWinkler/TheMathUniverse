shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;

uniform vec4 base_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.15;
uniform float fresnel_power : hint_range(0.0, 10.0) = 3.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Fresnel edge glow
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);

	// Pulsing animation
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;

	// Core color with fresnel glow
	vec3 core = base_color.rgb * glow_intensity * pulse;
	vec3 edge = base_color.rgb * glow_intensity * 2.0 * fresnel;

	ALBEDO = core + edge;
	EMISSION = (core + edge) * 0.8;
	ALPHA = clamp((0.6 + fresnel * 0.4) * opacity, 0.0, 1.0);
}
