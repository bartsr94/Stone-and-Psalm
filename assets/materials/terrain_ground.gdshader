shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Terrain ground material. The mesh's COLOR attribute carries the albedo — painted by
// scripts/view/palette.gd in linear space, exactly as the shared StandardMaterial3D would use
// it — so the valley still looks like one game.
//
// On top of that colour this shader does three things, in order of how much they matter:
//
// 1. **Breaks up the flat colour.** A cell's colour is one value across four square metres, and
//    a meadow of them is a single unbroken green filling most of the screen — the flattest,
//    most obviously untextured thing in the frame. Two octaves of cheap value noise vary the
//    ground's value and push it slightly toward soil, at two scales: a broad drift that reads as
//    changing ground, and a finer grain that reads as turf. No texture, no UVs, and it costs a
//    handful of instructions.
// 2. **Wears the ground down where it is steep.** Slope blends toward bare earth and then
//    toward rock, which is what puts scars and outcrops on the valley sides without authoring a
//    single one and without the terrain data knowing about it.
// 3. **Lies snow over it.** Fully, on flat ground, at high coverage; only on the high moor at
//    low coverage; never on faces too steep to hold it. Driven per day by
//    scripts/view/terrain_renderer.gd from the seasonal snow_coverage. Architecture Guide §4.7 —
//    snow is a terrain shader parameter, not a separate mesh.

uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float snow_line_m = 40.0;
uniform float snow_line_falloff_m = 22.0;
uniform vec3 snow_color : source_color = vec3(0.87, 0.89, 0.92);
uniform float base_roughness = 0.85;

// Ground variation. `_m` values are the wavelength in metres, so these read as sizes on the map.
uniform float broad_noise_m = 21.0;
uniform float fine_noise_m = 5.5;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec3 soil_color : source_color = vec3(0.31, 0.25, 0.20);
uniform vec3 rock_color : source_color = vec3(0.49, 0.46, 0.42);
// Slope in degrees at which bare earth starts to show, and at which it is all rock.
uniform float wear_slope_deg = 17.0;
uniform float rock_slope_deg = 33.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Value noise over the world plane. Hash-based rather than sampled, so there is no texture to
// import, no tiling to line up with the cell grid, and nothing to keep in sync with the terrain.
float hash21(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453123);
}

// Successive octaves are rotated as well as scaled. Value noise is built on an axis-aligned
// lattice, so stacking octaves at the same orientation leaves a visible grid of soft squares
// across the meadow — which looks more like a bug than the flat colour it replaced.
const mat2 OCTAVE_ROTATION = mat2(vec2(0.7660, 0.6428), vec2(-0.6428, 0.7660));

float value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 f = fract(position);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 base = COLOR.rgb;

	// --- 1. break up the flat cell colour ---
	vec2 ground_uv = v_world_pos.xz;
	float broad = value_noise(ground_uv / broad_noise_m);
	float mid = value_noise(OCTAVE_ROTATION * ground_uv / (fine_noise_m * 2.3));
	float fine = value_noise(OCTAVE_ROTATION * OCTAVE_ROTATION * ground_uv / fine_noise_m);
	float grain = (broad - 0.5) * 0.55 + (mid - 0.5) * 0.30 + (fine - 0.5) * 0.15;
	// Darken and lighten around the authored colour, and drift the darker patches toward soil so
	// the variation reads as ground rather than as a brightness wobble.
	base *= 1.0 + grain * noise_strength * 2.0;
	base = mix(base, soil_color, clamp(-grain, 0.0, 1.0) * noise_strength * 0.5);

	// --- 2. wear the steep ground down to earth, then to rock ---
	float slope_cos = clamp(v_world_normal.y, 0.0, 1.0);
	float slope_deg = degrees(acos(slope_cos));
	float worn = smoothstep(wear_slope_deg, rock_slope_deg, slope_deg);
	base = mix(base, soil_color, worn * 0.55);
	base = mix(base, rock_color, smoothstep(rock_slope_deg, rock_slope_deg + 12.0, slope_deg) * 0.7);

	// --- 3. snow ---
	// 0 on the valley floor, 1 well up the moor.
	float by_height = clamp((v_world_pos.y - snow_line_m) / max(snow_line_falloff_m, 0.001), 0.0, 1.0);
	// snow_amount 1 covers the floor; low amounts only reach the tops.
	float target = clamp(snow_amount * 1.7 - 0.7 + by_height * 0.9, 0.0, 1.0);
	// Steep faces shed snow, and so do the patches the noise left proud.
	float flatness = smoothstep(0.45, 0.78, slope_cos);
	float cover = clamp(target * flatness + grain * 0.35 * target, 0.0, 1.0);

	ALBEDO = mix(base, snow_color, cover);
	ROUGHNESS = mix(base_roughness, 0.62, cover);
	METALLIC = 0.0;
}
