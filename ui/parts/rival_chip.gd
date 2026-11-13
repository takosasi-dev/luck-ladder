# 相手の札(対戦。FR-41・画面設計書 §2.4): 名前、ライフの点 4 個、得点、状態(「12枚」「終了」「完走」「切断」)。
# 届いた値を見せるだけ。相手が確保する(得点が増える)と、縁が 0.4 秒光る。切断は 60% の濃さにする。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")

const GLOW_SEC := 0.4
const FS := 18

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
	# 左: 上に名前、下にライフの点と状態。右: 得点
	var score := ShareText.group(row["score"])
	var num := Kit.num(T.W_NUM)
	var score_w := num.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, FS + 6).x
	draw_string(num, Vector2(size.x - pad - score_w, half + (FS + 6) * 0.36), score, HORIZONTAL_ALIGNMENT_LEFT, -1, FS + 6, T.BRASS_HI)
	var left_w := size.x - pad * 3 - score_w
	draw_string(font, Vector2(pad, half - 3), row["name"], HORIZONTAL_ALIGNMENT_LEFT, left_w, FS, T.TEXT)
	for i in B.LIVES_MAX:
		var c := Vector2(pad + 6 + i * 14, half + 11)
		if i < row["lives"]:
			draw_circle(c, 5, T.GOOD)
		else:
			draw_arc(c, 4, 0, TAU, 12, Color(T.TEXT_DIM, 0.7), 1.5)
	draw_string(font, Vector2(pad + B.LIVES_MAX * 14 + 8, half + 17), status_text(), HORIZONTAL_ALIGNMENT_LEFT, left_w - B.LIVES_MAX * 14 - 8, FS - 2, T.TEXT_DIM)
