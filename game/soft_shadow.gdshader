shader_type canvas_item;
render_mode unshaded;

// For a CanvasGroup: draws its children's combined silhouette as one soft, see-through shadow,
// so overlapping limbs don't darken twice.

uniform sampler2D group_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float opacity = 0.34;
// Blur radius in screen pixels. Purely visual.
uniform float softness = 4.0;

const vec2 TAPS[12] = {
	vec2(1.0, 0.0), vec2(0.5, 0.866), vec2(-0.5, 0.866), vec2(-1.0, 0.0), vec2(-0.5, -0.866), vec2(0.5, -0.866),
	vec2(0.433, 0.25), vec2(0.0, 0.5), vec2(-0.433, 0.25), vec2(-0.433, -0.25), vec2(0.0, -0.5), vec2(0.433, -0.25)
};

void fragment() {
	float coverage = textureLod(group_texture, SCREEN_UV, 0.0).a;
	for (int i = 0; i < 12; i++) {
		coverage += textureLod(group_texture, SCREEN_UV + TAPS[i] * softness * SCREEN_PIXEL_SIZE, 0.0).a;
	}
	COLOR = vec4(0.0, 0.0, 0.0, opacity * coverage / 13.0);
}
