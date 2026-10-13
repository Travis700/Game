// The full-screen camera view: the same CCTV look as the monitors, drawn over the whole screen.
shader_type canvas_item;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 tinted = mix(vec3(grey), grey * vec3(0.78, 1.0, 0.82), 0.6);
	float scanline = 0.9 + 0.1 * sin(UV.y * 720.0 * 3.14159);
	float noise = (rand(UV * 600.0 + vec2(floor(TIME * 12.0))) - 0.5) * 0.08;
	vec2 d = UV - 0.5;
	float vignette = 1.0 - dot(d, d) * 0.9;
	COLOR = vec4(clamp((tinted * scanline + noise) * vignette, 0.0, 1.0), 1.0);
}
