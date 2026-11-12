# 保存データの既定値・検査・書き出し用の文字列化(§9.10・INV-14)。ファイルの読み書きは save/save_store.gd。
# 型や範囲が違う項目はその項目だけ既定値に戻し、version が 1 でないか読めないときは全体を既定値にする。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Ach := preload("res://core/achievements.gd")
const Progress := preload("res://core/progress.gd")
const DayIndex := preload("res://core/day_index.gd")

const VERSION := 1
const EXPORT_PREFIX := "LL1."
const TOTAL_KEYS := ["runs", "clears", "total_score", "best_score", "best_streak", "hits", "misses", "same_hits", "banks", "longshot_hits"]
const MODES := ["run", "daily", "versus"]
const RUN_KEYS := ["mode", "seed_text", "date", "actions", "counter_shown"]
const SEED_TEXT_MAX := 64
# 追補 1 §8: [項目, 上限, 既定値]。下限はどれも 0
const CASINO_KEYS := [
	["wallet", B.WALLET_MAX, B.WALLET_START], ["wallet_peak", B.WALLET_MAX, B.WALLET_START], ["refills", B.SAVE_INT_MAX, 0],
	["bj_hands", B.SAVE_INT_MAX, 0], ["bj_wins", B.SAVE_INT_MAX, 0], ["bj_naturals", B.SAVE_INT_MAX, 0],
	["pk_hands", B.SAVE_INT_MAX, 0], ["pk_paid", B.SAVE_INT_MAX, 0], ["pk_best", 9, 0],
]


static func default_name(two_digits: int) -> String:
	return S.DEFAULT_NAME + "%02d" % (absi(two_digits) % 100)


static func defaults(name: String = "") -> Dictionary:
	var totals := {}
	for k in TOTAL_KEYS:
		totals[k] = 0
	var casino := {}
	for k in CASINO_KEYS:
		casino[k[0]] = k[2]
	return {
		"casino": casino,
		"version": VERSION,
		"tutorial_done": false,
		"settings": {
			"bgm_volume": 5, "sfx_volume": 7, "name": name if is_valid_name(name) else default_name(0),
			"fx": "full", "speed": "normal", "counter": true, "card_back": "B-01", "table": "T-01",
		},
		"totals": totals,
		"top_runs": [],
		"achievements": {},
		"daily": {},
		"daily_days": 0,
		"daily_streak": {"last": "", "count": 0},
		"current_run": null,
		"current_daily": null,
	}


# 1〜8 文字で、制御文字と改行を含まない(§9.10・§9.15 の検査と同じ)。
static func is_valid_name(v) -> bool:
	if not v is String or v.length() < 1 or v.length() > 8:
		return false
	for i in v.length():
		var c: int = v.unicode_at(i)
		if c < 0x20 or c == 0x7F or c == 0x2028 or c == 0x2029:
			return false
	return true


# JSON の数は小数で読まれるので、整数の値なら int にする。範囲の外や整数でない物は null。
static func as_int(v, lo: int, hi: int):
	var n: int
	if v is int:
		n = v
	elif v is float and v == int(v) and absf(v) <= B.SAVE_INT_MAX:
		n = int(v)
	else:
		return null
	return n if n >= lo and n <= hi else null


static func _int_or(v, lo: int, hi: int, fallback: int) -> int:
	var n = as_int(v, lo, hi)
	return fallback if n == null else n


static func _bool_or(v, fallback: bool) -> bool:
	return v if v is bool else fallback


static func _pick(v, choices: Array, fallback: String) -> String:
	return v if v is String and v in choices else fallback


static func _dict(v) -> Dictionary:
	return v if v is Dictionary else {}


static func is_valid_actions(v) -> bool:
	if not v is String or v.length() > B.ACTIONS_MAX:
		return false
	for i in v.length():
		if not v[i] in ["H", "L", "S", "B"]:
			return false
	return true


# 途中のラン(current_run / current_daily)。キーは RUN_KEYS の 5 つだけにする(INV-4・AC-20)。
static func sanitize_run(v, mode: String):
	if not v is Dictionary:
		return null
	var date = v.get("date")
	var seed_value = v.get("seed_text")
	if v.get("mode") != mode or not date is String or not DayIndex.is_date(date):
		return null
	if not seed_value is String or seed_value.is_empty() or seed_value.length() > SEED_TEXT_MAX:
		return null
	if mode == "daily" and seed_value != DayIndex.daily_seed_text(date):
		return null
	if not is_valid_actions(v.get("actions")) or not v.get("counter_shown") is bool:
		return null
	return {"mode": mode, "seed_text": seed_value, "date": date, "actions": v["actions"], "counter_shown": v["counter_shown"]}


static func _top_entry(v):
	if not v is Dictionary:
		return null
	var score = as_int(v.get("score"), 0, B.SAVE_INT_MAX)
	var draws = as_int(v.get("draws"), 0, 51)
	var date = v.get("date")
	if score == null or draws == null or not v.get("cleared") is bool or not date is String or not DayIndex.is_date(date):
		return null
	if not v.get("mode") in MODES:
		return null
	return {"score": score, "cleared": v["cleared"], "draws": draws, "date": date, "mode": v["mode"]}


