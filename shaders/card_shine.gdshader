// 札の光沢(D-15)。角丸の札の形の中だけを、斜めの光の帯が 1 回横切る。
// progress を 0 → 1 に動かすと左上から右下へ通り、負の値では何も描かない。加算合成で札の上に重ねる。
shader_type canvas_item;
render_mode blend_add;

uniform vec2 rect_size = vec2(214.0, 300.0);
uniform float radius = 14.0;
uniform float progress = -1.0;
uniform float strength = 0.6;
uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.82, 1.0);

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(radius));
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float inside = clamp(0.5 - sd, 0.0, 1.0);
	float pos = progress * 1.5 - 0.25;
	float d = (UV.x + UV.y) * 0.5 - pos;
	float band = smoothstep(0.10, 0.0, abs(d)) + 0.35 * smoothstep(0.22, 0.0, abs(d - 0.12));
	COLOR = vec4(tint.rgb * band * strength * inside * step(0.0, progress), 1.0);
}
