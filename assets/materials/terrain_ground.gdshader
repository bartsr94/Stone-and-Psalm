shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Terrain ground material. The mesh's COLOR attribute carries the albedo — painted by
// scripts/view/palette.gd in linear space, exactly as the shared StandardMaterial3D would use
// it — so the valley still looks like one game. On top of that, snow_amount blends the ground
// toward snow: fully, on flat ground, at high coverage; only on the high moor at low coverage;
// never on faces too steep to hold it. Driven per day by scripts/view/terrain_renderer.gd
// from the seasonal snow_coverage. Architecture Guide §4.7 — snow is a terrain shader
// parameter, not a separate mesh.

uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float snow_line_m = 40.0;
uniform float snow_line_falloff_m = 22.0;
uniform vec3 snow_color : source_color = vec3(0.87, 0.89, 0.92);
uniform float base_roughness = 0.85;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;

	// 0 on the valley floor, 1 well up the moor.
	float by_height = clamp((v_world_pos.y - snow_line_m) / max(snow_line_falloff_m, 0.001), 0.0, 1.0);
	// snow_amount 1 covers the floor; low amounts only reach the tops.
	float target = clamp(snow_amount * 1.7 - 0.7 + by_height * 0.9, 0.0, 1.0);
	// Steep faces shed snow.
	float flatness = smoothstep(0.45, 0.78, v_world_normal.y);
	float cover = target * flatness;

	ALBEDO = mix(base, snow_color, cover);
	ROUGHNESS = mix(base_roughness, 0.62, cover);
	METALLIC = 0.0;
}
