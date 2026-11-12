# 連続の梯子(§9.1・画面設計書 §2.4)。10 段で、連続の数だけ下(縦長では左)から灯る。各段に倍率、
# 3・6・9 段目にライフ回復の印。11 連続以上は全段が灯り、数字で連続を出す。確保と外れで全段が消える。
extends Control

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")

const STEPS := 10

var vertical := true
var streak := 0
var _lit: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in STEPS:
		_lit.append(0.0)


# tw を渡すと動きを足す。from_top が真なら上の段から順に消す(確保のとき)。
func set_streak(n: int, tw: Tween = null, from_top: bool = false) -> void:
	streak = n
	for i in STEPS:
		var target := 1.0 if i < n else 0.0
		if tw == null:
			_lit[i] = target
		elif _lit[i] != target:
			var sec := T.t(T.LADDER_ON if target > 0.5 else T.LADDER_OFF)
			var tweener := tw.parallel().tween_method(_set_lit.bind(i), _lit[i], target, sec * (0.4 if from_top else 1.0))
			if from_top:
				tweener.set_delay(sec * 0.06 * (STEPS - 1 - i))
	queue_redraw()


func _set_lit(v: float, i: int) -> void:
	_lit[i] = v
	queue_redraw()


# 段 i(0 が ×1.1)の四角。
func step_rect(i: int) -> Rect2:
	if vertical:
		var top := 34.0
		var h := (size.y - top - 10) / STEPS
		return Rect2(26, size.y - 10 - (i + 1) * h + 4, size.x - 52, h - 8)
	var w := (size.x - 20) / STEPS
	return Rect2(10 + i * w + 3, 28, w - 6, size.y - 38)


func _draw() -> void:
	draw_style_box(Kit.box(T.PANEL_BG, T.R_PANEL, T.PANEL_EDGE, 1), Rect2(Vector2.ZERO, size))
	if vertical:
		for x in [14.0, size.x - 19.0]:
			var rail := Rect2(x, 34, 5, size.y - 44)
			Kit.draw_grad(self, rail, 2.5, Color(T.BRASS, 0.7), Color(T.BRASS_LO, 0.7))
	var font := Kit.num()
	for i in STEPS:
		var r := step_rect(i)
		var f := _lit[i]
		if f > 0.02:
			draw_style_box(_glow(f), r)
		Kit.draw_grad(self, r, 5, Color(T.BRASS, 0.16).lerp(T.BRASS_HI, f), Color(T.BRASS, 0.16).lerp(T.BRASS, f))
		var text := S.MULT % [(11 + i) / 10, (11 + i) % 10]
		var col := Color(T.TEXT, 0.72).lerp(T.RUNG_INK, f)
		var base_y := r.get_center().y + (font.get_ascent(T.FS_SMALL) - font.get_descent(T.FS_SMALL)) / 2
		draw_string(font, Vector2(r.position.x, base_y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, T.FS_SMALL, col)
		if (i + 1) % 3 == 0:
			var c := Vector2(size.x - 16.5, r.get_center().y) if vertical else Vector2(r.get_center().x, 15)
			draw_circle(c, 6, T.BG_DEEP.lerp(T.BRASS_HI, f), true, -1.0, true)
			draw_circle(c, 6, T.BRASS_HI, false, 2.0, true)
	if streak > STEPS:
		var jp := Kit.font(T.W_NUM)
		var label := S.STREAK % streak
		if vertical:
			draw_string(jp, Vector2(0, 26), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, T.FS_SMALL, T.BRASS_HI)
		else:
			draw_string(jp, Vector2(14, 23), label, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_SMALL, T.BRASS_HI)


func _glow(f: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_corner_radius_all(5)
	s.shadow_color = Color(T.BRASS_HI, 0.5 * f)
	s.shadow_size = 12
	return s
