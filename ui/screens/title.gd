# タイトル画面(FR-2・画面設計書 §3.1)。題名、梯子の段の灯り、「つづきから」「ラン」「今日の山札」
# 「対戦」(Phase 7 まで準備中で押せない)「ブラックジャック」「ポーカー」(追補 1)「実績」「コレクション」「記録」「設定」、称号、版を出す。
# 途中のランがあるのに「ラン」を押したら捨てるかを確かめ(E-11)、今日の山札の 2 回目からは 1 行断ってから始める(FR-14)。
extends Control

signal run_pressed
signal continue_pressed
signal daily_pressed
signal page_pressed(page: String)

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")

const RUNGS := 7
const RUNG_CYCLE := 3.2

# {has_continue, notice, daily_no, daily_first(初回の得点。無ければ -1), daily_ongoing, ach_done, ach_total, title_rank}
var info := {}
var logo: Label
var rungs: Control
var sub: Label
var notice_label: Label
var menu: VBoxContainer
var tall: Array[Control] = []
var short: Array[Control] = []
var main_buttons: Array[Button] = []
var versus: Button
var confirm_layer: Control
var confirm_args := []
var rank_label: Label
var version_label: Label
var used := false
var landscape := true
var view := Rect2(0, 0, 1280, 720)


func setup(title_info: Dictionary) -> void:
	info = title_info


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo = Kit.label(S.TITLE, T.FS_TITLE, T.W_BLACK, T.BRASS_HI)
	logo.add_theme_font_override("font", Kit.num_italic())
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	logo.add_theme_constant_override("shadow_offset_y", 5)
	logo.add_theme_constant_override("shadow_outline_size", 10)
	add_child(logo)
	rungs = Control.new()
	rungs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rungs.draw.connect(_draw_rungs)
	add_child(rungs)
	sub = Kit.label(S.SUBTITLE, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	add_child(sub)
	notice_label = Kit.label(info.get("notice", ""), T.FS_SMALL, T.W_BODY, T.BRASS_HI)
	add_child(notice_label)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	add_child(menu)
	var has_continue: bool = info.get("has_continue", false)
	if has_continue:
		main_buttons.append(_button(S.BTN_CONTINUE, "brass", func(): _go(continue_pressed), tall))
	main_buttons.append(_button(S.BTN_RUN, "green" if has_continue else "brass", _on_run, tall))
	var daily := S.BTN_DAILY + "  " + S.DAILY_NO % info.get("daily_no", 0)
	if info.get("daily_ongoing", false):
		daily += "  " + S.DAILY_ONGOING
	elif info.get("daily_first", -1) >= 0:
		daily += "  " + S.DAILY_FIRST % ShareText.group(info["daily_first"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	menu.add_child(row)
	_button(daily, "green", _on_daily, short, row).size_flags_stretch_ratio = 2.0
	# 対戦は Phase 7 で作るまで、押せないボタンとして出しておく(仕様書 §11 の Phase 5)
	versus = _button(S.BTN_VERSUS + "  " + S.COMING_SOON, "ghost", func(): pass, short, row)
	versus.disabled = true
	# 追補 1 §7.1
	_pair([[S.BTN_BJ, "blackjack"], [S.BTN_POKER, "poker"]], "green")
	var ach := S.BTN_ACH + "  " + S.ACH_COUNT % [info.get("ach_done", 0), info.get("ach_total", 0)]
	_pair([[ach, "achievements"], [S.BTN_COLLECTION, "collection"]])
	_pair([[S.BTN_RECORDS, "records"], [S.BTN_SETTINGS, "settings"]])
	rank_label = Kit.label(S.TITLES[clampi(info.get("title_rank", 1), 1, S.TITLES.size()) - 1], T.FS_SMALL, T.W_BODY, T.BRASS_HI)
	rank_label.add_theme_stylebox_override("normal", Kit.box(Color(0, 0, 0, 0), 18, Color(T.BRASS, 0.5), 1))
	add_child(rank_label)
	version_label = Kit.num_label(S.VERSION_PREFIX + str(ProjectSettings.get_setting("application/config/version")), T.FS_SMALL, T.TEXT_DIM, T.W_BODY)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_label)
	set_process(not T.lite)


func _button(text: String, kind: String, cb: Callable, group: Array, parent: Control = null) -> Button:
	var b := Kit.button(text, T.FS_BODY if is_same(group, tall) else T.FS_SMALL + 2, kind)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	(parent if parent != null else menu).add_child(b)
	group.append(b)
	return b


func _pair(items: Array, kind: String = "ghost") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	menu.add_child(h)
	for item in items:
		var page: String = item[1]
		_button(item[0], kind, func(): page_pressed.emit(page), short, h)


func _process(_delta: float) -> void:
	rungs.queue_redraw()


# 題名の下に梯子の段を 7 本並べ、左から右へ灯りが流れる(控えめでは流さない)。
func _draw_rungs() -> void:
	var w := 34.0
	var gap := 8.0
	var x0 := (rungs.size.x - (RUNGS * w + (RUNGS - 1) * gap)) / 2
	var t := fmod(Time.get_ticks_msec() / 1000.0, RUNG_CYCLE) / RUNG_CYCLE
	for i in RUNGS:
		var k := 0.0
		if not T.lite:
			var d := fposmod(t - float(i) / RUNGS * 0.5, 1.0)
			k = clampf(1.0 - absf(d - 0.12) / 0.14, 0.0, 1.0)
		var r := Rect2(x0 + i * (w + gap), rungs.size.y / 2 - 3, w, 6)
		rungs.draw_style_box(Kit.box(Color(T.BRASS, 0.25).lerp(T.BRASS_HI, k), 3), r)


func _on_run() -> void:
	if info.get("has_continue", false):
		_open_confirm(S.CONFIRM_DISCARD, S.BTN_DISCARD, func(): _go(run_pressed))
	else:
		_go(run_pressed)


# 途中の今日の山札はそのまま続ける(捨てる操作は無い)。初回が済んでいれば、1 行断ってから始める。
func _on_daily() -> void:
	if info.get("daily_first", -1) >= 0 and not info.get("daily_ongoing", false):
		_open_confirm(S.DAILY_AGAIN, S.BTN_START, func(): _go(daily_pressed))
	else:
		_go(daily_pressed)


func _open_confirm(text: String, yes_text: String, on_yes: Callable) -> void:
	_close_confirm()
	confirm_args = [text, yes_text, on_yes]
	confirm_layer = Control.new()
	Kit.place(confirm_layer, Rect2(Vector2.ZERO, size))
	var scrim := ColorRect.new()
	scrim.color = T.SCRIM
	Kit.place(scrim, view)
	confirm_layer.add_child(scrim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.add_child(Kit.label(text, T.FS_BODY, T.W_NUM))
	var no := Kit.button(S.BTN_CANCEL, T.FS_BODY, "green")
	no.custom_minimum_size = Vector2(480, 100)
	no.pressed.connect(_close_confirm)
	v.add_child(no)
	var yes := Kit.button(yes_text, T.FS_BODY, "ghost")
	yes.custom_minimum_size = Vector2(480, 100)
	yes.pressed.connect(func():
		_close_confirm()
		on_yes.call())
	v.add_child(yes)
	confirm_layer.add_child(v)
	Kit.place(v, Rect2((size.x - 560) / 2, (size.y - 290) / 2, 560, 290))
	add_child(confirm_layer)


func _close_confirm() -> void:
	if confirm_layer != null:
		confirm_layer.queue_free()
		confirm_layer = null


# E-20: 最初の 1 回だけ受ける
func _go(sig: Signal) -> void:
	if used:
		return
	used = true
	sig.emit()


func relayout(is_landscape: bool, view_rect: Rect2) -> void:
	landscape = is_landscape
	view = view_rect
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	# 横長は高さ 64 と 54(段が 1 つ増えたので詰めた。追補 1 の前提 A5)、縦長は当たりを 96 にする(画面設計書 §3.1)
	for b in tall:
		b.custom_minimum_size.y = 64 if landscape else 96
	for b in short:
		b.custom_minimum_size.y = 54 if landscape else 96
	var menu_w := 560.0 if landscape else 660.0
	var top := 16.0 if landscape else 130.0
	logo.add_theme_font_size_override("font_size", T.FS_TITLE if landscape else T.FS_TITLE - 8)
	Kit.place(logo, Rect2(0, top, size.x, 130))
	Kit.place(rungs, Rect2(0, top + 130, size.x, 20))
	Kit.place(sub, Rect2(0, top + 154, size.x, 34))
	Kit.place(notice_label, Rect2(0, top + 190, size.x, 34))
	var menu_top := top + 228.0 if landscape else top + 300.0
	Kit.place(menu, Rect2((size.x - menu_w) / 2, menu_top, menu_w, 0))
	Kit.place(rank_label, Rect2((size.x - 260) / 2, size.y - 52, 260, 40))
	Kit.place(version_label, Rect2(size.x - 220, size.y - 50, 200, 36))
	if confirm_layer != null:
		_open_confirm(confirm_args[0], confirm_args[1], confirm_args[2])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		if confirm_layer == null and not main_buttons.is_empty():
			main_buttons[0].pressed.emit()
