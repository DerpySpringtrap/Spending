shader_type canvas_item;
// Death dissolve for placeholder (Polygon2D) bodies. Set on the body root with
// children using use_parent_material. Noise is sampled in canvas space so all
// pieces of a body dissolve as one surface.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.75, 0.35, 1.0);
uniform float edge_width = 0.07;
uniform float noise_scale = 0.045;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float n = value_noise(world_pos * noise_scale) * 0.7 + value_noise(world_pos * noise_scale * 3.0) * 0.3;
	if (n < progress) {
		discard;
	}
	if (progress > 0.0 && n < progress + edge_width) {
		COLOR = vec4(edge_color.rgb, COLOR.a);
	}
}
