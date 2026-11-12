# 記録画面(FR-19・画面設計書 §3.4)。通算の値 10 個と、得点の上位 10 ランを出す。
# 上位ランが 0 件のときは「まだ記録がありません」。
extends "res://ui/screens/page.gd"

const ShareText := preload("res://core/share_text.gd")


func _title() -> String:
	return S.BTN_RECORDS


@warning_ignore("integer_division")
func _fill() -> void:
	var d: Dictionary = app.save.data
	var t: Dictionary = d["totals"]
	var tries: int = t["hits"] + t["misses"]
	var cols := 5 if landscape else 2
	var cell_w := (inner_width() - 10 * (cols - 1)) / cols
	var g := grid(cols)
	for item in [
		[S.REC_RUNS, ShareText.group(t["runs"])],
		[S.REC_CLEARS, ShareText.group(t["clears"])],
		[S.REC_BEST, ShareText.group(t["best_score"])],
		[S.REC_STREAK, str(t["best_streak"])],
		[S.REC_TOTAL, ShareText.group(t["total_score"])],
		[S.REC_HITS, S.RESULT_HITS_VALUE % [t["hits"], t["misses"]]],
		[S.REC_RATE, S.REC_RATE_VALUE % (t["hits"] * 100 / tries if tries > 0 else 0)],
		[S.REC_SAME, ShareText.group(t["same_hits"])],
		[S.REC_DAILY_DAYS, str(d["daily_days"])],
		[S.REC_DAILY_STREAK, str(d["daily_streak"]["count"])],
	]:
		g.add_child(Kit.stat(item[0], item[1], cell_w))
	section(S.REC_TOP)
	var tops: Array = d["top_runs"]
	if tops.is_empty():
		body.add_child(Kit.label(S.REC_EMPTY, T.FS_BODY, T.W_BODY, T.TEXT_DIM))
		return
	for i in tops.size():
		body.add_child(_row(i + 1, tops[i]))


func _row(rank: int, e: Dictionary) -> Control:
	var p := PanelContainer.new()
	var style := Kit.box(Color(T.BG_DEEP, 0.5), 12, Color(T.BRASS, 0.5 if rank == 1 else 0.15), 1)
	style.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", style)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var no := Kit.num_label(str(rank), T.FS_BODY, T.BRASS_HI)
	no.custom_minimum_size = Vector2(48, 44)
	h.add_child(no)
	var mode := Kit.label(S.REC_MODES.get(e["mode"], ""), T.FS_SMALL, T.W_BODY, T.TEXT)
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mode.custom_minimum_size = Vector2(130, 0)
	h.add_child(mode)
	var mark := Kit.label(S.REC_CLEAR_MARK if e["cleared"] else "", T.FS_SMALL, T.W_NUM, T.GOOD)
	mark.custom_minimum_size = Vector2(60, 0)
	h.add_child(mark)
	var draws := Kit.label(S.REC_DRAWS % e["draws"], T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	draws.custom_minimum_size = Vector2(80, 0)
	h.add_child(draws)
	var score := Kit.num_label(ShareText.group(e["score"]), T.FS_BODY + 2, T.TEXT)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(score)
	var date := Kit.num_label(e["date"], T.FS_SMALL, T.TEXT_DIM, T.W_BODY)
	date.custom_minimum_size = Vector2(150, 0)
	h.add_child(date)
	p.add_child(h)
	return p
