// 札の光沢(D-15)。角丸の札の形の中だけを、斜めの光の帯が period 秒ごとに 1 回横切る。
// 加算合成で札の上に重ねる。見た目だけで、ゲームの進行には関わらない。
shader_type canvas_item;
render_mode blend_add;

uniform vec2 rect_size = vec2(200.0, 280.0);
uniform float radius = 14.0;
uniform float period = 2.4;
uniform float strength = 0.55;
uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.82, 1.0);

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(radius));
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float inside = clamp(0.5 - sd, 0.0, 1.0);
	float pos = fract(TIME / period) * 2.4 - 0.7;
	float d = (UV.x + UV.y) * 0.5 - pos;
	float band = smoothstep(0.10, 0.0, abs(d)) + 0.35 * smoothstep(0.22, 0.0, abs(d - 0.12));
	COLOR = vec4(tint.rgb * band * strength * inside, 1.0);
}
