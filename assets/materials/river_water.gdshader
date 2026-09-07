shader_type spatial;

render_mode blend_mix, depth_prepass_alpha, cull_disabled;

// The beck. Retuned in the In-The-Nature look pass (2026-09-07): drawn as a dark albedo with a
// weak specular, the river rendered as a black trench across every wide shot, because from an
// orthographic camera at 40° the Fresnel term is tiny and the sky it should mirror is dim.
// Real water at that angle still reads as *sky-coloured*, so the surface now lifts toward a
// sky tint by a floor plus a Fresnel ramp, its normal ripples so the low sun scatters into
// glints rather than one hard highlight, and roughness is low enough for screen-space
// reflections (on in scenes/environment/valley_environment.tres) to bring the bank's trees in.

uniform vec4 water_color : source_color = vec4(0.12, 0.20, 0.22, 1.0);
uniform vec3 sky_tint : source_color = vec3(0.62, 0.72, 0.84);
uniform float reflect_floor : hint_range(0.0, 1.0) = 0.42;
uniform float reflect_fresnel : hint_range(0.0, 1.0) = 0.5;
uniform float flow_speed = 0.08;
uniform float flow_scale = 18.0;
uniform float wave_strength = 0.035;
uniform float ripple_normal = 0.12;
uniform float alpha = 0.9;


void vertex() {
	vec2 flow_uv = UV * vec2(flow_scale, flow_scale * 0.35);
	VERTEX.y += sin((flow_uv.x + TIME * flow_speed) * 6.28318) * wave_strength;
}


void fragment() {
	vec2 flow_uv = UV * vec2(flow_scale, flow_scale * 0.35);
	float ripple_a = sin((flow_uv.x + TIME * flow_speed) * 6.28318);
	float ripple_b = sin((flow_uv.x * 0.61 + flow_uv.y + TIME * flow_speed * 0.7) * 6.28318);
	float ripple_c = sin((flow_uv.y * 1.7 - flow_uv.x * 0.4 + TIME * flow_speed * 1.9) * 6.28318);
	float brightness = 0.9 + (ripple_a + ripple_b) * 0.05;

	// Tilt the normal with the ripples so specular breaks into moving glints.
	vec3 tilted = NORMAL + (TANGENT * (ripple_a * 0.6 + ripple_c * 0.4) + BINORMAL * ripple_b) * ripple_normal;
	NORMAL = normalize(tilted);

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	float reflect_amount = clamp(reflect_floor + reflect_fresnel * fresnel, 0.0, 1.0);

	vec3 base = water_color.rgb * brightness;
	ALBEDO = mix(base, sky_tint, reflect_amount);
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	ALPHA = alpha;
}
