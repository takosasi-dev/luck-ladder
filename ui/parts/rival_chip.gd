# 相手の札(対戦。FR-41・画面設計書 §2.4): 名前、ライフの点 4 個、得点、状態(「12枚」「終了」「完走」「切断」)。縦長は 2 行、横長は 1 行。
# 届いた値を見せるだけ。相手が確保する(得点が増える)と、縁が 0.4 秒光る。切断は 60% の濃さにする。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")

const GLOW_SEC := 0.4
# 縦長の 2 行と、横長の 1 行の字の大きさ(前は 2 行で 18 / 16 と、ゲームでいちばん小さかった)
const FS_TWO := 22
const FS_ONE := 20
const TWO_LINE_MIN_H := 56.0

var row := {}
var glow := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


# versus_state の行を渡す。
func set_row(next: Dictionary) -> void:
	if not row.is_empty() and next["score"] > row["score"] and not T.lite:
		create_tween().tween_method(_set_glow, 1.0, 0.0, GLOW_SEC)
	row = next.duplicate()
	modulate.a = 0.6 if row["gone"] and not row["final"] else 1.0
	queue_redraw()


func _set_glow(v: float) -> void:
	glow = v
	queue_redraw()


func status_text() -> String:
	if row.is_empty():
		return ""
	if row["final"]:
		return S.VS_CLEARED if row["ended"] == "clear" else S.VS_ENDED
	if row["gone"]:
		return S.VS_GONE
	return S.VS_ENDED if row["ended"] != "" else S.VS_DRAWS % row["draws"]


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(Kit.box(Color(T.BG_DEEP, 0.6), 12, T.BRASS_HI.lerp(Color(T.BRASS, 0.45), 1.0 - glow), 1 + int(glow * 2)), r)
	if row.is_empty():
		return
	var font := Kit.font(T.W_BODY)
	var half := size.y / 2
	var pad := 12.0
	var two_lines := size.y >= TWO_LINE_MIN_H
	var fs := FS_TWO if two_lines else FS_ONE
	# 右: 得点
	var score := ShareText.group(row["score"])
	var num := Kit.num(T.W_NUM)
	var score_w := num.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 4).x
	draw_string(num, Vector2(size.x - pad - score_w, half + (fs + 4) * 0.36), score, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 4, T.BRASS_HI)
	var left_w := size.x - pad * 3 - score_w
	var pips_w := B.LIVES_MAX * 14.0
	if two_lines:
		# 縦長(帯の高さ 62): 上に名前、下にライフの点と状態
		draw_string(font, Vector2(pad, half - 4), _fit(row["name"], font, fs, left_w), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, T.TEXT)
		_pips(Vector2(pad + 6, half + 13))
		draw_string(font, Vector2(pad + pips_w + 8, half + 20), _fit(status_text(), font, fs - 2, left_w - pips_w - 8), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, T.TEXT_DIM)
	else:
		# 横長(帯の高さ 44)は 1 行: ライフの点、名前(終わった人・切れた人は状態)。2 行では字が小さくなりすぎた
		_pips(Vector2(pad + 6, half))
		var gone_or_done: bool = row["final"] or row["gone"] or row["ended"] != ""
		var text: String = status_text() if gone_or_done else row["name"]
		draw_string(font, Vector2(pad + pips_w + 8, half + fs * 0.36), _fit(text, font, fs, left_w - pips_w - 8), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, T.TEXT_DIM if gone_or_done else T.TEXT)


func _pips(at: Vector2) -> void:
	for i in B.LIVES_MAX:
		var c := at + Vector2(i * 14, 0)
		if i < row["lives"]:
			draw_circle(c, 5, T.GOOD)
		else:
			draw_arc(c, 4, 0, TAU, 12, Color(T.TEXT_DIM, 0.7), 1.5)


# 幅に収まるまで後ろを削る(長い名前が得点に重ならないように)。
func _fit(text: String, font: Font, fs: int, max_w: float) -> String:
	var t := text
	while t.length() > 1 and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		t = t.left(-1)
	return t
