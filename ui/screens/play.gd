# プレイ画面(FR-4〜FR-12・FR-16・FR-23・FR-24・FR-27・§9.12)。部品を並べ、1 手の結果を演出に変える。
# 当たり外れ・点・ライフは core/run_state.gd が決め、ここは結果を見せるだけにする(INV-1)。
extends Control

signal finished(info: Dictionary)
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Layout := preload("res://ui/layout/play_layout.gd")
const Deck := preload("res://core/deck.gd")
const DayIndex := preload("res://core/day_index.gd")
const ShareText := preload("res://core/share_text.gd")
const RunStats := preload("res://core/run_stats.gd")
const Card := preload("res://ui/parts/card.gd")
const DeckPile := preload("res://ui/parts/deck_pile.gd")
const BetButton := preload("res://ui/parts/bet_button.gd")
const Ladder := preload("res://ui/parts/ladder.gd")
const CounterPanel := preload("res://ui/parts/counter_panel.gd")
const LifePips := preload("res://ui/parts/life_pips.gd")
const VolumeRow := preload("res://ui/parts/volume_row.gd")
const Toast := preload("res://ui/parts/toast.gd")
const Fx := preload("res://ui/fx/fx.gd")
const VersusState := preload("res://core/versus_state.gd")
const RivalChip := preload("res://ui/parts/rival_chip.gd")

# 対戦の秒読み(§9.15: 3 秒)
const COUNTDOWN_MS := 3000

const SIDE_KEYS := {KEY_UP: "H", KEY_W: "H", KEY_DOWN: "L", KEY_S: "L", KEY_RIGHT: "S", KEY_D: "S", KEY_SPACE: "B"}
const SIDE_BTN := {"H": "high", "L": "low", "S": "same", "B": "bank"}
const BTN_TITLES := {"high": S.BTN_HIGH, "low": S.BTN_LOW, "same": S.BTN_SAME, "bank": S.BTN_BANK}
const TUT_TARGETS := [[], ["card", "high", "low"], ["pot"], ["bank"]]
const TUT_TEXTS := ["", S.TUT_1, S.TUT_2, S.TUT_3]

var app
var save
var st
var stats
var mode := "run"
var date := ""
var day_no := 0
var counter_on := true
var landscape := true
var view := Rect2(0, 0, 1280, 720)

var pause_face: Panel
var pause_hit: Button
var score_label: Label
var score_num: Label
var mode_label: Label
var pips
var ladder
var deck
var deck_label: Label
var card
var incoming
var pot_label: Label
var pot_num: Label
var counter
var btn := {}
var fx
var tut: Label
var hl_frames := {}
var toast
var fade: ColorRect
var pause_layer: Control

var busy := false
var flip_tw: Tween
var post_tw: Tween
var hl_tw: Tween
var last_input_frame := -1
# この時刻(ms)までは、手を受けない(Kit.press_guard_ms)
var quiet_until := 0
# めくりが終わってから出す実績の通知(札より先に出すと、当たり外れが分かってしまう)
var pending_toasts := []
var run_ach := []
var tut_step := -1
var end_result := {}
var done := false
var shown := {"score": 0.0, "pot": 0.0}
var swipe_from := Vector2.INF
# 対戦のときだけ(FR-41〜FR-45)。vs は部屋(net/versus_session.gd)
var vs
var time_label: Label
var rival_box: Control
var rivals := {}
var count_label: Label
var wait_label: Label
# 対戦の途中の自分の順位(「いま 2 位」)
var rank_label: Label
# 「同じ」の当たりで、前の札を一瞬重ねて見せるために覚えておく
var prev_card := -1
var vs_start_ms := 0
# 秒読みの間と、自分の final を送った後は、手を受けない
var vs_locked := false
var vs_final := false
var vs_soon := false
var vs_count := 0


