shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_lambert, specular_disabled;
// A face you can't bring into focus: the Principal's, smudged out like the notebook drawing.

uniform sampler2D face : source_color, filter_linear_mipmap;
// How far the patch wraps round the head (its local units), so it hugs the face.
uniform float wrap = 9.0;

void vertex() {
	VERTEX.z -= VERTEX.x * VERTEX.x / (2.0 * wrap) + VERTEX.y * VERTEX.y / (5.0 * wrap);
}

void fragment() {
	// It never settles: the smear drifts and doubles, slowly.
	vec2 drift = vec2(sin(TIME * 1.7 + UV.y * 9.0), cos(TIME * 1.3 + UV.x * 7.0)) * 0.012;
	vec4 a = texture(face, UV + drift);
	vec4 b = texture(face, UV - drift * 1.6 + vec2(0.018 * sin(TIME * 0.6), 0.0));
	vec4 c = mix(a, b, 0.5);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 1.0;
}
