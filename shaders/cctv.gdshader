// A guard room monitor: shows a camera feed as grainy, slightly green CCTV with scanlines.
shader_type spatial;
render_mode unshaded;

uniform sampler2D feed : source_color, filter_linear;
uniform float highlight = 0.0;
uniform float seed = 0.0;
// 0..1: a burst of interference (something just walked onto this camera).
uniform float burst = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Interference tears the picture sideways in bands, and floods it with snow.
	float band = step(0.82, rand(vec2(floor(UV.y * 24.0), floor(TIME * 20.0))));
	vec2 uv = UV + vec2((rand(vec2(floor(UV.y * 60.0), TIME)) - 0.5) * 0.08 * burst * (0.3 + band), 0.0);
	vec3 c = texture(feed, uv).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 tinted = mix(vec3(grey), grey * vec3(0.78, 1.0, 0.82), 0.6);
	float scanline = 0.86 + 0.14 * sin(UV.y * 360.0 * 3.14159);
	float noise = (rand(UV * 300.0 + vec2(floor(TIME * 12.0) + seed)) - 0.5) * 0.1;
	vec2 d = UV - 0.5;
	float vignette = 1.0 - dot(d, d) * 1.3;
	vec3 col = (tinted * scanline + noise) * vignette;
	float snow = rand(UV * 500.0 + vec2(TIME * 37.0, seed));
	col = mix(col, vec3(snow), burst * 0.55);
	col += highlight * vec3(0.06, 0.1, 0.06);
	ALBEDO = clamp(col, 0.0, 1.0);
}
