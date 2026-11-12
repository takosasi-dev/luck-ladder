# 実績画面(FR-18・画面設計書 §3.3)。35 個の実績を、等級の丸・名前・条件・達成日つきで並べ、達成数を出す。
# 未達成は薄く、隠し実績は未達成の間は名前も条件も「???」。達成済みかどうかは、丸の中のチェックの形でも分かる。
extends "res://ui/screens/page.gd"

const Ach := preload("res://core/achievements.gd")


func _title() -> String:
	return S.BTN_ACH


func _fill() -> void:
	var done: Dictionary = app.save.data["achievements"]
	side.text = S.ACH_COUNT % [done.size(), Ach.DEFS.size()]
	var cols := 4 if landscape else 2
	var g := grid(cols)
	var cell_w := (inner_width() - 10 * (cols - 1)) / cols
	for id in Ach.ids():
		g.add_child(_cell(id, done.get(id, ""), cell_w))


func _cell(id: String, date: String, cell_w: float) -> Control:
	var got := date != ""
	var grade: Color = T.MEDAL[Ach.DEFS[id][0]]
	var masked: bool = Ach.is_hidden(id) and not got
	var p := PanelContainer.new()
	var style := Kit.box(Color(T.BG_DEEP, 0.5), 14, grade if got else Color(T.TEXT_DIM, 0.25), 2)
	style.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = Vector2(cell_w, 104)
	p.modulate.a = 1.0 if got else 0.6
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var medal := Control.new()
	medal.custom_minimum_size = Vector2(40, 40)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.draw.connect(func():
		var c := Vector2(20, 20)
		medal.draw_circle(c, 18, grade, false, 2.5, true)
		if got:
			medal.draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-3, 7), c + Vector2(10, -8)]), grade, 4, true))
	h.add_child(medal)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var lines := [[S.HIDDEN_TEXT if masked else S.ACHIEVEMENTS[id][0], T.W_NUM, T.TEXT], [S.HIDDEN_TEXT if masked else S.ACHIEVEMENTS[id][1], T.W_BODY, T.TEXT_DIM]]
	if got:
		lines.append([S.ACH_DATE % date, T.W_BODY, grade])
	for line in lines:
		var l := Kit.label(line[0], T.FS_SMALL, line[1], line[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(cell_w - 84, 0)
		v.add_child(l)
	h.add_child(v)
	p.add_child(h)
	return p
