# 結果画面(FR-13・画面設計書 §3.2)。得点(数え上げ)・完走か・めくった枚数・当たりと外れ・「同じ」の当たり・
# 最大の連続・確保の回数・自己ベスト・達成した実績・解放・称号の告知と、「もう一度」「タイトルへ」。共有は Phase 4。
extends Control

signal retry_pressed
signal title_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")

var info := {}
var best_before := 0
var sheet: Panel
var scroll: ScrollContainer
var box: VBoxContainer
var score_num: Label
var grid: GridContainer
var btn_box: HBoxContainer
var buttons: Array[Button] = []
var used := false


func setup(run_info: Dictionary, best_score_before: int) -> void:
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
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for item in [[S.RESULT_DRAWS, str(s.draws)], [S.RESULT_HITS, S.RESULT_HITS_VALUE % [s.hits, s.misses]], [S.RESULT_SAME, str(s.same_hits)], [S.RESULT_STREAK, str(s.best_streak)], [S.RESULT_BANKS, str(s.banks)]]:
		grid.add_child(_stat(item[0], item[1]))
	var ach: Array = info["new_achievements"]
	if not ach.is_empty():
		_wrap(S.RESULT_ACH % S.LIST_SEP.join(PackedStringArray(ach.map(func(id): return S.ACHIEVEMENTS[id][0]))), T.GOOD)
	var unlocks: Array = res["new_unlocks"]
	if not unlocks.is_empty():
		_wrap(S.RESULT_UNLOCK % S.LIST_SEP.join(PackedStringArray(unlocks.map(func(id): return S.CARD_BACKS.get(id, S.TABLES.get(id, id))))), T.BRASS_HI)
	if res["title_after"] > res["title_before"]:
		_wrap(S.RESULT_TITLE_UP % S.TITLES[res["title_after"] - 1], T.BRASS_HI)
	btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 14)
	add_child(btn_box)
	_add_button(S.BTN_RETRY, "brass", retry_pressed)
	_add_button(S.BTN_TO_TITLE, "green", title_pressed)
	# 得点は 0 から 0.8 秒で数え上げる。控えめでは数え上げない
	if T.lite:
		_set_score(st.score)
	else:
		create_tween().tween_method(_set_score, 0.0, float(st.score), T.RESULT_COUNT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_score(v: float) -> void:
	score_num.text = ShareText.group(roundi(v))


func _stat(title: String, value: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box(Color(T.FELT_HI, 0.5), 12))
	p.custom_minimum_size = Vector2(190, 84)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.add_child(Kit.num_label(value, T.FS_BODY + 4, T.TEXT))
	v.add_child(Kit.label(title, T.FS_SMALL, T.W_BODY, T.TEXT_DIM))
	p.add_child(v)
	return p


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


# 「もう一度」と「タイトルへ」は下に固定し、中身だけをスクロールする(画面設計書 §3.2)。
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
		b.custom_minimum_size = Vector2((w - 54) / 2, 100)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		buttons[0].pressed.emit()