func setup(app_ref, state, run_stats, mode_value: String, run_date: String, tutorial: bool) -> void:
	app = app_ref
	save = app.save
	st = state
	stats = run_stats
	mode = mode_value
	date = run_date
	var p := DayIndex.parse(run_date)
	day_no = DayIndex.day_no(p[0], p[1], p[2]) if not p.is_empty() else 0
	# 1 手以上打ったランを「つづきから」で開いたら、1・2 つ目は済んだものとして 3 つ目を待つ
	tut_step = -1 if not tutorial else 2 if st.actions != "" else 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	if mode == "versus":
		_build_versus()
	if tut_step == 0:
		tut_step = 1
	_snap()
	_refresh()
	# 前の画面のボタンを二度押しした 2 回目が、ここのボタンに入らないようにする
	quiet_until = Time.get_ticks_msec() + Kit.press_guard_ms


func _mode_text() -> String:
	return S.MODE_DAILY % day_no if mode == "daily" else S.MODE_RUN


# ---- 組み立て ----

func _build() -> void:
	pause_face = Kit.panel(Color(T.BG_DEEP, 0.5), T.R_BUTTON, Color(T.BRASS, 0.45), 2)
	pause_face.add_child(Kit.label(S.BTN_PAUSE, T.FS_SMALL, T.W_NUM))
	add_child(pause_face)
	# 見た目より広い当たり(96 × 96 以上。INV-11)
	pause_hit = Button.new()
	pause_hit.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		pause_hit.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	pause_hit.pressed.connect(_toggle_pause)
	add_child(pause_hit)
	score_label = Kit.label(S.SCORE_LABEL, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(score_label)
	score_num = Kit.num_label("0", T.FS_SCORE, T.TEXT)
	score_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(score_num)
	mode_label = Kit.label(_mode_text(), T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(mode_label)
	pips = LifePips.new()
	add_child(pips)
	ladder = Ladder.new()
	add_child(ladder)
	deck = DeckPile.new()
	add_child(deck)
	deck_label = Kit.label("", T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(deck_label)
	card = Card.new()
	add_child(card)
	incoming = Card.new()
	incoming.visible = false
	add_child(incoming)
	pot_label = Kit.label(S.POT_LABEL, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(pot_label)
	pot_num = Kit.num_label("0", T.FS_POT, T.BRASS_HI)
	add_child(pot_num)
	counter = CounterPanel.new()
	add_child(counter)
	for key in ["high", "same", "bank", "low"]:
		var b := BetButton.new()
		b.setup(key, BTN_TITLES[key])
		var side: String = SIDE_BTN.find_key(key)
		b.pressed.connect(func(): _act(side, false))
		add_child(b)
		btn[key] = b
	for key in ["card", "high", "low", "pot", "bank"]:
		var f := Kit.panel(Color(0, 0, 0, 0), T.R_BUTTON, T.BRASS_HI, 4)
		f.visible = false
		add_child(f)
		hl_frames[key] = f
	fx = Fx.new()
	add_child(fx)
	tut = Kit.label("", T.FS_SMALL, T.W_NUM, T.INK)
	tut.add_theme_stylebox_override("normal", Kit.box(T.IVORY, 24, Color(0, 0, 0, 0), 0, true))
	tut.visible = false
	add_child(tut)
	toast = Toast.new()
	toast.shown.connect(func(): app.sfx.play("toast"))
	add_child(toast)
	fade = ColorRect.new()
	fade.color = Color(T.BG_DEEP, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)


# ---- 配置(FR-22・E-13) ----

func relayout(is_landscape: bool, view_rect: Rect2) -> void:
	_finish_all()
	landscape = is_landscape
	view = view_rect
	size = Layout.size(landscape)
	counter_on = bool(save.data["settings"]["counter"])
	var r := Layout.rects(landscape, mode == "versus")
	var o := Layout.over(landscape, mode == "versus")
	Kit.place(pause_face, r["pause"])
	pause_face.get_child(0).size = r["pause"].size
	Kit.place(pause_hit, o["pause_hit"])
	var sc: Rect2 = r["score"]
	Kit.place(score_label, Rect2(sc.position, Vector2(64, sc.size.y)))
	Kit.place(score_num, Rect2(sc.position + Vector2(72, 0), sc.size - Vector2(72, 0)))
	mode_label.visible = r.has("mode") and mode != "versus"
	if r.has("mode"):
		Kit.place(mode_label, r["mode"])
	Kit.place(pips, r["lives"])
	ladder.vertical = landscape
	Kit.place(ladder, r["ladder"])
	Kit.place(deck, r["deck"])
	Kit.place(deck_label, r["deck_label"])
	Kit.place(card, r["card"])
	card.scale = Vector2.ONE
	card.rotation = 0.0
	var pot: Rect2 = r["pot"]
	Kit.place(pot_label, Rect2(pot.position, Vector2(pot.size.x, 34)))
	Kit.place(pot_num, Rect2(pot.position + Vector2(0, 30), pot.size - Vector2(0, 30)))
	pot_num.pivot_offset = pot_num.size / 2
	counter.visible = counter_on
	Kit.place(counter, r["counter"])
	for key in btn:
		Kit.place(btn[key], r[key])
	Kit.place(fx, Rect2(Vector2.ZERO, size))
	Kit.place(toast, o["toast"])
	Kit.place(fade, view)
	if mode == "versus":
		_layout_versus(r)
	_show_tutorial()
	if pause_layer != null:
		_open_pause()
	_refresh()


# ---- 表示の更新(結果を見せるだけ) ----

# 数え上げ・梯子・ライフを、動きなしで今の値にそろえる。
func _snap() -> void:
	_set_shown(st.score, "score")
	_set_shown(st.pot, "pot")
	ladder.set_streak(st.streak)
	pips.set_lives(st.lives)


func _set_shown(v: float, which: String) -> void:
	shown[which] = v
	(score_num if which == "score" else pot_num).text = ShareText.group(roundi(v))


func _refresh() -> void:
	var ended: bool = st.ended != ""
	deck.set_left(st.remaining())
	deck_label.text = S.DECK_LEFT % st.remaining()
	if not busy:
		card.show_card(st.current_card(), true)
	counter.update(st.rank_counts(), Deck.rank(st.current_card()))
	for side in ["H", "L", "S"]:
		var q: int = st.quote(side)
		var base: int = st.base_quote(side)
		var tier := 0 if base < T.QUOTE_TIER_1 else 1 if base < T.QUOTE_TIER_2 else 2
		btn[SIDE_BTN[side]].set_state(S.QUOTE % ShareText.group(q) if q > 0 else S.QUOTE_NONE, q > 0, tier, q > 0 and not ended)
	btn["bank"].set_state(ShareText.group(st.pot) if st.pot > 0 else S.BANK_EMPTY, st.pot > 0, 0, st.pot > 0 and not ended)
	if not ended:
		app.bgm.play("bgm_last" if st.lives == 1 else "bgm_play")


# FR-12: 手ほどきの 1 行を、指している部品の近くに出し、部品の縁を 2 回明滅させる。
func _show_tutorial() -> void:
	var on := tut_step >= 1 and tut_step <= 3
	tut.visible = on
	if hl_tw != null and hl_tw.is_valid():
		hl_tw.kill()
	for key in hl_frames:
		hl_frames[key].visible = false
	if not on:
		return
	tut.text = TUT_TEXTS[tut_step]
	Kit.place(tut, Layout.over(landscape, mode == "versus")["tut%d" % tut_step])
	var r := Layout.rects(landscape, mode == "versus")
	hl_tw = create_tween()
	for key in TUT_TARGETS[tut_step]:
		var f: Panel = hl_frames[key]
		Kit.place(f, r[key].grow(6))
		f.visible = true
		f.modulate.a = 0.0
		for i in 2:
			hl_tw.parallel().tween_property(f, "modulate:a", 1.0, 0.3).set_delay(i * 0.6)
			hl_tw.parallel().tween_property(f, "modulate:a", 0.0, 0.3).set_delay(i * 0.6 + 0.3)


# 1 手目の前に 1 つ目、2 手目の前に 2 つ目、その後ポットが 1 以上になった最初の手に 3 つ目。
func _advance_tutorial() -> void:
	match tut_step:
		1:
			tut_step = 2
		2:
			if st.pot >= 1:
				tut_step = 3
				save.set_tutorial_done(true)
			else:
				tut.visible = false
				return
		3:
			tut_step = -1
		_:
			return
	_show_tutorial()


# ---- 入力 ----

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif SIDE_KEYS.has(event.keycode):
			_act(SIDE_KEYS[event.keycode], true)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and busy:
		# FR-11: 演出中に画面を押すと最後の状態まで飛ばす
		_skip_flip()


# FR-27: 今の札の上で、上へはじくと HIGH、下へはじくと LOW。
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		# めくりの途中に押したら、演出を飛ばすだけ(E-3)。はじいても、次の手にはしない
		swipe_from = event.position if not busy and card.get_global_rect().has_point(event.position) else Vector2.INF
	elif swipe_from != Vector2.INF:
		var dy: float = event.position.y - swipe_from.y
		swipe_from = Vector2.INF
		if absf(dy) >= B.SWIPE_MIN:
			_act("H" if dy < 0 else "L", true)


func _act(side: String, show_press: bool) -> void:
	if done or pause_layer != null or app.overlay != null or vs_locked or vs_final:
		return
	# E-4: 同じフレームに届いた 2 つ目からは捨てる
	var f := Engine.get_process_frames()
	if f == last_input_frame:
		return
	last_input_frame = f
	# E-3: 演出中の 1 回目は演出を飛ばすだけ
	if busy:
		_skip_flip()
		return
	if st.ended != "" or Time.get_ticks_msec() < quiet_until:
		return
	var res: Dictionary = st.apply(side)
	if res["result"] == "invalid":
		return
	quiet_until = Time.get_ticks_msec() + Kit.press_guard_ms
	_finish_post()
	stats.note_counter(counter_on)
	app.sfx.play("tap")
	if show_press:
		btn[SIDE_BTN[side]].flash()
	if side == "B":
		stats.on_bank(res, st)
	else:
		stats.on_guess(res, st)
	if st.ended == "":
		# FR-17: 条件を満たした手の直後に達成にして、通知を出す
		var fresh: Array = save.judge_move(stats, date)
		run_ach.append_array(fresh)
		pending_toasts.append_array(fresh)
		# 対戦は途中の保存をしない(D-29)。この手で取った実績も入れるので、判定の後に書く
		if mode != "versus":
			save.save_current(mode, st.seed_text, date, st.actions, stats.counter_shown, run_ach)
	elif mode != "versus":
		_finish_run()
	if mode == "versus":
		# FR-41: 自分の手のたびに、自分の状態を送る。ランが終わったら final
		if st.ended != "":
			_versus_final(false)
		else:
			vs.report(VersusState.row_from_run(st, stats, 0, vs.round_no, false))
	if side == "B":
		_after_move()
		_animate_bank(res)
	else:
		_animate_flip(res)


# 実績の通知と手ほどきの次の行。確保はすぐ、予想は札がめくれてから(先に出すと、当たり外れが分かる)。
func _after_move() -> void:
	for id in pending_toasts:
		toast.push(S.ACHIEVEMENTS[id][0])
	pending_toasts = []
	_advance_tutorial()


func _finish_run() -> void:
	end_result = save.finish_run(stats, date, day_no)
	if tut_step >= 0:
		save.set_tutorial_done(true)
		tut_step = -1
		_show_tutorial()


# ---- 演出(§9.12) ----

func _animate_flip(res: Dictionary) -> void:
	busy = true
	prev_card = card.card
	_hide_ghost()
	app.sfx.play("flip")
	deck.set_left(st.remaining())
	deck_label.text = S.DECK_LEFT % st.remaining()
	var r := Layout.rects(landscape, mode == "versus")
	flip_tw = create_tween()
	if T.lite:
		# FR-29: 控えめでは 0.12 秒の入れ替え
		flip_tw.tween_property(card, "scale:x", 0.0, T.t(T.LITE_SWAP) / 2)
		flip_tw.tween_callback(card.show_card.bind(res["card"], true))
		flip_tw.tween_property(card, "scale:x", 1.0, T.t(T.LITE_SWAP) / 2)
	else:
		# 山札から次の札が今の札の位置へ滑る → 横幅を 0 まで縮めて表に替え、元の幅に戻す
		incoming.show_card(-1, false)
		Kit.place(incoming, r["deck"])
		incoming.visible = true
		flip_tw.tween_property(incoming, "position", r["card"].position, T.t(T.DEAL)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flip_tw.parallel().tween_property(incoming, "size", r["card"].size, T.t(T.DEAL))
		var arrive := func() -> void:
			incoming.visible = false
			card.show_card(res["card"], false)
		flip_tw.tween_callback(arrive)
		flip_tw.tween_property(card, "scale:x", 0.0, T.t(T.FLIP) / 2).set_ease(Tween.EASE_IN)
		flip_tw.tween_callback(card.show_card.bind(res["card"], true))
		flip_tw.tween_property(card, "scale:x", 1.0, T.t(T.FLIP) / 2).set_ease(Tween.EASE_OUT)
	flip_tw.tween_callback(_on_flip_done.bind(res))


func _hide_ghost() -> void:
	incoming.visible = false
	incoming.modulate.a = 1.0


func _skip_flip() -> void:
	if busy and flip_tw != null and flip_tw.is_valid():
		flip_tw.custom_step(100.0)


func _finish_post() -> void:
	if post_tw != null and post_tw.is_valid() and post_tw.is_running():
		post_tw.custom_step(100.0)


func _finish_all() -> void:
	_skip_flip()
	_finish_post()


func _new_post() -> Tween:
	post_tw = create_tween()
	post_tw.tween_interval(0.01)
	return post_tw


func _count(which: String, target: int, sec: float, delay: float) -> void:
	post_tw.parallel().tween_method(_set_shown.bind(which), shown[which], float(target), sec).set_delay(delay)


func _edge(col: Color) -> void:
	card.set_edge(col)
	post_tw.parallel().tween_method(func(a: float): card.set_edge(Color(col, a)), 1.0, 0.0, T.t(T.EDGE_GLOW) * 2)


# 当たり外れが分かる時点。ここから後の動きの間も、次の入力を受ける。
func _on_flip_done(res: Dictionary) -> void:
	busy = false
	incoming.visible = false
	card.scale.x = 1.0
	_refresh()
	_after_move()
	var r := Layout.rects(landscape, mode == "versus")
	var callout_at: Rect2 = Layout.over(landscape, mode == "versus")["callout"]
	var card_c: Vector2 = r["card"].get_center()
	var pot_c := pot_num.position + pot_num.size / 2
	var tw := _new_post()
	if res["result"] == "hit":
		var same: bool = res["side"] == "S"
		_edge(T.GOOD)
		fx.fly_text(tw, S.QUOTE % ShareText.group(res["gain"]), card_c, pot_c, T.t(T.FLY), T.GOOD, T.FS_QUOTE)
		_count("pot", st.pot, T.t(T.COUNT_UP), T.t(T.FLY) * 0.7)
		ladder.set_streak(st.streak, tw)
		if same or RunStats.is_longshot(res["n"], res["w"]):
			card.shine(tw, T.t(T.SHINE))
			fx.burst(card_c, T.SPARKS_HIT, T.t(T.SHINE))
			fx.callout(S.CALL_SAME if same else S.CALL_LONGSHOT, T.BRASS_HI, callout_at)
		if same and prev_card >= 0 and not T.lite:
			# §9.12: 前の札と今の札が一瞬重なって見える(前の札を左上にずらして重ね、0.6 秒で消す)
			incoming.show_card(prev_card, true)
			Kit.place(incoming, Rect2(r["card"].position + Vector2(-28, -16), r["card"].size))
			incoming.modulate.a = 0.9
			incoming.visible = true
			tw.parallel().tween_property(incoming, "modulate:a", 0.0, T.t(0.6))
			tw.parallel().tween_callback(_hide_ghost).set_delay(T.t(0.6))
		app.sfx.play("same" if same else "hit_1" if st.streak <= 3 else "hit_2" if st.streak <= 7 else "hit_3")
		if res["life_up"]:
			pips.set_lives(st.lives, tw)
			fx.callout(S.CALL_LIFE, T.GOOD, callout_at)
			app.sfx.play("life_up")
	else:
		_edge(T.BAD)
		fx.shake(tw, card, T.t(T.SHAKE))
		fx.shake(tw, self, T.t(T.SHAKE))
		if res["pot_lost"] > 0:
			fx.fly_text(tw, ShareText.group(res["pot_lost"]), pot_c, pot_c + Vector2(16, 46), T.t(T.POT_BREAK), T.BAD, T.FS_POT)
		_set_shown(0, "pot")
		pips.set_lives(st.lives, tw)
		ladder.set_streak(0, tw)
		app.sfx.play("miss")
	if st.ended == "clear":
		_count("pot", 0, T.t(T.COUNT_UP), 0.0)
		_count("score", st.score, T.t(T.BANK_COUNT), 0.0)
		fx.callout(S.CALL_CLEAR, T.BRASS_HI, callout_at)
		fx.confetti(size.x, size.y)
		app.sfx.play("clear")
		if not T.lite:
			tw.parallel().tween_property(card, "rotation", TAU, T.t(T.CLEAR_SPIN)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(card, "scale", Vector2.ONE * 1.15, T.t(T.CLEAR_SPIN))
		tw.parallel().tween_callback(_emit_finished).set_delay(T.CLEAR_WAIT)
	elif st.ended == "gameover":
		app.sfx.play("gameover")
		# 対戦では、結果が出るまで相手の札を見て待つので、暗くしない
		if mode != "versus":
			tw.parallel().tween_property(fade, "color:a", 1.0, T.END_FADE).set_delay(T.END_FADE)
			tw.parallel().tween_callback(_emit_finished).set_delay(T.END_FADE * 2)


func _animate_bank(res: Dictionary) -> void:
	app.sfx.play("bank")
	var tw := _new_post()
	var pot_c := pot_num.position + pot_num.size / 2
	var score_c := score_num.position + Vector2(60, score_num.size.y / 2)
	var text := ShareText.group(res["amount"])
	fx.fly_text(tw, text, pot_c, score_c, T.t(T.BANK_FLY), T.BRASS_HI, T.FS_POT, 70.0)
	fx.burst(pot_c, T.SPARKS_BANK, T.t(T.BANK_SPARK))
	fx.callout(S.CALL_BANK % text, T.BRASS_HI, Layout.over(landscape, mode == "versus")["callout"])
	_set_shown(0, "pot")
	_count("score", st.score, T.t(T.BANK_COUNT), T.t(T.BANK_FLY) * 0.8)
	ladder.set_streak(0, tw, true)
	_refresh()


func _emit_finished() -> void:
	if done or mode == "versus":
		return
	done = true
	finished.emit({"state": st, "stats": stats, "date": date, "mode": mode, "result": end_result, "new_achievements": run_ach + end_result["new_achievements"]})


# ---- 一時停止(FR-24・FR-33) ----

func _toggle_pause() -> void:
	# FR-44: 対戦中は止められない。ランが終わって待っている間も、部屋を出る確かめは出せる
	if done or (st.ended != "" and mode != "versus"):
		return
	if pause_layer != null:
		pause_layer.queue_free()
		pause_layer = null
		return
	_finish_all()
	_open_pause()


func _open_pause() -> void:
	if pause_layer != null:
		pause_layer.queue_free()
	pause_layer = Control.new()
	Kit.place(pause_layer, Rect2(Vector2.ZERO, size))
	var scrim := ColorRect.new()
	scrim.color = T.SCRIM
	Kit.place(scrim, view)
	pause_layer.add_child(scrim)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var items := [[S.BTN_RESUME, "brass", _toggle_pause], [S.BTN_SETTINGS, "green", app.open_settings], [S.BTN_TO_TITLE, "green", func(): to_title.emit()]]
	if mode == "versus":
		# FR-44: 確かめの間も時間は進む
		items = [[S.VS_STAY, "brass", _toggle_pause], [S.BTN_SETTINGS, "green", app.open_settings], [S.ROOM_LEAVE, "green", _leave_versus]]
	box.add_child(Kit.label(S.VS_LEAVE_ASK if mode == "versus" else S.PAUSED + "  " + _mode_text(), T.FS_HEAD if mode != "versus" else T.FS_BODY, T.W_NUM))
	for item in items:
		var b := Kit.button(item[0], T.FS_BODY, item[1])
		b.custom_minimum_size = Vector2(520, 96)
		b.pressed.connect(item[2])
		box.add_child(b)
	var st_now: Dictionary = save.data["settings"]
	for item in [[S.SET_BGM, "bgm_volume"], [S.SET_SFX, "sfx_volume"]]:
		var row := VolumeRow.new()
		row.setup(item[0], int(st_now[item[1]]))
		var key: String = item[1]
		row.changed.connect(func(v: int): _set_volume(key, v))
		box.add_child(row)
	# 対戦は途中の保存をしない(D-29)ので、「保存されます」は出さない
	if mode != "versus":
		box.add_child(Kit.label(S.PAUSE_NOTE, T.FS_SMALL, T.W_BODY, T.TEXT_DIM))
	pause_layer.add_child(box)
	Kit.place(box, Rect2((size.x - 520) / 2, (size.y - 640) / 2, 520, 640))
	add_child(pause_layer)


func _set_volume(key: String, v: int) -> void:
	save.data["settings"][key] = v
	save.write()
	app.apply_settings()
	if key == "sfx_volume":
		app.sfx.play("tap")


# ---- 対戦(FR-41〜FR-45) ----

func _build_versus() -> void:
	vs = app.session
	time_label = Kit.num_label("", T.FS_HEAD, T.TEXT)
	add_child(time_label)
	rival_box = Control.new()
	rival_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rival_box)
	var ids: Array = vs.vs.players.keys()
	ids.sort()
	for id in ids:
		if id != vs.vs.my_id:
			var chip := RivalChip.new()
			rival_box.add_child(chip)
			rivals[id] = chip
	vs.rivals_changed.connect(_refresh_rivals)
	rank_label = Kit.label("", T.FS_SMALL, T.W_NUM, T.BRASS_HI)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rank_label)
	count_label = Kit.num_label("", T.FS_TITLE, T.BRASS_HI)
	# 札の上に重なっても読めるように、暗い下地を敷く
	count_label.add_theme_stylebox_override("normal", Kit.box(Color(T.BG_DEEP, 0.88), 28, Color(T.BRASS, 0.5), 1))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)
	wait_label = Kit.label("", T.FS_BODY, T.W_NUM, T.BRASS_HI)
	wait_label.add_theme_stylebox_override("normal", Kit.box(Color(T.BG_DEEP, 0.85), 18, Color(T.BRASS, 0.5), 1))
	wait_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wait_label.visible = false
	add_child(wait_label)
	# 3 秒の秒読みの間は、手を受けない
	vs_locked = true
	vs_start_ms = Time.get_ticks_msec() + COUNTDOWN_MS
	_refresh_rivals()


func _layout_versus(r: Dictionary) -> void:
	Kit.place(time_label, r["timer"])
	var strip: Rect2 = r["rivals"]
	Kit.place(rival_box, strip)
	var n := maxi(rivals.size(), 1)
	var w := (strip.size.x - 8 * (n - 1)) / n
	var i := 0
	for id in rivals:
		Kit.place(rivals[id], Rect2(i * (w + 8), 0, w, strip.size.y))
		i += 1
	Kit.place(rank_label, r["rank_now"])
	Kit.place(count_label, Rect2(size.x / 2 - 110, size.y * 0.3 - 10, 220, 160))
	count_label.pivot_offset = count_label.size / 2
	Kit.place(wait_label, r["pot"])


func _refresh_rivals() -> void:
	for id in rivals:
		if vs.vs.players.has(id):
			rivals[id].set_row(vs.vs.players[id])


# 秒読みと残り時間。時間は、始めた時刻からの経過で数える(一時停止の確かめの間も、タブが裏に回っていた間も進む。FR-44・E-32)。
@warning_ignore("integer_division")
func _process(_delta: float) -> void:
	if mode != "versus" or done:
		return
	rank_label.text = S.VS_RANK_NOW % vs.vs.live_rank(vs.vs.my_id)
	if vs_locked:
		var left := vs_start_ms - Time.get_ticks_msec()
		if left > 0:
			var n := (left + 999) / 1000
			if n != vs_count:
				vs_count = n
				count_label.text = str(n)
				app.sfx.play("tap")
				if not T.lite:
					# 数字が変わるたびに、小さく弾ませる
					count_label.scale = Vector2(1.3, 1.3)
					create_tween().tween_property(count_label, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)
			return
		vs_locked = false
		count_label.visible = false
		vs.begin_play()
	var rem: int = vs.remaining_ms()
	time_label.visible = rem >= 0
	if rem < 0:
		return
	var sec := (rem + 999) / 1000
	time_label.text = "%d:%02d" % [sec / 60, sec % 60]
	time_label.add_theme_color_override("font_color", T.BAD if rem <= 30000 else T.TEXT)
	if rem <= 30000 and not vs_soon:
		vs_soon = true
		fx.callout(S.VS_SOON, T.BAD, Layout.over(landscape, true)["callout"])
	if rem == 0:
		_versus_final(true)


# 自分のランが終わった、または時間切れ。final を送って、対戦が締まるのを待つ(終わっていない人のポットは得点に入らない。FR-42)。
func _versus_final(timeout: bool) -> void:
	if vs_final:
		return
	vs_final = true
	if timeout:
		_finish_all()
	vs.report(VersusState.row_from_run(st, stats, 0, vs.round_no, true))
	wait_label.text = (S.VS_TIME_UP + "  " if timeout else "") + S.VS_WAIT_END
	wait_label.visible = true


# 対戦が締まった(main が呼ぶ)。自分のランを通算と実績に数える(D-29)。2 回目からは、同じ結果を返すだけ。
func close_versus() -> Dictionary:
	if not done:
		_finish_all()
		done = true
		end_result = save.finish_run(stats, date, day_no)
	return {"state": st, "stats": stats, "result": end_result, "new_achievements": run_ach + end_result["new_achievements"]}


# 自分のランを終えてから出るなら、そのランは数える。途中で出たランは数えない。
func _leave_versus() -> void:
	if vs_final:
		close_versus()
	to_title.emit()
