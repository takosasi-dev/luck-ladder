# user://save.json の読み書きと、ラン終了時の記録(通算・上位ラン・今日の山札・実績)。
# 検査と既定値は core/save_codec.gd、実績の判定は core/achievements.gd に任せる。
extends RefCounted

const B := preload("res://core/balance.gd")
const Codec := preload("res://core/save_codec.gd")
const Ach := preload("res://core/achievements.gd")
const Progress := preload("res://core/progress.gd")
const DayIndex := preload("res://core/day_index.gd")

const DEFAULT_PATH := "user://save.json"

var path := DEFAULT_PATH
var data: Dictionary = {}
# 最後の書き込みが通ったか(E-6: 偽なら設定画面に「記録が残りません」を出す)
var writable := true


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	load_file()


func load_file() -> void:
	if not FileAccess.file_exists(path):
		data = Codec.defaults(Codec.default_name(randi_range(0, 99)))
		write()
		return
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var raw = json.data if json.parse(text) == OK else null
	var res := Codec.sanitize(raw)
	data = res["data"]
	if res["broken"]:
		# E-7: 壊れた中身を上書きする前に 1 つだけ写す
		_write_to(path.get_basename() + ".broken.json", text)
		data["settings"]["name"] = Codec.default_name(randi_range(0, 99))
		write()


# テストでは書けない保存先の代わりに、これを差し替える(AC-28)。
func _write_to(file_path: String, text: String) -> bool:
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func write() -> bool:
	writable = _write_to(path, JSON.stringify(data, "\t"))
	return writable


# 起動時とタイトルに戻ったとき: 日付の変わった途中の今日の山札を捨てる(§9.10)。
func drop_stale_daily(today: String) -> void:
	var cd = data["current_daily"]
	if cd != null and cd["date"] != today:
		data["current_daily"] = null
		write()


func current(mode: String):
	return data["current_daily"] if mode == "daily" else data["current_run"] if mode == "run" else null


# 1 手ごとの途中の保存(FR-16)。対戦は保存しない(D-29)。
func save_current(mode: String, seed_text: String, date: String, actions: String, counter_shown: bool) -> void:
	if mode != "run" and mode != "daily":
		return
	var rec := {"mode": mode, "seed_text": seed_text, "date": date, "actions": actions, "counter_shown": counter_shown}
	data["current_daily" if mode == "daily" else "current_run"] = rec
	write()


func clear_current(mode: String) -> void:
	if mode == "run" or mode == "daily":
		data["current_daily" if mode == "daily" else "current_run"] = null
		write()


func set_tutorial_done(done: bool) -> void:
	data["tutorial_done"] = done
	write()


# コレクションの選択(FR-20)。key は "card_back" か "table"。未解放の物・種類の違う物は選べない。
func select(key: String, id: String) -> bool:
	var wanted := "B-" if key == "card_back" else "T-" if key == "table" else ""
	if wanted == "" or not id.begins_with(wanted) or not Progress.is_unlocked(id, data["achievements"], data["totals"]["total_score"]):
		return false
	data["settings"][key] = id
	write()
	return true


func is_first_daily(date: String) -> bool:
	return not data["daily"].has(date)


func _ctx() -> Dictionary:
	return {"totals": data["totals"], "daily_streak": int(data["daily_streak"]["count"]), "daily_days": int(data["daily_days"])}


func _add_achievements(ids: Array, date: String) -> Array:
	var fresh := []
	for id in ids:
		if not data["achievements"].has(id):
			data["achievements"][id] = date
			fresh.append(id)
	return fresh


# 1 手ごとの実績の判定(FR-17)。新しく達成した ID を返し、あれば保存する。
func judge_move(stats, date: String) -> Array:
	var fresh := _add_achievements(Ach.judge(stats, _ctx(), false), date)
	if not fresh.is_empty():
		write()
	return fresh


# ラン終了時の記録(§9.10)。結果: {new_achievements, title_before, title_after, new_unlocks, attempt}
func finish_run(stats, date: String, day_no: int) -> Dictionary:
	var t: Dictionary = data["totals"]
	var title_before := Progress.title_rank(t["total_score"])
	var unlocked_before := Progress.unlocked(data["achievements"], t["total_score"])
	var attempt := 0
	if stats.mode == "daily":
		var e = data["daily"].get(date)
		if e == null:
			e = {"no": day_no, "attempts": 0, "score": stats.score, "cleared": stats.cleared, "draws": stats.draws, "best_streak": stats.best_streak}
			data["daily_days"] += 1
			data["daily_streak"] = DayIndex.next_streak(data["daily_streak"], date)
		e["attempts"] += 1
		attempt = e["attempts"]
		data["daily"][date] = e
		data["daily"] = Codec.trim_daily(data["daily"])
	if stats.counts_for_records():
		t["runs"] += 1
		t["clears"] += 1 if stats.cleared else 0
		t["total_score"] += stats.score
		t["best_score"] = maxi(t["best_score"], stats.score)
		t["best_streak"] = maxi(t["best_streak"], stats.best_streak)
		t["hits"] += stats.hits
		t["misses"] += stats.misses
		t["same_hits"] += stats.same_hits
		t["banks"] += stats.banks
		t["longshot_hits"] += stats.longshot_hits
		var entry := {"score": stats.score, "cleared": stats.cleared, "draws": stats.draws, "date": date, "mode": stats.mode}
		data["top_runs"] = Codec.insert_top(data["top_runs"], entry)
	if stats.mode == "run" or stats.mode == "daily":
		data["current_daily" if stats.mode == "daily" else "current_run"] = null
	var fresh := _add_achievements(Ach.judge(stats, _ctx(), true), date)
	var unlocked_after := Progress.unlocked(data["achievements"], t["total_score"])
	var new_unlocks := unlocked_after.filter(func(id): return not id in unlocked_before)
	write()
	return {"new_achievements": fresh, "title_before": title_before, "title_after": Progress.title_rank(t["total_score"]), "new_unlocks": new_unlocks, "attempt": attempt}


func export_text() -> String:
	return Codec.to_export(data)


# 読み込み(FR-25)。通ったときだけ置き換える。確かめの表示は画面の側で行う。
func import_text(text: String) -> bool:
	var res := Codec.from_export(text)
	if not res["ok"]:
		return false
	data = res["data"]
	write()
	return true


# 消去(FR-26)。名前は新しく決める。
func erase_all() -> void:
	data = Codec.defaults(Codec.default_name(randi_range(0, 99)))
	write()
