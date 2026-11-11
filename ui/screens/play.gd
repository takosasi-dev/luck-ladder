# プレイ画面(FR-4〜FR-12・FR-16・FR-23・FR-24)。Phase 2 の仮の見た目: 色と箱と字だけで、演出は札の入れ替えだけ。
# 当たり外れ・点・ライフは core/run_state.gd が決め、ここは結果を見せるだけにする(INV-1)。
extends Control

signal finished(info: Dictionary)
signal to_title

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Layout := preload("res://ui/layout/play_layout.gd")
const Deck := preload("res://core/deck.gd")
const DayIndex := preload("res://core/day_index.gd")
const ShareText := preload("res://core/share_text.gd")

const SIDE_KEYS := {KEY_UP: "H", KEY_W: "H", KEY_DOWN: "L", KEY_S: "L", KEY_RIGHT: "S", KEY_D: "S", KEY_SPACE: "B"}
const BTN_SIDE := {"high": "H", "low": "L", "same": "S", "bank": "B"}
const END_WAIT_SEC := 0.8

var save
var st
var stats
var mode := "run"
var date := ""
var day_no := 0
var counter_on := true
var landscape := true

var n := {}
var ladder_steps: Array[Panel] = []
var ladder_labels: Array[Label] = []
var ladder_rings: Array[Panel] = []
var streak_label: Label
var counter_cells: Array[Panel] = []
var counter_ranks: Array[Label] = []
var counter_counts: Array[Label] = []
var card_rank: Label
var hl_frames := {}
var pause_layer: Control

var busy := false
var tween: Tween
var last_input_frame := -1
var run_ach := []
var tut_shown := -1
var hl_targets: Array = []
var end_result := {}
var done := false


func setup(save_store, state, run_stats, mode_value: String, run_date: String, tutorial: bool) -> void:
	save = save_store
	st = state
	stats = run_stats
	mode = mode_value
	date = run_date
	var p := DayIndex.parse(run_date)
	day_no = DayIndex.day_no(p[0], p[1], p[2]) if not p.is_empty() else 0
	counter_on = bool(save.data["settings"]["counter"])
	tut_shown = 0 if tutorial else -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	# 1 手以上打ったランを「つづきから」で開いたら、1・2 つ目は済んだものとして 3 つ目を待つ
	if tut_shown == 0 and st.actions != "":
		tut_shown = 2
	if tut_shown == 0:
		_show_tutorial(S.TUT_1, ["card", "high", "low"])
		tut_shown = 1
	_refresh()


# ---- 組み立て ----

