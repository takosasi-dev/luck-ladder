# 自前のテストランナー(D-19)。godot --headless --script res://tests/run_tests.gd で動かす。
# test_ で始まる関数を順に呼び、空文字なら成功、それ以外は失敗の理由。1 件でも失敗なら終了コード 1。
extends SceneTree

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Rng := preload("res://core/rng.gd")
const Deck := preload("res://core/deck.gd")
const RunState := preload("res://core/run_state.gd")
const RunStats := preload("res://core/run_stats.gd")
const Ach := preload("res://core/achievements.gd")
const Progress := preload("res://core/progress.gd")
const DayIndex := preload("res://core/day_index.gd")
const ShareText := preload("res://core/share_text.gd")
const Codec := preload("res://core/save_codec.gd")
const SaveStore := preload("res://save/save_store.gd")
const Fx := preload("res://tests/fixtures.gd")

const FONT_PATH := "res://assets/fonts/NotoSansJP-Variable.ttf"
const STRINGS_PATH := "res://core/strings.gd"
const TEST_SAVE := "user://ll_test_save.json"


# AC-28: 書けない保存先の代わり。
class FailStore extends SaveStore:
	func _write_to(_file_path: String, _text: String) -> bool:
		return false


func _initialize() -> void:
	var failed := 0
	var total := 0
	for m in get_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		total += 1
		var t0 := Time.get_ticks_msec()
		var err: String = call(name)
		var ms := Time.get_ticks_msec() - t0
		if err == "":
			print("PASS %s (%d ms)" % [name, ms])
		else:
			failed += 1
			printerr("FAIL ", name, ": ", err)
	print("%d passed, %d failed" % [total - failed, failed])
	quit(1 if failed > 0 or total == 0 else 0)


# ---- 共通の道具 ----

func _texts(v, out: Array) -> void:
	if v is String:
		out.append(v)
	elif v is Array:
		for e in v:
			_texts(e, out)
	elif v is Dictionary:
		for k in v:
			_texts(k, out)
			_texts(v[k], out)


# §9.4 の打ち方 P1・P2。
func _policy(name: String, st) -> String:
	var c: Array = st.counts()
	if st.pot >= 800:
		return "B"
	if name == "P2" and st.pot == 0 and st.lives >= 2 and c[2] >= 2:
		return "S"
	if c[0] >= c[1] and c[0] > 0:
		return "H"
	if c[1] > 0:
		return "L"
	return "S"


# 打ち方でランを最後まで進める。[state, stats]
func _play(policy: String, seed_text: String, mode: String = "run", first_daily: bool = false) -> Array:
	var st = RunState.new(seed_text)
	var stats = RunStats.new(mode, first_daily)
	while st.ended == "":
		var a := _policy(policy, st)
		stats.note_counter(true)
		if a == "B":
			stats.on_bank(st.bank(), st)
		else:
			stats.on_guess(st.guess(a), st)
	return [st, stats]


func _ordered_deck(head: Array = []) -> PackedInt32Array:
	var d := PackedInt32Array(head)
	for i in 52:
		if not i in head:
			d.append(i)
	return d


func _stats_with(fields: Dictionary):
	var s = RunStats.new()
	for k in fields:
		s.set(k, fields[k])
	return s


