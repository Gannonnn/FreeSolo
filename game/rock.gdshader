shader_type canvas_item;
render_mode unshaded;

// Lights a chunk of rock baked by RockRelief: sun with cast shadows, sky light, ambient occlusion,
// the wall's angle, and a procedural rock surface with chalk and rubber marks.

// The chunk's fine relief (also the sprite's texture, which sets UV): R = height in meters,
// G = chalk (positive) or rubber (negative). UV spans relief_rect (wall-space meters: xy = corner,
// zw = size).
uniform sampler2D relief : filter_linear_mipmap, repeat_disable;
uniform vec4 relief_rect;
uniform vec2 relief_texel;
uniform float relief_texel_m = 0.01;
// Creases and facets over the same area as the relief: 0.5 is flat, 0 and 1 are -/+ detail_depth.
uniform sampler2D detail : filter_linear_mipmap, repeat_disable;
uniform float detail_depth = 0.03;
// Coarse map for the whole wall: R = height in meters, G = inside the face, B = wall angle in
// radians, A = shade from rock above.
uniform sampler2D coarse : filter_linear, repeat_disable;
uniform vec4 coarse_rect;
uniform vec2 coarse_texel;
uniform float coarse_texel_m = 0.08;
// Where water runs down the face (WaterStreaks), over the same area as the coarse map.
uniform sampler2D wet : filter_linear, repeat_disable;

// Toward the sun: x right, y down the wall, z out of the wall. Same as RockRelief.SUN.
uniform vec3 sun_dir = vec3(-0.5, -0.68, 0.53);
uniform vec3 sun_color = vec3(1.0, 0.93, 0.8);
uniform vec3 sky_color = vec3(0.55, 0.62, 0.76);
// Sunlight bounced off the ground and the rock below, lighting faces that look down.
uniform vec3 bounce_color = vec3(0.62, 0.5, 0.38);
uniform float sun_strength = 1.0;
uniform float sky_strength = 0.62;
uniform float bounce_strength = 0.55;
// How soft cast shadow edges are, as a slope (the sun's apparent size). Shadows stay sharp near
// the rock that casts them and blur further away.
uniform float penumbra = 0.12;
// Sunlight in this many flat steps, for a posterized look. 0 = smooth.
uniform float light_bands = 0.0;
// How much the fine grain bends the light. Purely visual.
uniform float grain_bump = 0.18;

uniform vec3 base_color = vec3(0.62, 0.6, 0.57);
uniform vec3 dark_color = vec3(0.2, 0.19, 0.2);
uniform vec3 light_color = vec3(0.9, 0.88, 0.84);
uniform vec3 accent_color = vec3(0.66, 0.68, 0.46);
uniform vec3 streak_color = vec3(0.17, 0.16, 0.15);
// Soil and grime that collect in cracks, pockets and creases.
uniform vec3 dirt_color = vec3(0.3, 0.24, 0.17);
uniform float dirt = 0.5;
uniform float grain = 0.85;
uniform float strata = 0.0;
uniform float streaks = 0.4;
uniform float lichen = 0.4;
uniform float noise_seed = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm3(vec2 p) {
	return 0.5 * vnoise(p) + 0.3 * vnoise(p * 2.13 + 5.2) + 0.2 * vnoise(p * 4.37 + 1.7);
}

// Cast shadow marches, toward the sun: steps, and the first and last distances in meters. The
// fine march covers holds and features, the coarse one the shape of the face.
const int FINE_STEPS = 16;
const float FINE_NEAR = 0.008;
const float FINE_REACH = 0.3;
const int COARSE_STEPS = 8;
const float COARSE_NEAR = 0.1;
const float COARSE_REACH = 1.0;

// Meters per bed of rock on average, when strata > 0.
const float BED_THICKNESS = 0.8;

// Which bed `world` is in: x = bed number, y = 0..1 from its top to its bottom. Beds wander and
// vary in thickness.
vec2 bed_at(vec2 world) {
	float y = world.y + (vnoise(vec2(world.x * 0.35, noise_seed)) - 0.5) * 0.9 + (vnoise(vec2(world.x * 1.4, noise_seed + 4.0)) - 0.5) * 0.2;
	float t = y / BED_THICKNESS + (vnoise(vec2(y * 0.6, noise_seed + 9.0)) - 0.5) * 0.9;
	return vec2(floor(t), fract(t));
}

