# 画面の切り替えと、保存・効果音・BGM・背景を持つ。窓の縦横比を見て、基準の座標を
# 横長 1280×720 と縦長 720×1280 で付け替え、表示中の画面に relayout(横長か, 画面全体) を伝える(D-12・FR-22)。
extends Control

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const Kit := preload("res://ui/kit.gd")
const RunState := preload("res://core/run_state.gd")
const RunStats := preload("res://core/run_stats.gd")
const DayIndex := preload("res://core/day_index.gd")
const Ach := preload("res://core/achievements.gd")
const Progress := preload("res://core/progress.gd")
const SaveStore := preload("res://save/save_store.gd")
const Sfx := preload("res://audio/sfx.gd")
const Bgm := preload("res://audio/bgm.gd")
const Title := preload("res://ui/screens/title.gd")
const Play := preload("res://ui/screens/play.gd")
const Result := preload("res://ui/screens/result.gd")
const Settings := preload("res://ui/screens/settings.gd")
const SaveData := preload("res://ui/screens/save_data.gd")
const NetLab := preload("res://ui/screens/net_lab.gd")
const BrowserBridge := preload("res://net/browser_bridge.gd")
const PAGES := {
	"achievements": preload("res://ui/screens/achievements.gd"),
	"records": preload("res://ui/screens/records.gd"),
	"collection": preload("res://ui/screens/collection.gd"),
	"blackjack": preload("res://ui/screens/blackjack.gd"),
	"poker": preload("res://ui/screens/poker.gd"),
}

const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)

var save
var sfx
var bgm
var bridge
var bg_shader: ColorRect
var bg_plain: ColorRect
var bg_gradient: Gradient
var stage: Control
var screen: Control
var overlay: Control
var landscape := true
var view := Rect2(0, 0, 1280, 720)
var notice := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	save = SaveStore.new()
	sfx = Sfx.new()
	add_child(sfx)
	bgm = Bgm.new()
	add_child(bgm)
	_build_background()
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	# ボタンを押した音(§9.13 の tap)は、メニューのボタンすべてで鳴らす
	get_tree().node_added.connect(func(n: Node):
		if n is Button:
			n.button_down.connect(sfx.play.bind("tap")))
	apply_settings()
	# size_changed の中で content_scale_size を変えると、窓の側の計算が古い縦横比で上書きするので、後回しにする
	get_tree().root.size_changed.connect(_on_window_resized, CONNECT_DEFERRED)
	# Phase 6 の接続実験: URL に lab= か、招待(j=)・返事(a=)が付いて開かれたら、実験の画面を出す
	bridge = BrowserBridge.new()
	var query: String = bridge.url_query()
	if RegEx.create_from_string("[?&](lab|j|a)=").search(query):
		show_lab(query)
	else:
		show_title()
	_on_window_resized()


# 布地の背景。標準は table_bg のシェーダー、控えめでは単色と四隅の減光の画像(§9.12・D-15)。
func _build_background() -> void:
	bg_plain = ColorRect.new()
	bg_plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_gradient = Gradient.new()
	bg_gradient.set_offset(0, 0.35)
	var tex := GradientTexture2D.new()
	tex.gradient = bg_gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.4)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var vignette := TextureRect.new()
	vignette.texture = tex
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_plain.add_child(vignette)
	add_child(bg_plain)
	bg_shader = ColorRect.new()
	bg_shader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/table_bg.gdshader")
	bg_shader.material = m
	add_child(bg_shader)


# 保存してある設定を、見た目の値・音量・背景に写す。設定やコレクションを変えるたびに呼ぶ。
func apply_settings() -> void:
	var st: Dictionary = save.data["settings"]
	T.apply_settings(st)
	sfx.set_volume(int(st["sfx_volume"]))
	bgm.set_volume(int(st["bgm_volume"]))
	bg_shader.visible = not T.lite
	bg_plain.visible = T.lite
	bg_plain.color = T.BG_FELT
	bg_gradient.set_color(0, Color(T.BG_DEEP, 0.0))
	bg_gradient.set_color(1, T.BG_DEEP)
	var m: ShaderMaterial = bg_shader.material
	m.set_shader_parameter("deep", T.BG_DEEP)
	m.set_shader_parameter("felt", T.BG_FELT)
	m.set_shader_parameter("hi", T.FELT_HI)


func _on_window_resized() -> void:
	var w := get_window()
	var s := w.size
	landscape = s.x >= s.y
	w.content_scale_size = LANDSCAPE if landscape else PORTRAIT
	# 基準より細長い窓では、余った分にも背景を敷き、画面は中央に置く
	var full := get_viewport_rect().size
	var base := Vector2(LANDSCAPE if landscape else PORTRAIT)
	stage.position = ((full - base) / 2).floor()
	stage.size = base
	view = Rect2(-stage.position, full)
	for b in [bg_shader, bg_plain]:
		b.position = Vector2.ZERO
		b.size = full
	bg_shader.material.set_shader_parameter("px_size", full)
	if screen != null:
		screen.relayout(landscape, view)
	if overlay != null:
		overlay.relayout(landscape, view)


# 最初の入力の後から音を鳴らす(FR-1)。
func _input(event: InputEvent) -> void:
	if bgm.unlocked:
		return
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.pressed:
		bgm.unlock()


# タブが裏に回ったら BGM を止め、戻ったら続きから鳴らす(FR-34)。
func _notification(what: int) -> void:
	if bgm == null:
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		bgm.set_paused(true)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		bgm.set_paused(false)


