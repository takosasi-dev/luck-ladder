# 札 1 枚(§9.1・D-13・画面設計書 §2.4)。表は生成りの地に数字とマーク、J・Q・K は大きな字と二重の飾り枠。
# 裏は選んだ裏面の模様。当たり外れの縁の光と、光沢(card_shine、控えめのときは白い帯)を持つ。
extends Control

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Deck := preload("res://core/deck.gd")

const SUIT_FILES := ["spade", "heart", "diamond", "club"]

static var _suits: Array = []
static var _base: StyleBoxFlat

var card := -1
var face_up := true
var edge := Color(0, 0, 0, 0)
var _shine: ColorRect
var _band_clip: Control
var _band: Polygon2D


static func suit_texture(s: int) -> Texture2D:
	if _suits.is_empty():
		for n in SUIT_FILES:
			var tex: Texture2D = load("res://assets/suits/%s.svg" % n)
			var img := tex.get_image() if tex != null else null
			if img == null:
				_suits.append(tex)
				continue
			# 小さく描いても荒れないよう、縮小用の画像を作っておく
			img.generate_mipmaps()
			_suits.append(ImageTexture.create_from_image(img))
	return _suits[s]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_shine = ColorRect.new()
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/card_shine.gdshader")
	_shine.material = m
	_shine.visible = false
	add_child(_shine)
	_band_clip = Control.new()
	_band_clip.clip_contents = true
	_band_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band = Polygon2D.new()
	_band.color = Color(1, 1, 1, 0.5)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_band.material = add
	_band.visible = false
	_band_clip.add_child(_band)
	add_child(_band_clip)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size / 2
	_shine.size = size
	_band_clip.size = size
	_shine.material.set_shader_parameter("rect_size", size)
	_band.polygon = PackedVector2Array([Vector2(size.x * 0.25, 0), Vector2(size.x * 0.5, 0), Vector2(size.x * 0.25, size.y), Vector2(0, size.y)])
	queue_redraw()


func show_card(c: int, up: bool = true) -> void:
	card = c
	face_up = up
	queue_redraw()


func set_edge(c: Color) -> void:
	edge = c
	queue_redraw()


# 光沢を 1 回走らせる。tw に動きを足すので、呼ぶ側の飛ばし(FR-11)にそのまま乗る。
func shine(tw: Tween, sec: float) -> void:
	if T.lite:
		_band.visible = true
		tw.parallel().tween_property(_band, "position:x", size.x, sec).from(-size.x * 0.5)
		tw.parallel().tween_callback(func(): _band.visible = false).set_delay(sec)
		return
	_shine.visible = true
	tw.parallel().tween_method(func(v: float): _shine.material.set_shader_parameter("progress", v), 0.0, 1.0, sec)
	tw.parallel().tween_callback(func(): _shine.visible = false).set_delay(sec)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _base == null:
		_base = Kit.box(T.CARD_BOTTOM, T.R_CARD, Color(0, 0, 0, 0), 0, true)
	draw_style_box(_base, r)
	if face_up and card >= 0:
		_draw_face(r)
	else:
		draw_back(self, r)
	if edge.a > 0.0:
		var glow := StyleBoxFlat.new()
		glow.draw_center = false
		glow.set_corner_radius_all(T.R_CARD)
		glow.set_border_width_all(3)
		glow.border_color = edge
		glow.shadow_color = Color(edge, edge.a * 0.7)
		glow.shadow_size = 24
		draw_style_box(glow, r)


func _draw_face(r: Rect2) -> void:
	Kit.draw_grad(self, r, T.R_CARD, T.CARD_TOP, T.CARD_BOTTOM, Vector2(0.45, 1.0))
	var rank := Deck.rank(card)
	var suit := Deck.suit(card)
	var col := T.SUIT_RED if suit in [1, 2] else T.INK
	var text: String = S.RANKS[rank - 1]
	var tex := suit_texture(suit)
	for turn in 2:
		draw_set_transform(size if turn == 1 else Vector2.ZERO, PI if turn == 1 else 0.0)
		_draw_corner(text, tex, col)
	draw_set_transform(Vector2.ZERO)
	var c := size / 2
	if rank >= 11:
		for f in [[0.18, 0.16, 2.0, 8.0], [0.21, 0.185, 1.0, 6.0]]:
			var fr := Rect2(size.x * f[0], size.y * f[1], size.x * (1 - 2 * f[0]), size.y * (1 - 2 * f[1]))
			Kit.draw_outline(self, fr, f[3], Color(col, 0.35), f[2])
		var font := Kit.num_italic()
		var fs := int(size.y * 0.42)
		var base_y := c.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2
		draw_string(font, Vector2(0, base_y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, col)
	elif tex != null:
		var s := size.x * 0.42
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), false, col)


func _draw_corner(text: String, tex: Texture2D, col: Color) -> void:
	var font := Kit.num(800)
	var fs := int(size.y * 0.15)
	var col_w := size.y * 0.24
	var cx := size.x * 0.08 + size.y * 0.07
	var top := size.y * 0.05
	draw_string(font, Vector2(cx - col_w / 2, top + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_CENTER, col_w, fs, col)
	if tex != null:
		var s := size.y * 0.09
		draw_texture_rect(tex, Rect2(cx - s / 2, top + font.get_height(fs) * 0.92, s, s), false, col)


# 裏面 B-01「紺の格子」。ほかの裏面は Phase 4 のコレクションで足す。
static func draw_back(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(Kit.box(T.IVORY, T.R_CARD), r)
	var inner := r.grow(-5)
	ci.draw_style_box(Kit.box(T.BACK_B01_BG, T.R_CARD - 4), inner)
	var a := inner.grow(-3)
	var line := Color(T.BACK_B01_LINE, 0.55)
	var step := 10.5
	var c := a.position.x + a.position.y
	while c < a.end.x + a.end.y:
		var xa := maxf(a.position.x, c - a.end.y)
		var xb := minf(a.end.x, c - a.position.y)
		if xa < xb:
			ci.draw_line(Vector2(xa, c - xa), Vector2(xb, c - xb), line, 1.5, true)
		c += step
	c = a.position.x - a.end.y
	while c < a.end.x - a.position.y:
		var xa := maxf(a.position.x, c + a.position.y)
		var xb := minf(a.end.x, c + a.end.y)
		if xa < xb:
			ci.draw_line(Vector2(xa, xa - c), Vector2(xb, xb - c), line, 1.5, true)
		c += step
