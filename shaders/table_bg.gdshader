// 背景の布地(D-15・§9.12)。中央が明るく四隅へ暗くなる地に、布の細かいむらを重ねる。
// 動かない(時間を使わない)ので、スマホでも 1 回ぶんの塗りの重さで済む。
shader_type canvas_item;

uniform vec4 deep : source_color = vec4(0.055, 0.122, 0.110, 1.0);
uniform vec4 felt : source_color = vec4(0.090, 0.208, 0.184, 1.0);
uniform vec4 hi : source_color = vec4(0.122, 0.290, 0.255, 1.0);
uniform vec2 px_size = vec2(1280.0, 720.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// 中心を少し上(38%)に置いた楕円の距離。0 が中心、1 が四隅のあたり
	vec2 c = (UV - vec2(0.5, 0.38)) / vec2(0.62, 0.52);
	float d = length(c);
	vec3 col = mix(hi.rgb, felt.rgb, smoothstep(0.0, 0.45, d));
	col = mix(col, deep.rgb, smoothstep(0.45, 1.05, d));
	vec2 p = UV * px_size;
	float n = hash(floor(p / 2.0)) * 0.6 + hash(floor(p / 5.0) + 17.0) * 0.4;
	col += (n - 0.5) * 0.035;
	COLOR = vec4(col, 1.0);
}