// Height in meters at `uv`: carved relief plus creases.
float height_at(vec2 uv) {
	return texture(relief, uv).r + (texture(detail, uv).r - 0.5) * 2.0 * detail_depth;
}

float height_lod(vec2 uv, float lod) {
	return textureLod(relief, uv, lod).r + (textureLod(detail, uv, max(lod - 1.0, 0.0)).r - 0.5) * 2.0 * detail_depth;
}

void fragment() {
	vec2 world = relief_rect.xy + UV * relief_rect.zw;
	vec2 cuv = (world - coarse_rect.xy) / coarse_rect.zw;
	vec4 c = texture(coarse, cuv);
	float inside = smoothstep(0.42, 0.58, c.g);
	if (inside < 0.004) {
		discard;
	}

	// Slopes from the fine relief, the coarse relief and a fine grain.
	vec4 here = texture(relief, UV);
	float h = height_at(UV);
	float hl = height_at(UV - vec2(relief_texel.x, 0.0));
	float hr = height_at(UV + vec2(relief_texel.x, 0.0));
	float hu = height_at(UV - vec2(0.0, relief_texel.y));
	float hd = height_at(UV + vec2(0.0, relief_texel.y));
	vec2 grad = vec2(hr - hl, hd - hu) / (2.0 * relief_texel_m);
	float cl = texture(coarse, cuv - vec2(coarse_texel.x, 0.0)).r;
	float cr = texture(coarse, cuv + vec2(coarse_texel.x, 0.0)).r;
	float cu = texture(coarse, cuv - vec2(0.0, coarse_texel.y)).r;
	float cd = texture(coarse, cuv + vec2(0.0, coarse_texel.y)).r;
	grad += vec2(cr - cl, cd - cu) / (2.0 * coarse_texel_m);
	vec2 wp = world + vec2(noise_seed * 7.31, noise_seed * 3.17);
	vec2 gp = wp * 60.0;
	float g0 = fbm3(gp);
	vec2 grain_grad = vec2(fbm3(gp + vec2(0.4, 0.0)) - g0, fbm3(gp + vec2(0.0, 0.4)) - g0) * grain_bump;
	// Surface normals in relief space, tilted by the wall angle: `n` for lighting, and `ns`
	// without the grain, for where lichen grows.
	float ca = cos(c.b);
	float sa = sin(c.b);
	vec3 n = normalize(vec3(-grad - grain_grad, 1.0));
	n = vec3(n.x, n.y * ca + n.z * sa, -n.y * sa + n.z * ca);
	vec3 ns = normalize(vec3(-grad, 1.0));
	ns = vec3(ns.x, ns.y * ca + ns.z * sa, -ns.y * sa + ns.z * ca);
	vec3 L = normalize(sun_dir);
	float direct = max(dot(n, L), 0.0);

	// Cast shadows: march toward the sun through the fine relief, then the coarse relief. At each
	// step, `clearance` is the slope by which the sun's ray passes over the rock there; around zero
	// the sun is partly hidden, which gives soft edges that widen with distance from the caster.
	vec2 toward = normalize(L.xy);
	float rise = L.z / length(L.xy);
	float lit = 1.0;
	for (int i = 0; i < FINE_STEPS; i++) {
		float d = mix(FINE_NEAR, FINE_REACH, pow(float(i) / float(FINE_STEPS - 1), 1.7));
		float hs = height_at(UV + toward * d / relief_rect.zw);
		float clearance = (h + d * rise - hs) / d;
		lit = min(lit, smoothstep(-penumbra, penumbra, clearance));
	}
	float hc = c.r;
	for (int i = 0; i < COARSE_STEPS; i++) {
		float d = mix(COARSE_NEAR, COARSE_REACH, pow(float(i) / float(COARSE_STEPS - 1), 1.3));
		float hs = texture(coarse, cuv + toward * d / coarse_rect.zw).r;
		float clearance = (hc + d * rise - hs) / d;
		lit = min(lit, smoothstep(-penumbra, penumbra, clearance));
	}
	lit *= 1.0 - c.a;

	// Ambient occlusion: rock lower than its surroundings gets less sky.
	float near = height_lod(UV, 2.5);
	float wide = height_lod(UV, 4.5);
	float cavity = (h - near) * 22.0 + (h - wide) * 7.0 + (hc - (cl + cr + cu + cd) * 0.25) * 4.0;
	float ao = clamp(1.0 + cavity, 0.3, 1.12);

	// Rock surface: tone, bedding bands, mineral flecks, dirt, water streaks, lichen.
	vec3 albedo = base_color * (0.84 + 0.32 * fbm3(wp * 0.7));
	if (strata > 0.0) {
		// Each bed of rock has its own shade, blending into the next bed's over its lower half: a
		// sharp change from one bed to the next draws a long ruled line across the face.
		vec2 bed = bed_at(world);
		float tone = mix(hash12(vec2(bed.x, 5.0)), hash12(vec2(bed.x + 1.0, 5.0)), smoothstep(0.5, 1.0, bed.y)) - 0.5;
		albedo *= 1.0 + tone * strata * 0.6;
	}
	vec2 fleck_cell = wp * 60.0 + vec2(vnoise(wp * 23.0), vnoise(wp * 23.0 + 9.0)) * 0.8;
	float fleck_dark = step(1.0 - grain * 0.14, hash12(floor(fleck_cell)));
	float fleck_light = step(1.0 - grain * 0.1, hash12(floor(fleck_cell * 0.8) + 31.0));
	albedo = mix(albedo, dark_color, fleck_dark * 0.4);
	albedo = mix(albedo, light_color, fleck_light * 0.35);
	albedo = mix(albedo, dirt_color, smoothstep(-0.12, -0.6, cavity) * dirt);
	// Water streaks where water runs off features, breaking into strands along the way it runs,
	// over a faint general weathering.
	float weathering = smoothstep(0.58, 0.8, fbm3(vec2(wp.x * 6.0, wp.y * 0.3))) * 0.2;
	float strands = 0.5 + vnoise(vec2(wp.x * 22.0, wp.y * 0.9)) + 0.4 * vnoise(vec2(wp.x * 60.0, wp.y * 2.0));
	float streak = max(smoothstep(0.1, 0.75, texture(wet, cuv).r * strands), weathering);
	albedo = mix(albedo, streak_color, streak * streaks);
	// Lichen grows on rock that faces up, and not where climbers' hands and feet rub it off.
	float patch = fbm3(wp * 1.6 + 11.0);
	float lichen_cover = smoothstep(0.66 - lichen * 0.12, 0.72 - lichen * 0.12, patch) * lichen;
	lichen_cover *= smoothstep(-0.25, 0.35, 0.1 - ns.y) * 1.6 * (1.0 - smoothstep(0.05, 0.3, abs(here.g)));
	albedo = mix(albedo, accent_color, min(lichen_cover, 1.0) * (0.45 + 0.55 * hash12(floor(wp * 60.0))));

	// Chalk on handholds, rubber on footholds.
	float chalk = clamp(here.g, 0.0, 1.0) * (0.55 + 0.45 * vnoise(wp * 140.0));
	float rubber = clamp(-here.g, 0.0, 1.0) * (0.45 + 0.55 * vnoise(wp * 90.0));
	albedo = mix(albedo, vec3(0.95, 0.95, 0.93), chalk * 0.9);
	albedo = mix(albedo, vec3(0.08, 0.08, 0.09), rubber * 0.8);

	// Cool sky light from above, warm bounce light from below, then the sun.
	float sky = clamp(0.55 - 0.35 * n.y + 0.25 * n.z, 0.2, 1.15);
	float bounce = clamp(0.35 * n.y + 0.1 * n.z, 0.0, 0.5);
	vec3 ambient = sky_color * sky_strength * sky + bounce_color * bounce_strength * bounce;
	float sun = direct * lit * mix(1.0, ao, 0.4);
	if (light_bands > 0.0) {
		float steps = sun * light_bands;
		sun = (floor(steps) + smoothstep(0.42, 0.58, fract(steps))) / light_bands;
	}
	vec3 light = ambient * ao + sun_color * sun_strength * sun;
	COLOR = vec4(albedo * light, inside);
}