func _fresh_store(store_path: String = TEST_SAVE):
	for p in [store_path, store_path.get_basename() + ".broken.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	return SaveStore.new(store_path)


func _write_raw(store_path: String, text: String) -> void:
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ---- Phase 0 ----

# AC-18: strings.gd の全文字と ASCII の印字可能文字を、同梱フォントが持つ。
func test_font_covers_strings_and_ascii() -> String:
	var font: Font = load(FONT_PATH)
	if font == null:
		return "cannot load font: " + FONT_PATH
	var codes := {}
	for c in range(0x20, 0x7F):
		codes[c] = true
	var texts := []
	_texts(load(STRINGS_PATH).get_script_constant_map().values(), texts)
	for t in texts:
		for i in t.length():
			codes[t.unicode_at(i)] = true
	var missing := PackedStringArray()
	for c in codes:
		if not font.has_char(c):
			missing.append("U+%04X" % c)
	return "" if missing.is_empty() else "missing glyphs: " + ", ".join(missing)


# AC-5: §9.2 の固定値 5 行。
func test_rng_fixed_values() -> String:
	for k in Fx.FNV:
		if Rng.fnv1a(k) != Fx.FNV[k]:
			return "FNV-1a(%s) = %d" % [k, Rng.fnv1a(k)]
	var r := Rng.new(1)
	var got := []
	for i in 5:
		got.append(r.next())
	if got != Fx.XORSHIFT_SEED1:
		return "xorshift32 seed 1: " + str(got)
	if Rng.new(0).state != 1:
		return "seed 0 must become 1"
	return ""


# AC-5: §9.3 の固定値 4 行(先頭 10 枚の番号と数字、検査値)と、0〜51 を 1 つずつ含むこと。
func test_deck_fixed_values() -> String:
	for row in Fx.DECKS:
		var d := Deck.shuffled(row[0])
		var ids := []
		var ranks := []
		for i in 10:
			ids.append(d[i])
			ranks.append(Deck.rank(d[i]))
		if ids != row[1]:
			return "%s ids %s" % [row[0], str(ids)]
		if ranks != row[2]:
			return "%s ranks %s" % [row[0], str(ranks)]
		if Deck.checksum(d) != row[3]:
			return "%s checksum %d" % [row[0], Deck.checksum(d)]
		var sorted := Array(d)
		sorted.sort()
		if sorted != range(52):
			return "%s is not a permutation of 0..51" % row[0]
	return ""


func test_card_rank_and_suit() -> String:
	var cases := [[0, 1, 0], [12, 13, 0], [13, 1, 1], [25, 13, 1], [26, 1, 2], [51, 13, 3]]
	for c in cases:
		if Deck.rank(c[0]) != c[1] or Deck.suit(c[0]) != c[2]:
			return "card %d -> rank %d suit %d" % [c[0], Deck.rank(c[0]), Deck.suit(c[0])]
	return ""


# ---- Phase 1: ラン ----

# AC-6: §9.4 の quote の固定値。
func test_quote_fixed_values() -> String:
	for q in Fx.QUOTES:
		var got := RunState.quote_value(q[0], q[1], q[2])
		if got != q[3]:
			return "quote(n=%d, w=%d, streak=%d) = %d, want %d" % [q[0], q[1], q[2], got, q[3]]
	return ""


# AC-7: 通しのラン 5 行が、表の全項目で一致する。
func test_policy_runs() -> String:
	for r in Fx.RUNS:
		var res := _play(r[0], r[1])
		var st = res[0]
		var s = res[1]
		var got := [st.ended, st.score, s.draws, s.hits, s.misses, s.same_hits, s.banks, s.best_streak, st.lives]
		var want: Array = r.slice(2)
		if got != want:
			return "%s %s: got %s want %s" % [r[0], r[1], str(got), str(want)]
	return ""


# AC-8: 操作の列からの復元。
func test_replay() -> String:
	var r1 := RunState.replay("LL1:test:2", "LLLLLH")
	if not r1["ok"] or r1["state"].score != 0 or r1["state"].ended != "gameover":
		return "replay test:2"
	var r2 := RunState.replay("LL1:test:6", "SBSSSHLHHH")
	if not r2["ok"] or r2["state"].score != 5000 or r2["state"].ended != "gameover":
		return "replay test:6"
	var played = _play("P1", "LL1:test:1")[0]
	var r3 := RunState.replay("LL1:test:1", played.actions)
	if not r3["ok"] or r3["state"].score != 2720:
		return "replay of P1 test:1 actions: " + played.actions
	var r4 := RunState.replay("LL1:test:1", "H".repeat(60))
	if r4["ok"]:
		return "60 x H must fail"
	return ""


# AC-9: guess の境界。
func test_guess_boundaries() -> String:
	# 今の札が K: HIGH は当たりが 0 枚で invalid、状態を変えない
	var st = RunState.new("x", _ordered_deck([12, 0]))
	if st.guess("H")["result"] != "invalid" or st.pos != 1 or st.actions != "" or st.quote("H") != 0:
		return "K + HIGH must be invalid"
	# 同じ数字: HIGH は外れ、同じ は当たり
	st = RunState.new("x", _ordered_deck([0, 13]))
	if st.guess("H")["result"] != "miss":
		return "HIGH on same rank must miss"
	st = RunState.new("x", _ordered_deck([0, 13]))
	if st.guess("S")["result"] != "hit":
		return "SAME on same rank must hit"
	# 連続 3・6・9 でライフが戻り、4 のときは増えない
	st = RunState.new("x", _ordered_deck())
	st.lives = 1
	var want_lives := {3: 2, 6: 3, 9: 4, 12: 4}
	for i in range(1, 13):
		var res: Dictionary = st.guess("H")
		if res["result"] != "hit":
			return "ordered deck HIGH #%d not hit" % i
		if want_lives.has(i) and st.lives != want_lives[i]:
			return "after streak %d lives %d" % [i, st.lives]
	# ライフ 1 で外すと gameover、その後は invalid
	st = RunState.new("x", _ordered_deck([0, 13]))
	st.lives = 1
	if st.guess("H")["ended"] != "gameover":
		return "miss with 1 life must end"
	if st.guess("L")["result"] != "invalid" or st.bank()["result"] != "invalid":
		return "actions after gameover must be invalid"
	# 残り札の数の合計と hi + lo + sa が n に等しい
	st = RunState.new("LL1:test:2")
	for a in ["L", "L", "L"]:
		var c: Array = st.counts()
		var total := 0
		for v in st.rank_counts():
			total += v
		if c[0] + c[1] + c[2] != st.remaining() or total != st.remaining():
			return "counts do not add up to n"
		st.guess(a)
	st = RunState.new("LL1:test:2")
	if st.rank_counts()[11] != 3 or st.counts()[2] != 3:
		return "test:2 start: Q column %d sa %d" % [st.rank_counts()[11], st.counts()[2]]
	return ""


# AC-10: bank の境界。
func test_bank_boundaries() -> String:
	var st = RunState.new("x", _ordered_deck())
	if st.bank()["result"] != "invalid":
		return "bank with pot 0 must be invalid"
	st.guess("H")
	st.guess("H")
	if st.streak != 2 or st.pot == 0:
		return "setup failed"
	var pot: int = st.pot
	var res: Dictionary = st.bank()
	if res["result"] != "banked" or res["amount"] != pot or st.score != pot or st.pot != 0 or st.streak != 0:
		return "bank result " + str(res)
	if st.quote("H") != RunState.quote_value(st.remaining(), st.counts()[0], 0):
		return "multiplier after bank must be 1.0"
	return ""


# 完走の加点(FR-9・§9.4): 残り 0 枚で、ポット + 3,000 + ライフ × 1,000。
func test_clear_bonus() -> String:
	var res := _play("P1", "LL1:test:14")
	var st = res[0]
	if st.ended != "clear" or st.pot != 0 or st.remaining() != 0:
		return "test:14 must clear with empty pot"
	return ""


# AC-11: §9.5 の固定値と連続日数。
func test_day_index() -> String:
	for r in Fx.DAY_NOS:
		if DayIndex.day_no(r[0], r[1], r[2]) != r[3]:
			return "day_no %s = %d" % [str(r), DayIndex.day_no(r[0], r[1], r[2])]
	if DayIndex.daily_seed_text(DayIndex.date_string(2026, 11, 11)) != "LL1:daily:2026-11-11":
		return "daily seed text"
	var s := {"last": "2026-11-10", "count": 4}
	if DayIndex.next_streak(s, "2026-11-11") != {"last": "2026-11-11", "count": 5}:
		return "yesterday -> +1"
	if DayIndex.next_streak({"last": "2026-11-11", "count": 4}, "2026-11-11")["count"] != 4:
		return "today -> unchanged"
	if DayIndex.next_streak({"last": "2026-11-09", "count": 4}, "2026-11-11")["count"] != 1:
		return "2 days ago -> 1"
	if DayIndex.next_streak({"last": "2026-12-31", "count": 2}, "2027-01-01")["count"] != 3:
		return "year boundary"
	if DayIndex.next_streak({"last": "", "count": 0}, "2026-11-11")["count"] != 1:
		return "first time -> 1"
	return ""


# ---- Phase 1: 実績・称号・解放 ----

# AC-12: 実績 35 個を、ちょうど満たす値と 1 だけ足りない値で判定する。
# [ID, ラン終了時か, 満たす集計値, 足りない集計値, 満たす ctx, 足りない ctx, 足りない側のラン終了時]
func test_achievement_thresholds() -> String:
	var cleared := {"cleared": true}
	var vs := {"mode": "versus", "versus_done": true}
	var cases := [
		["A-01", true, {}, {}, {}, {}, false],
		["A-02", false, {"banks": 1}, {"banks": 0}],
		["A-03", false, {"best_streak": 3}, {"best_streak": 2}],
		["A-04", false, {"best_streak": 5}, {"best_streak": 4}],
		["A-05", false, {"best_streak": 8}, {"best_streak": 7}],
		["A-06", false, {"best_streak": 12}, {"best_streak": 11}],
		["A-07", false, {"longshot_hits": 1}, {"longshot_hits": 0}],
		["A-08", true, {}, {}, {"totals": {"longshot_hits": 25}}, {"totals": {"longshot_hits": 24}}],
		["A-09", false, {"max_gain": 3000}, {"max_gain": 2999}],
		["A-10", false, {"banks": 5}, {"banks": 4}],
		["A-11", false, {"max_bank": 3000}, {"max_bank": 2999}],
		["A-12", false, {"max_bank": 8000}, {"max_bank": 7999}],
		["A-13", true, cleared, {"cleared": false}],
		["A-14", true, {"cleared": true, "end_lives": 4}, {"cleared": true, "end_lives": 3}],
		["A-15", true, {"cleared": true, "misses": 6}, {"cleared": true, "misses": 7}],
		["A-16", true, {"score": 3000}, {"score": 2999}],
		["A-17", true, {"score": 10000}, {"score": 9999}],
		["A-18", true, {"score": 20000}, {"score": 19999}],
		["A-19", true, {"cleared": true, "counter_shown": false}, {"cleared": true, "counter_shown": true}],
		["A-20", false, {"comeback": true}, {"comeback": false}],
		["A-21", false, {"life_regains": 3}, {"life_regains": 2}],
		["A-22", false, {"same_hits": 1}, {"same_hits": 0}],
		["A-23", true, {"mode": "daily", "first_daily": true}, {"mode": "run"}],
		["A-24", true, {}, {}, {"daily_streak": 7}, {"daily_streak": 6}],
		["A-25", true, {}, {}, {"daily_days": 30}, {"daily_days": 29}],
		["A-26", true, {}, {}, {"totals": {"runs": 50}}, {"totals": {"runs": 49}}],
		["A-27", true, {}, {}, {"totals": {"runs": 200}}, {"totals": {"runs": 199}}],
		["A-28", true, {}, {}, {"totals": {"total_score": 100000}}, {"totals": {"total_score": 99999}}],
		["A-29", true, {}, {}, {"totals": {"total_score": 1000000}}, {"totals": {"total_score": 999999}}],
		["A-30", false, {"sure_misses": 1}, {"sure_misses": 0}],
		["A-31", false, {"max_pot_lost": 5000}, {"max_pot_lost": 4999}],
		["A-32", false, {"same_hits": 2}, {"same_hits": 1}],
		["A-33", true, vs, {"mode": "versus", "versus_done": false}],
		["A-34", true, {"mode": "versus", "versus_done": true, "versus_players": 2, "versus_solo_first": true}, {"mode": "versus", "versus_done": true, "versus_players": 2, "versus_solo_first": false}],
		["A-34", true, {"mode": "versus", "versus_done": true, "versus_players": 2, "versus_solo_first": true}, {"mode": "versus", "versus_done": true, "versus_players": 1, "versus_solo_first": true}],
		["A-35", true, {"mode": "versus", "versus_done": true, "versus_players": 4, "versus_solo_first": true}, {"mode": "versus", "versus_done": true, "versus_players": 3, "versus_solo_first": true}],
		# ラン終了時だけの条件は、1 手ごとの呼び出しでは満たさない
		["A-13", true, cleared, cleared, {}, {}, false],
		["A-16", true, {"score": 3000}, {"score": 3000}, {}, {}, false],
	]
	var seen := {}
	var checked := 0
	for c in cases:
		var ok_ctx: Dictionary = c[4] if c.size() > 4 else {}
		var ng_ctx: Dictionary = c[5] if c.size() > 5 else {}
		var ng_end: bool = c[6] if c.size() > 6 else c[1]
		if not c[0] in Ach.judge(_stats_with(c[2]), ok_ctx, c[1]):
			return "%s should be met with %s %s" % [c[0], str(c[2]), str(ok_ctx)]
		if c[0] in Ach.judge(_stats_with(c[3]), ng_ctx, ng_end):
			return "%s should not be met with %s %s" % [c[0], str(c[3]), str(ng_ctx)]
		seen[c[0]] = true
		checked += 2
	if seen.size() != 35 or checked < 70:
		return "covered %d ids, %d checks" % [seen.size(), checked]
	# 今日の山札の 2 回目からは、どの実績にも数えない(D-9)
	var second = _stats_with({"mode": "daily", "first_daily": false, "banks": 5, "best_streak": 12, "score": 30000})
	if not Ach.judge(second, {"totals": {"runs": 999}}, true).is_empty():
		return "second daily attempt must not count"
	return ""


func test_achievement_ids() -> String:
	var want := []
	for i in range(1, 36):
		want.append("A-%02d" % i)
	if Ach.ids() != want:
		return "ids " + str(Ach.ids())
	if S.ACHIEVEMENTS.keys() != want:
		return "strings.gd ACHIEVEMENTS keys differ"
	for id in want:
		if Ach.is_hidden(id) != (id in ["A-30", "A-31", "A-32"]):
			return "hidden flag " + id
	return ""


# AC-13: 称号と解放。
func test_titles_and_unlocks() -> String:
	var titles := [[0, 1], [4999, 1], [5000, 2], [1999999, 9], [2000000, 10]]
	for t in titles:
		if Progress.title_rank(t[0]) != t[1]:
			return "title_rank(%d) = %d" % [t[0], Progress.title_rank(t[0])]
	if S.TITLES.size() != 10:
		return "10 titles"
	var many := {}
	for i in range(1, 24):
		many["A-%02d" % i] = "2026-11-11"
	var many_plus := many.duplicate()
	many_plus["A-24"] = "2026-11-11"
	# [ID, 条件前の実績, 条件前の通算, 条件後の実績, 条件後の通算]
	var cases := [
		["B-01", {}, 0, {}, 0], ["B-02", {}, 0, {}, 0], ["T-01", {}, 0, {}, 0],
		["B-03", {}, 0, {"A-04": "d"}, 0], ["B-04", {}, 0, {"A-13": "d"}, 0],
		["B-05", {}, 19999, {}, 20000], ["B-06", {}, 0, {"A-24": "d"}, 0],
		["B-07", {}, 0, {"A-17": "d"}, 0], ["B-08", many, 0, many_plus, 0],
		["T-02", {}, 4999, {}, 5000], ["T-03", {}, 49999, {}, 50000],
		["T-04", {}, 199999, {}, 200000], ["T-05", {}, 0, {"A-14": "d"}, 0],
	]
	for c in cases:
		var start: bool = Progress.BACKS.get(c[0], Progress.TABLES.get(c[0]))[0] == "start"
		if not start and Progress.is_unlocked(c[0], c[1], c[2]):
			return c[0] + " unlocked too early"
		if not Progress.is_unlocked(c[0], c[3], c[4]):
			return c[0] + " not unlocked"
	if Progress.BACKS.size() != 8 or Progress.TABLES.size() != 5:
		return "8 backs and 5 tables"
	return ""


# ---- Phase 1: 共有テキスト ----

# AC-17: §9.11 の形。日本語の部分は strings.gd の定数から組む(AC-19)。
func test_share_text() -> String:
	if ShareText.group(0) != "0" or ShareText.group(999) != "999" or ShareText.group(1000) != "1,000" or ShareText.group(1234567) != "1,234,567":
		return "group"
	var d1 := ShareText.build("daily", 315, "2026-11-11", 1, 2720, false, 30, 4, "")
	var want1 := "LuckLadder %s No.315 (2026-11-11) %s\n%s" % [S.SHARE_DAILY, S.SHARE_FIRST, S.SHARE_LINE % ["2,720", 30, 4]]
	if d1 != want1:
		return "daily first: " + d1
	var d2 := ShareText.build("daily", 315, "2026-11-11", 2, 2720, false, 30, 4, "")
	if d2.split("\n")[0] != "LuckLadder %s No.315 (2026-11-11) %s" % [S.SHARE_DAILY, S.SHARE_NTH % 2]:
		return "daily second: " + d2
	var r := ShareText.build("run", 315, "2026-11-11", 1, 13225, true, 51, 6, "https://example.github.io/luck-ladder/")
	var want3 := "LuckLadder %s\n%s%s\nhttps://example.github.io/luck-ladder/" % [S.SHARE_RUN, S.SHARE_CLEAR, S.SHARE_LINE % ["13,225", 51, 6]]
	if r != want3:
		return "run clear: " + r
	if not S.SHARE_LINE.begins_with("%s") or not S.SHARE_NTH.begins_with("%d"):
		return "share format strings"
	return ""


# ---- Phase 1: 保存 ----

# AC-14: 保存の流れ。
func test_save_store_flow() -> String:
	var store = _fresh_store()
	var s = _play("P1", "LL1:test:1")[1]
	store.save_current("run", "LL1:test:1", "2026-11-11", "LLH", true)
	store.finish_run(s, "2026-11-11", 315)
	store = SaveStore.new(TEST_SAVE)
	if store.data["totals"]["runs"] != 1 or store.data["current_run"] != null:
		return "after one run: " + str(store.data["totals"])
	store.save_current("run", "LLR:1:2", "2026-11-11", "HL", true)
	store.save_current("daily", "LL1:daily:2026-11-11", "2026-11-11", "S", false)
	store = SaveStore.new(TEST_SAVE)
	if store.current("run") == null or store.current("daily") == null:
		return "run and daily in progress at the same time"
	store.drop_stale_daily("2026-11-12")
	if store.current("daily") != null or store.current("run") == null:
		return "stale daily must be dropped"
	for i in range(1, 12):
		store.finish_run(_play("P1", "LL1:test:%d" % i)[1], "2026-11-11", 315)
	var tops: Array = store.data["top_runs"]
	if tops.size() != 10:
		return "top_runs size %d" % tops.size()
	for i in range(1, tops.size()):
		if tops[i - 1]["score"] < tops[i]["score"]:
			return "top_runs not sorted"
	# 今日の山札: 初回と 2 回目
	store = _fresh_store()
	var first = _play("P1", "LL1:daily:2026-11-11", "daily", true)[1]
	store.finish_run(first, "2026-11-11", 315)
	var e: Dictionary = store.data["daily"]["2026-11-11"]
	if e["attempts"] != 1 or e["score"] != first.score or store.data["daily_days"] != 1 or store.data["daily_streak"]["count"] != 1:
		return "first daily: " + str(e)
	var totals_before: Dictionary = store.data["totals"].duplicate()
	var ach_before: Dictionary = store.data["achievements"].duplicate()
	var tops_before: Array = store.data["top_runs"].duplicate(true)
	var second = _play("P2", "LL1:daily:2026-11-11", "daily", false)[1]
	var res: Dictionary = store.finish_run(second, "2026-11-11", 315)
	e = store.data["daily"]["2026-11-11"]
	if e["attempts"] != 2 or e["score"] != first.score or res["attempt"] != 2:
		return "second daily: " + str(e)
	if store.data["totals"] != totals_before or store.data["achievements"] != ach_before or store.data["top_runs"] != tops_before:
		return "second daily changed records"
	if store.data["daily_days"] != 1:
		return "daily_days counted twice"
	return ""


# 結果画面のための戻り値: 新しい実績と称号・解放。
func test_finish_run_result() -> String:
	var store = _fresh_store()
	var res: Dictionary = store.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
	for id in ["A-01", "A-02", "A-13", "A-16", "A-17"]:
		if not id in res["new_achievements"]:
			return "missing %s in %s" % [id, str(res["new_achievements"])]
	if res["title_before"] != 1 or res["title_after"] != 2:
		return "title %d -> %d" % [res["title_before"], res["title_after"]]
	for id in ["B-03", "B-04", "B-07", "T-02"]:
		if not id in res["new_unlocks"]:
			return "missing unlock %s in %s" % [id, str(res["new_unlocks"])]
	var again: Dictionary = store.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
	if "A-13" in again["new_achievements"]:
		return "achievement reported twice"
	var s = _stats_with({"best_streak": 5})
	if store.judge_move(s, "2026-11-12") != []:
		return "judge_move must skip achieved ones"
	return ""


# AC-15: 壊れた値は、その項目だけ既定値に戻る。
func test_save_sanitize() -> String:
	_fresh_store()
	_write_raw(TEST_SAVE, "{broken")
	var store = SaveStore.new(TEST_SAVE)
	if store.data["totals"]["runs"] != 0 or not FileAccess.file_exists(TEST_SAVE.get_basename() + ".broken.json"):
		return "broken json must reset and keep a copy"
	if Codec.sanitize({"version": 2, "totals": {"runs": 5}})["broken"] != true:
		return "version 2 must reset"
	var good: Dictionary = Codec.defaults("Alice")
	good["totals"]["runs"] = 3
	var cases := [
		["settings", "sfx_volume", 99, 7],
		["settings", "bgm_volume", -1, 5],
		["settings", "name", "ABCDEFGHI", null],
		["settings", "name", "AB\nC", null],
		["settings", "name", "", null],
		["settings", "card_back", "B-99", "B-01"],
		["settings", "card_back", "B-03", "B-01"],
		["settings", "table", "B-01", "T-01"],
		["settings", "fx", "max", "full"],
	]
	for c in cases:
		var raw: Dictionary = good.duplicate(true)
		raw[c[0]][c[1]] = c[2]
		var res := Codec.sanitize(raw)
		var got = res["data"][c[0]][c[1]]
		if res["broken"] or res["data"]["totals"]["runs"] != 3:
			return "%s.%s must only reset that field" % [c[0], c[1]]
		if c[3] == null:
			if got == c[2] or not Codec.is_valid_name(got):
				return "name %s accepted" % str(c[2]).c_escape()
		elif got != c[3]:
			return "%s.%s = %s" % [c[0], c[1], str(got)]
	var raw2: Dictionary = good.duplicate(true)
	raw2["current_run"] = {"mode": "run", "seed_text": "LLR:1:2", "date": "2026-11-11", "actions": "HXL", "counter_shown": true}
	raw2["achievements"] = {"A-99": "2026-11-11", "A-01": "2026-11-11", "A-02": 5}
	raw2["top_runs"] = [{"score": -1, "cleared": false, "draws": 3, "date": "2026-11-11", "mode": "run"}, {"score": 10.0, "cleared": true, "draws": 51, "date": "2026-11-11", "mode": "run"}]
	raw2["daily"] = {"bad": {}, "2026-11-11": {"no": 315, "attempts": 1, "score": 5, "cleared": false, "draws": 4, "best_streak": 1}}
	var d: Dictionary = Codec.sanitize(raw2)["data"]
	if d["current_run"] != null:
		return "actions HXL must drop current_run"
	if d["achievements"] != {"A-01": "2026-11-11"}:
		return "achievements " + str(d["achievements"])
	if d["top_runs"].size() != 1 or not d["top_runs"][0]["score"] is int:
		return "top_runs " + str(d["top_runs"])
	if d["daily"].keys() != ["2026-11-11"]:
		return "daily " + str(d["daily"])
	# 解放済みの裏面は残る
	var raw3: Dictionary = good.duplicate(true)
	raw3["achievements"] = {"A-04": "2026-11-11"}
	raw3["settings"]["card_back"] = "B-03"
	if Codec.sanitize(raw3)["data"]["settings"]["card_back"] != "B-03":
		return "unlocked card back must stay"
	# 型の違う値で落ちない
	for junk in [null, 5, "x", [], {"version": "1"}, {"version": 1, "settings": [], "totals": "x", "top_runs": {}, "daily": [], "daily_streak": 3}]:
		Codec.sanitize(junk)
	return ""


# AC-16: 書き出しと読み込み。
func test_export_import() -> String:
	var store = _fresh_store()
	store.finish_run(_play("P1", "LL1:test:14")[1], "2026-11-11", 315)
	store.save_current("run", "LLR:1:2", "2026-11-11", "HL", true)
	var text: String = store.export_text()
	if not text.begins_with("LL1."):
		return "prefix"
	var res := Codec.from_export(text)
	var want: Dictionary = store.data.duplicate(true)
	want["current_run"] = null
	if not res["ok"] or res["data"] != want:
		return "round trip differs"
	var before: Dictionary = store.data.duplicate(true)
	for bad in ["abc", "LL1.###", "", "LL1." + Marshalls.utf8_to_base64("[1,2]"), "LL1." + Marshalls.utf8_to_base64("{\"version\":2}")]:
		if store.import_text(bad):
			return "accepted bad import: " + bad
	if store.data != before:
		return "failed import changed data"
	if not store.import_text("  " + text + "\n") or store.data["current_run"] != null:
		return "good import"
	return ""


# AC-20: 途中のランの保存は 5 つのキーだけで、めくっていない札の番号を持たない。
func test_current_run_keys() -> String:
	var store = _fresh_store()
	var st = RunState.new("LL1:test:1")
	st.guess("L")
	st.guess("L")
	store.save_current("run", st.seed_text, "2026-11-11", st.actions, true)
	var raw = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	var keys: Array = raw["current_run"].keys()
	keys.sort()
	var want := Codec.RUN_KEYS.duplicate()
	want.sort()
	if keys != want:
		return "current_run keys " + str(keys)
	var restored := RunState.replay(raw["current_run"]["seed_text"], raw["current_run"]["actions"])
	if not restored["ok"] or restored["state"].pos != st.pos or restored["state"].pot != st.pot:
		return "restore from save"
	return ""


# AC-28 の一部: 保存先に書けなくてもランを終えられる。
func test_unwritable_store() -> String:
	var store = FailStore.new("user://ll_never_written.json")
	if store.writable:
		return "writable must be false"
	store.save_current("run", "LLR:1:2", "2026-11-11", "H", true)
	var res: Dictionary = store.finish_run(_play("P1", "LL1:test:1")[1], "2026-11-11", 315)
	if store.data["totals"]["runs"] != 1 or not "A-01" in res["new_achievements"]:
		return "records must stay in memory"
	return ""


# ---- ソースの決まり ----

# AC-19(INV-1〜INV-3・INV-6・INV-15)。
func test_source_rules() -> String:
	var banned := RegEx.create_from_string("\\b(randi|randf|randomize|RandomNumberGenerator|shuffle|pick_random)\\b|\\bfloat\\(|\\b\\d+\\.\\d+\\b")
	for file in _gd_files("res://core"):
		var m := banned.search(_code_only(file))
		if m:
			return file + " contains " + m.get_string()
	var rule_names := RegEx.create_from_string("\\b(BASE|GAIN_CAP)\\b")
	for file in _gd_files("res://ui"):
		if rule_names.search(_code_only(file)):
			return file + " uses BASE or GAIN_CAP"
	var jp := RegEx.create_from_string("\"[^\"\\n]*[\\x{3040}-\\x{30FF}\\x{4E00}-\\x{9FFF}][^\"\\n]*\"")
	for dir in ["res://core", "res://ui", "res://save", "res://audio", "res://net", "res://tests", "res://tools"]:
		for file in _gd_files(dir):
			if file == STRINGS_PATH:
				continue
			var m := jp.search(_code_only(file))
			if m:
				return file + " has a Japanese literal " + m.get_string()
	# shortcut: Phase 3 で 2 本目(table_bg)を足すまでは 2 本以下で見る。足したら == 2 にする
	var shaders := DirAccess.get_files_at("res://shaders")
	var n := 0
	for f in shaders:
		if f.ends_with(".gdshader"):
			n += 1
	if n > 2:
		return "more than 2 shaders"
	return ""


# コメントを除いた本文(行の # から後を落とす。文字列の中の # は使わない前提)。
func _code_only(file: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(file).split("\n"):
		var i := line.find("#")
		out.append(line if i < 0 else line.substr(0, i))
	return "\n".join(out)


func _gd_files(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	return out