func _build() -> void:
	var pause := Kit.button(S.BTN_PAUSE, T.FS_SMALL, T.FELT_HI)
	pause.pressed.connect(_toggle_pause)
	_add("pause", pause)
	_add("score", Kit.label("", T.FS_BODY + 8, T.W_NUM, T.BRASS_HI))
	_add("mode", Kit.label(S.MODE_RUN, T.FS_BODY, T.W_BODY, T.TEXT_DIM))
	_add("lives", Kit.label("", T.FS_BODY, T.W_NUM, T.TEXT))
	_add("ladder", Kit.panel(Color(T.BG_DEEP, 0.55), T.R_PANEL, Color(T.BRASS, 0.22), 2))
	streak_label = Kit.label("", T.FS_SMALL, T.W_NUM, T.BRASS_HI)
	n["ladder"].add_child(streak_label)
	for i in 10:
		var step := Kit.panel(T.FELT_HI, 6)
		var l := Kit.label(S.MULT % [(11 + i) / 10, (11 + i) % 10], T.FS_SMALL, T.W_NUM, T.TEXT_DIM)
		step.add_child(l)
		n["ladder"].add_child(step)
		ladder_steps.append(step)
		ladder_labels.append(l)
		if (i + 1) % 3 == 0:
			var ring := Kit.panel(Color(0, 0, 0, 0), 8, T.GOOD, 3)
			n["ladder"].add_child(ring)
			ladder_rings.append(ring)
	var tut := Kit.label("", T.FS_BODY, T.W_NUM, T.INK)
	tut.add_theme_stylebox_override("normal", Kit.box(T.IVORY, T.R_BUTTON))
	tut.visible = false
	_add("tutorial", tut)
	_add("deck", Kit.panel(T.BACK_B01, T.R_CARD, T.IVORY, 5))
	_add("deck_label", Kit.label("", T.FS_SMALL, T.W_BODY, T.TEXT_DIM))
	var card := Kit.panel(T.IVORY, T.R_CARD)
	card_rank = Kit.label("", 120, 800, T.INK)
	card.add_child(card_rank)
	_add("card", card)
	_add("status", Kit.label("", T.FS_BODY, T.W_NUM, T.TEXT))
	var pot := Kit.label("", T.FS_POT, T.W_NUM, T.BRASS_HI)
	pot.add_theme_stylebox_override("normal", Kit.box(Color(T.BG_DEEP, 0.55), T.R_PANEL))
	_add("pot", pot)
	_add("counter", Kit.panel(Color(T.BG_DEEP, 0.55), T.R_PANEL))
	for i in 13:
		var cell := Kit.panel(Color(0, 0, 0, 0), 8)
		var rl := Kit.label(S.RANKS[i], T.FS_SMALL, T.W_NUM, T.TEXT)
		var cl := Kit.label("", T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
		cell.add_child(rl)
		cell.add_child(cl)
		n["counter"].add_child(cell)
		counter_cells.append(cell)
		counter_ranks.append(rl)
		counter_counts.append(cl)
	_add("high", Kit.button("", T.FS_QUOTE, T.FELT_HI))
	_add("same", Kit.button("", T.FS_QUOTE - 6, T.SAME_BG, T.TEXT, T.IVORY))
	_add("bank", Kit.button("", T.FS_QUOTE - 6, T.BRASS, T.BANK_INK, T.BRASS_HI))
	_add("low", Kit.button("", T.FS_QUOTE, T.FELT_HI))
	for key in BTN_SIDE:
		var side: String = BTN_SIDE[key]
		n[key].pressed.connect(func(): _act(side))
	for key in ["card", "high", "low", "pot", "bank"]:
		var f := Kit.panel(Color(0, 0, 0, 0), T.R_BUTTON, T.BRASS_HI, 4)
		f.visible = false
		add_child(f)
		hl_frames[key] = f
	_build_pause()


func _add(key: String, c: Control) -> void:
	n[key] = c
	add_child(c)


func _build_pause() -> void:
	pause_layer = Control.new()
	pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.visible = false
	var scrim := ColorRect.new()
	scrim.color = T.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(scrim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 20)
	box.add_child(Kit.label(S.PAUSED + "  " + S.MODE_RUN, T.FS_BODY + 8, T.W_NUM))
	var resume := Kit.button(S.BTN_RESUME, T.FS_BODY, T.FELT_HI)
	resume.custom_minimum_size = Vector2(480, 100)
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var title := Kit.button(S.BTN_TO_TITLE, T.FS_BODY, T.FELT_HI)
	title.custom_minimum_size = Vector2(480, 100)
	title.pressed.connect(func(): to_title.emit())
	box.add_child(title)
	box.add_child(Kit.label(S.PAUSE_NOTE, T.FS_SMALL, T.W_BODY, T.TEXT_DIM))
	pause_layer.add_child(box)
	add_child(pause_layer)


# ---- 配置(FR-22・E-13) ----

func relayout(is_landscape: bool) -> void:
	_skip_anim()
	landscape = is_landscape
	var r := Layout.rects(landscape)
	for key in n:
		n[key].visible = r.has(key) and (key != "tutorial" or not n[key].text.is_empty()) and (key != "counter" or counter_on)
		if r.has(key):
			Kit.place(n[key], r[key])
	var card: Control = n["card"]
	card.pivot_offset = card.size / 2
	card_rank.size = card.size
	card_rank.add_theme_font_size_override("font_size", int(card.size.y * 0.4))
	_layout_ladder(r["ladder"].size)
	_layout_counter(r["counter"].size)
	_place_highlights()
	Kit.place(pause_layer, Rect2(Vector2.ZERO, Layout.size(landscape)))
	_refresh()


func _layout_ladder(sz: Vector2) -> void:
	var ri := 0
	if landscape:
		Kit.place(streak_label, Rect2(0, 6, sz.x, 40))
		var h := (sz.y - 52) / 10.0
		for i in 10:
			var y := sz.y - 6 - (i + 1) * h
			Kit.place(ladder_steps[i], Rect2(10, y + 3, sz.x - 44, h - 6))
			ladder_labels[i].size = ladder_steps[i].size
			if (i + 1) % 3 == 0:
				Kit.place(ladder_rings[ri], Rect2(sz.x - 28, y + h / 2 - 8, 16, 16))
				ri += 1
	else:
		Kit.place(streak_label, Rect2(6, 0, 104, sz.y))
		var w := (sz.x - 116) / 10.0
		for i in 10:
			var x := 112 + i * w
			Kit.place(ladder_steps[i], Rect2(x + 2, 24, w - 4, sz.y - 30))
			ladder_labels[i].size = ladder_steps[i].size
			if (i + 1) % 3 == 0:
				Kit.place(ladder_rings[ri], Rect2(x + w / 2 - 8, 4, 16, 16))
				ri += 1


func _layout_counter(sz: Vector2) -> void:
	var w := (sz.x - 8) / 13.0
	for i in 13:
		Kit.place(counter_cells[i], Rect2(4 + i * w, 4, w - 2, sz.y - 8))
		var half := (sz.y - 8) / 2.0
		Kit.place(counter_ranks[i], Rect2(0, 0, w - 2, half))
		Kit.place(counter_counts[i], Rect2(0, half, w - 2, half))


# ---- 表示の更新(結果を見せるだけ) ----

func _refresh() -> void:
	n["score"].text = S.SCORE % ShareText.group(st.score)
	n["lives"].text = S.LIVES + S.LIFE_ON.repeat(st.lives) + S.LIFE_OFF.repeat(maxi(0, 4 - st.lives))
	n["deck_label"].text = S.DECK_LEFT % st.remaining()
	n["deck"].visible = st.remaining() > 0
	n["pot"].text = S.POT % ShareText.group(st.pot)
	var card: int = st.current_card()
	card_rank.text = S.RANKS[Deck.rank(card) - 1]
	card_rank.add_theme_color_override("font_color", T.SUIT_RED if Deck.suit(card) in [1, 2] else T.INK)
	streak_label.text = S.STREAK % st.streak
	for i in 10:
		var lit: bool = st.streak > i
		ladder_steps[i].add_theme_stylebox_override("panel", Kit.box(T.BRASS if lit else T.FELT_HI, 6))
		ladder_labels[i].add_theme_color_override("font_color", T.BANK_INK if lit else T.TEXT_DIM)
	var rc: Array = st.rank_counts()
	var cur_rank: int = Deck.rank(card)
	for i in 13:
		var cur: bool = i + 1 == cur_rank
		counter_cells[i].add_theme_stylebox_override("panel", Kit.box(Color(T.IVORY, 0.12) if cur else Color(0, 0, 0, 0), 8, T.IVORY, 2 if cur else 0))
		counter_counts[i].text = str(rc[i])
		var a := 0.28 if rc[i] == 0 else 1.0
		counter_ranks[i].modulate.a = a
		counter_counts[i].modulate.a = a
	var ended: bool = st.ended != ""
	for key in ["high", "low", "same"]:
		var side: String = BTN_SIDE[key]
		var q: int = st.quote(side)
		var name: String = {"high": S.BTN_HIGH, "low": S.BTN_LOW, "same": S.BTN_SAME}[key]
		var b: Button = n[key]
		b.text = name + "\n" + (S.QUOTE % ShareText.group(q) if q > 0 else S.QUOTE_NONE)
		b.disabled = q == 0 or ended
		var base: int = st.base_quote(side)
		var col := T.TEXT if base < 300 else T.BRASS if base < 1000 else T.BRASS_HI
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, col)
	var bank: Button = n["bank"]
	bank.text = S.BTN_BANK + "\n" + (ShareText.group(st.pot) if st.pot > 0 else S.BANK_EMPTY)
	bank.disabled = st.pot == 0 or ended


