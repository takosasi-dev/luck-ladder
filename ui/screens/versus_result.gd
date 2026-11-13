# 対戦の結果(FR-43・FR-45、画面設計書 §3.8)。自分の順位、全員の行(順位・名前・得点・完走か・めくった枚数・最大の連続)、
# 「もう一戦」(ホストだけ)と「部屋を出る」。相手の値は、届いた物をそのまま出す(確かめない。§9.15)。
extends Control

signal leave_pressed

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const ShareText := preload("res://core/share_text.gd")
const VersusState := preload("res://core/versus_state.gd")
const Fx := preload("res://ui/fx/fx.gd")

var app
var results := []
var info := {}
var my_id := 0
var my_rank := 0
var scroll: ScrollContainer
var box: VBoxContainer
var fx
var rematch: Button
var wait_label: Label
var used := false
var confetti_done := false


func setup(app_ref, results_list: Array, run_info: Dictionary) -> void:
	app = app_ref
	results = results_list
	info = run_info
	my_id = app.session.vs.my_id


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	var ranks := VersusState.ranks(results)
	for i in results.size():
		if results[i]["id"] == my_id:
			my_rank = ranks[i]
	box.add_child(Kit.label(S.VS_RESULT, T.FS_HEAD, T.W_NUM))
	# 数字用の字には漢字が無い(「位」が豆腐になる)ので、本文の字で出す
	box.add_child(Kit.label(S.VS_RANK % my_rank, T.FS_TITLE, T.W_NUM, T.BRASS_HI))
	if app.session.host_gone:
		_text(S.VS_HOST_LOST, T.FS_SMALL, T.BAD)
	# 順位の順に並べる(同点は席の番号の順)
	var order := range(results.size())
	order.sort_custom(func(a, b): return ranks[a] < ranks[b] if ranks[a] != ranks[b] else results[a]["id"] < results[b]["id"])
	for i in order:
		box.add_child(_row(results[i], ranks[i]))
	for id in info["new_achievements"]:
		_text(S.ACHIEVEMENTS[id][0], T.FS_SMALL, T.BRASS_HI)
	rematch = Kit.button(S.VS_REMATCH, T.FS_BODY, "brass")
	rematch.custom_minimum_size = Vector2(0, 96)
	rematch.pressed.connect(_rematch)
	box.add_child(rematch)
	wait_label = _text(S.VS_WAIT_REMATCH, T.FS_BODY, T.BRASS_HI)
	var leave := Kit.button(S.ROOM_LEAVE, T.FS_BODY, "ghost")
	leave.custom_minimum_size = Vector2(0, 96)
	leave.pressed.connect(func(): leave_pressed.emit())
	box.add_child(leave)
	fx = Fx.new()
	add_child(fx)
	# §9.13: 対戦の終了は、1 位なら clear、それ以外は gameover の音
	app.sfx.play("clear" if my_rank == 1 else "gameover")
	_refresh()


func _text(text: String, font_size: int, color: Color) -> Label:
	var l := Kit.label(text, font_size, T.W_BODY, color)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	box.add_child(l)
	return l


func _row(r: Dictionary, rank: int) -> Control:
	var mine: bool = r["id"] == my_id
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box(Color(T.BRASS, 0.22) if mine else Color(T.BG_DEEP, 0.5), 14, Color(T.BRASS, 0.45), 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var who: String = r["name"]
	if r["status"] == "disconnected":
		who += "  " + S.VS_GONE
	elif r["cleared"]:
		who += "  " + S.VS_CLEARED
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Kit.label(S.VS_ROW % [rank, who], T.FS_BODY, T.W_NUM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(title)
	var detail := Kit.label(S.VS_ROW_DETAIL % [r["draws"], r["best_streak"]], T.FS_SMALL, T.W_BODY, T.TEXT_DIM)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(detail)
	h.add_child(left)
	h.add_child(Kit.num_label(ShareText.group(r["score"]), T.FS_SCORE, T.BRASS_HI if mine else T.TEXT))
	return p


# 「もう一戦」はホストだけ。ゲストは、ホストがつながっている間「待っています」を出す。
func _refresh() -> void:
	var se = app.session
	if se == null:
		return
	rematch.visible = se.is_host
	rematch.disabled = se.connected_links().is_empty()
	wait_label.visible = not se.is_host and not se.host_gone


func _process(_delta: float) -> void:
	_refresh()


func _rematch() -> void:
	# E-37: 最初の 1 回だけ受ける(始まれば、main がプレイ画面に替える)
	if used:
		return
	var se = app.session
	used = se.start(se.vs.match_sec, int(Time.get_unix_time_from_system()), Time.get_ticks_usec())


func relayout(landscape: bool, _view: Rect2) -> void:
	size = Vector2(1280, 720) if landscape else Vector2(720, 1280)
	var w := minf(size.x - 28, 860)
	Kit.place(scroll, Rect2((size.x - w) / 2, 10, w, size.y - 20))
	if fx != null:
		Kit.place(fx, Rect2(Vector2.ZERO, size))
		# 1 位のときだけ紙吹雪(1 回だけ)
		if my_rank == 1 and not confetti_done:
			confetti_done = true
			fx.confetti(size.x, size.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		leave_pressed.emit()
