shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Vegetation material. Like the shared material it takes the mesh COLOR as albedo, so props
// still batch by look. On top of that: canopy vertices (the green ones) are recoloured toward
// the season's foliage tint — green in spring, deep green in summer, bracken-gold in autumn,
// bare twig-brown in winter — while trunks, stumps and rock (not green) keep their colour; and
// snow_amount dusts every upward face. Driven per day by scripts/view/vegetation_renderer.gd
// from the SeasonBlender. Architecture Guide §4.7.

uniform vec3 foliage_tint : source_color = vec3(0.36, 0.45, 0.25);
uniform float foliage_recolor : hint_range(0.0, 1.0) = 0.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.87, 0.89, 0.92);
uniform float base_roughness = 0.85;

varying vec3 v_world_normal;

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;

	// Leaves read green: the green channel sits above red and blue. Trunks and rock do not.
	float leafiness = clamp((base.g - base.r) * 4.0 + (base.g - base.b) * 2.0, 0.0, 1.0);
	vec3 recolored = mix(base, foliage_tint, leafiness * foliage_recolor);

	// Snow settles on upward faces, most on the flattest.
	float up = clamp(v_world_normal.y, 0.0, 1.0);
	float snow = snow_amount * smoothstep(0.35, 0.85, up);

	ALBEDO = mix(recolored, snow_color, snow);
	ROUGHNESS = mix(base_roughness, 0.6, snow);
	METALLIC = 0.0;
}
