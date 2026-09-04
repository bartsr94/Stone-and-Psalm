shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.12, 0.20, 0.22, 1.0);
uniform float flow_speed = 0.08;
uniform float flow_scale = 18.0;
uniform float wave_strength = 0.035;
uniform float alpha = 0.86;


void vertex() {
	vec2 flow_uv = UV * vec2(flow_scale, flow_scale * 0.35);
	VERTEX.y += sin((flow_uv.x + TIME * flow_speed) * 6.28318) * wave_strength;
}


void fragment() {
	vec2 flow_uv = UV * vec2(flow_scale, flow_scale * 0.35);
	float ripple_a = sin((flow_uv.x + TIME * flow_speed) * 6.28318);
	float ripple_b = sin((flow_uv.x * 0.61 + flow_uv.y + TIME * flow_speed * 0.7) * 6.28318);
	float brightness = 0.88 + (ripple_a + ripple_b) * 0.06;
	ALBEDO = water_color.rgb * brightness;
	ROUGHNESS = 0.18;
	SPECULAR = 0.72;
	ALPHA = alpha;
}
