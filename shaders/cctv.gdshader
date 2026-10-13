// A guard room monitor: shows a camera feed as grainy, slightly green CCTV with scanlines.
shader_type spatial;
render_mode unshaded;

uniform sampler2D feed : source_color, filter_linear;
uniform float highlight = 0.0;
uniform float seed = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(feed, UV).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 tinted = mix(vec3(grey), grey * vec3(0.78, 1.0, 0.82), 0.6);
	float scanline = 0.86 + 0.14 * sin(UV.y * 360.0 * 3.14159);
	float noise = (rand(UV * 300.0 + vec2(floor(TIME * 12.0) + seed)) - 0.5) * 0.1;
	vec2 d = UV - 0.5;
	float vignette = 1.0 - dot(d, d) * 1.3;
	vec3 col = (tinted * scanline + noise) * vignette;
	col += highlight * vec3(0.06, 0.1, 0.06);
	ALBEDO = clamp(col, 0.0, 1.0);
}
