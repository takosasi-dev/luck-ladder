# 設定の重ね表示(FR-21 のうち Phase 3 の分)。BGM と効果音の音量、演出、めくりの速さ、残り札の表示、
# 手ほどきをもう一度。変えた時点で反映して保存する(FR-33)。名前・書き出し・読み込み・消去は後のフェーズで足す。
extends Control

signal closed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const VolumeRow := preload("res://ui/parts/volume_row.gd")

var app
var scrim: ColorRect
var sheet: Panel
var head: Label
var scroll: ScrollContainer
var rows: VBoxContainer
var back: Button
var tutorial_queued := false


func setup(app_ref) -> void:
	app = app_ref


func _ready() -> void:
	scrim = ColorRect.new()
	scrim.color = T.SCRIM
	add_child(scrim)
	sheet = Kit.panel(Color(T.BG_DEEP, 0.92))
	add_child(sheet)
	head = Kit.label(S.SETTINGS, T.FS_HEAD, T.W_NUM)
	add_child(head)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	back = Kit.button(S.BTN_BACK, T.FS_BODY, "brass")
	back.pressed.connect(func(): closed.emit())
	add_child(back)
	_rebuild()


func _settings() -> Dictionary:
	return app.save.data["settings"]


func _store(key: String, value) -> void:
	_settings()[key] = value
	app.save.write()
	app.apply_settings()


func _rebuild() -> void:
	for c in rows.get_children():
		rows.remove_child(c)
		c.queue_free()
	var st := _settings()
	if not app.save.writable:
		# E-6: 保存できない端末では、いちばん上に 1 行出す
		rows.add_child(Kit.label(S.SAVE_UNAVAILABLE, T.FS_SMALL, T.W_BODY, T.BAD))
	var bgm := VolumeRow.new()
	bgm.setup(S.SET_BGM, int(st["bgm_volume"]))
	bgm.changed.connect(func(v: int): _store("bgm_volume", v))
	rows.add_child(bgm)
	var sfx := VolumeRow.new()
	sfx.setup(S.SET_SFX, int(st["sfx_volume"]))
	sfx.changed.connect(func(v: int):
		_store("sfx_volume", v)
		app.sfx.play("tap"))
	rows.add_child(sfx)
	_choice(S.SET_FX, [[S.FX_FULL, "full"], [S.FX_LITE, "lite"]], "fx")
	_choice(S.SET_SPEED, [[S.SPEED_NORMAL, "normal"], [S.SPEED_FAST, "fast"]], "speed")
	_choice(S.SET_COUNTER, [[S.SWITCH_ON, true], [S.SWITCH_OFF, false]], "counter")
	var again := Kit.button(S.TUTORIAL_QUEUED if tutorial_queued else S.BTN_TUTORIAL_AGAIN, T.FS_BODY, "ghost")
	again.disabled = tutorial_queued
	again.pressed.connect(func():
		app.save.set_tutorial_done(false)
		tutorial_queued = true
		_rebuild.call_deferred())
	_row(S.SET_TUTORIAL, [again])


func _choice(title: String, options: Array, key: String) -> void:
	var buttons := []
	for o in options:
		var on: bool = _settings()[key] == o[1]
		var b := Kit.button(o[0], T.FS_BODY, "brass" if on else "ghost")
		var value = o[1]
		b.pressed.connect(func():
			_store(key, value)
			_rebuild.call_deferred())
		buttons.append(b)
	_row(title, buttons)


func _row(title: String, controls: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Kit.label(title, T.FS_BODY, T.W_BODY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(220, 96)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for c in controls:
		c.custom_minimum_size = Vector2(150, 96)
		h.add_child(c)
	rows.add_child(h)


# view は、基準の座標で見た画面全体(左右や上下に余りがある端末では、基準より広い)。
func relayout(landscape: bool, view: Rect2) -> void:
	var base := Vector2(1280, 720) if landscape else Vector2(720, 1280)
	Kit.place(self, Rect2(Vector2.ZERO, base))
	Kit.place(scrim, view)
	var w := 760.0 if landscape else 680.0
	var r := Rect2((base.x - w) / 2, 16, w, base.y - 32)
	if not landscape:
		r = Rect2((base.x - w) / 2, 150, w, 980)
	Kit.place(sheet, r)
	Kit.place(head, Rect2(r.position.x, r.position.y + 8, w, 56))
	Kit.place(scroll, Rect2(r.position.x + 28, r.position.y + 70, w - 56, r.size.y - 70 - 124))
	Kit.place(back, Rect2(r.position.x + (w - 360) / 2, r.end.y - 112, 360, 96))
