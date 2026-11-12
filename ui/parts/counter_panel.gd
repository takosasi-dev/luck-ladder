# 残り札の表示(FR-10・画面設計書 §2.4)。A〜K の 13 欄に、数字と残り枚数の点 0〜4 個を出す。
# 今の札の数字の欄に枠、0 枚の欄は薄く。今より大きい数字は緑、小さい数字は青(左が小さく右が大きい並びは崩さない)。
extends Control

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")

var counts: Array = []
var cur_rank := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update(rank_counts: Array, current_rank: int) -> void:
	counts = rank_counts
	cur_rank = current_rank
	queue_redraw()


func _draw() -> void:
	draw_style_box(Kit.box(T.PANEL_BG, T.R_PANEL, T.PANEL_EDGE, 1), Rect2(Vector2.ZERO, size))
	if counts.size() != 13:
		return
	var font := Kit.num()
	var pad := 8.0
	var w := (size.x - pad * 2) / 13.0
	var dot := 3.2 if w > 60 else 2.6
	for i in 13:
		var cell := Rect2(pad + i * w + 2, 5, w - 4, size.y - 10)
		var n: int = counts[i]
		var a := 0.28 if n == 0 else 1.0
		var col := T.TEXT
		if i + 1 > cur_rank:
			col = T.GOOD
		elif i + 1 < cur_rank:
			col = T.LOWER
		else:
			draw_style_box(Kit.box(Color(T.IVORY, 0.1), 10, T.IVORY, 2), cell)
		var base_y := cell.position.y + cell.size.y * 0.36 + font.get_ascent(T.FS_SMALL) / 2
		draw_string(font, Vector2(cell.position.x, base_y), S.RANKS[i], HORIZONTAL_ALIGNMENT_CENTER, cell.size.x, T.FS_SMALL, Color(col, a))
		var gap := dot * 2 + 2.5
		var x0 := cell.get_center().x - gap * (n - 1) / 2.0
		for k in n:
			draw_circle(Vector2(x0 + k * gap, cell.end.y - cell.size.y * 0.2), dot, T.BRASS, true, -1.0, true)
