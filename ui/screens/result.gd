# 結果画面(FR-13)。得点・完走か・めくった枚数・当たりと外れ・「同じ」の当たり・最大の連続・確保の回数・
# 自己ベスト・達成した実績・解放・称号の告知と、「もう一度」「タイトルへ」を出す。共有は Phase 4。
extends Control

signal retry_pressed
signal title_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")

var info := {}
var best_before := 0
var scroll: ScrollContainer
var box: VBoxContainer
var grid: GridContainer
var btn_box: BoxContainer
var buttons: Array[Button] = []
var used := false


func setup(run_info: Dictionary, best_score_before: int) -> void:
	info = run_info
	best_before = best_score_before


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var st = info["state"]
	var s = info["stats"]
	var res: Dictionary = info["result"]
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	btn_box = BoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	add_child(btn_box)
	box.add_child(Kit.label(S.RESULT_CLEAR if st.ended == "clear" else S.RESULT_GAMEOVER, T.FS_BODY + 8, T.W_NUM, T.BRASS))
	box.add_child(Kit.label(S.RESULT_POINTS % ShareText.group(st.score), T.FS_SCORE + 16, T.W_NUM, T.BRASS_HI))
	if s.counts_for_records() and st.score > best_before:
		box.add_child(Kit.label(S.RESULT_BEST, T.FS_BODY, T.W_NUM, T.GOOD))
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 40)
	box.add_child(grid)
	for line in [S.RESULT_DRAWS % s.draws, S.RESULT_HITS % [s.hits, s.misses], S.RESULT_SAME % s.same_hits, S.RESULT_STREAK % s.best_streak, S.RESULT_BANKS % s.banks]:
		grid.add_child(Kit.label(line, T.FS_BODY, T.W_BODY, T.TEXT))
	var ach: Array = info["new_achievements"]
	if not ach.is_empty():
		_wrap(S.RESULT_ACH % S.LIST_SEP.join(PackedStringArray(ach.map(func(id): return S.ACHIEVEMENTS[id][0]))), T.GOOD)
	var unlocks: Array = res["new_unlocks"]
	if not unlocks.is_empty():
		_wrap(S.RESULT_UNLOCK % S.LIST_SEP.join(PackedStringArray(unlocks.map(func(id): return S.CARD_BACKS.get(id, S.TABLES.get(id, id))))), T.BRASS_HI)
	if res["title_after"] > res["title_before"]:
		_wrap(S.RESULT_TITLE_UP % S.TITLES[res["title_after"] - 1], T.BRASS_HI)
	_add_button(S.BTN_RETRY, T.BRASS, T.BANK_INK, retry_pressed)
	_add_button(S.BTN_TO_TITLE, T.FELT_HI, T.TEXT, title_pressed)


func _wrap(text: String, color: Color) -> void:
	var l := Kit.label(text, T.FS_SMALL + 2, T.W_BODY, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	box.add_child(l)


func _add_button(text: String, bg: Color, fg: Color, sig: Signal) -> void:
	var b := Kit.button(text, T.FS_BODY + 4, bg, fg)
	b.custom_minimum_size = Vector2(520, 100)
	b.pressed.connect(func():
		# E-20: 最初の 1 回だけ受ける
		if not used:
			used = true
			sig.emit())
	btn_box.add_child(b)
	buttons.append(b)


# 「もう一度」と「タイトルへ」は下に固定し、中身だけをスクロールする(画面設計書 §3.2)。
func relayout(landscape: bool) -> void:
	var sz := Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var bottom := 130.0 if landscape else 250.0
	Kit.place(scroll, Rect2(0, 20, sz.x, sz.y - bottom - 30))
	Kit.place(btn_box, Rect2(0, sz.y - bottom, sz.x, bottom - 20))
	btn_box.vertical = not landscape
	grid.columns = 2 if landscape else 1
	for b in buttons:
		b.custom_minimum_size = Vector2(420 if landscape else 660, 100)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		buttons[0].pressed.emit()
