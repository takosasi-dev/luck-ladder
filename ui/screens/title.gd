# タイトル画面(FR-2 のうち Phase 3 の分・画面設計書 §3.1)。題名、梯子の段の灯り、「つづきから」「ラン」「設定」、版。
# 途中のランがあるのに「ラン」を押したら、捨てるかを確かめる(E-11)。固定値の診断は Phase 4 で消す。
extends Control

signal run_pressed
signal continue_pressed
signal settings_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Rng := preload("res://core/rng.gd")
const Deck := preload("res://core/deck.gd")
const Fx := preload("res://tests/fixtures.gd")

const RUNGS := 7
const RUNG_CYCLE := 3.2

var has_continue := false
var notice := ""
var logo: Label
var rungs: Control
var sub: Label
var notice_label: Label
var menu: VBoxContainer
var main_buttons: Array[Button] = []
var confirm_layer: Control
var version_label: Label
var diag_label: Label
var used := false
var landscape := true
var view := Rect2(0, 0, 1280, 720)


func setup(continue_available: bool, notice_text: String) -> void:
	has_continue = continue_available
	notice = notice_text


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
	notice_label = Kit.label(notice, T.FS_SMALL, T.W_BODY, T.BAD)
	add_child(notice_label)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	add_child(menu)
	if has_continue:
		_add_button(S.BTN_CONTINUE, "brass", func(): _go(continue_pressed))
	_add_button(S.BTN_RUN, "green" if has_continue else "brass", _on_run)
	var settings := Kit.button(S.BTN_SETTINGS, T.FS_BODY, "ghost")
	settings.custom_minimum_size = Vector2(0, 96)
	settings.pressed.connect(func(): settings_pressed.emit())
	menu.add_child(settings)
	version_label = Kit.num_label(S.VERSION_PREFIX + str(ProjectSettings.get_setting("application/config/version")), T.FS_SMALL, T.TEXT_DIM, T.W_BODY)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_label)
	diag_label = Kit.label(S.FIXED_OK if _fixed_values_ok() else S.FIXED_NG, T.FS_SMALL, T.W_BODY, Color(T.TEXT_DIM, 0.7))
	diag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(diag_label)
	set_process(not T.lite)


func _add_button(text: String, kind: String, cb: Callable) -> void:
	var b := Kit.button(text, T.FS_BODY + 6, kind)
	b.custom_minimum_size = Vector2(0, 100)
	b.pressed.connect(cb)
	menu.add_child(b)
	main_buttons.append(b)


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
	if has_continue:
		_open_confirm()
	else:
		_go(run_pressed)


func _open_confirm() -> void:
	if confirm_layer != null:
		return
	confirm_layer = Control.new()
	Kit.place(confirm_layer, Rect2(Vector2.ZERO, size))
	var scrim := ColorRect.new()
	scrim.color = T.SCRIM
	Kit.place(scrim, view)
	confirm_layer.add_child(scrim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.add_child(Kit.label(S.CONFIRM_DISCARD, T.FS_BODY, T.W_NUM))
	var no := Kit.button(S.BTN_CANCEL, T.FS_BODY, "green")
	no.custom_minimum_size = Vector2(480, 100)
	no.pressed.connect(_close_confirm)
	v.add_child(no)
	var yes := Kit.button(S.BTN_DISCARD, T.FS_BODY, "ghost")
	yes.custom_minimum_size = Vector2(480, 100)
	yes.pressed.connect(func():
		_close_confirm()
		_go(run_pressed))
	v.add_child(yes)
	confirm_layer.add_child(v)
	Kit.place(v, Rect2((size.x - 520) / 2, (size.y - 290) / 2, 520, 290))
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
	var menu_w := 520.0 if landscape else 660.0
	var menu_h := menu.get_combined_minimum_size().y
	var top := 70.0 if landscape else 190.0
	logo.add_theme_font_size_override("font_size", T.FS_TITLE if landscape else T.FS_TITLE - 8)
	Kit.place(logo, Rect2(0, top, size.x, 130))
	Kit.place(rungs, Rect2(0, top + 132, size.x, 20))
	Kit.place(sub, Rect2(0, top + 160, size.x, 36))
	Kit.place(notice_label, Rect2(0, top + 204, size.x, 34))
	var menu_top := top + 250.0 if landscape else top + 330.0
	Kit.place(menu, Rect2((size.x - menu_w) / 2, menu_top, menu_w, menu_h))
	Kit.place(version_label, Rect2(size.x - 220, size.y - 46, 200, 36))
	Kit.place(diag_label, Rect2(20, size.y - 46, 400, 36))
	if confirm_layer != null:
		_close_confirm()
		_open_confirm()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		if confirm_layer == null and not main_buttons.is_empty():
			main_buttons[0].pressed.emit()


# §9.2・§9.3 の固定値を、この端末で計算し直して照らす(Phase 0 の診断の続き。Phase 4 で消す)。
func _fixed_values_ok() -> bool:
	for k in Fx.FNV:
		if Rng.fnv1a(k) != Fx.FNV[k]:
			return false
	for row in Fx.DECKS:
		if Deck.checksum(Deck.shuffled(row[0])) != row[3]:
			return false
	return true