func _show_tutorial(text: String, targets: Array) -> void:
	n["tutorial"].text = text
	n["tutorial"].visible = text != ""
	hl_targets = targets
	_place_highlights()


func _place_highlights() -> void:
	var r := Layout.rects(landscape)
	for key in hl_frames:
		var on: bool = key in hl_targets
		hl_frames[key].visible = on
		if on:
			Kit.place(hl_frames[key], r[key].grow(6))


# ---- 入力 ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif SIDE_KEYS.has(event.keycode):
			_act(SIDE_KEYS[event.keycode])
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and busy:
		# FR-11: 演出中に画面を押すと最後の状態まで飛ばす
		_skip_anim()


func _act(side: String) -> void:
	if done or pause_layer.visible:
		return
	# E-4: 同じフレームに届いた 2 つ目からは捨てる
	var f := Engine.get_process_frames()
	if f == last_input_frame:
		return
	last_input_frame = f
	# E-3: 演出中の 1 回目は演出を飛ばすだけ
	if busy:
		_skip_anim()
		return
	stats.note_counter(counter_on)
	var res: Dictionary
	if side == "B":
		res = st.bank()
		if res["result"] == "invalid":
			return
		stats.on_bank(res, st)
	else:
		res = st.guess(side)
		if res["result"] == "invalid":
			return
		stats.on_guess(res, st)
	if st.ended == "":
		save.save_current(mode, st.seed_text, date, st.actions, stats.counter_shown)
		run_ach.append_array(save.judge_move(stats, date))
	else:
		_finish_run()
	_advance_tutorial()
	if side == "B":
		n["status"].text = S.ST_BANKED % ShareText.group(res["amount"])
		n["status"].add_theme_color_override("font_color", T.BRASS_HI)
		_refresh()
		return
	_animate_flip(res)


