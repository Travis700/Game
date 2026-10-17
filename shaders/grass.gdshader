// The long grass outside (see Grass): blades dark at the root and paler at the tip, bending in
// a slow wind. UV.y is how far up the blade a vertex is; COLOR varies the shade blade by blade.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 root_color : source_color = vec3(0.10, 0.14, 0.05);
uniform vec3 tip_color : source_color = vec3(0.42, 0.50, 0.22);
uniform float wind = 0.09;

void vertex() {
	float up = UV.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 1.3 + world.x * 0.21 + world.z * 0.13) * 0.6 + 0.4;
	float flutter = sin(TIME * 3.1 + world.x * 1.7 + world.z * 1.3);
	vec2 bend = vec2(0.8, 0.45) * (gust + flutter * 0.25) * wind * up * up;
	// The bend is in world space; turn it into the tuft's own (each tuft is spun round Y).
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(bend.x, 0.0, bend.y);
	// Lit mostly from above, like a lawn, rather than as thin flat cards.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	ALBEDO = mix(root_color, tip_color, UV.y) * COLOR.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	// Darker down among the blades.
	AO = mix(0.35, 1.0, UV.y);
	AO_LIGHT_AFFECT = 0.6;
	BACKLIGHT = vec3(0.12, 0.16, 0.05);
}