func _today() -> String:
	var t := DayIndex.today()
	return DayIndex.date_string(t[0], t[1], t[2])


# 画面の切り替え: 透明度と 12 px の横ずらし(§9.12)。
func _swap(next: Control) -> void:
	_close_overlay()
	if screen != null:
		screen.queue_free()
	screen = next
	stage.add_child(screen)
	screen.relayout(landscape, view)
	if T.lite:
		return
	screen.modulate.a = 0.0
	screen.position.x = T.SCREEN_SHIFT
	var tw := screen.create_tween().set_parallel(true)
	tw.tween_property(screen, "modulate:a", 1.0, T.SCREEN_FADE)
	tw.tween_property(screen, "position:x", 0.0, T.SCREEN_FADE)


# ---- 重ね表示(設定・保存データ) ----

func _open_overlay(o: Control) -> void:
	_close_overlay()
	overlay = o
	stage.add_child(overlay)
	overlay.relayout(landscape, view)
	# 重ね表示を開いている間は、下の画面にキー操作を渡さない
	if screen != null:
		screen.set_process_unhandled_input(false)


func _close_overlay() -> void:
	if overlay == null:
		return
	overlay.queue_free()
	overlay = null
	if screen != null:
		screen.set_process_unhandled_input(true)


func open_settings() -> void:
	var o := Settings.new()
	o.setup(self)
	o.closed.connect(close_settings)
	_open_overlay(o)


func close_settings() -> void:
	_close_overlay()
	if screen != null:
		screen.relayout(landscape, view)


func open_data() -> void:
	var o := SaveData.new()
	o.setup(self)
	o.closed.connect(open_settings)
	o.replaced.connect(_on_data_replaced)
	_open_overlay(o)


# 保存データを丸ごと入れ替えた後は、設定を写し直してタイトルから始める。
func _on_data_replaced(message: String) -> void:
	apply_settings()
	notice = message
	show_title()


# ---- 画面 ----

func show_title() -> void:
	var today := _today()
	save.drop_stale_daily(today)
	bgm.play("bgm_title")
	var t := DayIndex.parse(today)
	var first = save.data["daily"].get(today)
	var title := Title.new()
	title.setup({
		"has_continue": save.current("run") != null,
		"notice": notice,
		"daily_no": DayIndex.day_no(t[0], t[1], t[2]),
		"daily_first": -1 if first == null else int(first["score"]),
		"daily_ongoing": save.current("daily") != null,
		"ach_done": save.data["achievements"].size(),
		"ach_total": Ach.DEFS.size(),
		"title_rank": Progress.title_rank(save.data["totals"]["total_score"]),
	})
	notice = ""
	title.run_pressed.connect(start_new_run)
	title.continue_pressed.connect(func(): _continue("run"))
	title.daily_pressed.connect(start_daily)
	title.page_pressed.connect(_open_page)
	_swap(title)


func show_lab(query: String) -> void:
	var lab := NetLab.new()
	lab.setup(self, bridge, query)
	lab.back_pressed.connect(show_title)
	_swap(lab)


# 設定の「対戦の接続テスト」から開く(招待を作る側として)。
func open_lab() -> void:
	show_lab("?lab=1")


func _open_page(page: String) -> void:
	if page == "settings":
		open_settings()
		return
	var p: Control = PAGES[page].new()
	p.setup(self)
	p.back_pressed.connect(show_title)
	_swap(p)


func start_new_run() -> void:
	var seed_text := "LLR:%d:%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	_start("run", seed_text, _today())


# 今日の山札(FR-14)。途中の物があれば続きから。無ければ、端末の今日の日付の山札を始める。
func start_daily() -> void:
	if save.current("daily") != null:
		_continue("daily")
		return
	var date := _today()
	_start("daily", DayIndex.daily_seed_text(date), date)


func _start(mode: String, seed_text: String, date: String) -> void:
	save.save_current(mode, seed_text, date, "", bool(save.data["settings"]["counter"]))
	# 初回かどうかは始めた時点で決め、終わるまで変えない(D-9・E-10)
	_play(RunState.new(seed_text), RunStats.new(mode, mode == "daily" and save.is_first_daily(date)), mode, date)


# FR-16・E-9: 種と操作の列から復元する。失敗したら捨ててタイトルに 1 回知らせる。
func _continue(mode: String) -> void:
	var rec = save.current(mode)
	if rec == null:
		show_title()
		return
	var first: bool = mode == "daily" and save.is_first_daily(rec["date"])
	var r := RunStats.rebuild(rec["seed_text"], rec["actions"], mode, first, rec["counter_shown"])
	if not r["ok"] or r["state"].ended != "":
		save.clear_current(mode)
		notice = S.RESTORE_FAILED
		show_title()
		return
	_play(r["state"], r["stats"], mode, rec["date"])


func _play(st, stats, mode: String, date: String) -> void:
	var p := Play.new()
	p.setup(self, st, stats, mode, date, not bool(save.data["tutorial_done"]))
	var best_before: int = save.data["totals"]["best_score"]
	p.finished.connect(func(info: Dictionary): _show_result(info, best_before))
	p.to_title.connect(show_title)
	_swap(p)


func _show_result(info: Dictionary, best_before: int) -> void:
	bgm.play("bgm_title")
	var r := Result.new()
	r.setup(self, info, best_before)
	# 「もう一度」: ランは新しい山札、今日の山札は同じ山札の次の回(§9.1)
	r.retry_pressed.connect(start_daily if info["mode"] == "daily" else start_new_run)
	r.title_pressed.connect(show_title)
	_swap(r)
