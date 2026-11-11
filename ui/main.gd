# 画面の切り替え(タイトル → プレイ → 結果)と保存を持つ。窓の縦横比を見て、基準の座標を
# 横長 1280×720 と縦長 720×1280 で付け替え、表示中の画面に relayout(横長か) を伝える(D-12・FR-22)。
extends Control

const S := preload("res://core/strings.gd")
const T := preload("res://ui/theme/tokens.gd")
const RunState := preload("res://core/run_state.gd")
const RunStats := preload("res://core/run_stats.gd")
const DayIndex := preload("res://core/day_index.gd")
const SaveStore := preload("res://save/save_store.gd")
const Title := preload("res://ui/screens/title.gd")
const Play := preload("res://ui/screens/play.gd")
const Result := preload("res://ui/screens/result.gd")

const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)

var save
var screen: Control
var landscape := true
var notice := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = T.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	save = SaveStore.new()
	# size_changed の中で content_scale_size を変えると、窓の側の計算が古い縦横比で上書きするので、後回しにする
	get_tree().root.size_changed.connect(_on_window_resized, CONNECT_DEFERRED)
	show_title()
	_on_window_resized()


func _on_window_resized() -> void:
	var w := get_window()
	var s := w.size
	landscape = s.x >= s.y
	w.content_scale_size = LANDSCAPE if landscape else PORTRAIT
	if screen != null:
		screen.relayout(landscape)


func _today() -> String:
	var t := DayIndex.today()
	return DayIndex.date_string(t[0], t[1], t[2])


func _swap(next: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = next
	add_child(screen)
	screen.relayout(landscape)


func show_title() -> void:
	save.drop_stale_daily(_today())
	var t := Title.new()
	t.setup(save.current("run") != null, notice)
	notice = ""
	t.run_pressed.connect(start_new_run)
	t.continue_pressed.connect(continue_run)
	_swap(t)


func start_new_run() -> void:
	var seed_text := "LLR:%d:%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var date := _today()
	save.save_current("run", seed_text, date, "", bool(save.data["settings"]["counter"]))
	_play(RunState.new(seed_text), RunStats.new("run", false), date)


# FR-16・E-9: 種と操作の列から復元する。失敗したら捨ててタイトルに 1 回知らせる。
func continue_run() -> void:
	var rec = save.current("run")
	if rec == null:
		show_title()
		return
	var r := RunStats.rebuild(rec["seed_text"], rec["actions"], "run", false, rec["counter_shown"])
	if not r["ok"] or r["state"].ended != "":
		save.clear_current("run")
		notice = S.RESTORE_FAILED
		show_title()
		return
	_play(r["state"], r["stats"], rec["date"])


func _play(st, stats, date: String) -> void:
	var p := Play.new()
	p.setup(save, st, stats, "run", date, not bool(save.data["tutorial_done"]))
	var best_before: int = save.data["totals"]["best_score"]
	p.finished.connect(func(info: Dictionary): _show_result(info, best_before))
	p.to_title.connect(show_title)
	_swap(p)


func _show_result(info: Dictionary, best_before: int) -> void:
	var r := Result.new()
	r.setup(info, best_before)
	r.retry_pressed.connect(start_new_run)
	r.title_pressed.connect(show_title)
	_swap(r)