# 得点の大きい順。同点は先に出た方が上(安定な挿入)。
static func insert_top(list: Array, entry: Dictionary) -> Array:
	var out := list.duplicate()
	var i := 0
	while i < out.size() and out[i]["score"] >= entry["score"]:
		i += 1
	out.insert(i, entry)
	return out.slice(0, B.TOP_RUNS)


static func _daily_entry(v):
	if not v is Dictionary:
		return null
	var e := {
		"no": as_int(v.get("no"), -B.SAVE_INT_MAX, B.SAVE_INT_MAX),
		"attempts": as_int(v.get("attempts"), 1, B.SAVE_INT_MAX),
		"score": as_int(v.get("score"), 0, B.SAVE_INT_MAX),
		"draws": as_int(v.get("draws"), 0, 51),
		"best_streak": as_int(v.get("best_streak"), 0, 51),
	}
	if e.values().has(null) or not v.get("cleared") is bool:
		return null
	e["cleared"] = v["cleared"]
	return e


# 新しい日付から DAILY_KEEP 件だけ残す。
static func trim_daily(daily: Dictionary) -> Dictionary:
	var keys := daily.keys()
	keys.sort()
	keys.reverse()
	var out := {}
	for k in keys.slice(0, B.DAILY_KEEP):
		out[k] = daily[k]
	return out


# 結果: {data, broken}。broken は全体を既定値にしたとき真(E-7)。
static func sanitize(raw) -> Dictionary:
	if not raw is Dictionary or as_int(raw.get("version"), VERSION, VERSION) == null:
		return {"data": defaults(), "broken": true}
	var d := defaults()
	d["tutorial_done"] = _bool_or(raw.get("tutorial_done"), false)

	var rt := _dict(raw.get("totals"))
	for k in TOTAL_KEYS:
		d["totals"][k] = _int_or(rt.get(k), 0, B.SAVE_INT_MAX, 0)

	# 追補 1・E-A6: casino の無い古い保存データには既定値が入る
	var rc := _dict(raw.get("casino"))
	for k in CASINO_KEYS:
		d["casino"][k[0]] = _int_or(rc.get(k[0]), 0, k[1], k[2])

	for id in _dict(raw.get("achievements")):
		var date = raw["achievements"][id]
		if id in Ach.DEFS and date is String and DayIndex.is_date(date):
			d["achievements"][id] = date

	var tops := []
	var rtop = raw.get("top_runs")
	if rtop is Array:
		for v in rtop:
			var e = _top_entry(v)
			if e != null:
				tops = insert_top(tops, e)
	d["top_runs"] = tops

	var daily := {}
	for date in _dict(raw.get("daily")):
		var e = _daily_entry(raw["daily"][date])
		if date is String and DayIndex.is_date(date) and e != null:
			daily[date] = e
	d["daily"] = trim_daily(daily)
	d["daily_days"] = _int_or(raw.get("daily_days"), 0, B.SAVE_INT_MAX, 0)
	var rs := _dict(raw.get("daily_streak"))
	var last = rs.get("last")
	if last is String and DayIndex.is_date(last):
		d["daily_streak"] = {"last": last, "count": _int_or(rs.get("count"), 0, B.SAVE_INT_MAX, 0)}

	var st := _dict(raw.get("settings"))
	var ds: Dictionary = d["settings"]
	ds["bgm_volume"] = _int_or(st.get("bgm_volume"), 0, 10, ds["bgm_volume"])
	ds["sfx_volume"] = _int_or(st.get("sfx_volume"), 0, 10, ds["sfx_volume"])
	if is_valid_name(st.get("name")):
		ds["name"] = st["name"]
	ds["fx"] = _pick(st.get("fx"), ["full", "lite"], "full")
	ds["speed"] = _pick(st.get("speed"), ["normal", "fast"], "normal")
	ds["counter"] = _bool_or(st.get("counter"), true)
	var total: int = d["totals"]["total_score"]
	for key in ["card_back", "table"]:
		var id = st.get(key)
		if id is String and Progress.is_unlocked(id, d["achievements"], total) and (id.begins_with("B-") == (key == "card_back")):
			ds[key] = id

	d["current_run"] = sanitize_run(raw.get("current_run"), "run")
	d["current_daily"] = sanitize_run(raw.get("current_daily"), "daily")
	return {"data": d, "broken": false}


# 書き出しの文字列(FR-25)。途中のランは含めない。
static func to_export(data: Dictionary) -> String:
	var copy := data.duplicate(true)
	copy["current_run"] = null
	copy["current_daily"] = null
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(copy))


# 読み込み(FR-25・E-8)。{ok, data}。先頭・Base64・JSON・version の検査を通ったときだけ ok。
static func from_export(text: String) -> Dictionary:
	var t := text.strip_edges()
	if not t.begins_with(EXPORT_PREFIX):
		return {"ok": false}
	var body := t.substr(EXPORT_PREFIX.length())
	var re := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if body.length() % 4 != 0 or re.search(body) == null:
		return {"ok": false}
	var json := JSON.new()
	if json.parse(Marshalls.base64_to_utf8(body)) != OK:
		return {"ok": false}
	var res := sanitize(json.data)
	if res["broken"]:
		return {"ok": false}
	var data: Dictionary = res["data"]
	data["current_run"] = null
	data["current_daily"] = null
	return {"ok": true, "data": data}
