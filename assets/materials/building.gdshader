shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Building material. Like the terrain and vegetation materials it takes the mesh COLOR as
// albedo, so every building batches into the same look as everything else in the valley
// (Architecture Guide §4.1). It adds the two things a building needs that a prop does not.
//
// **build_height_m raises the building out of the ground as it is built.** Anything above that
// height in the model's own local space is discarded, so a site under construction shows its
// plinth first, then its walls course by course, and its roof only at the end — which is the
// honest picture of a construction site and costs one uniform per site rather than a second set
// of part-built models. It is model-local, not world, so a building on a slope clips level with
// itself rather than with the horizon.
//
// **snow settles on the roof.** Upward faces take the seasonal snow, exactly as the terrain and
// vegetation do, so a winter valley is white all the way up rather than white only where nobody
// has built.
//
// Driven per building by scripts/view/buildings_renderer.gd.

uniform float build_height_m = 1000.0;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.87, 0.89, 0.92);
uniform float base_roughness = 0.88;

varying vec3 v_world_normal;
varying float v_local_height;

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The model's origin sits on the ground at the footprint centre, so local y is height above
	// the building's own base — see tools/blender/meshkit.py's `finish`.
	v_local_height = VERTEX.y;
}

void fragment() {
	if (v_local_height > build_height_m) {
		discard;
	}

	vec3 base = COLOR.rgb;

	float up = clamp(v_world_normal.y, 0.0, 1.0);
	// Roofs hold snow; walls do not. The threshold is higher than the terrain's because a steep
	// thatch pitch should still take a covering while a wall never should.
	float snow = snow_amount * smoothstep(0.30, 0.80, up);

	ALBEDO = mix(base, snow_color, snow);
	ROUGHNESS = mix(base_roughness, 0.62, snow);
	METALLIC = 0.0;
}
