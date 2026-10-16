shader_type canvas_item;
// Low nerve, on screen: the edges close in, the colour drains away and grain creeps in.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// 0: steady nerves (no effect) .. 1: about to break.
uniform float fear : hint_range(0.0, 1.0) = 0.0;

float grain(vec2 uv, float t) {
	return fract(sin(dot(uv * vec2(1280.0, 720.0) + t * 61.0, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 colour = texture(screen, SCREEN_UV).rgb;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(colour, vec3(grey), fear * 0.65);
	vec2 from_centre = (SCREEN_UV - 0.5) * vec2(1.6, 1.0);
	float edge = smoothstep(0.95 - fear * 0.45, 0.25, length(from_centre));
	colour *= mix(1.0, edge, fear * 0.9);
	colour += (grain(SCREEN_UV, TIME) - 0.5) * 0.12 * fear;
	COLOR = vec4(colour, 1.0);
}
