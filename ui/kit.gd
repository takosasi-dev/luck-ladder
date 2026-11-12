# 画面の共通部品(フォント・ラベル・ボタン・箱・角丸のグラデーション描き)。色や大きさは ui/theme/tokens.gd から取る。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。数字・英字だけの表示には num() の Playfair Display を使う(INV-6)。
extends RefCounted

const T := preload("res://ui/theme/tokens.gd")
const FONT_JP := "res://assets/fonts/NotoSansJP-Variable.ttf"
const FONT_NUM := "res://assets/fonts/PlayfairDisplay-Variable.ttf"
const FONT_NUM_ITALIC := "res://assets/fonts/PlayfairDisplay-Italic-Variable.ttf"

static var _fonts := {}
static var _discs := {}


static func _font(path: String, weight: int, numeric: bool) -> Font:
	var key := "%s:%d" % [path, weight]
	if not _fonts.has(key):
		var ts := TextServerManager.get_primary_interface()
		var fv := FontVariation.new()
		fv.base_font = load(path)
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		if numeric:
			# 等幅の並び数字。数え上げで幅が動かないようにする(画面設計書 §1.2)
			fv.opentype_features = {ts.name_to_tag("tnum"): 1, ts.name_to_tag("lnum"): 1}
		_fonts[key] = fv
	return _fonts[key]


static func font(weight: int = T.W_BODY) -> Font:
	return _font(FONT_JP, weight, false)


static func num(weight: int = T.W_NUM) -> Font:
	return _font(FONT_NUM, weight, true)


static func num_italic(weight: int = T.W_BLACK) -> Font:
	return _font(FONT_NUM_ITALIC, weight, true)


static func label(text: String, size: int, weight: int = T.W_BODY, color: Color = T.TEXT) -> Label:
	return _label(text, size, font(weight), color)


static func num_label(text: String, size: int, color: Color = T.TEXT, weight: int = T.W_NUM) -> Label:
	return _label(text, size, num(weight), color)


static func _label(text: String, size: int, f: Font, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), width: int = 0, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if width > 0:
		s.border_color = border
		s.set_border_width_all(width)
	if shadow:
		s.shadow_color = T.SHADOW
		s.shadow_size = T.SHADOW_SIZE
		s.shadow_offset = Vector2(0, T.SHADOW_DROP)
	return s


static func panel(bg: Color = T.PANEL_BG, radius: int = T.R_PANEL, border: Color = T.PANEL_EDGE, width: int = 1) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box(bg, radius, border, width))
	return p


# メニューのボタン。kind: "green"(標準)/ "brass"(主役)/ "ghost"(静か)。押した瞬間に沈む(INV-13)。
static func button(text: String, size: int = T.FS_BODY, kind: String = "green") -> Button:
	var bg := T.BET_BOTTOM.lerp(T.BET_TOP, 0.5)
	var fg := T.TEXT
	var edge := Color(T.BRASS, 0.45)
	if kind == "brass":
		bg = T.BANK_BOTTOM.lerp(T.BANK_TOP, 0.6)
		fg = T.BANK_INK
		edge = T.BRASS_HI
	elif kind == "ghost":
		bg = Color(T.BG_DEEP, 0.5)
		edge = Color(T.TEXT_DIM, 0.35)
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(T.W_BODY if kind == "ghost" else T.W_NUM))
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.4))
	b.add_theme_stylebox_override("normal", box(bg, T.R_BUTTON, edge, 2, true))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.06), T.R_BUTTON, edge, 2, true))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.12), T.R_BUTTON, T.BRASS_HI, 2, true))
	b.add_theme_stylebox_override("disabled", box(bg.darkened(0.45), T.R_BUTTON, Color(edge, 0.2), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.button_down.connect(func(): squash(b, true))
	b.button_up.connect(func(): squash(b, false))
	return b


# 押すと 0.94 倍に沈み、離すと少し行き過ぎて戻る(§9.12)。
static func squash(c: Control, down: bool) -> void:
	c.pivot_offset = c.size / 2
	if down:
		c.scale = Vector2.ONE * T.PRESS_SCALE
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, T.PRESS_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


# 角丸の四角の輪郭(時計回り)。
static func rrect(r: Rect2, radius: float, segs: int = 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2)
	var centers := [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]
	for c in 4:
		for s in segs + 1:
			var a := PI + c * PI / 2 + PI / 2 * s / segs
			pts.append(centers[c] + Vector2(cos(a), sin(a)) * rad)
	return pts


# 角丸の四角を 2 色のグラデーションで塗る。dir は色が進む向き(下向きなら Vector2.DOWN)。
static func draw_grad(ci: CanvasItem, r: Rect2, radius: float, c0: Color, c1: Color, dir: Vector2 = Vector2.DOWN) -> void:
	var pts := rrect(r, radius)
	var cols := PackedColorArray()
	var span := absf(r.size.x * dir.x) + absf(r.size.y * dir.y)
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p - r.position).dot(dir) / span, 0, 1)))
	ci.draw_polygon(pts, cols)


static func draw_outline(ci: CanvasItem, r: Rect2, radius: float, color: Color, width: float) -> void:
	var pts := rrect(r, radius)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, width, true)


# 丸い画像(スライダーのつまみ用)。
static func disc(diameter: int, color: Color) -> Texture2D:
	var key := "%d:%s" % [diameter, color.to_html()]
	if not _discs.has(key):
		var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
		var c := Vector2(diameter, diameter) / 2
		for y in diameter:
			for x in diameter:
				var d := (Vector2(x + 0.5, y + 0.5) - c).length()
				img.set_pixel(x, y, Color(color, clampf(diameter / 2.0 - d, 0, 1)))
		_discs[key] = ImageTexture.create_from_image(img)
	return _discs[key]


# 数字 1 つと、その下の小さな名前を入れた箱(結果・記録)。値が日本語のときは numeric を偽にする。
static func stat(title: String, value: String, width: float = 190.0, numeric: bool = true) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(T.FELT_HI, 0.5), 12))
	p.custom_minimum_size = Vector2(width, 84)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.add_child(num_label(value, T.FS_BODY + 4, T.TEXT) if numeric else label(value, T.FS_BODY, T.W_NUM))
	v.add_child(label(title, T.FS_SMALL, T.W_BODY, T.TEXT_DIM))
	p.add_child(v)
	return p


# 選択できる文字欄(共有テキスト・保存データの書き出し)。スマホで画面のキーボードは出さない。
static func text_box(text: String, editable: bool, hint: String = "") -> TextEdit:
	var t := TextEdit.new()
	t.text = text
	t.editable = editable
	t.placeholder_text = hint
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	# 区切りの無い長い文字(保存データ)も、欄の幅で折り返す
	t.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	t.virtual_keyboard_enabled = editable
	t.context_menu_enabled = false
	t.add_theme_font_override("font", font(T.W_BODY))
	t.add_theme_font_size_override("font_size", T.FS_SMALL)
	t.add_theme_color_override("font_color", T.TEXT)
	t.add_theme_color_override("font_readonly_color", T.TEXT_DIM)
	t.add_theme_color_override("font_placeholder_color", Color(T.TEXT_DIM, 0.6))
	for s in ["normal", "focus", "read_only"]:
		var b := box(Color(0, 0, 0, 0.35), 10, Color(T.TEXT_DIM, 0.3), 1)
		b.set_content_margin_all(10)
		t.add_theme_stylebox_override(s, b)
	return t


# 3 桁ごとの区切りは core/share_text.gd の group を使う(数の書式を 2 か所に書かない)。