func _status_for(res: Dictionary) -> void:
	var l: Label = n["status"]
	if res["result"] == "hit":
		l.text = (S.ST_SAME if res["side"] == "S" else S.ST_HIT) % ShareText.group(res["gain"])
		if res["life_up"]:
			l.text += S.ST_LIFE_UP
		l.add_theme_color_override("font_color", T.GOOD)
	else:
		l.text = S.ST_MISS
		l.add_theme_color_override("font_color", T.BAD)
	if res["ended"] == "clear":
		l.text = S.ST_CLEAR
		l.add_theme_color_override("font_color", T.BRASS_HI)


# 仮の演出: 札の横幅を 0 まで縮めて表を替え、元の幅に戻す(§9.12 のめくりを簡単にした物)。
func _animate_flip(res: Dictionary) -> void:
	busy = true
	var card: Control = n["card"]
	tween = create_tween()
	tween.tween_property(card, "scale:x", 0.0, T.SWAP_SEC / 2)
	tween.tween_callback(func():
		_status_for(res)
		_refresh())
	tween.tween_property(card, "scale:x", 1.0, T.SWAP_SEC / 2)
	tween.tween_callback(_on_anim_done)


func _skip_anim() -> void:
	if busy and tween != null and tween.is_valid():
		tween.custom_step(10.0)


func _on_anim_done() -> void:
	busy = false
	n["card"].scale.x = 1.0
	if st.ended != "" and not end_result.is_empty():
		get_tree().create_timer(END_WAIT_SEC).timeout.connect(_emit_finished)


func _emit_finished() -> void:
	if done:
		return
	done = true
	finished.emit({"state": st, "stats": stats, "date": date, "mode": mode, "result": end_result, "new_achievements": run_ach + end_result["new_achievements"]})


func _finish_run() -> void:
	end_result = save.finish_run(stats, date, day_no)
	if tut_shown >= 0:
		save.set_tutorial_done(true)
		tut_shown = -1
		_show_tutorial("", [])


# FR-12: 1 手目の前に 1 つ目、2 手目の前に 2 つ目、その後ポットが 1 以上になった最初の手に 3 つ目。
func _advance_tutorial() -> void:
	match tut_shown:
		1:
			_show_tutorial(S.TUT_2, ["pot"])
			tut_shown = 2
		2:
			if st.pot >= 1:
				_show_tutorial(S.TUT_3, ["bank"])
				tut_shown = 3
				save.set_tutorial_done(true)
			else:
				_show_tutorial("", [])
		3:
			_show_tutorial("", [])
			tut_shown = -1


func _toggle_pause() -> void:
	if done:
		return
	_skip_anim()
	pause_layer.visible = not pause_layer.visible
	move_child(pause_layer, get_child_count() - 1)
