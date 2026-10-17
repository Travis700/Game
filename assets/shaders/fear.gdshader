shader_type canvas_item;
// The look of the picture: always a little film grain, a soft vignette and a touch of colour
// fringing towards the edges, like a cheap camera in the dark. And with low nerve, on top: the
// edges close in, the colour drains away and the grain thickens.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// 0: steady nerves (no effect) .. 1: about to break.
uniform float fear : hint_range(0.0, 1.0) = 0.0;
// 0: a clean picture .. 1: the full camera look.
uniform float film : hint_range(0.0, 1.0) = 1.0;

float grain(vec2 uv, float t) {
	return fract(sin(dot(uv * vec2(1280.0, 720.0) + floor(t * 24.0) * 61.0, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 offset = SCREEN_UV - 0.5;
	vec2 fringe = offset * dot(offset, offset) * 0.012 * film;
	vec3 colour = vec3(texture(screen, SCREEN_UV + fringe).r, texture(screen, SCREEN_UV).g,
			texture(screen, SCREEN_UV - fringe).b);
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(colour, vec3(grey), fear * 0.65);
	vec2 from_centre = offset * vec2(1.6, 1.0);
	colour *= mix(1.0, smoothstep(1.25, 0.3, length(from_centre)), 0.4 * film);
	float edge = smoothstep(0.95 - fear * 0.45, 0.25, length(from_centre));
	colour *= mix(1.0, edge, fear * 0.9);
	// Grain shows most in the shadows, as on a real sensor.
	float noise = grain(SCREEN_UV, TIME) - 0.5;
	colour += noise * (0.035 * film * (1.0 - grey * 0.6) + 0.12 * fear);
	COLOR = vec4(colour, 1.0);
}
