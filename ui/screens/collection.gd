# コレクション画面(FR-20・画面設計書 §3.5)。札の裏面 8 種とテーブル 5 種を見本つきで並べ、解放済みの物を選べる。
# 未解放の物は薄くして条件を出し、押しても選べない。選んだ瞬間に、背景と見本が新しい物に替わる。
extends "res://ui/screens/page.gd"

const Progress := preload("res://core/progress.gd")
const CardBack := preload("res://ui/parts/card_back.gd")


func _title() -> String:
	return S.BTN_COLLECTION


func _fill() -> void:
	var cols := 8 if landscape else 4
	var cell_w := (inner_width() - 10 * (cols - 1)) / cols
	section(S.COL_BACKS)
	var g := grid(cols)
	for id in Progress.BACKS:
		g.add_child(_cell(id, "card_back", S.CARD_BACKS[id], Progress.BACKS[id], cell_w))
	section(S.COL_TABLES)
	cols = 5 if landscape else 3
	cell_w = (inner_width() - 10 * (cols - 1)) / cols
	g = grid(cols)
	for id in Progress.TABLES:
		g.add_child(_cell(id, "table", S.TABLES[id], Progress.TABLES[id], cell_w))


# 解放の条件の文(初めから持っている物は空)。
func _condition(cond: Array) -> String:
	match cond[0]:
		"ach":
			return S.COL_COND % S.ACHIEVEMENTS[cond[1]][0]
		"title":
			return S.COL_COND % (S.COND_TITLE % S.TITLES[cond[1] - 1])
		"count":
			return S.COL_COND % (S.COND_COUNT % cond[1])
	return ""


func _cell(id: String, key: String, title: String, cond: Array, cell_w: float) -> Control:
	var d: Dictionary = app.save.data
	var open: bool = Progress.is_unlocked(id, d["achievements"], d["totals"]["total_score"])
	var chosen: bool = d["settings"][key] == id
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(cell_w, 220)
	var style := Kit.box(Color(T.BG_DEEP, 0.5), 14, T.BRASS_HI if chosen else Color(T.TEXT_DIM, 0.2), 3 if chosen else 1)
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, style)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.modulate.a = 1.0 if open else 0.5
	var view := Control.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.custom_minimum_size = Vector2(cell_w, 104)
	if key == "card_back":
		view.draw.connect(func(): CardBack.draw(view, Rect2((cell_w - 72) / 2, 2, 72, 100), id))
	else:
		view.draw.connect(func():
			var c: Array = T.TABLES[id]
			var r := Rect2(12, 14, cell_w - 24, 76)
			Kit.draw_grad(view, r, 10, Color(c[2]), Color(c[0]))
			Kit.draw_outline(view, r.grow(-1), 10, Color(c[3]), 2))
	v.add_child(view)
	v.add_child(Kit.label(title, T.FS_SMALL, T.W_NUM, T.TEXT))
	var note := Kit.label("" if open else _condition(cond), T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	note.custom_minimum_size = Vector2(cell_w - 12, 60)
	note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(note)
	b.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func():
		if app.save.select(key, id):
			# 選んだ瞬間に、背景と見本を新しい物に替える
			app.apply_settings()
			refill.call_deferred()
		elif not open:
			# 未解放: 条件の文が 1 回弾むだけで、選べない
			note.pivot_offset = note.size / 2
			var tw := note.create_tween()
			tw.tween_property(note, "scale", Vector2.ONE * 1.12, 0.08)
			tw.tween_property(note, "scale", Vector2.ONE, 0.16))
	return b
