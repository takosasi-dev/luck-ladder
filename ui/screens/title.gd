# Phase 0 のタイトル画面。題名と版、縦横の切り替えの見本(箱 3 つ)、card_shine を掛けた札 1 枚、
# §9.2・§9.3 の固定値を照らした診断表示を出す。見本と診断表示は Phase 4 で消す。
extends Control

const S := preload("res://core/strings.gd")
const Rng := preload("res://core/rng.gd")
const Deck := preload("res://core/deck.gd")
const Fx := preload("res://tests/fixtures.gd")

const C_TEXT := Color("#F2EDE1")
const C_DIM := Color("#9FB3AC")
const C_BRASS := Color("#C9A45C")
const C_IVORY := Color("#F5EFE0")
const C_INK := Color("#1B1B1F")
const C_GOOD := Color("#5FD3A0")
const C_BAD := Color("#E2574C")
const BOX_COLORS := [Color("#B8323A"), Color("#2F6FB0"), Color("#C9A45C")]
const CARD_SIZE := Vector2(200, 280)

var title_label: Label
var sub_label: Label
var version_label: Label
var mode_label: Label
var boxes: Array[PanelContainer] = []
var card: Panel
var shine: ColorRect
var diag: Label
var diag_body := ""
var all_ok := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label = _label(S.TITLE, 96, 800, C_TEXT)
	sub_label = _label(S.SUBTITLE, 36, 500, C_BRASS)
	version_label = _label(S.VERSION_PREFIX + str(ProjectSettings.get_setting("application/config/version")), 22, 500, C_DIM)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_label = _label("", 28, 700, C_TEXT)
	for l in [title_label, sub_label, version_label, mode_label]:
		add_child(l)
	for i in 3:
		var b := PanelContainer.new()
		b.add_theme_stylebox_override("panel", _box(BOX_COLORS[i], 18))
		var l := _label(S.DEMO_BOXES[i], 28, 700, C_TEXT)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
		add_child(b)
		boxes.append(b)
	card = Panel.new()
	card.add_theme_stylebox_override("panel", _box(C_IVORY, 14))
	card.size = CARD_SIZE
	add_child(card)
	var rank := _label("A", 120, 800, C_INK)
	rank.size = CARD_SIZE
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(rank)
	shine = ColorRect.new()
	shine.size = CARD_SIZE
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/card_shine.gdshader")
	m.set_shader_parameter("rect_size", CARD_SIZE)
	shine.material = m
	card.add_child(shine)
	diag = _label("", 22, 500, C_DIM)
	diag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(diag)
	diag_body = _fixed_value_report()
	diag.add_theme_color_override("font_color", C_GOOD if all_ok else C_BAD)
	print(diag_body)


func relayout(landscape: bool, window_size: Vector2i) -> void:
	if title_label == null:
		return
	mode_label.text = (S.DEMO_LANDSCAPE + " 1280×720") if landscape else (S.DEMO_PORTRAIT + " 720×1280")
	diag.text = "%s  %s %d×%d\n%s" % [S.DIAG_HEAD, S.DIAG_WINDOW, window_size.x, window_size.y, diag_body]
	if landscape:
		_place(title_label, 0, 30, 1280, 120)
		_place(sub_label, 0, 150, 1280, 50)
		_place(mode_label, 40, 200, 640, 40)
		for i in 3:
			_place(boxes[i], 40 + i * 220, 250, 200, 220)
		card.position = Vector2(900, 210)
		_place(diag, 24, 490, 1000, 220)
		_place(version_label, 1080, 670, 180, 36)
	else:
		_place(title_label, 0, 60, 720, 130)
		_place(sub_label, 0, 190, 720, 50)
		card.position = Vector2(260, 280)
		_place(mode_label, 40, 590, 640, 40)
		for i in 3:
			_place(boxes[i], 40, 640 + i * 126, 640, 110)
		_place(diag, 24, 1030, 680, 220)
		_place(version_label, 520, 1230, 180, 36)


# §9.2・§9.3 の固定値を、この端末で計算し直して照らす(§8.1 の Windows・Linux・Web の比較用)。
func _fixed_value_report() -> String:
	var lines := PackedStringArray()
	var fnv_ok := 0
	for k in Fx.FNV:
		if Rng.fnv1a(k) == Fx.FNV[k]:
			fnv_ok += 1
	var r := Rng.new(1)
	var xs := []
	for i in 5:
		xs.append(r.next())
	var xs_ok: bool = xs == Fx.XORSHIFT_SEED1
	all_ok = fnv_ok == Fx.FNV.size() and xs_ok
	lines.append("FNV-1a %d/%d  xorshift32 %s" % [fnv_ok, Fx.FNV.size(), S.DIAG_OK if xs_ok else S.DIAG_NG])
	for row in Fx.DECKS:
		var d := Deck.shuffled(row[0])
		var head := []
		for i in 10:
			head.append(d[i])
		var sum := Deck.checksum(d)
		var ok: bool = head == row[1] and sum == row[3]
		all_ok = all_ok and ok
		lines.append("%s  %d  %s  %s" % [row[0], sum, str(head.slice(0, 4)), S.DIAG_OK if ok else S.DIAG_NG])
	return "\n".join(lines)


func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)


func _label(text: String, size: int, weight: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/NotoSansJP-Variable.ttf")
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 6)
	return s
