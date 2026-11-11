# 画面の共通部品(太さ違いのフォント・ラベル・ボタン・箱)。色や大きさは ui/theme/tokens.gd から取る。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。
extends RefCounted

const T := preload("res://ui/theme/tokens.gd")
const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"

static var _fonts := {}


static func font(weight: int = T.W_BODY) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(FONT_PATH)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func label(text: String, size: int, weight: int = T.W_BODY, color: Color = T.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if width > 0:
		s.border_color = border
		s.set_border_width_all(width)
	return s


static func panel(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), width: int = 0) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box(bg, radius, border, width))
	return p


# 押せる物。当たりの大きさは呼ぶ側が 96 × 96 以上にする(INV-11)。
static func button(text: String, size: int, bg: Color, fg: Color = T.TEXT, border: Color = T.BRASS) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(T.W_NUM))
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	b.add_theme_stylebox_override("normal", box(bg, T.R_BUTTON, Color(border, 0.6), 2))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.08), T.R_BUTTON, border, 2))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.15), T.R_BUTTON, T.BRASS_HI, 3))
	b.add_theme_stylebox_override("disabled", box(bg.darkened(0.45), T.R_BUTTON, Color(border, 0.2), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size
