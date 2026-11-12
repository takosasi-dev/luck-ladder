# HIGH・LOW・同じ・確保のボタン(§9.1・画面設計書 §2.4)。名前、形(上向き・下向きの矢印、横の二重線)、点を出す。
# 押した瞬間に 0.94 倍に沈む(INV-13)。押せないときは暗くして、押しても何も起きない(E-1・E-5)。
extends Control

signal pressed

const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")

var kind := "high"  # high / low / same / bank
var title := ""
var quote := ""
var quote_is_number := true
var tier := 0
var enabled := true


func setup(kind_value: String, title_text: String) -> void:
	kind = kind_value
	title = title_text


# tier: 点の色の段(0 = 文字色、1 = brass、2 = brass_hi と光)。number が偽なら点の代わりの文言(「なし」)。
func set_state(quote_text: String, number: bool, tier_value: int, can_press: bool) -> void:
	if quote == quote_text and quote_is_number == number and tier == tier_value and enabled == can_press:
		return
	quote = quote_text
	quote_is_number = number
	tier = tier_value
	enabled = can_press
	queue_redraw()


# キーボードで押されたときの手応え(沈んで戻る)。
func flash() -> void:
	Kit.squash(self, true)
	Kit.squash(self, false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and enabled:
			Kit.squash(self, true)
			pressed.emit()
		elif not event.pressed:
			Kit.squash(self, false)
		accept_event()


func _dim(c: Color) -> Color:
	if enabled:
		return c
	var g := c.get_luminance()
	return Color(lerpf(c.r, g, 0.8) * 0.55, lerpf(c.g, g, 0.8) * 0.55, lerpf(c.b, g, 0.8) * 0.55, c.a)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var top := T.BET_TOP
	var bottom := T.BET_BOTTOM
	var edge := Color(T.BRASS, 0.5)
	var ink := T.TEXT
	if kind == "same":
		top = T.SAME_TOP
		bottom = T.SAME_BOTTOM
		edge = Color(T.IVORY, 0.55)
	elif kind == "bank":
		top = T.BANK_TOP
		bottom = T.BANK_BOTTOM
		edge = T.BRASS_HI
		ink = T.BANK_INK
	draw_style_box(Kit.box(_dim(bottom), T.R_BUTTON, Color(0, 0, 0, 0), 0, true), r)
	Kit.draw_grad(self, r, T.R_BUTTON, _dim(top), _dim(bottom))
	Kit.draw_outline(self, r.grow(-1), T.R_BUTTON, _dim(edge), 2)
	var q_col := ink
	if kind != "bank" and quote_is_number:
		q_col = [T.TEXT, T.BRASS, T.BRASS_HI][tier]
	var name_font := Kit.font(T.W_BLACK)
	var q_font := Kit.num() if quote_is_number else Kit.font(T.W_NUM)
	if kind == "high" or kind == "low":
		var cy := size.y / 2
		var ax := 30.0
		var up := -1.0 if kind == "high" else 1.0
		draw_polyline(PackedVector2Array([Vector2(ax, cy - 7 * up), Vector2(ax + 13, cy + 7 * up), Vector2(ax + 26, cy - 7 * up)]), _dim(ink), 5, true)
		_text(name_font, title, Vector2(ax + 40, cy), T.FS_BUTTON, _dim(ink), HORIZONTAL_ALIGNMENT_LEFT, -1)
		_quote(q_font, Vector2(0, cy), T.FS_QUOTE, _dim(q_col), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24)
	else:
		var y1 := size.y * 0.34
		var name_w := name_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, T.FS_BUTTON - 4).x
		var x0 := (size.x - name_w) / 2
		if kind == "same":
			x0 += 17
			for dy in [-5.0, 5.0]:
				draw_line(Vector2(x0 - 34, y1 + dy), Vector2(x0 - 12, y1 + dy), _dim(ink), 4, true)
		_text(name_font, title, Vector2(x0, y1), T.FS_BUTTON - 4, _dim(ink), HORIZONTAL_ALIGNMENT_LEFT, -1)
		_quote(q_font, Vector2(0, size.y * 0.68), T.FS_QUOTE_SMALL, _dim(q_col), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _quote(f: Font, at: Vector2, fs: int, col: Color, align: HorizontalAlignment, width: float) -> void:
	if tier == 2 and enabled and quote_is_number and kind != "bank":
		var base := at.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2
		draw_string_outline(f, Vector2(at.x, base), quote, align, width, fs, 10, Color(T.BRASS_HI, 0.16))
	_text(f, quote, at, fs, col, align, width)


# at.y を字の縦の中心にして描く。
func _text(f: Font, text: String, at: Vector2, fs: int, col: Color, align: HorizontalAlignment, width: float) -> void:
	var base := at.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2
	draw_string(f, Vector2(at.x, base), text, align, width, fs, col)
