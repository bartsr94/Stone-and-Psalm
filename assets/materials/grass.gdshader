shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_disabled, depth_draw_opaque;

// Ground-cover material: the grass clumps and moor tufts instanced by
// scripts/view/vegetation_renderer.gd. Like every other material in the valley it takes the
// mesh COLOR as albedo (Architecture Guide §4.1), then does the three things a blade of grass
// needs that a tree does not:
//
// **It moves.** A sway in the vertex shader, weighted by height up the blade so the roots stay
// planted, phased by world position so a meadow ripples in waves rather than nodding in
// unison. Grass that stands perfectly still is the second thing (after a flat green plane) that
// says "game" about a meadow.
//
// **It takes the season's ground tint and a per-instance colour.** The MultiMesh carries a
// colour per clump (a hashed drift toward straw or toward shade), and the season blender's
// ground_tint is multiplied over the lot, so the same mesh is spring-green, hay-gold and
// winter-grey without any variant meshes. Snow settles on the tips.
//
// **Both sides render.** Blades are single quads; cull_disabled makes each read from either
// side, which halves the geometry of every clump. Specular is off: at this size a highlight
// on a blade is a white speck, and ten thousand white specks are noise.

uniform vec3 season_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.87, 0.89, 0.92);
uniform float wind_strength = 0.09;
uniform float wind_speed = 1.4;
uniform float wind_wavelength_m = 9.0;
uniform float ambient_lift : hint_range(0.0, 1.0) = 0.25;

varying float v_height;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Height fraction up the blade, clamped: every clump is under a metre tall.
	float up = clamp(VERTEX.y / 0.75, 0.0, 1.0);
	v_height = up;
	float phase = (world.x * 0.9 + world.z * 0.6) * (6.28318 / wind_wavelength_m);
	float gust = sin(TIME * wind_speed + phase) * 0.7 + sin(TIME * wind_speed * 2.3 + phase * 1.7) * 0.3;
	// Bend over rather than slide: the top moves sideways and dips very slightly.
	float bend = gust * wind_strength * up * up;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.55;
	VERTEX.y -= abs(bend) * 0.25;
	// Blades are flat cards; give them a normal that leans up so both faces light like a
	// leaf catching sky rather than one dark side and one lit side.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	vec3 base = COLOR.rgb * season_tint;
	// Roots sit in their own shade; a touch of darkening at the base grounds the clump without
	// a real AO pass having to find it.
	base *= mix(0.72, 1.0, smoothstep(0.0, 0.5, v_height));
	float snow = snow_amount * smoothstep(0.35, 0.9, v_height);
	ALBEDO = mix(base, snow_color, snow);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	// Backlit blades glow a little: a cheap stand-in for translucency at a low sun.
	BACKLIGHT = vec3(ambient_lift);
}
