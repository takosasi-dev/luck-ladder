# タイトル画面(FR-2 のうち Phase 2 の分)。題名・「つづきから」(途中のランがあるとき)・「ラン」・版を出す。
# 途中のランがあるのに「ラン」を押したら、捨てるかを確かめる(E-11)。固定値の診断は Phase 4 で消す。
extends Control

signal run_pressed
signal continue_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const Rng := preload("res://core/rng.gd")
const Deck := preload("res://core/deck.gd")
const Fx := preload("res://tests/fixtures.gd")

var has_continue := false
var notice := ""
var box: VBoxContainer
var buttons: Array[Button] = []
var confirm_layer: Control
var version_label: Label
var diag_label: Label
var used := false


func setup(continue_available: bool, notice_text: String) -> void:
	has_continue = continue_available
	notice = notice_text


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.add_child(Kit.label(S.TITLE, 96, 800, T.TEXT))
	box.add_child(Kit.label(S.SUBTITLE, 36, T.W_BODY, T.BRASS))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)
	if notice != "":
		box.add_child(Kit.label(notice, T.FS_SMALL, T.W_BODY, T.BAD))
	if has_continue:
		_add_button(S.BTN_CONTINUE, T.BRASS, T.BANK_INK, func(): _go(continue_pressed))
	var run := _add_button(S.BTN_RUN, T.FELT_HI if has_continue else T.BRASS, T.TEXT if has_continue else T.BANK_INK, _on_run)
	run.name = "run"
	version_label = Kit.label(S.VERSION_PREFIX + str(ProjectSettings.get_setting("application/config/version")), T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_label)
	diag_label = Kit.label(S.FIXED_OK if _fixed_values_ok() else S.FIXED_NG, T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	diag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(diag_label)
	_build_confirm()


func _add_button(text: String, bg: Color, fg: Color, cb: Callable) -> Button:
	var b := Kit.button(text, T.FS_BODY + 4, bg, fg)
	b.custom_minimum_size = Vector2(520, 100)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	box.add_child(b)
	buttons.append(b)
	return b


func _build_confirm() -> void:
	confirm_layer = Control.new()
	confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_layer.visible = false
	var scrim := ColorRect.new()
	scrim.color = T.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(scrim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 20)
	v.add_child(Kit.label(S.CONFIRM_DISCARD, T.FS_BODY, T.W_NUM))
	var yes := Kit.button(S.BTN_DISCARD, T.FS_BODY, T.FELT_HI, T.TEXT, T.BAD)
	yes.custom_minimum_size = Vector2(480, 100)
	yes.pressed.connect(func():
		confirm_layer.visible = false
		_go(run_pressed))
	var no := Kit.button(S.BTN_CANCEL, T.FS_BODY, T.FELT_HI)
	no.custom_minimum_size = Vector2(480, 100)
	no.pressed.connect(func(): confirm_layer.visible = false)
	v.add_child(no)
	v.add_child(yes)
	confirm_layer.add_child(v)
	add_child(confirm_layer)


func _on_run() -> void:
	if has_continue:
		confirm_layer.visible = true
	else:
		_go(run_pressed)


# E-20: 最初の 1 回だけ受ける
func _go(sig: Signal) -> void:
	if used:
		return
	used = true
	sig.emit()


func relayout(landscape: bool) -> void:
	var sz := Vector2(1280, 720) if landscape else Vector2(720, 1280)
	Kit.place(box, Rect2(0, 0, sz.x, sz.y - 60))
	for b in buttons:
		b.custom_minimum_size.x = 520 if landscape else 660
	Kit.place(version_label, Rect2(sz.x - 220, sz.y - 50, 200, 40))
	Kit.place(diag_label, Rect2(20, sz.y - 50, 400, 40))
	Kit.place(confirm_layer, Rect2(Vector2.ZERO, sz))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		if confirm_layer.visible:
			return
		if not buttons.is_empty():
			buttons[0].pressed.emit()


# §9.2・§9.3 の固定値を、この端末で計算し直して照らす(Phase 0 の診断の続き。Phase 4 で消す)。
func _fixed_values_ok() -> bool:
	for k in Fx.FNV:
		if Rng.fnv1a(k) != Fx.FNV[k]:
			return false
	for row in Fx.DECKS:
		if Deck.checksum(Deck.shuffled(row[0])) != row[3]:
			return false
	return true
