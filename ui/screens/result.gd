# 結果画面(FR-13・画面設計書 §3.2)。得点(数え上げ)・完走か・めくった枚数・当たりと外れ・「同じ」の当たり・
# 最大の連続・確保の回数・自己ベスト・達成した実績・解放・称号の告知と、「もう一度」「タイトルへ」。共有は Phase 4。
extends Control

signal retry_pressed
signal title_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")
const DayIndex := preload("res://core/day_index.gd")
const B := preload("res://core/balance.gd")

var app
var info := {}
var best_before := 0
var copy_note: Label
var sheet: Panel
var scroll: ScrollContainer
var box: VBoxContainer
var score_num: Label
var grid: GridContainer
var btn_box: HBoxContainer
var buttons: Array[Button] = []
var used := false


func setup(app_ref, run_info: Dictionary, best_score_before: int) -> void:
	app = app_ref
	info = run_info
	best_before = best_score_before


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st = info["state"]
	var s = info["stats"]
	var res: Dictionary = info["result"]
	sheet = Kit.panel(Color(T.BG_DEEP, 0.8))
	add_child(sheet)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	box.add_child(Kit.label(S.RESULT_CLEAR if st.ended == "clear" else S.RESULT_GAMEOVER, T.FS_BODY + 4, T.W_NUM, T.BRASS))
	score_num = Kit.num_label("0", 84, T.BRASS_HI)
	box.add_child(score_num)
	if s.counts_for_records() and st.score > best_before:
		box.add_child(Kit.label(S.RESULT_BEST, T.FS_SMALL + 2, T.W_NUM, T.GOOD))
	var date: String = info["date"]
	var attempt: int = res["attempt"]
	if s.mode == "daily" and attempt > 1:
		# FR-14: 2 回目からは、初回の結果を並べて出す
		var first: Dictionary = app.save.data["daily"].get(date, {})
		box.add_child(Kit.label(S.DAILY_FIRST % ShareText.group(first.get("score", 0)) + "  " + S.RESULT_NOT_RECORDED, T.FS_SMALL, T.W_BODY, T.TEXT_DIM))
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for item in [[S.RESULT_DRAWS, str(s.draws)], [S.RESULT_HITS, S.RESULT_HITS_VALUE % [s.hits, s.misses]], [S.RESULT_SAME, str(s.same_hits)], [S.RESULT_STREAK, str(s.best_streak)], [S.RESULT_BANKS, str(s.banks)]]:
		grid.add_child(Kit.stat(item[0], item[1]))
	var ach: Array = info["new_achievements"]
	if not ach.is_empty():
		_wrap(S.RESULT_ACH % S.LIST_SEP.join(PackedStringArray(ach.map(func(id): return S.ACHIEVEMENTS[id][0]))), T.GOOD)
	var unlocks: Array = res["new_unlocks"]
	if not unlocks.is_empty():
		_wrap(S.RESULT_UNLOCK % S.LIST_SEP.join(PackedStringArray(unlocks.map(func(id): return S.CARD_BACKS.get(id, S.TABLES.get(id, id))))), T.BRASS_HI)
	if res["title_after"] > res["title_before"]:
		_wrap(S.RESULT_TITLE_UP % S.TITLES[res["title_after"] - 1], T.BRASS_HI)
	# FR-15: 共有テキストを選択できる欄に出し、コピーは「試す」だけにする(INV-10)
	var p := DayIndex.parse(date)
	var no := DayIndex.day_no(p[0], p[1], p[2]) if not p.is_empty() else 0
	var share := ShareText.build(s.mode, no, date, attempt, st.score, st.ended == "clear", s.draws, s.best_streak, B.SHARE_URL)
	var share_box := Kit.text_box(share, false)
	share_box.custom_minimum_size = Vector2(560, 138)
	copy_note = Kit.label("", T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	copy_note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	# 2 行ぶんの高さを先に取っておく(押した後に中身の高さが変わると、文字欄まで送る位置がずれる)
	copy_note.custom_minimum_size = Vector2(560, 72)
	box.add_child(copy_note)
	box.add_child(share_box)
	btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 14)
	add_child(btn_box)
	_add_button(S.BTN_RETRY, "brass", retry_pressed)
	_add_button(S.BTN_TO_TITLE, "green", title_pressed)
	# 「結果をコピー」も下に固定する(実績の行が増えた回に、スクロールの下へ隠れていた)。押したら共有の文字欄まで送る
	var copy := Kit.button(S.BTN_COPY_RESULT, T.FS_SMALL + 2, "ghost")
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(share)
		copy_note.text = S.COPY_TRIED
		scroll.ensure_control_visible(share_box))
	btn_box.add_child(copy)
	buttons.append(copy)
	# 得点は 0 から 0.8 秒で数え上げる。控えめでは数え上げない
	if T.lite:
		_set_score(st.score)
	else:
		create_tween().tween_method(_set_score, 0.0, float(st.score), T.RESULT_COUNT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_score(v: float) -> void:
	score_num.text = ShareText.group(roundi(v))


func _wrap(text: String, color: Color) -> void:
	var l := Kit.label(text, T.FS_SMALL + 2, T.W_BODY, color)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = Vector2(560, 0)
	box.add_child(l)


func _add_button(text: String, kind: String, sig: Signal) -> void:
	var b := Kit.button(text, T.FS_BODY + 4, kind)
	b.pressed.connect(func():
		# E-20: 最初の 1 回だけ受ける
		if not used:
			used = true
			sig.emit())
	btn_box.add_child(b)
	buttons.append(b)


# 「もう一度」「タイトルへ」「結果をコピー」は下に固定し、中身だけをスクロールする(画面設計書 §3.2)。
func relayout(landscape: bool, _view: Rect2) -> void:
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var w := 700.0 if landscape else 660.0
	var r := Rect2((size.x - w) / 2, 16, w, size.y - 32)
	if not landscape:
		r = Rect2((size.x - w) / 2, 150, w, 980)
	Kit.place(sheet, r)
	Kit.place(scroll, Rect2(r.position.x + 20, r.position.y + 14, w - 40, r.size.y - 14 - 128))
	Kit.place(btn_box, Rect2(r.position.x + 20, r.end.y - 116, w - 40, 100))
	grid.columns = 3 if landscape else 2
	for b in buttons:
		b.custom_minimum_size = Vector2((w - 68) / 3, 100)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		buttons[0].pressed.emit()
